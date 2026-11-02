// @ts-nocheck
import { pool } from "./db.js";
import { generate, parseJSON } from "./llm.js";

// Laws followed in the "Lois" tab. Source: Tricoteuses "API Parlement" (Assemblée nationale + Sénat
// open data, cleaned; refreshed daily upstream). We keep every government bill in progress (minus
// treaty ratifications) and the members' bills that match stories in the feed.

const API = "https://parlement.tricoteuses.fr";
const LEGISLATURE = 17;
const FULL_WINDOW_DAYS = 120;      // a full sync looks at dossiers active in the last 4 months
const MIN_SYNC_INTERVAL = "10 minutes";
const STORY_WINDOW_DAYS = 45;
const MAX_STORIES_PER_LAW = 6;
/** Summed rarity (IDF) of the shared words: two words seen in under ~0.5 % of stories each. */
const MIN_MATCH_WEIGHT = 10.5;
const SUMMARIES_PER_SYNC = 5;

async function tric(path: string, params: Record<string, string | number> = {}) {
  const url = new URL(path, API);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`Tricoteuses ${res.status} for ${url.pathname}`);
  const body = await res.json();
  return body.data ?? body;
}

// ── Story matching ────────────────────────────────────────────────────────────

const STOPWORDS = new Set([
  "projet", "proposition", "relative", "relatif", "relatives", "relatifs", "visant", "portant",
  "renforcer", "diverses", "dispositions", "mesures", "creer", "creation", "francaise", "francais",
  "nationale", "national", "generale", "general", "publique", "public", "droit", "droits", "matiere",
  "application", "article", "articles", "ordonnance", "mise", "place", "cadre", "ameliorer",
  "amelioration", "lutte", "lutter", "contre", "pour", "dans", "avec", "sein", "leurs", "leur",
  "afin", "certaines", "certains", "ainsi", "entre", "vers", "faire", "permettre", "garantir",
  "assurer", "constitutionnelle", "organique", "republique", "france", "etat", "annee", "loi", "lois",
  "parlement", "europeen", "europeenne", "directive", "transposition", "union", "produits", "commis",
  "lors", "debat", "organisation", "organiser", "renforcement", "prevention", "exercice", "usage",
]);

function stems(text: string): Set<string> {
  return new Set(
    text
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .split(/[^a-z0-9]+/)
      .filter((w) => w.length >= 4 && !STOPWORDS.has(w))
      .map((w) => w.slice(0, 6))
  );
}

/** Story titles about Parliament's work, the only ones a law can be linked to. */
const PARLIAMENTARY = /\b(lois?|législ\w*|parlement\w*|assemblée|sénat\w*|députés?|amendements?|hémicycle|vot(e|é|ée|és|ent|er)|adopt\w*|projet de loi|proposition de loi|PLF|PLFSS|budget|49[.,]3|motion)\b/i;

type StoryRef = { id: string; stems: Set<string>; at: number };

async function recentStories(): Promise<{ stories: StoryRef[]; df: Map<string, number> }> {
  const { rows } = await pool.query(
    `SELECT s.id, s.title, s.last_updated_at
       FROM stories s
      WHERE s.last_updated_at > now() - make_interval(days => $1)
        AND (SELECT count(*) FROM articles a WHERE a.story_id = s.id AND a.is_primary) >= 3`,
    [STORY_WINDOW_DAYS]
  );
  // Word frequencies over every recent story, to tell distinctive words from common ones.
  const df = new Map<string, number>();
  const all = rows.map((r) => ({ id: r.id, title: r.title, stems: stems(r.title), at: new Date(r.last_updated_at).getTime() }));
  for (const s of all) for (const w of s.stems) df.set(w, (df.get(w) ?? 0) + 1);
  const stories = all.filter((s) => PARLIAMENTARY.test(s.title)).map(({ title, ...rest }) => rest);
  return { stories, df: Object.assign(df, { total: all.length }) as any };
}

/**
 * Stories about Parliament that share at least two words with the law's title, weighted by how rare
 * each word is across the feed (inverse document frequency): "victimes" + "enfants" alone never link
 * a law to a crime story, "casseur" + "payeur" do.
 */
function matchStories(title: string, corpus: Awaited<ReturnType<typeof recentStories>>): string[] {
  const words = stems(title);
  if (words.size === 0) return [];
  const total = (corpus.df as any).total || 1;
  const idf = (w: string) => Math.log(total / Math.max(corpus.df.get(w) ?? 1, 1));
  return corpus.stories
    .map((s) => {
      const shared = [...words].filter((w) => s.stems.has(w));
      return { s, score: shared.length, weight: shared.reduce((sum, w) => sum + idf(w), 0) };
    })
    .filter((x) => x.score >= Math.min(2, words.size) && x.weight >= MIN_MATCH_WEIGHT)
    .sort((a, b) => b.weight - a.weight || b.s.at - a.s.at)
    .slice(0, MAX_STORIES_PER_LAW)
    .map((x) => x.s.id);
}

// ── Steps ─────────────────────────────────────────────────────────────────────

const READINGS: Record<string, string> = {
  AN1: "1re lecture", SN1: "1re lecture", AN2: "2e lecture", SN2: "2e lecture",
  AN3: "3e lecture", SN3: "3e lecture", ANNLEC: "Nouvelle lecture", SNNLEC: "Nouvelle lecture",
  ANLDEF: "Lecture définitive", ANLUNI: "Lecture unique", SNLUNI: "Lecture unique",
  CMP: "Commission mixte paritaire", CC: "Conseil constitutionnel", PROM: "Promulgation",
};

function chamberOf(code: string, chambre: string | null): string {
  if (code.startsWith("AN")) return "AN";
  if (code.startsWith("SN")) return "SN";
  if (code === "CMP") return "CMP";
  if (code === "CC") return "CC";
  if (code === "PROM") return "GVT";
  return chambre ?? "AUTRE";
}

const day = (d: string | null) => (d ? d.slice(0, 10) : null);

const SEATS: Record<string, number> = { AN: 577, SN: 348 };

/**
 * Where each parliamentary group sits on the app's five-position scale (1 extrême gauche, 2 gauche,
 * 4 centre, 6 droite, 7 extrême droite; centre-droit counts as droite, centre-gauche as gauche, like the
 * media positions). 0 = unaffiliated. Matched on the group's short name, then on its full name.
 */
function groupLean(abbr: string | null, name: string | null): number {
  const key = `${abbr ?? ""} ${name ?? ""}`.toLowerCase();
  const rules: [RegExp, number][] = [
    [/insoumise|lfi|communiste républicain|crce/, 1],
    [/gauche démocrate|gdr|socialiste|soc\b|\bser\b|écologiste|ecos|gest\b|rdse|radical/, 2],
    [/ensemble pour la république|epr|démocrates|\bdem\b|rdpi|rassemblement des démocrates|liot|libertés, indépendants|union centriste|uci|centriste/, 4],
    [/horizons|hor\b|droite républicaine|\bdr\b|les républicains|indépendants - république|les indépendants/, 6],
    [/rassemblement national|\brn\b|union des droites|udr|union nationale pour les territoires/, 7],
  ];
  for (const [re, lean] of rules) if (re.test(key)) return lean;
  return 0;
}

const organeCache = new Map<string, { abbr: string | null; name: string | null }>();
async function organe(uid: string) {
  if (!organeCache.has(uid)) {
    const o = await tric(`/organes/${uid}`).catch(() => ({}));
    organeCache.set(uid, { abbr: o.libelleAbrege ?? o.libelleAbrev ?? null, name: o.libelle ?? null });
  }
  return organeCache.get(uid)!;
}

/** How each group voted on a scrutin, ordered left to right. */
async function fetchGroups(scrutinUid: string) {
  const rows = await tric("/groupesVotants/json", { scrutinRefUid: scrutinUid, perPage: 40 }).catch(() => []);
  const groups = await Promise.all(
    rows.map(async (g: any) => {
      const o = await organe(g.organeRefUid);
      return {
        name: o.abbr ?? o.name ?? "",
        lean: groupLean(o.abbr, o.name),
        members: g.nombreMembresGroupe ?? 0,
        yes: g.pour ?? 0,
        no: g.contre ?? 0,
        abstained: g.abstentions ?? 0,
      };
    })
  );
  // Far left to far right; unaffiliated members last.
  const order = (l: number) => (l === 0 ? 99 : l);
  return groups.sort((a, b) => order(a.lean) - order(b.lean) || a.name.localeCompare(b.name));
}

/** Final public votes of a dossier, keyed by the step they close (e.g. "AN1-DEC-SCRUTIN"). */
async function fetchVotes(uid: string): Promise<Record<string, any>> {
  const rows = await tric("/scrutins/json", {
    dossierRefUid: uid,
    perPage: 100,
    select: "uid,chambre,dateScrutin,code,codeEtape,typeObjet,pour,contre,abstentions,nombreVotants,nonVotants",
  }).catch(() => []);
  const out: Record<string, any> = {};
  for (const r of rows) {
    if (!r.codeEtape?.endsWith("-DEC-SCRUTIN") || ["amendement", "article"].includes(r.typeObjet)) continue;
    out[r.codeEtape] = {
      chamber: r.chambre,
      date: day(r.dateScrutin),
      adopted: r.code === "adopté",
      yes: r.pour ?? 0,
      no: r.contre ?? 0,
      abstained: r.abstentions ?? 0,
      voters: r.nombreVotants ?? (r.pour ?? 0) + (r.contre ?? 0) + (r.abstentions ?? 0),
      seats: SEATS[r.chambre] ?? null,
      groups: await fetchGroups(r.uid),
    };
  }
  return out;
}

/** One step per reading (top-level act), with where it stands inside that reading. */
export function buildSteps(actes: any[], votes: Record<string, any> = {}) {
  const byDate = (a: any, b: any) => (a.dateActe ?? "9999").localeCompare(b.dateActe ?? "9999");
  const tops = actes.filter((a) => !a.parentUid).sort(byDate);
  return tops.map((top) => {
    const code = top.codeActe;
    const kids = actes.filter((a) => a.codeActe.startsWith(code + "-")).sort(byDate);
    const first = (suffix: string) => kids.find((a) => a.codeActe.includes(suffix) && a.dateActe);
    const decisionActe = [...kids].reverse().find((a) => a.codeActe.endsWith("-DEC") || a.xsiType === "Decision_Type");
    const commission = first("-COM");
    const debate = first("-DEBATS");
    const publication = kids.find((a) => a.codeActe === "PROM-PUB");
    const decision =
      decisionActe?.libelleStatutConclusion ?? decisionActe?.libelleDecision ?? (code === "CC" ? top.libelleDecision : null);
    const stage = code === "PROM" ? "done" : decision ? "vote" : debate ? "seance" : commission ? "commission" : "depot";
    return {
      code,
      chamber: chamberOf(code, top.chambre),
      label: READINGS[code] ?? top.libelleCourtActe ?? top.nomCanonique ?? code,
      startedAt: day(top.dateActe ?? kids[0]?.dateActe ?? null),
      stage,
      decision: decision ?? null,
      commissionAt: day(commission?.dateActe ?? null),
      debateAt: day(debate?.dateActe ?? null),
      decidedAt: day(decisionActe?.dateActe ?? null),
      vote: votes[`${code}-DEC-SCRUTIN`] ?? null,
      lawTitle: publication?.titreLoi ?? null,
      url: publication?.urlLegifrance ?? top.urlConclusionConseilConstitutionnel ?? null,
    };
  });
}

/** Generic steps still to come, so the path shows where the text is heading. */
export function upcoming(steps: any[], title: string): string[] {
  if (steps.some((s) => s.code === "PROM")) return [];
  const finale = /constitutionnelle/i.test(title) ? "Congrès ou référendum" : "Promulgation";
  if (steps.some((s) => s.code === "CC")) return [finale];
  const chambers = new Set(steps.map((s) => s.chamber).filter((c) => c === "AN" || c === "SN"));
  if (chambers.size <= 1) {
    const other = chambers.has("SN") ? "Assemblée" : "Sénat";
    return [`1re lecture · ${other}`, "Adoption définitive", finale];
  }
  return ["Adoption définitive", finale];
}

// ── Summary ───────────────────────────────────────────────────────────────────

/**
 * Plain-language pieces for several laws in one Gemini call (free-tier quota): a title anyone can
 * understand, why it matters to an ordinary reader, and a 2-sentence summary.
 */
async function explainLaws(laws: { uid: string; title: string; expose: string | null }[]) {
  if (laws.length === 0) return {};
  const block = laws
    .map((l) => `### [${l.uid}] ${l.title}\n${(l.expose ?? "(exposé des motifs non disponible)").slice(0, 2500)}`)
    .join("\n\n");
  const prompt = `Tu expliques des textes de loi à des lecteurs qui ne connaissent rien au droit. Pour chaque texte ci-dessous (titre officiel et exposé des motifs), écris en français :
- "plain_title" : un titre simple de 70 caractères maximum qui dit ce que le texte change concrètement, avec un verbe (ex. « Interdire les réseaux sociaux aux moins de 15 ans »). Pas de jargon (pas de « projet de loi », « relatif à », « portant »).
- "why" : une phrase de 110 caractères maximum qui dit qui est concerné et comment, dans la vie de tous les jours.
- "summary" : 2 phrases courtes et simples sur ce que le texte changerait et pour qui.
Pas d'opinion, pas de guillemets, première lettre en majuscule, pas de point final dans le titre.

Réponds UNIQUEMENT avec du JSON valide : [{ "uid": "...", "plain_title": "...", "why": "...", "summary": "..." }]

Textes :

${block}`;
  const raw = (await generate(prompt, 2500)) ?? "";
  const out: Record<string, { plain_title: string; why: string; summary: string }> = {};
  try {
    for (const item of parseJSON(raw) ?? []) {
      const uid = String(item.uid ?? "").replace(/[\[\]\s]/g, "");
      if (!laws.some((l) => l.uid === uid)) continue;
      const clean = (v: unknown) => String(v ?? "").replace(/\s+/g, " ").trim();
      out[uid] = { plain_title: clean(item.plain_title).replace(/[.\s]+$/, ""), why: clean(item.why), summary: clean(item.summary) };
    }
  } catch {
    console.error("Failed to parse law explanations:", raw.slice(0, 300));
  }
  return out;
}

// ── Sync ──────────────────────────────────────────────────────────────────────

const isTreaty = (title: string) =>
  /autorisant (la ratification|l['’]approbation|l['’]adhésion)|ratifiant l['’]ordonnance|ratification de l['’]ordonnance/i.test(title);

async function listDossiers(since: string) {
  const out: any[] = [];
  for (let page = 1; page <= 20; page++) {
    const batch = await tric("/dossiers/json", {
      xsiType: "DossierLegislatif_Type",
      legislature: LEGISLATURE,
      typeInitiative: "Projet de loi,Proposition de loi",
      "dateDernierActe.gte": since,
      sort: "dateDernierActe.desc",
      perPage: 100,
      page,
      select: "uid,titre,typeInitiative,statut,etat,procedureAcceleree,dateDepot,dateDernierActe,senatChemin,documentDeposeRefUid",
    });
    out.push(...batch);
    if (batch.length < 100) break;
  }
  return out;
}

/**
 * Brings the laws table up to date. Incremental runs (at most every 10 minutes, triggered by the
 * app) only look at dossiers with a recent act; a full run (daily) re-selects everything active.
 */
export async function syncLaws({ full = false } = {}): Promise<{ skipped?: boolean; updated: number }> {
  await pool.query("ALTER TABLE laws ADD COLUMN IF NOT EXISTS plain_title text, ADD COLUMN IF NOT EXISTS why_it_matters text");
  await pool.query("INSERT INTO laws_sync (id) VALUES (1) ON CONFLICT DO NOTHING");
  const { rows: claim } = await pool.query(
    `UPDATE laws_sync SET synced_at = now()
      WHERE id = 1 AND (synced_at IS NULL OR synced_at < now() - $1::interval)
      RETURNING full_at`,
    [full ? "0 seconds" : MIN_SYNC_INTERVAL]
  );
  if (claim.length === 0) return { skipped: true, updated: 0 };
  const lastFull = claim[0].full_at ? new Date(claim[0].full_at).getTime() : 0;
  const doFull = full || Date.now() - lastFull > 24 * 3600 * 1000;
  const sinceDays = doFull ? FULL_WINDOW_DAYS : 3;
  const since = new Date(Date.now() - sinceDays * 86400 * 1000).toISOString().slice(0, 10);

  const [dossiers, stories] = await Promise.all([listDossiers(since), recentStories()]);

  let updated = 0;
  for (const d of dossiers) {
    if (isTreaty(d.titre)) continue;
    const storyIds = matchStories(d.titre, stories);
    const keep = d.typeInitiative === "Projet de loi" || storyIds.length > 0;
    if (!keep) continue;
    const [actes, votes] = await Promise.all([
      tric("/actesLegislatifs/json", { dossierRefUid: d.uid, perPage: 300 }),
      fetchVotes(d.uid),
    ]);
    const steps = buildSteps(actes, votes);
    const promulgated = steps.some((s) => s.code === "PROM");
    await pool.query(
      `INSERT INTO laws (uid, title, kind, status, state, accelerated, deposited_at, last_act_at, steps,
                         story_ids, senat_url, document_uid, synced_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::uuid[], $11, $12, now())
       ON CONFLICT (uid) DO UPDATE SET
         title = EXCLUDED.title, kind = EXCLUDED.kind, status = EXCLUDED.status, state = EXCLUDED.state,
         accelerated = EXCLUDED.accelerated, last_act_at = EXCLUDED.last_act_at, steps = EXCLUDED.steps,
         story_ids = EXCLUDED.story_ids, senat_url = EXCLUDED.senat_url,
         document_uid = EXCLUDED.document_uid, synced_at = now()`,
      [
        d.uid, d.titre, d.typeInitiative, d.statut, promulgated ? "Promulguée" : d.etat,
        !!d.procedureAcceleree, d.dateDepot, d.dateDernierActe, JSON.stringify(steps),
        storyIds, d.senatChemin, d.documentDeposeRefUid,
      ]
    );
    updated++;
  }

  // Story links drift as the feed moves on: refresh them for every law, not just the changed ones.
  const { rows: laws } = await pool.query("SELECT uid, title FROM laws");
  for (const law of laws) {
    await pool.query("UPDATE laws SET story_ids = $2::uuid[] WHERE uid = $1", [law.uid, matchStories(law.title, stories)]);
  }

  // The same text can have both an Assemblée and a Sénat dossier: keep the one with the longer history.
  await pool.query(`DELETE FROM laws a USING laws b
                     WHERE lower(a.title) = lower(b.title) AND a.uid <> b.uid
                       AND (jsonb_array_length(a.steps), a.uid) < (jsonb_array_length(b.steps), b.uid)`);

  // Members' bills are only listed while the news covers them.
  await pool.query("DELETE FROM laws WHERE kind = 'Proposition de loi' AND cardinality(story_ids) = 0");

  // Plain-language title, "why it matters" line and summary: one Gemini call for a few laws per run (quota).
  const { rows: missing } = await pool.query(
    `SELECT uid, title, document_uid FROM laws WHERE plain_title IS NULL ORDER BY cardinality(story_ids) DESC, last_act_at DESC LIMIT $1`,
    [SUMMARIES_PER_SYNC]
  );
  const docs = await Promise.all(
    missing.map((law) => (law.document_uid ? tric(`/documents/${law.document_uid}`).catch(() => null) : null))
  );
  const explained = await explainLaws(missing.map((law, i) => ({ uid: law.uid, title: law.title, expose: docs[i]?.exposeMotifsTexte ?? null })));
  for (const [i, law] of missing.entries()) {
    const e = explained[law.uid];
    await pool.query(
      `UPDATE laws SET
         plain_title = COALESCE(NULLIF($2, ''), plain_title),
         why_it_matters = COALESCE(NULLIF($3, ''), why_it_matters),
         summary = COALESCE(NULLIF($4, ''), summary),
         summary_at = CASE WHEN $4 IS NULL OR $4 = '' THEN summary_at ELSE now() END,
         short_title = COALESCE(short_title, $5)
       WHERE uid = $1`,
      [law.uid, e?.plain_title ?? null, e?.why ?? null, e?.summary ?? null, docs[i]?.titrePrincipalCourt ?? null]
    );
  }

  if (doFull) await pool.query("UPDATE laws_sync SET full_at = now() WHERE id = 1");
  return { updated };
}

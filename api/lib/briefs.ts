// @ts-nocheck
import { pool } from "./db.js";
import { generate, parseJSON } from "./llm.js";

// Story briefs, written ahead of time so a story never opens on an empty or loading summary:
//   - dek: one plain sentence on what happened (shown under the title),
//   - topic + political: a reliable topic and whether the political lens means anything for it,
//   - spectrum_summary: what each political side's outlets say (same format as the on-demand endpoint).
// Runs inside the refresh cron and from scripts/backfill-briefs.ts. Several stories per model call (Groq, Gemini fallback).

const BATCH = 2;   // keeps each request under Groq's free tokens-per-minute limit
const MIN_SOURCES = 3;
const WINDOW_HOURS = 72;
const TOPICS = ["politique", "economie", "societe", "international", "environnement", "justice", "culture", "sport"];

const LEAN_ORDER = ["extreme_gauche", "gauche", "centre", "droite", "extreme_droite"];
const LEAN_LABELS: Record<string, string> = {
  extreme_gauche: "Extrême-gauche",
  gauche: "Gauche",
  centre: "Centre",
  droite: "Droite",
  extreme_droite: "Extrême-droite",
};

function leanBucket(lean: number): string {
  if (lean === 1) return "extreme_gauche";
  if (lean <= 3) return "gauche";
  if (lean === 4) return "centre";
  if (lean <= 6) return "droite";
  return "extreme_droite";
}

export async function ensureBriefColumns() {
  await pool.query(`ALTER TABLE stories
    ADD COLUMN IF NOT EXISTS dek text,
    ADD COLUMN IF NOT EXISTS topic text,
    ADD COLUMN IF NOT EXISTS is_political boolean,
    ADD COLUMN IF NOT EXISTS brief_at timestamptz`);
}

type Input = { id: string; title: string; grouped: Record<string, { title: string; summary: string | null }[]>; hasSpectrum: boolean };

function promptFor(stories: Input[]): string {
  const blocks = stories
    .map((s) => {
      const sides = LEAN_ORDER.filter((l) => s.grouped[l])
        .map((l) => `#### ${l} (${LEAN_LABELS[l]})\n` + s.grouped[l].map((a) => `- ${a.title}${a.summary ? ". " + a.summary.slice(0, 220) : ""}`).join("\n"))
        .join("\n");
      return `### [${s.id}] ${s.title}\n${sides}`;
    })
    .join("\n\n");

  return `Tu es éditeur d'une application d'actualité française qui montre comment chaque bord politique couvre un même sujet. Pour chaque sujet ci-dessous (titres d'articles regroupés par tendance politique du média), produis :

1. "dek" : UNE phrase simple et factuelle (140 caractères maximum) qui complète le titre sans le répéter : le contexte, la cause ou la conséquence principale. Compréhensible sans avoir lu l'article. Première lettre en majuscule, pas de point final, pas de guillemets.
2. "topic" : un seul thème parmi ${TOPICS.join(", ")}.
3. "political" : true si le sujet a un enjeu politique ou de société sur lequel les bords peuvent diverger, false sinon (sport, faits divers sans enjeu, météo, culture sans débat…).
4. "perspectives" : pour chaque tendance présente, 3 points courts (une phrase chacun, 120 caractères maximum) qui disent ce que CES médias mettent en avant : faits retenus, angle, vocabulaire. Formule directement, sans « les médias disent que ». Si les tendances racontent la même chose, dis-le dans le premier point.

Écris toujours en français, même si les articles sont dans une autre langue.

Réponds UNIQUEMENT avec du JSON valide :
[{ "id": "...", "dek": "...", "topic": "...", "political": true, "perspectives": [{ "lean": "gauche", "points": ["...", "...", "..."] }] }]

Sujets :

${blocks}`;
}

async function loadInputs(limit: number): Promise<Input[]> {
  const { rows } = await pool.query(
    `SELECT s.id, s.title, s.spectrum_summary IS NOT NULL AS has_spectrum
       FROM stories s
      WHERE s.brief_at IS NULL
        AND s.last_updated_at > now() - make_interval(hours => $1)
        AND (SELECT count(*) FROM articles a WHERE a.story_id = s.id AND a.is_primary) >= $2
      ORDER BY s.last_updated_at DESC
      LIMIT $3`,
    [WINDOW_HOURS, MIN_SOURCES, limit]
  );
  if (rows.length === 0) return [];
  const { rows: arts } = await pool.query(
    `SELECT a.story_id, a.title, a.summary, src.political_lean
       FROM articles a JOIN sources src ON src.id = a.source_id
      WHERE a.story_id = ANY($1::uuid[]) AND a.is_primary
      ORDER BY a.published_at DESC`,
    [rows.map((r) => r.id)]
  );
  return rows.map((r) => {
    const grouped: Input["grouped"] = {};
    for (const a of arts) {
      if (a.story_id !== r.id || a.political_lean == null) continue;
      const bucket = leanBucket(a.political_lean);
      (grouped[bucket] ??= []);
      if (grouped[bucket].length < 3) grouped[bucket].push({ title: a.title, summary: a.summary });
    }
    return { id: r.id, title: r.title, grouped, hasSpectrum: r.has_spectrum };
  });
}

/** Writes briefs for recent feed stories that don't have one yet. Returns how many were written. */
export async function writeBriefs(limit = 24): Promise<number> {
  await ensureBriefColumns();
  const inputs = await loadInputs(limit);
  let written = 0;
  for (let i = 0; i < inputs.length; i += BATCH) {
    const batch = inputs.slice(i, i + BATCH);
    const raw = await generate(promptFor(batch), 6000);
    if (!raw) break; // quota or outage: the next run picks up where this one stopped
    const items = parseJSON(raw);
    if (!Array.isArray(items)) {
      console.error("Brief JSON parse failed:", raw.slice(0, 300));
      continue;
    }
    for (const item of items) {
      const story = batch.find((s) => s.id === String(item.id ?? "").replace(/[\[\]\s]/g, ""));
      if (!story) continue;
      const dek = String(item.dek ?? "").replace(/\s+/g, " ").trim().replace(/[.\s]+$/, "");
      const topic = TOPICS.includes(item.topic) ? item.topic : null;
      const now = new Date().toISOString();
      const perspectives = (item.perspectives ?? [])
        .filter((p: any) => LEAN_ORDER.includes(p.lean) && story.grouped[p.lean] && Array.isArray(p.points))
        .map((p: any) => ({
          lean: p.lean,
          summary: p.points.slice(0, 3).map((pt: string) => `• ${String(pt).trim()}`).join("\n"),
          source_count: story.grouped[p.lean].length,
        }));
      const spectrum = !story.hasSpectrum && perspectives.length ? JSON.stringify({ generated_at: now, perspectives }) : null;
      await pool.query(
        `UPDATE stories SET
           dek = NULLIF($2, ''),
           topic = COALESCE($3, topic),
           is_political = $4,
           topic_tags = CASE WHEN $3::text IS NULL THEN topic_tags ELSE ARRAY[$3::text] END,
           spectrum_summary = COALESCE(spectrum_summary, $5::jsonb),
           summary_generated_at = CASE WHEN $5::jsonb IS NULL THEN summary_generated_at ELSE now() END,
           brief_at = now()
         WHERE id = $1::uuid`,
        [story.id, dek.slice(0, 160), topic, item.political === false ? false : true, spectrum]
      );
      written++;
    }
  }
  return written;
}

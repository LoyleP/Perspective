// @ts-nocheck
import { pool } from "./db.js";
import { generate, parseJSON } from "./llm.js";

// Story briefs, written ahead of time so a story never opens on a raw wire headline:
//   - title: the story's headline reworded to fit three lines in the app (TITLE_MAX characters),
//   - dek: the description under it, reworded to fit six lines (DEK_MAX characters),
//   - topic + political: a reliable topic and whether the political lens means anything for it.
// Runs inside the refresh cron. Many stories per model call (Gemini free tier: about 20 requests a day),
// with a short prompt, numbered stories and one-letter JSON keys to keep tokens low.

const BATCH = 12;
const MIN_SOURCES = 3;
const WINDOW_HOURS = 72;
const BRIEF_VERSION = 2;
const TOPICS = ["politique", "economie", "societe", "international", "environnement", "justice", "culture", "sport"];

// What fits in the app: the story headline (34 pt condensed, ~26 characters a line) stays on 3 lines up to
// 68 characters; the description (17 pt, ~40 characters a line) stays on 6 lines up to 220. The model is asked
// for less (62 / 200) because it counts characters badly; anything over the hard limit is dropped.
const TITLE_ASK = 62;
const TITLE_MAX = 68;
const DEK_ASK = 200;
const DEK_MAX = 220;

export async function ensureBriefColumns() {
  await pool.query(`ALTER TABLE stories
    ADD COLUMN IF NOT EXISTS dek text,
    ADD COLUMN IF NOT EXISTS topic text,
    ADD COLUMN IF NOT EXISTS is_political boolean,
    ADD COLUMN IF NOT EXISTS brief_title text,
    ADD COLUMN IF NOT EXISTS brief_v smallint,
    ADD COLUMN IF NOT EXISTS brief_at timestamptz`);
}

type Input = { id: string; title: string; items: { title: string; summary: string | null }[] };

function promptFor(stories: Input[]): string {
  const blocks = stories
    .map((s, i) => `#${i + 1} ${s.title}\n` + s.items.map((a) => `- ${a.title}${a.summary ? ". " + a.summary : ""}`).join("\n"))
    .join("\n");

  return `Éditeur d'une app d'actualité française. Pour chaque sujet (#n, titre, extraits d'articles), écris en français :
t : titre neutre et factuel, ${TITLE_ASK} caractères MAXIMUM espaces compris (compte-les), sans guillemets ni point final.
d : description de 2 à 3 phrases courtes, ${DEK_ASK} caractères MAXIMUM espaces compris, qui complète t sans le répéter (contexte, cause, conséquence).
c : thème parmi ${TOPICS.join(",")}.
p : 1 si la gauche et la droite peuvent diverger sur ce sujet, 0 sinon (sport, faits divers, météo…).
Réponds par du JSON seul : [{"n":1,"t":"","d":"","c":"","p":1}]

${blocks}`;
}

async function loadInputs(limit: number): Promise<Input[]> {
  const { rows } = await pool.query(
    `SELECT s.id, s.title
       FROM stories s
      WHERE s.brief_v IS DISTINCT FROM $4
        AND s.last_updated_at > now() - make_interval(hours => $1)
        AND (SELECT count(*) FROM articles a WHERE a.story_id = s.id AND a.is_primary) >= $2
      ORDER BY s.last_updated_at DESC
      LIMIT $3`,
    [WINDOW_HOURS, MIN_SOURCES, limit, BRIEF_VERSION]
  );
  if (rows.length === 0) return [];
  const { rows: arts } = await pool.query(
    `SELECT a.story_id, a.title, a.summary
       FROM articles a
      WHERE a.story_id = ANY($1::uuid[]) AND a.is_primary
      ORDER BY a.published_at DESC`,
    [rows.map((r) => r.id)]
  );
  return rows.map((r) => {
    // Three headlines are enough to know the story; only the newest carries an excerpt.
    const mine = arts.filter((a) => a.story_id === r.id).slice(0, 3);
    return {
      id: r.id,
      title: r.title,
      items: mine.map((a, i) => ({ title: a.title, summary: i === 0 && a.summary ? a.summary.slice(0, 180) : null })),
    };
  });
}

const clean = (v: unknown) => String(v ?? "").replace(/\s+/g, " ").replace(/[«»"“”]/g, "").trim();

/** The reworded description, cut back to its last full sentence if it runs over; null when unusable. */
function fitDek(text: string): string | null {
  if (!text) return null;
  if (text.length <= DEK_MAX) return text;
  const cut = text.slice(0, DEK_MAX);
  const end = Math.max(cut.lastIndexOf(". "), cut.lastIndexOf("."));
  return end > 60 ? cut.slice(0, end + 1) : null;
}

/** Writes briefs for recent feed stories that don't have a current one yet. Returns how many were written. */
export async function writeBriefs(limit = 24): Promise<number> {
  await ensureBriefColumns();
  const inputs = await loadInputs(limit);
  let written = 0;
  for (let i = 0; i < inputs.length; i += BATCH) {
    const batch = inputs.slice(i, i + BATCH);
    const raw = await generate(promptFor(batch), 2400);
    if (!raw) break; // quota or outage: the next run picks up where this one stopped
    const items = parseJSON(raw);
    if (!Array.isArray(items)) {
      console.error("Brief JSON parse failed:", raw.slice(0, 300));
      continue;
    }
    for (const item of items) {
      const story = batch[Number(item.n) - 1];
      if (!story) continue;
      const title = clean(item.t).replace(/[.\s]+$/, "");
      const dek = fitDek(clean(item.d));
      const topic = TOPICS.includes(item.c) ? item.c : null;
      await pool.query(
        `UPDATE stories SET
           brief_title = $2,
           dek = $3,
           topic = COALESCE($4, topic),
           is_political = $5,
           topic_tags = CASE WHEN $4::text IS NULL THEN topic_tags ELSE ARRAY[$4::text] END,
           brief_v = $6,
           brief_at = now()
         WHERE id = $1::uuid`,
        [story.id, title && title.length <= TITLE_MAX ? title : null, dek, topic, item.p === 0 ? false : true, BRIEF_VERSION]
      );
      written++;
    }
  }
  return written;
}

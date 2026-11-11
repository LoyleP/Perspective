// @ts-nocheck
import { pool } from "./db.js";

// The Brief: two editions a day (matin from 06:00, soir from 18:00, Paris time), built here so every reader
// gets the same one. An edition is five stories chosen from what is new since the last edition:
//   - the most covered first (primary sources count), written up (brief title and description) and covered by 3+ outlets;
//   - at most two per topic (one for sport), so the five are not all the same story;
//   - none already in the previous edition.
// Built by the hourly refresh, once per slot (a unique day + slot), never twice.

const STORIES = 5;
const MIN_SOURCES = 3;
const WINDOW_HOURS = 16;
const PER_TOPIC = 2;

export async function ensureEditionTable() {
  await pool.query(`CREATE TABLE IF NOT EXISTS editions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    day date NOT NULL,
    slot text NOT NULL,
    published_at timestamptz NOT NULL DEFAULT now(),
    headline text NOT NULL,
    story_ids uuid[] NOT NULL,
    UNIQUE (day, slot)
  )`);
  await pool.query(`CREATE INDEX IF NOT EXISTS editions_published_idx ON editions (published_at DESC)`);
}

/** Paris date, and the slot that is open now: matin from 06:00, soir from 18:00, none overnight. */
export async function currentSlot(): Promise<{ day: string; slot: "matin" | "soir" | null }> {
  const { rows } = await pool.query(
    `SELECT (now() AT TIME ZONE 'Europe/Paris')::date::text AS day,
            EXTRACT(HOUR FROM now() AT TIME ZONE 'Europe/Paris')::int AS hour`
  );
  const { day, hour } = rows[0];
  return { day, slot: hour >= 18 ? "soir" : hour >= 6 ? "matin" : null };
}

type Candidate = { id: string; title: string; topic: string | null; sources: number };

/** The stories an edition would hold right now, in reading order. */
export async function selectStories(excludeIds: string[] = []): Promise<Candidate[]> {
  const { rows } = await pool.query(
    `SELECT s.id, s.brief_title AS title, s.topic,
            (SELECT count(*) FROM articles a WHERE a.story_id = s.id AND a.is_primary)::int AS sources
       FROM stories s
      WHERE s.last_updated_at > now() - make_interval(hours => $1)
        AND s.brief_title IS NOT NULL AND s.dek IS NOT NULL
        AND NOT (s.id = ANY($3::uuid[]))
        AND (SELECT count(*) FROM articles a WHERE a.story_id = s.id AND a.is_primary) >= $2
      ORDER BY sources DESC, s.last_updated_at DESC
      LIMIT 60`,
    [WINDOW_HOURS, MIN_SOURCES, excludeIds]
  );
  const picked: Candidate[] = [];
  const perTopic = new Map<string, number>();
  for (const row of rows) {
    const topic = row.topic ?? "autre";
    const limit = topic === "sport" ? 1 : PER_TOPIC;
    if ((perTopic.get(topic) ?? 0) >= limit) continue;
    perTopic.set(topic, (perTopic.get(topic) ?? 0) + 1);
    picked.push(row);
    if (picked.length === STORIES) break;
  }
  return picked;
}

/** Builds the edition of the open slot when it doesn't exist yet. Returns what it did. */
export async function buildEditionIfDue(): Promise<{ built: boolean; reason?: string; slot?: string; stories?: number }> {
  await ensureEditionTable();
  const { day, slot } = await currentSlot();
  if (!slot) return { built: false, reason: "overnight" };
  const existing = await pool.query(`SELECT 1 FROM editions WHERE day = $1::date AND slot = $2`, [day, slot]);
  if (existing.rowCount) return { built: false, reason: "already built", slot };

  const previous = await pool.query(`SELECT story_ids FROM editions ORDER BY published_at DESC LIMIT 1`);
  const stories = await selectStories(previous.rows[0]?.story_ids ?? []);
  if (stories.length < 3) return { built: false, reason: "not enough stories", slot, stories: stories.length };

  await pool.query(
    `INSERT INTO editions (day, slot, headline, story_ids) VALUES ($1::date, $2, $3, $4::uuid[])
     ON CONFLICT (day, slot) DO NOTHING`,
    [day, slot, stories[0].title, stories.map((s) => s.id)]
  );
  return { built: true, slot, stories: stories.length };
}

/** The latest edition with its stories in reading order (same shape as the feed), or null when none exists yet. */
export async function latestEdition() {
  await ensureEditionTable();
  const { rows } = await pool.query(
    `SELECT id, day::text AS day, slot, published_at, headline, story_ids FROM editions ORDER BY published_at DESC LIMIT 1`
  );
  const edition = rows[0];
  if (!edition) return null;
  const { storiesWithArticles } = await import("./db.js");
  const found = await storiesWithArticles("s.id = ANY($1::uuid[])", [edition.story_ids], "");
  const byId = new Map(found.map((s) => [s.id, s]));
  const stories = edition.story_ids.map((id: string) => byId.get(id)).filter(Boolean);
  return { id: edition.id, day: edition.day, slot: edition.slot, published_at: edition.published_at, headline: edition.headline, stories };
}

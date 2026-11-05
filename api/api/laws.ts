import { waitUntil } from "@vercel/functions";
import { err, json, pool } from "../lib/db.js";
import { syncLaws, upcoming } from "../lib/laws.js";

const LAW_COLS = `uid, title, short_title, plain_title, why_it_matters, kind, status, state, accelerated, deposited_at, last_act_at,
  steps, summary, cardinality(story_ids) AS story_count, senat_url, author_name, author_photo`;

/** Laws in the "Lois" tab, most recent activity first. `?sync=full` runs the daily full sync (cron). */
export async function GET(request: Request): Promise<Response> {
  const q = new URL(request.url).searchParams;
  if (q.get("sync") === "full") {
    try {
      return json(await syncLaws({ full: true }));
    } catch (e) {
      console.error(e);
      return err("laws sync failed");
    }
  }
  try {
    // Keep the data close to live: each read may start a quick incremental sync in the background
    // (it skips itself if another ran in the last 10 minutes).
    waitUntil(syncLaws().catch((e) => console.error("laws sync failed:", e)));
    const [{ rows }, { rows: sync }] = await Promise.all([
      pool.query(`SELECT ${LAW_COLS} FROM laws ORDER BY last_act_at DESC NULLS LAST LIMIT 100`),
      pool.query("SELECT synced_at FROM laws_sync WHERE id = 1"),
    ]);
    return json(
      {
        checked_at: sync[0]?.synced_at ?? null,
        laws: rows.map((l) => ({ ...l, upcoming: upcoming(l.steps, l.title) })),
      },
      200,
      "public, s-maxage=60, stale-while-revalidate=300"
    );
  } catch (e) {
    console.error(e);
    return err("laws failed");
  }
}

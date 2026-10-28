import { err, json, pool } from "../lib/db.js";

export async function GET(request: Request): Promise<Response> {
  const limit = Math.min(Math.max(Number(new URL(request.url).searchParams.get("limit") ?? 50), 1), 100);
  try {
    // lean_counts: primary articles of the linked story per lean 1–7, for the alert's spectrum line.
    const { rows } = await pool.query(
      `SELECT n.id, n.title, n.body, n.story_count, n.story_id, n.sent_at, n.created_at,
              CASE WHEN n.story_id IS NULL THEN NULL ELSE (
                SELECT array_agg(coalesce(c.cnt, 0)::int ORDER BY l)
                  FROM generate_series(1, 7) l
                  LEFT JOIN (
                    SELECT src.political_lean AS pl, count(*) AS cnt
                      FROM articles a JOIN sources src ON src.id = a.source_id
                     WHERE a.story_id = n.story_id AND a.is_primary
                     GROUP BY 1
                  ) c ON c.pl = l
              ) END AS lean_counts
         FROM notifications n
        ORDER BY n.sent_at DESC
        LIMIT $1`,
      [limit]
    );
    return json(rows);
  } catch (e) {
    console.error(e);
    return err("notifications failed");
  }
}

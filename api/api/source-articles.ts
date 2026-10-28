import { err, json, pool } from "../lib/db.js";

export async function GET(request: Request): Promise<Response> {
  const q = new URL(request.url).searchParams;
  const id = q.get("source_id");
  const limit = Math.min(Math.max(Number(q.get("limit") ?? 20), 1), 100);
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) return err("invalid source_id", 400);
  try {
    const { rows } = await pool.query(
      `SELECT id, source_id, title, url, summary, image_url, published_at, fetched_at, story_id,
              raw_keywords, click_count, is_primary, created_at, updated_at
         FROM articles WHERE source_id = $1::uuid ORDER BY published_at DESC LIMIT $2`,
      [id, limit]
    );
    return json(rows);
  } catch (e) {
    console.error(e);
    return err("articles failed");
  }
}

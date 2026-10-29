import { err, json, storiesWithArticles } from "../lib/db.js";

export async function GET(request: Request): Promise<Response> {
  const q = new URL(request.url).searchParams;
  const limit = Math.min(Math.max(Number(q.get("limit") ?? 20), 1), 100);
  const offset = Math.max(Number(q.get("offset") ?? 0), 0);
  const topic = q.get("topic");
  const search = q.get("q")?.trim();
  // Only stories covered by several outlets: 3+ sources for browsing, 2+ for search.
  // Override with ?min_sources=N.
  const minSources = Math.min(Math.max(Number(q.get("min_sources") ?? (search ? 2 : 3)), 1), 10);
  const where = ["(SELECT count(*) FROM articles a WHERE a.story_id = s.id AND a.is_primary) >= " + minSources];
  const params: unknown[] = [limit, offset];
  if (topic) {
    params.push(topic);
    where.push(`s.topic_tags @> ARRAY[$${params.length}]::text[]`);
  }
  if (search) {
    params.push(`%${search.replace(/[%_\\]/g, "\\$&")}%`);
    where.push(`unaccent(s.title) ILIKE unaccent($${params.length})`);
  }
  try {
    const stories = await storiesWithArticles(
      where.join(" AND "),
      params,
      "ORDER BY s.last_updated_at DESC, s.id ASC LIMIT $1 OFFSET $2"
    );
    return json(stories, 200, "public, s-maxage=60, stale-while-revalidate=300");
  } catch (e) {
    console.error(e);
    return err("feed failed");
  }
}

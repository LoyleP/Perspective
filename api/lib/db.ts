import pg from "pg";

declare global {
  // eslint-disable-next-line no-var
  var __pool: pg.Pool | undefined;
}

export const pool: pg.Pool =
  globalThis.__pool ??
  (globalThis.__pool = new pg.Pool({
    connectionString: process.env.DATABASE_URL,
    max: 5,
  }));

export const json = (data: unknown, status = 200, cache = "no-store") =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": cache },
  });

export const err = (message: string, status = 500) => json({ error: message }, status);

const ARTICLE_COLS = `a.id, a.source_id, a.title, a.url, a.summary, a.image_url, a.published_at,
  a.fetched_at, a.story_id, a.raw_keywords, a.click_count, a.is_primary, a.created_at, a.updated_at`;

export async function storiesWithArticles(where: string, params: unknown[], tail: string) {
  const { rows: stories } = await pool.query(
    `SELECT s.* FROM stories s WHERE ${where} ${tail}`,
    params
  );
  if (stories.length === 0) return [];
  const ids = stories.map((s) => s.id);
  const { rows: arts } = await pool.query(
    `SELECT ${ARTICLE_COLS}, to_jsonb(src) AS sources
       FROM articles a JOIN sources src ON src.id = a.source_id
      WHERE a.story_id = ANY($1::uuid[]) AND a.is_primary
      ORDER BY a.published_at DESC`,
    [ids]
  );
  const byStory = new Map<string, any[]>();
  for (const a of arts) {
    if (!byStory.has(a.story_id)) byStory.set(a.story_id, []);
    byStory.get(a.story_id)!.push(a);
  }
  return stories
    .filter((s) => byStory.has(s.id))
    .map((s) => {
      const articles = byStory.get(s.id)!;
      const counts = [0, 0, 0, 0, 0, 0, 0];
      for (const a of articles) {
        const l = a.sources?.political_lean;
        if (l >= 1 && l <= 7) counts[l - 1]++;
      }
      const total = counts.reduce((x, y) => x + y, 0);
      const cov: Record<string, unknown> = { story_id: s.id, total_count: total, updated_at: s.updated_at };
      counts.forEach((c, i) => {
        cov[`lean_${i + 1}_count`] = c;
        cov[`lean_${i + 1}_pct`] = total ? c / total : 0;
      });
      const { cycle_id, ...story } = s;
      return { ...story, story_coverage_view: cov, articles };
    });
}

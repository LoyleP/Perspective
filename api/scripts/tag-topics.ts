// Re-tags recent stories from their headline and article titles.
// Usage: DATABASE_URL_UNPOOLED=... npx tsx scripts/tag-topics.ts [days=60]
import pg from "pg";
import { topicTags } from "../lib/topics.js";

const days = Number(process.argv[2] ?? 60);
const db = new pg.Client({ connectionString: process.env.DATABASE_URL_UNPOOLED });
await db.connect();
const { rows } = await db.query(
  `SELECT s.id, s.title, coalesce(array_agg(a.title) FILTER (WHERE a.id IS NOT NULL), '{}') AS titles
     FROM stories s LEFT JOIN articles a ON a.story_id = s.id
    WHERE s.last_updated_at > now() - make_interval(days => $1)
    GROUP BY s.id`,
  [days]
);
const counts: Record<string, number> = {};
for (const row of rows) {
  const tags = topicTags(row.title, ...row.titles.slice(0, 5));
  for (const t of tags) counts[t] = (counts[t] ?? 0) + 1;
  await db.query("UPDATE stories SET topic_tags = $2 WHERE id = $1", [row.id, tags]);
}
console.log(`tagged ${rows.length} stories`, counts);
await db.end();

// One-off backfill: rewrites every story title that hasn't been rewritten yet.
// Usage: set -a; . ./.env.local; set +a; npx tsx scripts/rewrite-titles.ts
import { pool } from "../lib/db.js";
import { rewriteStoryTitles } from "../lib/titles.js";

await pool.query("ALTER TABLE stories ADD COLUMN IF NOT EXISTS title_rewritten_at timestamptz");
let total = 0;
for (;;) {
  const n = await rewriteStoryTitles(60);
  total += n;
  console.log(`rewrote ${n} (total ${total})`);
  if (n === 0) break;
}
await pool.end();

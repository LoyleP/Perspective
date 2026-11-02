// Writes briefs (dek, topic, per-side summaries) for recent feed stories that lack one.
// Usage: set -a; . ./.env.local; set +a; npx tsx scripts/backfill-briefs.ts
import { pool } from "../lib/db.js";
import { writeBriefs } from "../lib/briefs.js";

let total = 0;
for (;;) {
  const n = await writeBriefs(40);
  total += n;
  console.log(`briefs written: ${n} (total ${total})`);
  if (n === 0) break;
}
await pool.end();

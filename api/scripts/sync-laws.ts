// Creates the laws tables if needed and runs a full sync of the "Lois" tab.
// Usage: set -a; . ./.env.local; set +a; npx tsx scripts/sync-laws.ts
import { readFileSync } from "node:fs";
import { pool } from "../lib/db.js";
import { syncLaws } from "../lib/laws.js";

const schema = readFileSync(new URL("../db/schema.sql", import.meta.url), "utf8");
await pool.query(schema.slice(schema.indexOf("-- Laws followed")));
console.log(await syncLaws({ full: true }));
const { rows } = await pool.query("SELECT kind, count(*), count(summary) AS summaries, sum(cardinality(story_ids)) AS links FROM laws GROUP BY kind");
console.table(rows);
await pool.end();

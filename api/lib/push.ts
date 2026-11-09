// Push alerts: device registry and the sender that turns the latest `notifications` row into an APNs push
// carrying the story's title, description and coverage (rendered on the phone by the notification extensions).

import { pool } from "./db.js";
import { apnsConfigured, isDeadToken, sendToTokens, type ApnsEnvironment, type ApnsResult } from "./apns.js";

/** Pushes only go out between these Paris hours; a story found at night is pushed at the next run after 8:00. */
const QUIET_END_HOUR = 8;
const QUIET_START_HOUR = 22;
/** Minimum time between two pushes, so the hourly refresh doesn't send fourteen alerts a day. */
const MIN_GAP_HOURS = Number(process.env.PUSH_MIN_GAP_HOURS ?? 3);
/** A notification older than this is no longer news and is never pushed. */
const MAX_AGE_HOURS = 12;

let schemaReady = false;

export async function ensurePushSchema() {
  if (schemaReady) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS push_devices (
      token text PRIMARY KEY,
      environment text NOT NULL CHECK (environment IN ('sandbox', 'production')),
      app_version text,
      created_at timestamptz NOT NULL DEFAULT now(),
      last_seen_at timestamptz NOT NULL DEFAULT now()
    )`);
  await pool.query(`
    ALTER TABLE notifications
      ADD COLUMN IF NOT EXISTS pushed_at timestamptz,
      ADD COLUMN IF NOT EXISTS push_sent int`);
  schemaReady = true;
}

/** Same reading as the app's coverage tag: the side clearly ahead, or "tous les bords". */
export function coverageVerdict(leans: number[]): string {
  if (leans.length < 3) return "Peu de sources";
  const bucket = (l: number) => (l === 1 ? 0 : l <= 3 ? 1 : l === 4 ? 2 : l <= 6 ? 3 : 4);
  const counts = [0, 0, 0, 0, 0];
  for (const l of leans) counts[bucket(l)]++;
  const ranked = counts.map((c, i) => [c, i]).sort((x, y) => y[0] - x[0]);
  if ((ranked[0][0] - ranked[1][0]) / leans.length < 0.1) return "Relayé par tous les bords";
  return ["Surtout relayé à l'extrême gauche", "Surtout relayé à gauche", "Surtout relayé au centre",
          "Surtout relayé à droite", "Surtout relayé à l'extrême droite"][ranked[0][1]];
}

/** Primary articles of a story per lean 1–7 (index 0 = lean 1), as SQL returning int[]. */
export const leanCountsSQL = (storyId: string) => `(
  SELECT array_agg(coalesce(c.cnt, 0)::int ORDER BY l)
    FROM generate_series(1, 7) l
    LEFT JOIN (
      SELECT src.political_lean AS pl, count(*) AS cnt
        FROM articles a JOIN sources src ON src.id = a.source_id
       WHERE a.story_id = ${storyId} AND a.is_primary
       GROUP BY 1
    ) c ON c.pl = l
)`;

/** The description as one paragraph: the dek's bullets as sentences, else the story summary. */
export function describe(dek: string | null, summary: string | null): string | null {
  const bullets = (dek ?? "").split("\n").map((b) => b.trim()).filter(Boolean);
  const text = bullets.length > 0
    ? bullets.map((b) => (/[.!?…]$/.test(b) ? b : `${b}.`)).join(" ")
    : (summary ?? "").replace(/\s+/g, " ").trim();
  if (!text) return null;
  return text.length > 280 ? `${text.slice(0, 277).replace(/\s+\S*$/, "")}…` : text;
}

interface PushContent {
  notificationId: string;
  storyId: string;
  title: string;
  description: string | null;
  leanCounts: number[];
}

async function loadContent(notificationId: string): Promise<PushContent | null> {
  const { rows: [row] } = await pool.query(
    `SELECT n.id, n.story_id, COALESCE(NULLIF(s.brief_title, ''), s.title, n.title) AS title, s.dek, s.summary,
            ${leanCountsSQL("n.story_id")} AS lean_counts
       FROM notifications n JOIN stories s ON s.id = n.story_id
      WHERE n.id = $1::uuid`,
    [notificationId]
  );
  if (!row) return null;
  return {
    notificationId: row.id,
    storyId: row.story_id,
    title: row.title,
    description: describe(row.dek, row.summary),
    leanCounts: row.lean_counts ?? [0, 0, 0, 0, 0, 0, 0],
  };
}

/** The APNs payload. `mutable-content` wakes the service extension (coverage thumbnail); `category` picks the
 *  content extension (expanded view with the full coverage bar). */
export function payloadFor(c: PushContent) {
  const total = c.leanCounts.reduce((a, b) => a + b, 0);
  const leans = c.leanCounts.flatMap((n, i) => Array(n).fill(i + 1));
  const verdict = coverageVerdict(leans);
  return {
    aps: {
      alert: { title: c.title, body: c.description ?? `${verdict} · ${total} ${total === 1 ? "source" : "sources"}` },
      sound: "default",
      "mutable-content": 1,
      category: "STORY",
      "thread-id": "stories",
    },
    story_id: c.storyId,
    notification_id: c.notificationId,
    lean_counts: c.leanCounts,
    source_count: total,
    verdict,
  };
}

async function deliver(c: PushContent, onlyToken?: string): Promise<{ sent: number; failed: number; removed: number; errors: ApnsResult[] }> {
  const { rows } = onlyToken
    ? await pool.query("SELECT token, environment FROM push_devices WHERE token = $1", [onlyToken])
    : await pool.query("SELECT token, environment FROM push_devices");
  const byEnv = new Map<ApnsEnvironment, string[]>();
  for (const r of rows) byEnv.set(r.environment, [...(byEnv.get(r.environment) ?? []), r.token]);

  const message = { payload: payloadFor(c), collapseId: c.storyId };
  const results: ApnsResult[] = [];
  for (const [env, tokens] of byEnv) results.push(...(await sendToTokens(env, tokens, message)));

  const dead = results.filter(isDeadToken).map((r) => r.token);
  if (dead.length > 0) await pool.query("DELETE FROM push_devices WHERE token = ANY($1::text[])", [dead]);
  const errors = results.filter((r) => r.status !== 200);
  return { sent: results.length - errors.length, failed: errors.length, removed: dead.length, errors: errors.slice(0, 5) };
}

function parisHour(): number {
  return Number(new Intl.DateTimeFormat("fr-FR", { hour: "numeric", hour12: false, timeZone: "Europe/Paris" }).format(new Date()));
}

/** Pushes the newest notification not yet pushed, if the hour, the gap and the configuration allow it.
 *  Older unpushed notifications are marked as superseded so they never go out late. */
export async function sendPendingPush(): Promise<Record<string, unknown>> {
  if (!apnsConfigured()) return { skipped: "APNs not configured" };
  await ensurePushSchema();

  const hour = parisHour();
  if (hour < QUIET_END_HOUR || hour >= QUIET_START_HOUR) return { skipped: "quiet hours", paris_hour: hour };

  const { rows: [last] } = await pool.query("SELECT max(pushed_at) AS at FROM notifications WHERE push_sent > 0");
  if (last?.at && Date.now() - new Date(last.at).getTime() < MIN_GAP_HOURS * 3600_000) {
    return { skipped: "min gap", last_push: last.at };
  }

  const { rows: [next] } = await pool.query(
    `SELECT id, sent_at FROM notifications
      WHERE pushed_at IS NULL AND story_id IS NOT NULL AND sent_at > now() - make_interval(hours => $1)
      ORDER BY sent_at DESC LIMIT 1`,
    [MAX_AGE_HOURS]
  );
  if (!next) return { skipped: "nothing new" };

  const content = await loadContent(next.id);
  if (!content) return { skipped: "story gone" };
  const result = await deliver(content);

  await pool.query("UPDATE notifications SET pushed_at = now(), push_sent = $2 WHERE id = $1::uuid", [next.id, result.sent]);
  await pool.query(
    "UPDATE notifications SET pushed_at = now(), push_sent = 0 WHERE pushed_at IS NULL AND sent_at <= $1",
    [next.sent_at]
  );
  return { notification_id: next.id, title: content.title, ...result };
}

/** Sends the latest (or a given) notification right away, ignoring quiet hours and the gap: for testing. */
export async function sendTestPush(opts: { token?: string; notificationId?: string }) {
  if (!apnsConfigured()) return { error: "APNs not configured" };
  await ensurePushSchema();
  const { rows: [n] } = opts.notificationId
    ? await pool.query("SELECT id FROM notifications WHERE id = $1::uuid AND story_id IS NOT NULL", [opts.notificationId])
    : await pool.query("SELECT id FROM notifications WHERE story_id IS NOT NULL ORDER BY sent_at DESC LIMIT 1");
  if (!n) return { error: "no notification" };
  const content = await loadContent(n.id);
  if (!content) return { error: "story gone" };
  return { notification_id: n.id, payload: payloadFor(content), ...(await deliver(content, opts.token)) };
}

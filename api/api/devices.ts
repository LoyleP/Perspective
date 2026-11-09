import { err, json, pool } from "../lib/db.js";
import { ensurePushSchema, sendTestPush } from "../lib/push.js";

// POST   { token, environment: "sandbox" | "production", app_version? }  registers or refreshes a device
// POST ?test=1 (Bearer $CRON_SECRET)  sends the latest alert now, for testing
// DELETE { token }                                                       forgets it (notifications turned off)
// The token is an opaque 64-hex APNs device token: it identifies a phone, not a person.

const TOKEN = /^[0-9a-f]{32,200}$/i;

export async function POST(request: Request): Promise<Response> {
  try {
    const body = await request.json().catch(() => ({}));
    if (new URL(request.url).searchParams.has("test")) {
      // POST /api/devices?test=1 { token?, notification_id? } with Bearer $CRON_SECRET: sends the latest alert now,
      // to one device when `token` is set, else to all. Lives here because the Hobby plan caps a project at 12 functions.
      const secret = process.env.CRON_SECRET;
      if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) return new Response("Unauthorized", { status: 401 });
      return json(await sendTestPush({ token: body?.token?.toLowerCase(), notificationId: body?.notification_id }));
    }
    const token = String(body?.token ?? "").toLowerCase();
    const environment = body?.environment === "production" ? "production" : body?.environment === "sandbox" ? "sandbox" : null;
    if (!TOKEN.test(token) || !environment) return err("invalid device", 400);
    await ensurePushSchema();
    await pool.query(
      `INSERT INTO push_devices (token, environment, app_version) VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET environment = $2, app_version = $3, last_seen_at = now()`,
      [token, environment, body?.app_version ? String(body.app_version).slice(0, 32) : null]
    );
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return err("devices failed");
  }
}

export async function DELETE(request: Request): Promise<Response> {
  try {
    const body = await request.json();
    const token = String(body?.token ?? "").toLowerCase();
    if (!TOKEN.test(token)) return err("invalid device", 400);
    await ensurePushSchema();
    await pool.query("DELETE FROM push_devices WHERE token = $1", [token]);
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return err("devices failed");
  }
}

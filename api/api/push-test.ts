import { err, json } from "../lib/db.js";
import { sendTestPush } from "../lib/push.js";

// POST { token?, notification_id? } with Authorization: Bearer $CRON_SECRET.
// Sends the latest alert (or the given one) now, to one device when `token` is set, else to every device.
export async function POST(request: Request): Promise<Response> {
  const secret = process.env.CRON_SECRET;
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  try {
    const body = await request.json().catch(() => ({}));
    return json(await sendTestPush({ token: body?.token?.toLowerCase(), notificationId: body?.notification_id }));
  } catch (e) {
    console.error(e);
    return err("push-test failed");
  }
}

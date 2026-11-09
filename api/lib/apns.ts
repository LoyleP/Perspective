// Apple Push Notification service client: token-based auth (.p8 key) over HTTP/2.
//
// Env vars (Vercel, Production and Preview):
//   APNS_KEY_ID     the 10-character Key ID of the .p8 key (Certificates, Identifiers & Profiles > Keys)
//   APNS_TEAM_ID    the Apple developer Team ID (BJ66V252MG)
//   APNS_KEY        the full contents of the .p8 file, BEGIN/END lines included (literal "\n" are accepted)
//   APNS_BUNDLE_ID  optional, defaults to com.flow.optique (the apns-topic)

import { connect, constants, type ClientHttp2Session } from "node:http2";
import { createPrivateKey, sign } from "node:crypto";

export type ApnsEnvironment = "sandbox" | "production";

const HOSTS: Record<ApnsEnvironment, string> = {
  sandbox: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com",
};

export const apnsTopic = () => process.env.APNS_BUNDLE_ID || "com.flow.optique";

export function apnsConfigured(): boolean {
  return Boolean(process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID && process.env.APNS_KEY);
}

const b64url = (input: Buffer | string) =>
  Buffer.from(input).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");

// Apple accepts a provider token for up to an hour and refuses one refreshed more than every 20 minutes,
// so one token is reused for 40 minutes across warm invocations.
let cachedJWT: { token: string; at: number } | null = null;

function providerToken(): string {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.at < 40 * 60) return cachedJWT.token;
  const keyPem = (process.env.APNS_KEY ?? "").replace(/\\n/g, "\n");
  const header = b64url(JSON.stringify({ alg: "ES256", kid: process.env.APNS_KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: process.env.APNS_TEAM_ID, iat: now }));
  const signature = sign("sha256", Buffer.from(`${header}.${claims}`), {
    key: createPrivateKey(keyPem),
    dsaEncoding: "ieee-p1363", // JWS wants r||s, not DER
  });
  const token = `${header}.${claims}.${b64url(signature)}`;
  cachedJWT = { token, at: now };
  return token;
}

export interface ApnsResult {
  token: string;
  status: number;
  reason?: string;
}

export interface ApnsMessage {
  payload: object;
  collapseId?: string;
  /** Seconds after which APNs stops trying to deliver to an offline device. */
  ttlSeconds?: number;
}

/** True when the token will never work again and should be forgotten. */
export function isDeadToken(r: ApnsResult): boolean {
  return r.status === 410 || (r.status === 400 && (r.reason === "BadDeviceToken" || r.reason === "DeviceTokenNotForTopic"));
}

function post(session: ClientHttp2Session, token: string, body: string, headers: Record<string, string>): Promise<ApnsResult> {
  return new Promise((resolve) => {
    const req = session.request({
      [constants.HTTP2_HEADER_METHOD]: "POST",
      [constants.HTTP2_HEADER_PATH]: `/3/device/${token}`,
      ...headers,
    });
    let status = 0;
    let data = "";
    req.setEncoding("utf8");
    req.on("response", (h) => { status = Number(h[constants.HTTP2_HEADER_STATUS]); });
    req.on("data", (chunk) => { data += chunk; });
    req.on("end", () => {
      let reason: string | undefined;
      try { reason = data ? JSON.parse(data).reason : undefined; } catch { reason = data.slice(0, 100); }
      resolve({ token, status, reason });
    });
    req.on("error", (e) => resolve({ token, status: 0, reason: e.message }));
    req.setTimeout(10_000, () => { req.close(); resolve({ token, status: 0, reason: "timeout" }); });
    req.end(body);
  });
}

/** Sends one message to many devices of one environment over a single HTTP/2 connection. */
export async function sendToTokens(env: ApnsEnvironment, tokens: string[], message: ApnsMessage): Promise<ApnsResult[]> {
  if (tokens.length === 0) return [];
  const session = connect(HOSTS[env]);
  session.on("error", (e) => console.error(`APNs ${env} session error:`, e.message));
  const headers: Record<string, string> = {
    authorization: `bearer ${providerToken()}`,
    "apns-topic": apnsTopic(),
    "apns-push-type": "alert",
    "apns-priority": "10",
    "apns-expiration": String(Math.floor(Date.now() / 1000) + (message.ttlSeconds ?? 12 * 3600)),
    "content-type": "application/json",
  };
  if (message.collapseId) headers["apns-collapse-id"] = message.collapseId.slice(0, 64);
  const body = JSON.stringify(message.payload);
  const results: ApnsResult[] = [];
  try {
    // Small batches keep well under APNs' concurrent stream limit.
    for (let i = 0; i < tokens.length; i += 50) {
      results.push(...(await Promise.all(tokens.slice(i, i + 50).map((t) => post(session, t, body, headers)))));
    }
  } finally {
    session.close();
  }
  return results;
}

// Fetches a square logo for every active source and stores it in source_logos,
// then points sources.logo_url at /api/logo. Re-run after adding sources.
// Usage: DATABASE_URL_UNPOOLED=... API_BASE=https://... node scripts/fetch-logos.mjs
import pg from "pg";

const API_BASE = process.env.API_BASE ?? "https://api-chi-henna-92.vercel.app";
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";

const db = new pg.Client({ connectionString: process.env.DATABASE_URL_UNPOOLED });
await db.connect();

async function get(url) {
  const res = await fetch(url, { headers: { "User-Agent": UA }, redirect: "follow", signal: AbortSignal.timeout(10_000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res;
}

function pngWidth(buf) {
  return buf.length > 24 && buf.readUInt32BE(0) === 0x89504e47 ? buf.readUInt32BE(16) : null;
}

// Icon candidates from the homepage's <link rel="...icon..."> tags, best first.
async function candidates(home) {
  const list = [];
  try {
    const html = await (await get(home)).text();
    for (const tag of html.match(/<link[^>]+>/gi) ?? []) {
      const rel = tag.match(/rel=["']([^"']+)["']/i)?.[1]?.toLowerCase() ?? "";
      const href = tag.match(/href=["']([^"']+)["']/i)?.[1];
      if (!href || !rel.includes("icon") || /\.svg(\?|$)/i.test(href) || rel.includes("mask")) continue;
      const size = Number(tag.match(/sizes=["'](\d+)x\d+["']/i)?.[1] ?? (rel.includes("apple") ? 180 : 32));
      list.push({ url: new URL(href.replace(/&amp;/g, "&"), home).href, score: size + (rel.includes("apple") ? 1000 : 0) });
    }
  } catch {}
  list.sort((a, b) => b.score - a.score);
  const origin = new URL(home).origin;
  list.push({ url: `${origin}/apple-touch-icon.png` });
  list.push({ url: `https://www.google.com/s2/favicons?domain=${new URL(home).hostname}&sz=128` });
  return list.map((c) => c.url);
}

const { rows: sources } = await db.query("SELECT id, name, url, rss_url FROM sources WHERE is_active ORDER BY name");
for (const source of sources) {
  const home = source.url ?? new URL(source.rss_url).origin;
  let saved = null;
  let ico = null; // .ico files are usually 16–32 px: only used when nothing better exists
  for (const url of await candidates(home)) {
    try {
      const res = await get(url);
      const type = (res.headers.get("content-type") ?? "").split(";")[0];
      if (!/^image\/(png|jpeg|webp|x-icon|vnd\.microsoft\.icon)$/.test(type)) continue;
      const buf = Buffer.from(await res.arrayBuffer());
      const width = pngWidth(buf);
      if (buf.length < 300 || (width !== null && width < 64 && !url.includes("google.com"))) continue;
      if (type.includes("icon")) { ico ??= { url, type, buf }; continue; }
      saved = await save(source, url, type, buf, width);
      break;
    } catch {}
  }
  if (!saved && ico) saved = await save(source, ico.url, ico.type, ico.buf, null);
  console.log(saved ? "ok  " : "MISS", source.name.padEnd(28), saved ?? home);
}
await db.end();

async function save(source, url, type, buf, width) {
  await db.query(
    `INSERT INTO source_logos (source_id, content_type, data, origin_url, updated_at) VALUES ($1, $2, $3, $4, now())
     ON CONFLICT (source_id) DO UPDATE SET content_type = $2, data = $3, origin_url = $4, updated_at = now()`,
    [source.id, type, buf, url]
  );
  await db.query("UPDATE sources SET logo_url = $2 WHERE id = $1", [source.id, `${API_BASE}/api/logo?id=${source.id}`]);
  return `${type} ${width ?? "?"}px ${url}`;
}

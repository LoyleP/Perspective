import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Source {
  id: string;
  name: string;
  rss_url: string;
}

interface Article {
  source_id: string;
  title: string;
  url: string;
  summary: string | null;
  image_url: string | null;
  published_at: string;
  fetched_at: string;
  story_id: string | null;
}

// ── RSS Parsing ───────────────────────────────────────────────────────────────

function decodeEntities(s: string): string {
  return s
    .replace(/&#x([0-9a-fA-F]+);/g, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#([0-9]+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, " ");
}

function cdata(s: string): string {
  return decodeEntities(s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").trim());
}

function getTag(xml: string, name: string): string | null {
  const m = xml.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`, "i"));
  return m ? cdata(m[1]).trim() || null : null;
}

function getAttr(xml: string, tag: string, attr: string): string | null {
  const m = xml.match(new RegExp(`<${tag}[^>]*\\s${attr}=["']([^"']+)["']`, "i"));
  return m ? m[1] : null;
}

function isoDate(s: string | null): string {
  if (!s) return new Date().toISOString();
  try {
    return new Date(s).toISOString();
  } catch {
    return new Date().toISOString();
  }
}

function parseRSS(xml: string, sourceId: string): Article[] {
  const isAtom = xml.includes("<feed") && xml.includes("<entry");
  const pattern = isAtom
    ? /<entry[\s>][\s\S]*?<\/entry>/g
    : /<item[\s>][\s\S]*?<\/item>/g;
  const now = new Date().toISOString();
  const out: Article[] = [];

  for (const item of xml.match(pattern) ?? []) {
    const title = getTag(item, "title");
    if (!title || title.length < 5) continue;

    let url = isAtom
      ? (getAttr(item, "link", "href") ?? getTag(item, "link"))
      : (getTag(item, "link") ?? getTag(item, "guid"));
    if (!url?.startsWith("http")) continue;

    try {
      const u = new URL(url);
      url = `${u.origin}${u.pathname}`;
    } catch { /* keep as-is */ }

    const rawSummary =
      getTag(item, "description") ??
      getTag(item, "content:encoded") ??
      getTag(item, "summary");
    const summary = rawSummary
      ? rawSummary.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().slice(0, 500) || null
      : null;

    const image =
      getAttr(item, "media:content", "url") ??
      getAttr(item, "enclosure", "url") ??
      getAttr(item, "media:thumbnail", "url") ??
      null;

    out.push({
      source_id: sourceId,
      title: title.slice(0, 500),
      url,
      summary,
      image_url: image,
      published_at: isoDate(
        getTag(item, "pubDate") ?? getTag(item, "published") ?? getTag(item, "updated")
      ),
      fetched_at: now,
      story_id: null,
    });
  }
  return out;
}

// ── Main Handler ──────────────────────────────────────────────────────────────

Deno.serve(async (_req: Request) => {
  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // 1. Fetch all active sources
    const { data: sources, error: e1 } = await db
      .from("sources")
      .select("id, name, rss_url")
      .eq("is_active", true);
    if (e1) throw e1;

    // 2. Fetch RSS feeds concurrently
    const fetched: Article[] = [];
    const log: { source: string; count: number; error?: string }[] = [];

    await Promise.allSettled(
      (sources as Source[]).map(async (src) => {
        try {
          const res = await fetch(src.rss_url, {
            headers: { "User-Agent": "Mozilla/5.0" },
            signal: AbortSignal.timeout(10_000),
          });
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const items = parseRSS(await res.text(), src.id);
          fetched.push(...items);
          log.push({ source: src.name, count: items.length });
        } catch (err) {
          log.push({ source: src.name, count: 0, error: String(err) });
        }
      })
    );

    if (!fetched.length) {
      return new Response(JSON.stringify({ ok: true, message: "No articles fetched", log }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. Deduplicate by URL
    const { data: existing } = await db
      .from("articles")
      .select("url")
      .in("url", fetched.map((a) => a.url));
    const knownUrls = new Set((existing ?? []).map((r: { url: string }) => r.url));
    const newArts = fetched.filter((a) => !knownUrls.has(a.url));

    if (!newArts.length) {
      return new Response(JSON.stringify({ ok: true, message: "No new articles", log }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Deduplicate within batch
    const seenUrls = new Map<string, Article>();
    for (const a of newArts) {
      if (!seenUrls.has(a.url)) seenUrls.set(a.url, a);
    }
    newArts.splice(0, newArts.length, ...seenUrls.values());

    // 4. Insert articles without clustering (story_id remains null)
    const { error: e3 } = await db.from("articles").upsert(newArts, {
      onConflict: "url",
      ignoreDuplicates: true,
    });
    if (e3) throw e3;

    return new Response(
      JSON.stringify({
        ok: true,
        new_articles: newArts.length,
        log,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ingest-rss error:", message);
    return new Response(JSON.stringify({ ok: false, error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

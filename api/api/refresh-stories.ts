// @ts-nocheck
import { pool } from "../lib/db.js";
import { topicTags } from "../lib/topics.js";
import { rewriteStoryTitles } from "../lib/titles.js";

// ── Constants ─────────────────────────────────────────────────────────────────

const TFIDF_THRESHOLD = 0.28;
const NER_THRESHOLD = 2;
// Entity-driven links also require a minimum text similarity, so a single
// shared person (e.g. a spokesperson quoted across unrelated subjects) cannot
// bridge two different stories via Union-Find transitive chaining.
const NER_LINK_MIN_SIMILARITY = 0.12;
// A very high text similarity alone is enough to link two articles, even
// without shared title entities.
const STRONG_TFIDF_THRESHOLD = 0.45;
const CROSS_CYCLE_NER_THRESHOLD = 3;
const MIN_CLUSTER_SIZE = 2;
const WINDOW_HOURS = 72;
// Keep cross-cycle merge aligned with the refresh cadence (every 48h). A wider
// window scans many prior runs' stories, inflating spurious entity overlaps.
const CROSS_CYCLE_HOURS = 48;
const BATCH_SIZE = 50;
const MAX_ARTICLES_PER_RUN = 4000;
// A lone article joins an existing recent story when its text is this similar to the story's
// headlines (and they share at least one entity).
const SINGLETON_ATTACH_SIMILARITY = 0.33;

const FRENCH_STOPWORDS = new Set([
  "le", "la", "les", "un", "une", "des", "de", "du", "et", "ou", "mais",
  "donc", "or", "ni", "car", "ce", "cette", "ces", "cet", "mon", "ton",
  "son", "notre", "votre", "leur", "mes", "tes", "ses", "nos", "vos",
  "leurs", "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
  "me", "te", "se", "lui", "leur", "y", "en", "dans", "sur", "sous",
  "avec", "sans", "pour", "par", "vers", "chez", "contre", "entre",
  "pendant", "selon", "malgré", "depuis", "avant", "après", "plus",
  "moins", "très", "trop", "assez", "peu",
]);

// English stopwords — English sources contribute coverage volume, but their
// common function words must be filtered so TF-IDF reflects topical content,
// not grammar. (Words < 3 chars like "a", "of", "to" are already dropped.)
const ENGLISH_STOPWORDS = new Set([
  "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
  "had", "her", "was", "one", "our", "out", "has", "him", "his", "how",
  "its", "may", "new", "now", "old", "see", "two", "way", "who", "did",
  "get", "got", "let", "put", "say", "she", "too", "use", "that", "this",
  "with", "have", "from", "they", "will", "would", "there", "their",
  "what", "about", "which", "when", "make", "like", "time", "just",
  "into", "over", "also", "after", "before", "than", "then", "them",
  "these", "those", "been", "more", "most", "some", "such", "only",
  "other", "could", "should", "where", "while", "says", "said", "amid",
]);

// Combined stopword filter applied during tokenization (language-agnostic).
const STOPWORDS = new Set([...FRENCH_STOPWORDS, ...ENGLISH_STOPWORDS]);

// Generic capitalized words that are too common to identify a story.
// Normalized (lowercased, accents stripped) to match extractEntities output.
const ENTITY_STOPWORDS = new Set([
  // Geography — appears across unrelated subjects
  "france", "paris", "europe", "europeenne", "francais", "francaise",
  "national", "nationale", "republique", "etat", "ville", "region",
  "monde", "pays", "gouvernement", "assemblee", "senat",
  // Time / sentence-initial common words
  "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche",
  "janvier", "fevrier", "mars", "avril", "mai", "juin", "juillet",
  "aout", "septembre", "octobre", "novembre", "decembre",
  // Frequent title-initial words that get capitalized by position, not meaning
  "le", "la", "les", "un", "une", "des", "ce", "cette", "apres", "avant",
  "comment", "pourquoi", "quand", "video", "direct", "live", "exclusif",
  // English equivalents — generic geo + title-initial words
  "the", "this", "how", "why", "what", "when", "watch", "breaking",
  "world", "news", "live", "update", "updates", "opinion", "exclusive",
  "us", "usa", "uk", "europe", "european", "national", "state", "city",
]);

const MIN_ENTITY_LENGTH = 3;

// ── Types ─────────────────────────────────────────────────────────────────────

interface Source {
  id: string;
  name: string;
  rss_url: string;
}

interface RawArticle {
  source_id: string;
  title: string;
  url: string;
  summary: string | null;
  image_url: string | null;
  published_at: string;
  fetched_at: string;
  story_id: string | null;
}

interface ClusterArticle {
  id: string;
  title: string;
  summary: string | null;
  published_at: string;
  source_id: string;
}

interface TFIDFVector {
  [token: string]: number;
}

interface Cluster {
  articles: ClusterArticle[];
  entities: Set<string>;
}

// ── RSS Parsing ───────────────────────────────────────────────────────────────

function decodeEntities(s: string): string {
  return s
    .replace(/&#x([0-9a-fA-F]+);/g, (_, h) =>
      String.fromCodePoint(parseInt(h, 16))
    )
    .replace(/&#([0-9]+);/g, (_, d) =>
      String.fromCodePoint(parseInt(d, 10))
    )
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, " ");
}

function cdata(s: string): string {
  return decodeEntities(
    s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").trim()
  );
}

function getTag(xml: string, name: string): string | null {
  const m = xml.match(
    new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`, "i")
  );
  return m ? cdata(m[1]).trim() || null : null;
}

function getAttr(xml: string, tag: string, attr: string): string | null {
  const m = xml.match(
    new RegExp(`<${tag}[^>]*\\s${attr}=["']([^"']+)["']`, "i")
  );
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

function parseRSS(xml: string, sourceId: string): RawArticle[] {
  const isAtom = xml.includes("<feed") && xml.includes("<entry");
  const pattern = isAtom
    ? /<entry[\s>][\s\S]*?<\/entry>/g
    : /<item[\s>][\s\S]*?<\/item>/g;
  const now = new Date().toISOString();
  const out: RawArticle[] = [];

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
    } catch {
      /* keep as-is */
    }

    const rawSummary =
      getTag(item, "description") ??
      getTag(item, "content:encoded") ??
      getTag(item, "summary");
    const summary = rawSummary
      ? rawSummary
          .replace(/<[^>]+>/g, " ")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, 500) || null
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
        getTag(item, "pubDate") ??
          getTag(item, "published") ??
          getTag(item, "updated")
      ),
      fetched_at: now,
      story_id: null,
    });
  }
  return out;
}

// ── NLP Utilities ─────────────────────────────────────────────────────────────

function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function tokenize(text: string): string[] {
  const normalized = normalize(text);
  return normalized
    .split(/\s+/)
    .map((token) => token.replace(/[^a-z]/g, ""))
    .filter((token) => token.length >= 3 && !STOPWORDS.has(token));
}

function extractEntities(title: string): string[] {
  const words = title.split(/\s+/);
  const entities: string[] = [];

  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    const cleaned = word.replace(/[^a-zA-ZÀ-ÿ]/g, "");
    const normalized = normalize(cleaned);

    // Acronyms: ALL-CAPS, but require >= 3 chars to avoid noise like "LE", "RT".
    const isAcronym =
      cleaned.length >= MIN_ENTITY_LENGTH && cleaned === cleaned.toUpperCase();
    // Proper nouns: capitalized but NOT sentence-initial (i > 0), so title-case
    // first words aren't mistaken for entities.
    const isProperNoun =
      i > 0 &&
      cleaned.length >= MIN_ENTITY_LENGTH &&
      /^[A-ZÀ-Ÿ]/.test(cleaned);

    if (!isAcronym && !isProperNoun) continue;
    if (ENTITY_STOPWORDS.has(normalized)) continue;

    entities.push(normalized);
  }

  return [...new Set(entities)];
}

function computeTFIDF(
  articles: ClusterArticle[]
): Map<string, TFIDFVector> {
  const vectors = new Map<string, TFIDFVector>();
  const docFrequency = new Map<string, number>();
  const totalDocs = articles.length;

  for (const article of articles) {
    const text = article.title + " " + (article.summary || "");
    const tokens = new Set(tokenize(text));
    for (const token of tokens) {
      docFrequency.set(token, (docFrequency.get(token) || 0) + 1);
    }
  }

  for (const article of articles) {
    const text = article.title + " " + (article.summary || "");
    const tokens = tokenize(text);
    const termFreq = new Map<string, number>();
    for (const token of tokens) {
      termFreq.set(token, (termFreq.get(token) || 0) + 1);
    }

    const vector: TFIDFVector = {};
    for (const [token, tf] of termFreq) {
      const df = docFrequency.get(token) || 1;
      const idf = Math.log(totalDocs / df);
      vector[token] = tf * idf;
    }
    vectors.set(article.id, vector);
  }

  return vectors;
}

function cosineSimilarity(v1: TFIDFVector, v2: TFIDFVector): number {
  let dotProduct = 0;
  let norm1 = 0;
  let norm2 = 0;

  for (const [token, weight] of Object.entries(v1)) {
    dotProduct += weight * (v2[token] || 0);
    norm1 += weight * weight;
  }

  for (const weight of Object.values(v2)) {
    norm2 += weight * weight;
  }

  if (norm1 === 0 || norm2 === 0) return 0;
  return dotProduct / (Math.sqrt(norm1) * Math.sqrt(norm2));
}

function vectorNorm(v: TFIDFVector): number {
  let sum = 0;
  for (const w of Object.values(v)) sum += w * w;
  return Math.sqrt(sum);
}

/** Cosine similarity with precomputed norms; iterates the smaller vector. */
function cosineWithNorms(v1: TFIDFVector, n1: number, v2: TFIDFVector, n2: number): number {
  if (n1 === 0 || n2 === 0) return 0;
  // Iterate v1; the callers keep the shorter vector first when it matters.
  let dot = 0;
  for (const token in v1) {
    const w = v2[token];
    if (w) dot += v1[token] * w;
  }
  return dot / (n1 * n2);
}

function countSharedEntities(
  entities1: string[],
  entities2: string[]
): number {
  const set1 = new Set(entities1);
  return entities2.filter((e) => set1.has(e)).length;
}

// ── Union-Find ────────────────────────────────────────────────────────────────

class UnionFind {
  private parent: Map<string, string>;

  constructor(items: string[]) {
    this.parent = new Map();
    for (const item of items) {
      this.parent.set(item, item);
    }
  }

  find(x: string): string {
    if (this.parent.get(x) !== x) {
      this.parent.set(x, this.find(this.parent.get(x)!));
    }
    return this.parent.get(x)!;
  }

  union(x: string, y: string): void {
    const rootX = this.find(x);
    const rootY = this.find(y);
    if (rootX !== rootY) {
      this.parent.set(rootX, rootY);
    }
  }

  getClusters(): Map<string, string[]> {
    const clusters = new Map<string, string[]>();
    for (const item of this.parent.keys()) {
      const root = this.find(item);
      if (!clusters.has(root)) {
        clusters.set(root, []);
      }
      clusters.get(root)!.push(item);
    }
    return clusters;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function batchArray<T>(array: T[], size: number): T[][] {
  const batches: T[][] = [];
  for (let i = 0; i < array.length; i += size) {
    batches.push(array.slice(i, i + size));
  }
  return batches;
}

// ── Phase 1: RSS Ingest ───────────────────────────────────────────────────────

async function ingestRSS(): Promise<{ new_articles: number; log: { source: string; count: number; error?: string }[] }> {
  const { rows: sources } = await pool.query(
    "SELECT id, name, rss_url FROM sources WHERE is_active"
  );

  const fetched: RawArticle[] = [];
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
    return { new_articles: 0, log };
  }

  const { rows: existing } = await pool.query(
    "SELECT url FROM articles WHERE url = ANY($1::text[])",
    [fetched.map((a) => a.url)]
  );
  const knownUrls = new Set(existing.map((r: { url: string }) => r.url));

  const seenUrls = new Map<string, RawArticle>();
  for (const a of fetched) {
    if (!knownUrls.has(a.url) && !seenUrls.has(a.url)) {
      seenUrls.set(a.url, a);
    }
  }
  const newArts = [...seenUrls.values()];

  if (!newArts.length) {
    return { new_articles: 0, log };
  }

  for (const batch of batchArray(newArts, 200)) {
    await pool.query(
      `INSERT INTO articles (source_id, title, url, summary, image_url, published_at, fetched_at)
       SELECT source_id, title, url, summary, image_url, published_at, fetched_at
         FROM jsonb_to_recordset($1::jsonb) AS t(source_id uuid, title text, url text, summary text,
              image_url text, published_at timestamptz, fetched_at timestamptz)
       ON CONFLICT (url) DO NOTHING`,
      [JSON.stringify(batch)]
    );
  }

  return { new_articles: newArts.length, log };
}

// ── Phase 2: Clustering ──────────────────────────────────────────────────────

async function clusterStories(): Promise<{
  articles_processed: number;
  valid_clusters: number;
  articles_assigned: number;
  singletons: number;
  attached_to_existing?: number;
}> {
  const cycleId = new Date().toISOString();

  const { rows: articles } = await pool.query(
    `SELECT id, title, summary, published_at, source_id FROM articles
      WHERE story_id IS NULL AND published_at >= $1
      ORDER BY published_at DESC LIMIT $2`,
    [new Date(Date.now() - WINDOW_HOURS * 60 * 60 * 1000).toISOString(), MAX_ARTICLES_PER_RUN]
  );
  if (articles.length === 0) {
    return {
      articles_processed: 0,
      valid_clusters: 0,
      articles_assigned: 0,
      singletons: 0,
    };
  }

  const tfidfVectors = computeTFIDF(articles);

  const entitiesMap = new Map<string, string[]>();
  for (const article of articles) {
    entitiesMap.set(article.id, extractEntities(article.title));
  }

  const norms = new Map<string, number>();
  for (const a of articles) norms.set(a.id, vectorNorm(tfidfVectors.get(a.id)!));

  const uf = new UnionFind(articles.map((a) => a.id));

  for (let i = 0; i < articles.length; i++) {
    for (let j = i + 1; j < articles.length; j++) {
      const a1 = articles[i];
      const a2 = articles[j];

      const similarity = cosineWithNorms(
        tfidfVectors.get(a1.id)!, norms.get(a1.id)!,
        tfidfVectors.get(a2.id)!, norms.get(a2.id)!
      );
      const sharedEntities = countSharedEntities(
        entitiesMap.get(a1.id)!,
        entitiesMap.get(a2.id)!
      );

      // Link if: strong text similarity alone, OR shared entities backed by at
      // least a weak text similarity. The similarity floor on the entity path
      // prevents one common person/place from chaining unrelated subjects.
      const strongText = similarity >= STRONG_TFIDF_THRESHOLD;
      const entityBacked =
        sharedEntities >= NER_THRESHOLD &&
        similarity >= NER_LINK_MIN_SIMILARITY;
      const moderateText = similarity >= TFIDF_THRESHOLD;

      if (strongText || moderateText || entityBacked) {
        uf.union(a1.id, a2.id);
      }
    }
  }

  const rawClusters = uf.getClusters();
  const validClusters: Cluster[] = [];
  const singletonIds: string[] = [];

  for (const [_, articleIds] of rawClusters) {
    if (articleIds.length >= MIN_CLUSTER_SIZE) {
      const clusterArticles = articles.filter((a) =>
        articleIds.includes(a.id)
      );
      const allEntities = new Set<string>();
      for (const id of articleIds) {
        for (const entity of entitiesMap.get(id)!) {
          allEntities.add(entity);
        }
      }
      validClusters.push({ articles: clusterArticles, entities: allEntities });
    } else {
      singletonIds.push(...articleIds);
    }
  }

  // Cross-cycle merge (72h window)
  const { rows: recentStories } = await pool.query(
    "SELECT id, title FROM stories WHERE last_updated_at >= $1",
    [new Date(Date.now() - CROSS_CYCLE_HOURS * 60 * 60 * 1000).toISOString()]
  );
  // Sources that already have a primary article in each recent story (one primary per source).
  const { rows: primaryRows } = await pool.query(
    `SELECT a.story_id, a.source_id FROM articles a
       JOIN stories s ON s.id = a.story_id
      WHERE s.last_updated_at >= $1 AND a.is_primary`,
    [new Date(Date.now() - CROSS_CYCLE_HOURS * 60 * 60 * 1000).toISOString()]
  );
  const primarySources = new Map<string, Set<string>>();
  for (const row of primaryRows) {
    if (!primarySources.has(row.story_id)) primarySources.set(row.story_id, new Set());
    primarySources.get(row.story_id)!.add(row.source_id);
  }

  const recentStoriesEntities = new Map<string, Set<string>>();
  if (recentStories) {
    for (const story of recentStories) {
      const entities = extractEntities(story.title);
      recentStoriesEntities.set(story.id, new Set(entities));
    }
  }

  const newStoryIds: string[] = [];
  const assignments: {
    articleId: string;
    storyId: string;
    isPrimary: boolean;
  }[] = [];

  for (const cluster of validClusters) {
    let mergedStoryId: string | null = null;

    // Pick the story with the MOST shared entities above threshold, not the
    // first one to cross it. Avoids grabbing an unrelated story that happens
    // to share the minimum count earlier in iteration order.
    let bestShared = CROSS_CYCLE_NER_THRESHOLD - 1;
    for (const [storyId, storyEntities] of recentStoriesEntities) {
      const shared = [...cluster.entities].filter((e) =>
        storyEntities.has(e)
      ).length;
      if (shared > bestShared) {
        bestShared = shared;
        mergedStoryId = storyId;
      }
    }

    if (!mergedStoryId) {
      const headline = cluster.articles[0].title.slice(0, 120);
      const firstPublished = cluster.articles.reduce(
        (earliest, article) =>
          article.published_at < earliest ? article.published_at : earliest,
        cluster.articles[0].published_at
      );
      const { rows: [newStory] } = await pool.query(
        `INSERT INTO stories (title, cycle_id, first_published_at, last_updated_at, topic_tags)
         VALUES ($1, $2, $3, now(), $4) RETURNING id`,
        [headline, cycleId, firstPublished, topicTags(headline, ...cluster.articles.slice(0, 5).map((a) => a.title))]
      );
      mergedStoryId = newStory.id;
      newStoryIds.push(newStory.id);
    } else {
      await pool.query("UPDATE stories SET last_updated_at = now() WHERE id = $1", [mergedStoryId]);
    }

    const sourcesSeen = new Set<string>(primarySources.get(mergedStoryId) ?? []);
    if (!primarySources.has(mergedStoryId)) primarySources.set(mergedStoryId, sourcesSeen);
    for (const article of cluster.articles) {
      const isPrimary = !sourcesSeen.has(article.source_id);
      if (isPrimary) {
        sourcesSeen.add(article.source_id);
      }
      assignments.push({
        articleId: article.id,
        storyId: mergedStoryId,
        isPrimary,
      });
    }
  }

  // Lone articles: attach each to the best-matching recent story instead of leaving it orphaned.
  const attached = new Set<string>();
  if (singletonIds.length > 0) {
    const { rows: storyDocs } = await pool.query(
      `SELECT s.id, s.title, array_agg(a.title) AS titles
         FROM stories s JOIN articles a ON a.story_id = s.id
        WHERE s.last_updated_at >= $1
        GROUP BY s.id, s.title`,
      [new Date(Date.now() - CROSS_CYCLE_HOURS * 60 * 60 * 1000).toISOString()]
    );
    if (storyDocs.length > 0) {
      const singles = articles.filter((a) => singletonIds.includes(a.id));
      const docs: ClusterArticle[] = storyDocs.map((d) => ({
        id: `story:${d.id}`,
        title: [d.title, ...d.titles].join(" "),
        summary: null,
        published_at: "",
        source_id: "",
      }));
      const vectors = computeTFIDF([...singles, ...docs]);
      const docNorms = docs.map((d) => vectorNorm(vectors.get(d.id)!));
      const docEntities = docs.map((d) => new Set(extractEntities(d.title)));

      for (const single of singles) {
        const v = vectors.get(single.id)!;
        const n = vectorNorm(v);
        const ents = entitiesMap.get(single.id) ?? [];
        let best = -1;
        let bestSim = SINGLETON_ATTACH_SIMILARITY;
        for (let i = 0; i < docs.length; i++) {
          const sim = cosineWithNorms(v, n, vectors.get(docs[i].id)!, docNorms[i]);
          if (sim > bestSim && ents.some((e) => docEntities[i].has(e))) {
            bestSim = sim;
            best = i;
          }
        }
        if (best < 0) continue;
        const storyId = storyDocs[best].id;
        const seen = primarySources.get(storyId) ?? new Set<string>();
        primarySources.set(storyId, seen);
        const isPrimary = !seen.has(single.source_id);
        if (isPrimary) seen.add(single.source_id);
        assignments.push({ articleId: single.id, storyId, isPrimary });
        attached.add(single.id);
      }
    }
  }

  for (const assignmentBatch of batchArray(assignments, BATCH_SIZE)) {
    await Promise.all(
      assignmentBatch.map(({ articleId, storyId, isPrimary }) =>
        pool.query(
          `UPDATE articles SET story_id = $2, clustered_at = now(), entities = $3::text[], is_primary = $4
            WHERE id = $1`,
          [articleId, storyId, entitiesMap.get(articleId) ?? [], isPrimary]
        )
      )
    );
  }

  // A story's "last updated" is when its newest article was published, not when we merged it.
  const touched = [...new Set(assignments.map((a) => a.storyId))];
  if (touched.length > 0) {
    await pool.query(
      `UPDATE stories s SET last_updated_at = m.latest
         FROM (SELECT story_id, max(published_at) AS latest FROM articles
                WHERE story_id = ANY($1::uuid[]) GROUP BY story_id) m
        WHERE s.id = m.story_id`,
      [touched]
    );
  }

  // Mark lone articles as seen (they stay unclustered and are retried while inside the window).
  const unseen = singletonIds.filter((id) => !attached.has(id));
  if (unseen.length > 0) {
    await pool.query("UPDATE articles SET clustered_at = now() WHERE id = ANY($1::uuid[]) AND clustered_at IS NULL", [unseen]);
  }

  await pool.query("UPDATE stories SET is_featured = false WHERE is_featured");
  await pool.query(
    `UPDATE stories SET is_featured = true WHERE id = (
       SELECT s.id FROM stories s JOIN articles a ON a.story_id = s.id
        WHERE a.published_at > now() - interval '6 hours'
        GROUP BY s.id ORDER BY count(*) DESC LIMIT 1)`
  );

  // Notify about the freshly created stories (at most once per hour).
  if (newStoryIds.length > 0) {
    const { rows: [last] } = await pool.query("SELECT sent_at FROM notifications ORDER BY sent_at DESC LIMIT 1");
    if (!last || Date.now() - new Date(last.sent_at).getTime() > 60 * 60 * 1000) {
      const { rows: [top] } = await pool.query(
        `SELECT s.id, s.title, count(a.id)::int AS n FROM stories s
           LEFT JOIN articles a ON a.story_id = s.id
          WHERE s.id = ANY($1::uuid[]) GROUP BY s.id, s.title
          ORDER BY n DESC, s.created_at DESC LIMIT 1`,
        [newStoryIds]
      );
      if (top) {
        const body = `${top.n} ${top.n === 1 ? "source" : "sources"} • ${newStoryIds.length} ${
          newStoryIds.length === 1 ? "nouvelle actualité" : "nouvelles actualités"
        }`;
        await pool.query(
          "INSERT INTO notifications (title, body, story_count, story_id) VALUES ($1, $2, $3, $4)",
          [top.title, body, newStoryIds.length, top.id]
        );
      }
    }
  }

  return {
    articles_processed: articles.length,
    valid_clusters: validClusters.length,
    articles_assigned: assignments.length,
    singletons: singletonIds.length - attached.size,
    attached_to_existing: attached.size,
  };
}

// ── Main Handler ──────────────────────────────────────────────────────────────

async function handle(req: Request): Promise<Response> {
  const secret = process.env.CRON_SECRET;
  if (!secret || req.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    // Phase 1: Ingest RSS feeds
    const ingestResult = await ingestRSS();

    // Phase 2: Cluster unclustered articles into stories
    const clusterResult = await clusterStories();

    // Phase 3: Gemini rewrites the titles of new stories (short, neutral, 3 lines max)
    let titlesRewritten = 0;
    try { titlesRewritten = await rewriteStoryTitles(); } catch (e) { console.error("title rewrite failed:", e); }

    return new Response(
      JSON.stringify({
        ok: true,
        ingest: {
          new_articles: ingestResult.new_articles,
          source_log: ingestResult.log,
        },
        cluster: clusterResult,
        titles_rewritten: titlesRewritten,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("refresh-stories error:", message);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}

export const GET = handle;
export const POST = handle;

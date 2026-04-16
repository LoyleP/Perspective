import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Constants
const TFIDF_THRESHOLD = 0.28;
const NER_THRESHOLD = 2;
const CROSS_CYCLE_NER_THRESHOLD = 2;
const MIN_CLUSTER_SIZE = 2;
const WINDOW_HOURS = 6;
const BATCH_SIZE = 50;
const MAX_ARTICLES_PER_RUN = 200; // Limit to prevent memory issues

const FRENCH_STOPWORDS = new Set([
  "le", "la", "les", "un", "une", "des", "de", "du", "et", "ou", "mais",
  "donc", "or", "ni", "car", "ce", "cette", "ces", "cet", "mon", "ton",
  "son", "notre", "votre", "leur", "mes", "tes", "ses", "nos", "vos",
  "leurs", "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
  "me", "te", "se", "lui", "leur", "y", "en", "dans", "sur", "sous",
  "avec", "sans", "pour", "par", "vers", "chez", "contre", "entre",
  "pendant", "selon", "malgré", "depuis", "avant", "après", "plus",
  "moins", "très", "trop", "assez", "peu"
]);

interface Article {
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
  articles: Article[];
  entities: Set<string>;
}

// Text normalization
function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

// Tokenization
function tokenize(text: string): string[] {
  const normalized = normalize(text);
  return normalized
    .split(/\s+/)
    .map(token => token.replace(/[^a-z]/g, ""))
    .filter(token => token.length >= 3 && !FRENCH_STOPWORDS.has(token));
}

// Extract named entities using heuristic
function extractEntities(title: string): string[] {
  const words = title.split(/\s+/);
  const entities: string[] = [];

  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    const cleaned = word.replace(/[^a-zA-ZÀ-ÿ]/g, "");

    // ALL-CAPS acronyms (2+ chars)
    if (cleaned.length >= 2 && cleaned === cleaned.toUpperCase()) {
      entities.push(normalize(cleaned));
      continue;
    }

    // Capitalized mid-sentence words (not first word)
    if (i > 0 && cleaned.length >= 3 && /^[A-ZÀ-Ÿ]/.test(cleaned)) {
      entities.push(normalize(cleaned));
    }
  }

  return [...new Set(entities)];
}

// Compute TF-IDF weights for a set of articles
function computeTFIDF(articles: Article[]): Map<string, TFIDFVector> {
  const vectors = new Map<string, TFIDFVector>();
  const docFrequency = new Map<string, number>();
  const totalDocs = articles.length;

  // Count document frequencies
  for (const article of articles) {
    const text = article.title + " " + (article.summary || "");
    const tokens = new Set(tokenize(text));

    for (const token of tokens) {
      docFrequency.set(token, (docFrequency.get(token) || 0) + 1);
    }
  }

  // Compute TF-IDF vectors
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

// Cosine similarity between two TF-IDF vectors
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

// Count shared entities
function countSharedEntities(entities1: string[], entities2: string[]): number {
  const set1 = new Set(entities1);
  return entities2.filter(e => set1.has(e)).length;
}

// Union-Find data structure
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

// Batch array into chunks
function batch<T>(array: T[], size: number): T[][] {
  const batches: T[][] = [];
  for (let i = 0; i < array.length; i += size) {
    batches.push(array.slice(i, i + size));
  }
  return batches;
}

Deno.serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const cycleId = new Date().toISOString();

    // Parse request body for optional window_hours parameter
    let windowHours = WINDOW_HOURS;
    try {
      const body = await req.json();
      if (body.window_hours !== undefined) {
        windowHours = body.window_hours;
      }
    } catch {
      // No body or invalid JSON, use default
    }

    // 1. Fetch unclustered articles (optionally filtered by time window)
    let query = supabase
      .from("articles")
      .select("id, title, summary, published_at, source_id")
      .is("story_id", null);

    // If window_hours is 0 or null, fetch all unclustered articles
    if (windowHours > 0) {
      query = query.gte("published_at", new Date(Date.now() - windowHours * 60 * 60 * 1000).toISOString());
    }

    const { data: articles, error: fetchError } = await query
      .order("published_at", { ascending: false })
      .limit(MAX_ARTICLES_PER_RUN);

    if (fetchError) throw fetchError;
    if (!articles || articles.length === 0) {
      return new Response(
        JSON.stringify({ message: "No unclustered articles found" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. Compute TF-IDF weights
    const tfidfVectors = computeTFIDF(articles);

    // 3. Extract named entities
    const entitiesMap = new Map<string, string[]>();
    for (const article of articles) {
      entitiesMap.set(article.id, extractEntities(article.title));
    }

    // 4. Pairwise comparison using Union-Find
    const uf = new UnionFind(articles.map(a => a.id));

    for (let i = 0; i < articles.length; i++) {
      for (let j = i + 1; j < articles.length; j++) {
        const article1 = articles[i];
        const article2 = articles[j];

        const v1 = tfidfVectors.get(article1.id)!;
        const v2 = tfidfVectors.get(article2.id)!;
        const similarity = cosineSimilarity(v1, v2);

        const entities1 = entitiesMap.get(article1.id)!;
        const entities2 = entitiesMap.get(article2.id)!;
        const sharedEntities = countSharedEntities(entities1, entities2);

        if (similarity >= TFIDF_THRESHOLD || sharedEntities >= NER_THRESHOLD) {
          uf.union(article1.id, article2.id);
        }
      }
    }

    // 5. Extract clusters
    const rawClusters = uf.getClusters();
    const validClusters: Cluster[] = [];
    const singletonIds: string[] = [];

    for (const [_, articleIds] of rawClusters) {
      if (articleIds.length >= MIN_CLUSTER_SIZE) {
        const clusterArticles = articles.filter(a => articleIds.includes(a.id));
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

    // 6. Cross-cycle merge
    const { data: recentStories } = await supabase
      .from("stories")
      .select("id, title")
      .gte("last_updated_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    const recentStoriesEntities = new Map<string, Set<string>>();
    if (recentStories) {
      for (const story of recentStories) {
        const entities = extractEntities(story.title);
        recentStoriesEntities.set(story.id, new Set(entities));
      }
    }

    const assignments: { articleId: string; storyId: string }[] = [];

    for (const cluster of validClusters) {
      let mergedStoryId: string | null = null;

      // Check for cross-cycle merge
      for (const [storyId, storyEntities] of recentStoriesEntities) {
        const sharedEntities = [...cluster.entities].filter(e => storyEntities.has(e)).length;
        if (sharedEntities >= CROSS_CYCLE_NER_THRESHOLD) {
          mergedStoryId = storyId;
          break;
        }
      }

      // Create new story if no merge
      if (!mergedStoryId) {
        const headline = cluster.articles[0].title.slice(0, 120);
        const firstPublished = cluster.articles.reduce((earliest, article) =>
          article.published_at < earliest ? article.published_at : earliest,
          cluster.articles[0].published_at
        );
        const { data: newStory, error: createError } = await supabase
          .from("stories")
          .insert({
            title: headline,
            cycle_id: cycleId,
            first_published_at: firstPublished,
            last_updated_at: new Date().toISOString()
          })
          .select("id")
          .single();

        if (createError) throw createError;
        mergedStoryId = newStory.id;
      } else {
        // Update existing story timestamp
        await supabase
          .from("stories")
          .update({ last_updated_at: new Date().toISOString() })
          .eq("id", mergedStoryId);
      }

      // Record assignments and determine primary articles (one per source)
      const sourcesSeen = new Set<string>();
      for (const article of cluster.articles) {
        const isPrimary = !sourcesSeen.has(article.source_id);
        if (isPrimary) {
          sourcesSeen.add(article.source_id);
        }
        assignments.push({
          articleId: article.id,
          storyId: mergedStoryId,
          isPrimary
        });
      }
    }

    // 7. Batch update clustered articles
    for (const assignmentBatch of batch(assignments, BATCH_SIZE)) {
      await Promise.all(
        assignmentBatch.map(({ articleId, storyId, isPrimary }) =>
          supabase
            .from("articles")
            .update({
              story_id: storyId,
              clustered_at: new Date().toISOString(),
              entities: entitiesMap.get(articleId),
              is_primary: isPrimary
            })
            .eq("id", articleId)
        )
      );
    }

    // 8. Mark singletons as processed
    for (const singletonBatch of batch(singletonIds, BATCH_SIZE)) {
      await Promise.all(
        singletonBatch.map(id =>
          supabase
            .from("articles")
            .update({
              clustered_at: new Date().toISOString(),
              entities: entitiesMap.get(id)
            })
            .eq("id", id)
        )
      );
    }

    // 9. Update featured story
    await supabase.rpc("update_featured_story");

    return new Response(
      JSON.stringify({
        articles_processed: articles.length,
        valid_clusters: validClusters.length,
        articles_assigned: assignments.length,
        singletons: singletonIds.length,
        cycle_id: cycleId
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

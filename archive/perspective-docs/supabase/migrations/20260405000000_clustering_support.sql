-- Add clustering support columns to articles and stories tables
-- Migration: 20260405000000_clustering_support

-- Articles columns for clustering
ALTER TABLE articles ADD COLUMN IF NOT EXISTS entities TEXT[] DEFAULT '{}';
ALTER TABLE articles ADD COLUMN IF NOT EXISTS tfidf_weights JSONB;
ALTER TABLE articles ADD COLUMN IF NOT EXISTS clustered_at TIMESTAMPTZ;

-- Stories columns for cycle tracking
ALTER TABLE stories ADD COLUMN IF NOT EXISTS cycle_id TEXT;

-- Indexes for clustering performance
CREATE INDEX IF NOT EXISTS articles_story_id_idx ON articles(story_id);
CREATE INDEX IF NOT EXISTS articles_published_at_idx ON articles(published_at DESC);
CREATE INDEX IF NOT EXISTS articles_clustered_at_idx ON articles(clustered_at);
CREATE INDEX IF NOT EXISTS stories_last_updated_at_idx ON stories(last_updated_at DESC);

-- Add is_primary flag to articles table
-- This marks one article per source as the "representative" article for a story
-- Enables "one article per source" UI approach

ALTER TABLE articles
ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;

-- Create index for efficient querying of primary articles
CREATE INDEX IF NOT EXISTS articles_is_primary_idx ON articles(is_primary) WHERE is_primary = true;

-- Create unique constraint: only one primary article per (story_id, source_id) combination
CREATE UNIQUE INDEX IF NOT EXISTS articles_story_source_primary_unique
ON articles(story_id, source_id)
WHERE is_primary = true AND story_id IS NOT NULL;

COMMENT ON COLUMN articles.is_primary IS 'True if this is the representative article from this source for this story';

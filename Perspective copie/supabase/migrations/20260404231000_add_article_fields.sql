-- Add missing fields to articles table that Swift model expects
ALTER TABLE articles
ADD COLUMN IF NOT EXISTS raw_keywords TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS click_count INTEGER DEFAULT 0;

-- Add comment
COMMENT ON COLUMN articles.raw_keywords IS 'Keywords extracted from article content';
COMMENT ON COLUMN articles.click_count IS 'Number of times article was clicked by users';

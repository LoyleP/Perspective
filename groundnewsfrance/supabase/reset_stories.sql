-- Reset all stories so the next ingest-rss run re-clusters everything from scratch.
-- Run both statements in order.

-- 1. Unassign all articles
UPDATE articles SET story_id = NULL;

-- 2. Delete all stories
DELETE FROM stories;

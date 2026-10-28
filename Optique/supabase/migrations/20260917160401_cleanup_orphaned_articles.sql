-- Clean up orphaned articles (articles with NULL story_id)
-- These are unclustered articles that were never assigned to a story
-- and are causing query performance issues (179k+ rows)

DELETE FROM articles WHERE story_id IS NULL;

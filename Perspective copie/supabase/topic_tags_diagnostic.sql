-- topic_tags_diagnostic.sql
-- Run this in the Supabase SQL editor.
-- Purpose: surface the current state of topic_tags on stories so you can
-- decide how to tag each story and run the UPDATE script below.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. COLUMN STATE — how many stories are tagged vs. untagged
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    COUNT(*)                                                    AS total_stories,
    COUNT(*) FILTER (WHERE topic_tags IS NULL)                  AS null_tags,
    COUNT(*) FILTER (WHERE topic_tags = '{}')                   AS empty_tags,
    COUNT(*) FILTER (WHERE topic_tags IS NOT NULL
                       AND topic_tags != '{}')                  AS has_tags
FROM stories;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. UNIQUE TAG VALUES — what's already in use (if anything)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    tag,
    COUNT(*) AS story_count
FROM stories, UNNEST(topic_tags) AS tag
GROUP BY tag
ORDER BY story_count DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. STORY LIST — id, title, article count, current tags
-- Use this to decide which tag(s) to assign to each story.
--
-- Expected tag values (must match the iOS app's StoryTopic.filterValue):
--   politique | economie | societe | international | environnement | justice | culture
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    s.id,
    s.title,
    s.last_updated_at::DATE                     AS last_updated,
    s.is_featured,
    COUNT(a.id)                                 AS article_count,
    COALESCE(s.topic_tags, '{}')                AS current_tags
FROM stories s
LEFT JOIN articles a ON a.story_id = s.id
GROUP BY s.id, s.title, s.last_updated_at, s.is_featured, s.topic_tags
ORDER BY s.last_updated_at DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. UPDATE TEMPLATE
-- Once you know which tag(s) each story should have, copy and edit the
-- UPDATE below. You can assign multiple tags per story.
--
-- Example:
--   UPDATE stories SET topic_tags = ARRAY['politique']
--   WHERE id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
--
--   UPDATE stories SET topic_tags = ARRAY['economie', 'politique']
--   WHERE id = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy';
--
-- Or update all untagged stories at once with a single tag if most share
-- the same topic:
--   UPDATE stories SET topic_tags = ARRAY['politique']
--   WHERE topic_tags IS NULL OR topic_tags = '{}';
-- ─────────────────────────────────────────────────────────────────────────────

-- Run section 3 first, then write your UPDATEs here and execute them.

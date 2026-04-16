-- Analysis query to understand article titles and story tags
-- This will help identify which keywords should trigger which tags

-- Part 1: Show stories with their tags and a sample of article titles
SELECT
    s.id,
    s.title as story_title,
    s.topic_tags,
    COUNT(a.id) as article_count,
    array_agg(DISTINCT src.name) as sources,
    -- Sample article headlines from this story
    string_agg(DISTINCT a.headline, ' | ') as sample_headlines
FROM stories s
LEFT JOIN articles a ON a.story_id = s.id
LEFT JOIN sources src ON a.source_id = src.id
GROUP BY s.id, s.title, s.topic_tags
ORDER BY s.created_at DESC
LIMIT 30;

-- Part 2: Show untagged stories (empty topic_tags array)
SELECT
    COUNT(*) as untagged_story_count
FROM stories
WHERE topic_tags = '{}';

-- Part 3: Show distribution of tags
SELECT
    unnest(topic_tags) as tag,
    COUNT(*) as story_count
FROM stories
WHERE topic_tags != '{}'
GROUP BY tag
ORDER BY story_count DESC;

-- Part 4: Sample of article headlines that are currently untagged
SELECT
    a.headline,
    src.name as source,
    a.published_at
FROM articles a
LEFT JOIN sources src ON a.source_id = src.id
LEFT JOIN stories s ON a.story_id = s.id
WHERE s.id IS NULL OR s.topic_tags = '{}'
ORDER BY a.published_at DESC
LIMIT 50;

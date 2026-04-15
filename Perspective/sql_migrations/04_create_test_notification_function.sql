-- Create a test notification function (for dev/testing purposes)
-- This function creates a notification entry that mimics what the auto-trigger does

CREATE OR REPLACE FUNCTION create_test_notification()
RETURNS void AS $$
DECLARE
    top_story_title TEXT;
    top_story_article_count INTEGER;
    total_stories INTEGER;
BEGIN
    -- Count total stories
    SELECT COUNT(*) INTO total_stories
    FROM stories;

    -- Find the story with the most articles
    SELECT s.title, COUNT(a.id)
    INTO top_story_title, top_story_article_count
    FROM stories s
    LEFT JOIN articles a ON a.story_id = s.id
    GROUP BY s.id, s.title
    ORDER BY COUNT(a.id) DESC, s.created_at DESC
    LIMIT 1;

    -- Create test notification
    INSERT INTO notifications (title, body, story_count, sent_at)
    VALUES (
        COALESCE(top_story_title, 'Test Notification'),
        COALESCE(
            top_story_article_count || ' ' ||
            CASE WHEN top_story_article_count = 1 THEN 'source'
                 ELSE 'sources'
            END ||
            ' • ' ||
            total_stories || ' ' ||
            CASE WHEN total_stories = 1 THEN 'actualité disponible'
                 ELSE 'actualités disponibles'
            END,
            'Test notification'
        ),
        COALESCE(total_stories, 0),
        NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

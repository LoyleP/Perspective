-- Automatically create notification when stories are added after ingest

-- Drop existing trigger if it exists (safe to re-run this migration)
DROP TRIGGER IF EXISTS trigger_notify_new_stories ON stories;

-- Function to create notification after story insert
CREATE OR REPLACE FUNCTION notify_new_stories()
RETURNS TRIGGER AS $$
DECLARE
    story_count INTEGER;
    last_notification_time TIMESTAMPTZ;
    top_story_title TEXT;
    top_story_article_count INTEGER;
BEGIN
    -- Get the time of the last notification
    SELECT sent_at INTO last_notification_time
    FROM notifications
    ORDER BY sent_at DESC
    LIMIT 1;

    -- Only create notification if last one was > 1 hour ago (avoid spam)
    IF last_notification_time IS NULL OR
       (NOW() - last_notification_time) > INTERVAL '1 hour' THEN

        -- Count stories created in the last 5 minutes
        SELECT COUNT(*) INTO story_count
        FROM stories
        WHERE created_at > NOW() - INTERVAL '5 minutes';

        -- If we have new stories, create a notification
        IF story_count > 0 THEN
            -- Find the story with the most articles from the recent batch
            SELECT s.title, COUNT(a.id)
            INTO top_story_title, top_story_article_count
            FROM stories s
            LEFT JOIN articles a ON a.story_id = s.id
            WHERE s.created_at > NOW() - INTERVAL '5 minutes'
            GROUP BY s.id, s.title
            ORDER BY COUNT(a.id) DESC, s.created_at DESC
            LIMIT 1;

            -- Create notification with the top story as the title
            INSERT INTO notifications (title, body, story_count, sent_at)
            VALUES (
                COALESCE(top_story_title, 'Nouvelles actualités'),
                top_story_article_count || ' ' ||
                CASE WHEN top_story_article_count = 1 THEN 'source'
                     ELSE 'sources'
                END ||
                ' • ' ||
                story_count || ' ' ||
                CASE WHEN story_count = 1 THEN 'nouvelle actualité'
                     ELSE 'nouvelles actualités'
                END,
                story_count,
                NOW()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger after stories are inserted
CREATE TRIGGER trigger_notify_new_stories
    AFTER INSERT ON stories
    FOR EACH STATEMENT
    EXECUTE FUNCTION notify_new_stories();

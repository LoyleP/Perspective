-- Replace batch notification trigger with per-story notifications.
-- Each newly inserted story now creates its own notification row,
-- using the story's title and a French topic label as the body.

-- Drop old batch trigger and function
DROP TRIGGER IF EXISTS trigger_notify_new_stories ON stories;
DROP FUNCTION IF EXISTS notify_new_stories();

-- One notification per inserted story
CREATE OR REPLACE FUNCTION notify_new_story()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_body TEXT;
BEGIN
  -- Map DB topic tag to French display label
  v_body := CASE NEW.topic_tags[1]
    WHEN 'politique'     THEN 'Politique'
    WHEN 'economie'      THEN 'Économie'
    WHEN 'societe'       THEN 'Société'
    WHEN 'international' THEN 'International'
    WHEN 'environnement' THEN 'Environnement'
    WHEN 'justice'       THEN 'Justice'
    WHEN 'culture'       THEN 'Culture'
    ELSE                      'Nouvelle actualité'
  END;

  INSERT INTO notifications (title, body, story_count)
  VALUES (NEW.title, v_body, 1);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_notify_new_story ON stories;

CREATE TRIGGER trigger_notify_new_story
AFTER INSERT ON stories
FOR EACH ROW
EXECUTE FUNCTION notify_new_story();

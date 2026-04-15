-- Add story_id FK to notifications and include it in the per-story trigger.

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS story_id UUID REFERENCES stories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_story_id ON notifications(story_id);

-- Update the trigger function to populate story_id
CREATE OR REPLACE FUNCTION notify_new_story()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_body TEXT;
BEGIN
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

  INSERT INTO notifications (title, body, story_count, story_id)
  VALUES (NEW.title, v_body, 1, NEW.id);

  RETURN NEW;
END;
$$;

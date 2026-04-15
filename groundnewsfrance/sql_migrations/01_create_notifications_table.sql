-- Simple notifications table to track notification history
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    story_count INTEGER NOT NULL DEFAULT 0,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);

-- RLS policy
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view notifications"
    ON notifications FOR SELECT
    USING (true);

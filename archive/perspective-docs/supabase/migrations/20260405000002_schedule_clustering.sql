-- Schedule the cluster-stories Edge Function to run every 6 hours
-- Migration: 20260405000002_schedule_clustering

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Store Supabase credentials in vault (if not already stored)
-- Note: These will need to be set with actual values after deployment
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'project_url') THEN
    PERFORM vault.create_secret(current_setting('app.settings.api_url', true), 'project_url');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'anon_key') THEN
    PERFORM vault.create_secret(current_setting('app.settings.anon_key', true), 'anon_key');
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Skip if vault is not available or settings are not configured
  NULL;
END $$;

-- Schedule cluster-stories to run every 6 hours (at 00:00, 06:00, 12:00, 18:00)
SELECT cron.schedule(
  'cluster-stories-every-6-hours',
  '0 */6 * * *',
  $$
  SELECT
    net.http_post(
        url:= (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/cluster-stories',
        headers:=jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key')
        ),
        body:='{}'::jsonb
    ) as request_id;
  $$
);

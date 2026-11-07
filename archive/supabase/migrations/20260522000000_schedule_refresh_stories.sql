-- Unschedule the old cluster-stories cron job
SELECT cron.unschedule('cluster-stories-every-6-hours');

-- Schedule refresh-stories to run every 2 days at midnight UTC
SELECT cron.schedule(
  'refresh-stories-every-48-hours',
  '0 0 */2 * *',
  $$
  SELECT
    net.http_post(
        url:= (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/refresh-stories',
        headers:=jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key')
        ),
        body:='{}'::jsonb
    ) as request_id;
  $$
);

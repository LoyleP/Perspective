-- Backend moved to Vercel + Neon: stop the Supabase-side schedules.
DO $$
DECLARE j record;
BEGIN
  FOR j IN SELECT jobname FROM cron.job WHERE jobname LIKE 'refresh-stories%' OR jobname LIKE 'cluster-stories%' LOOP
    PERFORM cron.unschedule(j.jobname);
  END LOOP;
END $$;

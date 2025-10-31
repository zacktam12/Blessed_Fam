-- Setup Supabase pg_cron extension for automated weekly performance computation
-- Run this SQL in your Supabase SQL Editor after enabling the pg_cron extension

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage on cron schema to postgres role
GRANT USAGE ON SCHEMA cron TO postgres;

-- Schedule weekly performance computation
-- Runs every Monday at 1:00 AM UTC
SELECT cron.schedule(
  'compute-weekly-performance',
  '0 1 * * 1', -- Cron expression: At 01:00 on Monday
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/compute_weekly_performance',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.supabase_anon_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Alternative: Call the SQL function directly (if you don't want to use Edge Functions)
-- This is simpler and doesn't require Edge Function deployment
SELECT cron.schedule(
  'compute-weekly-performance-direct',
  '0 1 * * 1', -- Cron expression: At 01:00 on Monday
  $$
  SELECT public.compute_weekly_performance(date_trunc('week', now())::date);
  $$
);

-- View scheduled jobs
SELECT * FROM cron.job;

-- Unschedule a job (if needed)
-- SELECT cron.unschedule('compute-weekly-performance');

-- To manually trigger for testing:
-- SELECT public.compute_weekly_performance(date_trunc('week', now())::date);

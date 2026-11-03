-- Authenticated scheduling for every database-driven Edge Function worker.
-- Jobs resolve URL and service key at execution time, so a fresh project can
-- apply migrations before setup stores its generated project credentials.

BEGIN;

CREATE OR REPLACE FUNCTION public.edge_request_headers()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets
   WHERE name = 'service_role_key'
   LIMIT 1;
  IF COALESCE(v_key, '') = '' THEN
    RAISE EXCEPTION 'Vault secret service_role_key is not configured';
  END IF;
  RETURN jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || v_key,
    'apikey', v_key
  );
END;
$$;
REVOKE ALL ON FUNCTION public.edge_request_headers() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.edge_request_headers() TO service_role;

DO $$
DECLARE v_name text;
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'process-ai-queue', 'process-ai-cadence', 'noshow-followup',
    'process-scheduled-messages-1min', 'process-message-sequences-1min',
    'agent-jobs-poller'
  ] LOOP
    BEGIN PERFORM cron.unschedule(v_name); EXCEPTION WHEN OTHERS THEN NULL; END;
  END LOOP;
END $$;

SELECT cron.schedule('process-ai-queue', '* * * * *', $job$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/ai-sales-agent',
    headers := public.edge_request_headers(),
    body := '{"action":"process_queue"}'::jsonb
  );
$job$);

SELECT cron.schedule('process-ai-cadence', '* * * * *', $job$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/ai-sales-agent',
    headers := public.edge_request_headers(),
    body := '{"action":"process_cadence"}'::jsonb
  );
$job$);

SELECT cron.schedule('noshow-followup', '30 12 * * 1-5', $job$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/process-noshow-followup',
    headers := public.edge_request_headers(), body := '{}'::jsonb
  );
$job$);

SELECT cron.schedule('process-scheduled-messages-1min', '* * * * *', $job$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/process-scheduled-messages',
    headers := public.edge_request_headers(), body := '{}'::jsonb
  );
$job$);

SELECT cron.schedule('process-message-sequences-1min', '* * * * *', $job$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/process-message-sequences',
    headers := public.edge_request_headers(), body := '{}'::jsonb
  );
$job$);

SELECT cron.schedule('agent-jobs-poller', '* * * * *', $job$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/agent-jobs-poller',
    headers := public.edge_request_headers(), body := '{}'::jsonb
  );
$job$);

COMMIT;

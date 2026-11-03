-- ============================================================
-- 0006 — Cron do Poller
--
-- O agent-jobs-poller é o "coração" da proatividade: a cada 1 minuto
-- ele verifica jobs assíncronos e lembretes/rotinas vencidos e acorda
-- os agentes pra trabalhar sozinhos.
--
-- URL e autenticação são resolvidas dinamicamente em config/Vault.
-- ============================================================

-- extensões necessárias (já existem em projetos Supabase, garante)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- remove agendamento anterior se reinstalando
DO $$ BEGIN
  PERFORM cron.unschedule('agent-jobs-poller');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
  'agent-jobs-poller',
  '* * * * *',
  $CRON$
  SELECT net.http_post(
    url := (SELECT value FROM public.config WHERE key='SUPABASE_PROJECT_URL') || '/functions/v1/agent-jobs-poller',
    headers := public.edge_request_headers(),
    body := '{}'::jsonb
  ) AS request_id
  $CRON$
);

-- confirma
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'agent-jobs-poller';

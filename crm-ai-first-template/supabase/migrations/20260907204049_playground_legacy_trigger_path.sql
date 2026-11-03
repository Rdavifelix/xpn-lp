BEGIN;
-- Invoker RPCs retain user privileges. Existing business triggers use unqualified table names.
ALTER FUNCTION public.playground_change_stage(uuid,uuid,text,uuid,text,uuid,boolean) SET search_path=pg_catalog,public;
ALTER FUNCTION public.playground_update_lead(uuid,uuid,jsonb,text,uuid) SET search_path=pg_catalog,public;
ALTER FUNCTION public.playground_schedule_meeting(uuid,uuid,uuid,timestamptz,integer,text,text,uuid) SET search_path=pg_catalog,public;
COMMIT;

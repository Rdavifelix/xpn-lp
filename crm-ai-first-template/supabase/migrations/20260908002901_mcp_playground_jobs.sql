BEGIN;
ALTER FUNCTION public.playground_change_stage(uuid,uuid,text,uuid,text,uuid,boolean) SET search_path=pg_catalog,public;
ALTER FUNCTION public.playground_update_lead(uuid,uuid,jsonb,text,uuid) SET search_path=pg_catalog,public;
CREATE TABLE crm_mcp.playground_jobs(id uuid PRIMARY KEY,tenant_id uuid NOT NULL,actor uuid NOT NULL,payload jsonb NOT NULL,status text NOT NULL DEFAULT 'running',events jsonb NOT NULL DEFAULT '[]',created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE crm_mcp.playground_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON crm_mcp.playground_jobs FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.mcp_playground_job(p_id uuid,p_payload jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid;j crm_mcp.playground_jobs%ROWTYPE;created boolean:=false;BEGIN
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_id::text,12));
 SELECT * INTO j FROM crm_mcp.playground_jobs WHERE id=p_id;
 IF FOUND THEN
  IF j.tenant_id<>tid OR j.actor<>(ctx->>'user_id')::uuid THEN RAISE EXCEPTION 'Teste não encontrado' USING ERRCODE='42501';END IF;
  IF p_payload IS NOT NULL AND p_payload<>j.payload THEN RAISE EXCEPTION 'request_id já utilizado' USING ERRCODE='22023';END IF;
 ELSE
  IF p_payload IS NULL THEN RAISE EXCEPTION 'Teste não encontrado' USING ERRCODE='P0002';END IF;
  IF p_payload-ARRAY['agent_id','channel','playground','session_id','message']<>'{}' OR p_payload->>'channel'<>'playground' OR length(coalesce(p_payload->>'message','')) NOT BETWEEN 1 AND 10000 OR (p_payload->'playground')-ARRAY['lead_id','deal_id']<>'{}' THEN RAISE EXCEPTION 'Teste inválido' USING ERRCODE='22023';END IF;
  PERFORM public.playground_assert_access((p_payload->>'agent_id')::uuid,(p_payload->'playground'->>'lead_id')::uuid);
  PERFORM public.agent_playground_context((p_payload->'playground'->>'lead_id')::uuid,(p_payload->'playground'->>'deal_id')::uuid);
  INSERT INTO crm_mcp.playground_jobs(id,tenant_id,actor,payload) VALUES(p_id,tid,(ctx->>'user_id')::uuid,p_payload) RETURNING * INTO j;created:=true;
 END IF;
 RETURN jsonb_build_object('test_id',j.id,'started',created,'status',CASE WHEN j.status='running' AND j.updated_at<now()-interval '4 minutes' THEN 'interrupted' ELSE j.status END,'events',j.events,'created_at',j.created_at,'updated_at',j.updated_at);
END $$;
CREATE FUNCTION public.playground_job_progress(p_id uuid,p_events jsonb,p_status text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF p_status NOT IN ('running','completed','failed','interrupted') OR jsonb_typeof(p_events)<>'array' OR octet_length(p_events::text)>1000000 THEN RAISE EXCEPTION 'Resultado inválido';END IF;
 UPDATE crm_mcp.playground_jobs SET events=crm_mcp.redact(p_events),status=p_status,updated_at=now() WHERE id=p_id;
END $$;
REVOKE ALL ON FUNCTION public.mcp_playground_job(uuid,jsonb),public.playground_job_progress(uuid,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mcp_playground_job(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.playground_job_progress(uuid,jsonb,text) TO service_role;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_playground_job','rpc/playground_qualify_lead','rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
      RAISE EXCEPTION 'Esta conexão só pode usar as operações MCP autorizadas' USING ERRCODE='42501'; END IF;
    PERFORM crm_mcp.context();
  ELSIF auth.jwt()->>'role'='authenticated' AND public.get_tenant_id() IS NULL
    AND p NOT IN ('rpc/tenant_onboard','config') THEN
    RAISE EXCEPTION 'Conclua o cadastro da sua empresa' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_request_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mcp_request_guard() TO anon,authenticated,service_role;


NOTIFY pgrst,'reload schema';
COMMIT;

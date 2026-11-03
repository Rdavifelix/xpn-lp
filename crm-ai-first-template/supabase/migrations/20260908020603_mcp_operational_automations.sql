BEGIN;
CREATE TABLE crm_mcp.automation_runs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES public.tenants(id),rule_id uuid NOT NULL,entity_id uuid NOT NULL,event text NOT NULL,status text NOT NULL,result jsonb,created_at timestamptz NOT NULL DEFAULT now());
REVOKE ALL ON crm_mcp.automation_runs FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.mcp_automation(p_action text,p_id uuid,p_request_id uuid DEFAULT NULL,p_active boolean DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid;r public.sales_automation_rules%ROWTYPE;payload jsonb;old crm_mcp.operations%ROWTYPE;result jsonb;s uuid;target public.sales_pipeline_stages%ROWTYPE;
BEGIN
 SELECT * INTO r FROM public.sales_automation_rules WHERE id=p_id AND tenant_id=tid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Automação não encontrada' USING ERRCODE='42501';END IF;
 IF p_action='runs' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM(SELECT id,event,entity_id,status,result,created_at FROM crm_mcp.automation_runs WHERE tenant_id=tid AND rule_id=p_id ORDER BY created_at DESC LIMIT 100)x;RETURN result;END IF;
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_action<>'activate' OR p_request_id IS NULL OR p_active IS NULL THEN RAISE EXCEPTION 'Operação inválida' USING ERRCODE='22023';END IF;
 payload:=jsonb_build_object('operation','automation_activate','id',p_id,'active',p_active);
 PERFORM pg_advisory_xact_lock(hashtextextended(tid::text,0));
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tid AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023';END IF;RETURN old.result;END IF;
 IF p_active THEN
  IF r.trigger_type NOT IN ('deal_created','deal_stage_changed','task_created','task_completed','meeting_scheduled','meeting_cancelled','meeting_rescheduled') OR r.action_type NOT IN ('move_deal_stage','create_task') THEN RAISE EXCEPTION 'Este executor suporta eventos de oportunidade/tarefa/reunião e ações internas move_deal_stage/create_task. Envios e temporizadores exigem outro executor.' USING ERRCODE='22023';END IF;
  IF coalesce(r.trigger_conditions,'{}')-ARRAY['stage_ids','exclude_stages','task_types','has_scheduled_date']<>'{}' THEN RAISE EXCEPTION 'Condições não suportadas pelo executor' USING ERRCODE='22023';END IF;
  FOR s IN SELECT x::uuid FROM jsonb_array_elements_text(coalesce(r.trigger_conditions->'stage_ids','[]')||coalesce(r.trigger_conditions->'exclude_stages','[]')) x LOOP
   IF NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=s AND tenant_id=tid) THEN RAISE EXCEPTION 'Etapa de outra empresa' USING ERRCODE='42501';END IF;
  END LOOP;
  IF r.action_type='move_deal_stage' THEN
   IF r.action_config-ARRAY['target_stage_id','only_if_position_less_than','executor','owner_id']<>'{}' THEN RAISE EXCEPTION 'Configuração de movimentação inválida' USING ERRCODE='22023';END IF;
   SELECT * INTO target FROM public.sales_pipeline_stages WHERE id=(r.action_config->>'target_stage_id')::uuid AND tenant_id=tid;
   IF NOT FOUND OR target.is_won OR target.is_lost THEN RAISE EXCEPTION 'Selecione etapa intermediária da empresa; encerramento exige ação explícita' USING ERRCODE='22023';END IF;
  ELSE
   IF length(coalesce(r.action_config->'task_template'->>'name','')) NOT BETWEEN 2 AND 200 OR r.action_config-ARRAY['task_template','executor','owner_id']<>'{}' OR r.action_config->'task_template'-ARRAY['name','description','days_offset','task_type','responsavel_id']<>'{}' OR coalesce(r.action_config->'task_template'->>'task_type','internal') NOT IN ('internal','follow_up') OR coalesce((r.action_config->'task_template'->>'days_offset')::integer,0) NOT BETWEEN 0 AND 365 THEN RAISE EXCEPTION 'Template de tarefa interna inválido' USING ERRCODE='22023';END IF;
   IF r.action_config->'task_template'->>'responsavel_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=(r.action_config->'task_template'->>'responsavel_id')::uuid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501';END IF;
  END IF;
 END IF;
 UPDATE public.sales_automation_rules SET is_active=p_active,action_config=coalesce(action_config,'{}')||jsonb_build_object('executor','mcp_sql','owner_id',(ctx->>'member_id')),updated_at=now() WHERE id=p_id AND tenant_id=tid;
 result:=jsonb_build_object('id',p_id,'active',p_active,'executor','mcp_sql','external_messages',false,'note','Execução em novos eventos; não reaplica ao histórico. Sem encadeamento recursivo de regras.');
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tid,p_request_id,auth.uid(),payload,result);RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.mcp_automation(text,uuid,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mcp_automation(text,uuid,uuid,boolean) TO authenticated;
CREATE FUNCTION crm_mcp.run_operational_rules(tid uuid,event text,entity uuid,lid uuid,did uuid,sid uuid,tasktype text,hasdate boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE r public.sales_automation_rules%ROWTYPE;d public.deals%ROWTYPE;target public.sales_pipeline_stages%ROWTYPE;task uuid;mid uuid;pos integer;result jsonb;
BEGIN
 FOR r IN SELECT * FROM public.sales_automation_rules WHERE tenant_id=tid AND is_active AND trigger_type=event AND action_config->>'executor'='mcp_sql' ORDER BY priority,id LOOP
  BEGIN
   IF jsonb_array_length(coalesce(r.trigger_conditions->'stage_ids','[]'))>0 AND NOT coalesce(r.trigger_conditions->'stage_ids' ? sid::text,false) THEN CONTINUE;END IF;
   IF coalesce(r.trigger_conditions->'exclude_stages' ? sid::text,false) THEN CONTINUE;END IF;
   IF jsonb_array_length(coalesce(r.trigger_conditions->'task_types','[]'))>0 AND NOT coalesce(r.trigger_conditions->'task_types' ? tasktype,false) THEN CONTINUE;END IF;
   IF coalesce((r.trigger_conditions->>'has_scheduled_date')::boolean,false) AND NOT hasdate THEN CONTINUE;END IF;
   IF r.action_type='move_deal_stage' THEN
    SELECT * INTO target FROM public.sales_pipeline_stages WHERE id=(r.action_config->>'target_stage_id')::uuid AND tenant_id=tid AND NOT is_won AND NOT is_lost;
    IF NOT FOUND THEN RAISE EXCEPTION 'Etapa destino inválida';END IF;
    IF did IS NULL THEN
     IF (SELECT count(*) FROM public.deals WHERE tenant_id=tid AND lead_id=lid AND pipeline_id=target.pipeline_id AND status NOT IN ('won','lost'))<>1 THEN RAISE EXCEPTION 'Oportunidade ausente ou ambígua';END IF;
     SELECT * INTO d FROM public.deals WHERE tenant_id=tid AND lead_id=lid AND pipeline_id=target.pipeline_id AND status NOT IN ('won','lost') FOR UPDATE;
    ELSE SELECT * INTO d FROM public.deals WHERE id=did AND tenant_id=tid AND lead_id=lid FOR UPDATE;END IF;
    IF d.id IS NULL OR d.pipeline_id<>target.pipeline_id OR d.status IN ('won','lost') THEN CONTINUE;END IF;
    SELECT position INTO pos FROM public.sales_pipeline_stages WHERE id=d.pipeline_stage_id;
    IF target.position<=pos OR (r.action_config->>'only_if_position_less_than' IS NOT NULL AND pos>=(r.action_config->>'only_if_position_less_than')::integer) THEN CONTINUE;END IF;
    UPDATE public.deals SET pipeline_stage_id=target.id,stage_changed_at=now(),updated_at=now() WHERE id=d.id AND tenant_id=tid;
    result:=jsonb_build_object('deal_id',d.id,'stage_id',target.id);
   ELSIF r.action_type='create_task' THEN
    mid:=coalesce((r.action_config->'task_template'->>'responsavel_id')::uuid,(r.action_config->>'owner_id')::uuid);
    IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=mid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável não está ativo';END IF;
    INSERT INTO public.company_activities(tenant_id,lead_id,name,description,task_type,status,completed,responsavel_id,due_datetime,metadata)
    VALUES(tid,lid,r.action_config->'task_template'->>'name',r.action_config->'task_template'->>'description',coalesce(r.action_config->'task_template'->>'task_type','internal'),'pending',false,mid,now()+make_interval(days=>coalesce((r.action_config->'task_template'->>'days_offset')::integer,0)),jsonb_build_object('automation_id',r.id,'source_entity_id',entity,'deal_id',did)) RETURNING id INTO task;
    result:=jsonb_build_object('task_id',task);
   ELSE CONTINUE;END IF;
   INSERT INTO crm_mcp.automation_runs(tenant_id,rule_id,entity_id,event,status,result) VALUES(tid,r.id,entity,event,'success',result);
   IF lid IS NOT NULL THEN INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(tid,lid,'automation',r.name,jsonb_build_object('rule_id',r.id,'event',event,'result',result));END IF;
  EXCEPTION WHEN OTHERS THEN
   INSERT INTO crm_mcp.automation_runs(tenant_id,rule_id,entity_id,event,status,result) VALUES(tid,r.id,entity,event,'failed',jsonb_build_object('error',left(SQLERRM,500)));
  END;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.run_operational_rules(uuid,text,uuid,uuid,uuid,uuid,text,boolean) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION crm_mcp.operational_event_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ev text;did uuid;sid uuid;BEGIN
 IF pg_trigger_depth()>1 THEN RETURN NEW;END IF;
 IF TG_TABLE_NAME='deals' THEN
  IF TG_OP='INSERT' THEN ev:='deal_created';ELSIF NEW.pipeline_stage_id IS DISTINCT FROM OLD.pipeline_stage_id THEN ev:='deal_stage_changed';ELSE RETURN NEW;END IF;
  PERFORM crm_mcp.run_operational_rules(NEW.tenant_id,ev,NEW.id,NEW.lead_id,NEW.id,NEW.pipeline_stage_id,NULL,false);
 ELSE
  IF TG_OP='INSERT' THEN ev:=CASE WHEN NEW.task_type IN ('meeting','call') AND NEW.scheduled_at IS NOT NULL THEN 'meeting_scheduled' ELSE 'task_created' END;
  ELSIF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' AND NEW.task_type IN ('meeting','call') THEN ev:='meeting_cancelled';
  ELSIF NEW.completed AND NOT OLD.completed THEN ev:='task_completed';
  ELSIF NEW.scheduled_at IS DISTINCT FROM OLD.scheduled_at AND NEW.task_type IN ('meeting','call') THEN ev:='meeting_rescheduled';ELSE RETURN NEW;END IF;
  did:=nullif(NEW.metadata->>'deal_id','')::uuid;
  IF did IS NOT NULL THEN SELECT pipeline_stage_id INTO sid FROM public.deals WHERE id=did AND tenant_id=NEW.tenant_id AND lead_id=NEW.lead_id;END IF;
  PERFORM crm_mcp.run_operational_rules(NEW.tenant_id,ev,NEW.id,NEW.lead_id,did,sid,NEW.task_type,NEW.scheduled_at IS NOT NULL);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.operational_event_trigger() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER mcp_operational_deal_event AFTER INSERT OR UPDATE ON public.deals FOR EACH ROW EXECUTE FUNCTION crm_mcp.operational_event_trigger();
CREATE TRIGGER mcp_operational_activity_event AFTER INSERT OR UPDATE ON public.company_activities FOR EACH ROW EXECUTE FUNCTION crm_mcp.operational_event_trigger();
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_automation','rpc/mcp_agent_admin','rpc/playground_crm_action','rpc/mcp_configure_operational_skill','rpc/playground_mark_deal_lost','rpc/playground_notify_human','rpc/mcp_playground_job','rpc/playground_qualify_lead','rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

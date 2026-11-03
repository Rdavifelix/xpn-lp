BEGIN;
-- All agent business actions bind to the agent tenant and immutable session context.
CREATE FUNCTION public.agent_assert_session(p_agent_id uuid,p_session_id uuid,p_lead_id uuid,p_deal_id uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid;s public.agents_sessions%ROWTYPE;
BEGIN
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id AND NOT is_template;
 SELECT * INTO s FROM public.agents_sessions WHERE id=p_session_id AND agent_id=p_agent_id AND tenant_id=tid;
 IF tid IS NULL OR NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=tid AND is_active)
 OR NOT EXISTS(SELECT 1 FROM public.leads WHERE id=p_lead_id AND tenant_id=tid)
 OR (p_deal_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.deals WHERE id=p_deal_id AND tenant_id=tid AND lead_id=p_lead_id))
 OR (s.playground_context IS NOT NULL AND (s.playground_context->>'lead_id' IS DISTINCT FROM p_lead_id::text OR (p_deal_id IS NOT NULL AND s.playground_context->>'deal_id' IS DISTINCT FROM p_deal_id::text)))
 THEN RAISE EXCEPTION 'Sessão, contato e oportunidade incompatíveis' USING ERRCODE='42501';END IF;
END $$;
CREATE OR REPLACE FUNCTION public.agent_mark_deal_lost(p_deal_id uuid,p_agent_id uuid,p_reason text,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE d public.deals%ROWTYPE; stage uuid; tid uuid;
BEGIN
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id;
 SELECT * INTO d FROM public.deals WHERE id=p_deal_id AND tenant_id=tid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Selecione a oportunidade antes de marcar a perda' USING ERRCODE='22023';END IF;
 PERFORM public.agent_assert_session(p_agent_id,p_session_id,d.lead_id,d.id);
 IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 2000 THEN RAISE EXCEPTION 'Informe o motivo confirmado da perda' USING ERRCODE='22023';END IF;
 IF d.status='won' THEN RAISE EXCEPTION 'Oportunidade ganha não pode ser marcada perdida pelo agente' USING ERRCODE='22023';END IF;
 IF d.status='lost' THEN RETURN jsonb_build_object('ok',true,'deal_id',d.id,'already_lost',true,'reason',d.lost_reason);END IF;
 SELECT id INTO stage FROM public.sales_pipeline_stages WHERE tenant_id=tid AND pipeline_id=d.pipeline_id AND is_lost AND lower(btrim(name))='perdido' ORDER BY position LIMIT 1;
 IF stage IS NULL AND (SELECT count(*) FROM public.sales_pipeline_stages WHERE tenant_id=tid AND pipeline_id=d.pipeline_id AND is_lost)=1 THEN
 SELECT id INTO stage FROM public.sales_pipeline_stages WHERE tenant_id=tid AND pipeline_id=d.pipeline_id AND is_lost;END IF;
 IF stage IS NULL THEN RAISE EXCEPTION 'Configure uma etapa Perdido no funil; destino ausente ou ambíguo' USING ERRCODE='22023';END IF;
 UPDATE public.deals SET status='lost',pipeline_stage_id=stage,lost_at=now(),lost_reason=btrim(p_reason),updated_at=now() WHERE id=d.id AND tenant_id=tid;
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(tid,d.lead_id,'stage_change',p_reason,jsonb_build_object('action','mark_deal_lost','agent_id',p_agent_id,'session_id',p_session_id,'deal_id',d.id,'previous_stage_id',d.pipeline_stage_id,'stage_id',stage));
 RETURN jsonb_build_object('ok',true,'deal_id',d.id,'status','lost','to_stage_id',stage,'reason',p_reason);
END $$;
CREATE FUNCTION public.playground_mark_deal_lost(p_deal_id uuid,p_agent_id uuid,p_reason text,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE lid uuid;BEGIN
 SELECT lead_id INTO lid FROM public.deals WHERE id=p_deal_id AND tenant_id=public.get_tenant_id();
 PERFORM public.playground_assert_access(p_agent_id,lid);
 IF NOT EXISTS(SELECT 1 FROM public.agents_sessions WHERE id=p_session_id AND tenant_id=public.get_tenant_id() AND user_id IN(SELECT id FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=public.get_tenant_id() AND is_active)) THEN RAISE EXCEPTION 'Sessão não pertence ao usuário' USING ERRCODE='42501';END IF;
 RETURN public.agent_mark_deal_lost(p_deal_id,p_agent_id,p_reason,p_session_id);
END $$;
-- Internal handoff only. No email, WhatsApp or external notification.
CREATE OR REPLACE FUNCTION public.agent_skill_notify_human(p_agent_id uuid,p_user_id uuid,p_session_id uuid,p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE s public.agents_sessions%ROWTYPE;mid uuid;task uuid;previous uuid;
BEGIN
 SELECT * INTO s FROM public.agents_sessions WHERE id=p_session_id AND agent_id=p_agent_id;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=s.tenant_id AND NOT is_template)
 OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=s.tenant_id AND is_active) THEN RAISE EXCEPTION 'Sessão inválida' USING ERRCODE='42501';END IF;
 IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 2000 THEN RAISE EXCEPTION 'Informe o motivo do encaminhamento' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_session_id::text,0));
 SELECT id INTO previous FROM public.agents_action_log WHERE session_id=p_session_id AND tool_name='notify_human' AND status='completed' AND input->>'reason'=p_reason ORDER BY created_at DESC LIMIT 1;
 IF previous IS NOT NULL THEN RETURN previous;END IF;
 SELECT id INTO mid FROM public.team_members WHERE id=p_user_id AND tenant_id=s.tenant_id AND is_active;
 IF mid IS NULL THEN SELECT id INTO mid FROM public.team_members WHERE tenant_id=s.tenant_id AND is_active AND role='admin' ORDER BY id LIMIT 1;END IF;
 IF mid IS NULL THEN RAISE EXCEPTION 'Configure um responsável humano ativo' USING ERRCODE='22023';END IF;
 INSERT INTO public.company_activities(tenant_id,name,description,task_type,responsavel_id,lead_id,status,completed)
 VALUES(s.tenant_id,'Encaminhamento do agente',p_reason,'task',mid,nullif(s.playground_context->>'lead_id','')::uuid,'pending',false) RETURNING id INTO task;
 INSERT INTO public.agents_action_log(tenant_id,agent_id,session_id,user_id,tool_name,input,output,status)
 VALUES(s.tenant_id,p_agent_id,p_session_id,mid,'notify_human',jsonb_build_object('reason',p_reason),jsonb_build_object('task_id',task,'external_message_sent',false),'completed') RETURNING id INTO previous;
 RETURN previous;
END $$;
CREATE FUNCTION public.playground_notify_human(p_agent_id uuid,p_user_id uuid,p_session_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE lid uuid;logid uuid; result jsonb;
BEGIN
 SELECT nullif(playground_context->>'lead_id','')::uuid INTO lid FROM public.agents_sessions WHERE id=p_session_id AND agent_id=p_agent_id AND tenant_id=public.get_tenant_id()
 AND user_id IN(SELECT id FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=public.get_tenant_id() AND is_active);
 PERFORM public.playground_assert_access(p_agent_id,lid);
 logid:=public.agent_skill_notify_human(p_agent_id,p_user_id,p_session_id,p_reason);
 SELECT output INTO result FROM public.agents_action_log WHERE id=logid;
 RETURN result||jsonb_build_object('ok',true,'handoff_id',logid,'message','Tarefa interna criada; nenhum envio externo realizado');
END $$;
REVOKE ALL ON FUNCTION public.agent_assert_session(uuid,uuid,uuid,uuid),public.agent_mark_deal_lost(uuid,uuid,text,uuid),public.agent_skill_notify_human(uuid,uuid,uuid,text),public.playground_mark_deal_lost(uuid,uuid,text,uuid),public.playground_notify_human(uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.agent_assert_session(uuid,uuid,uuid,uuid),public.agent_mark_deal_lost(uuid,uuid,text,uuid),public.agent_skill_notify_human(uuid,uuid,uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.playground_mark_deal_lost(uuid,uuid,text,uuid),public.playground_notify_human(uuid,uuid,uuid,text) TO authenticated;
-- Explicit, audited admin configuration for the two reviewed operational skills.
CREATE FUNCTION public.mcp_configure_operational_skill(p_request_id uuid,p_agent_id uuid,p_skill text,p_enabled boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid;c public.agents_skill_catalog%ROWTYPE;old crm_mcp.operations%ROWTYPE;payload jsonb;result jsonb;
BEGIN
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_request_id IS NULL OR p_enabled IS NULL OR p_skill IS NULL OR p_skill NOT IN ('mark_deal_lost','notify_human') THEN RAISE EXCEPTION 'Habilidade operacional inválida' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(tid::text,0));
 payload:=jsonb_build_object('operation','configure_operational_skill','agent_id',p_agent_id,'skill',p_skill,'enabled',p_enabled);
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tid AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023';END IF;RETURN old.result;END IF;
 PERFORM 1 FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=tid AND NOT is_template FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Agente não encontrado' USING ERRCODE='42501';END IF;
 SELECT * INTO c FROM public.agents_skill_catalog WHERE slug=p_skill;
 IF EXISTS(SELECT 1 FROM public.agents_tools WHERE agent_id=p_agent_id AND name=p_skill AND (action_config<>c.action_config OR parameters_schema<>c.parameters_schema OR action_type<>c.action_type)) THEN RAISE EXCEPTION 'Ferramenta personalizada preservada; revise antes de substituir' USING ERRCODE='22023';END IF;
 INSERT INTO public.agents_tools(tenant_id,agent_id,name,description,parameters_schema,action_type,action_config,is_active,requires_approval,usage_mode)
 VALUES(tid,p_agent_id,c.slug,c.description,c.parameters_schema,c.action_type,c.action_config,p_enabled,false,CASE WHEN p_enabled THEN 'always' ELSE 'disabled' END)
 ON CONFLICT(agent_id,name) DO UPDATE SET is_active=excluded.is_active,requires_approval=false,usage_mode=excluded.usage_mode,description=excluded.description;
 UPDATE public.agents_registry SET version=version+1,updated_at=now() WHERE id=p_agent_id AND tenant_id=tid;
 result:=jsonb_build_object('agent_id',p_agent_id,'skill',p_skill,'enabled',p_enabled,'scope','selected_contact_and_deal','tested',false);
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tid,p_request_id,auth.uid(),payload,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.mcp_configure_operational_skill(uuid,uuid,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mcp_configure_operational_skill(uuid,uuid,text,boolean) TO authenticated;
UPDATE public.agents_skill_catalog SET description='Marca a oportunidade selecionada como perdida com motivo confirmado e etapa Perdido. Não cancela reuniões nem envia mensagens. Habilite explicitamente com configurar_habilidade_operacional.' WHERE slug='mark_deal_lost';
UPDATE public.agents_skill_catalog SET description='Cria tarefa interna para atendimento humano com o motivo informado. Não envia mensagens externas nem promete atendimento imediato.' WHERE slug='notify_human';
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_configure_operational_skill','rpc/playground_mark_deal_lost','rpc/playground_notify_human','rpc/mcp_playground_job','rpc/playground_qualify_lead','rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

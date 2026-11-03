BEGIN;
CREATE TABLE crm_mcp.agent_rotations(agent_id uuid PRIMARY KEY REFERENCES public.agents_registry(id),tenant_id uuid NOT NULL REFERENCES public.tenants(id),members uuid[] NOT NULL,last_member uuid,updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE crm_mcp.agent_rotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON crm_mcp.agent_rotations FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.mcp_agent_operation(p_action text,p_agent_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid;a public.agents_registry%ROWTYPE;ids uuid[];cred uuid;trace jsonb;BEGIN
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_action='credentials' THEN RETURN (SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'label',label,'provider',provider_type,'is_active',is_active)),'[]') FROM agents_provider_credentials WHERE tenant_id=tid AND is_active);END IF;
 SELECT * INTO a FROM agents_registry WHERE id=p_agent_id AND tenant_id=tid AND NOT is_template FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Agente não encontrado' USING ERRCODE='42501';END IF;
 IF p_action='rotation' THEN
  IF p_data-ARRAY['member_ids']<>'{}' OR jsonb_typeof(p_data->'member_ids') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Informe closers' USING ERRCODE='22023';END IF;
  ids:=ARRAY(SELECT value::uuid FROM jsonb_array_elements_text(p_data->'member_ids'));
  IF cardinality(ids) NOT BETWEEN 1 AND 30 OR cardinality(ids)<>(SELECT count(DISTINCT x) FROM unnest(ids)x) OR EXISTS(SELECT 1 FROM unnest(ids)x WHERE NOT EXISTS(SELECT 1 FROM team_members WHERE id=x AND tenant_id=tid AND is_active AND (sub_role='closer' OR role='closer'))) THEN RAISE EXCEPTION 'Informe closers ativos e únicos da empresa' USING ERRCODE='22023';END IF;
  INSERT INTO crm_mcp.agent_rotations(agent_id,tenant_id,members) VALUES(a.id,tid,ids) ON CONFLICT(agent_id) DO UPDATE SET members=excluded.members,last_member=CASE WHEN crm_mcp.agent_rotations.last_member=ANY(excluded.members) THEN crm_mcp.agent_rotations.last_member END,updated_at=now();
  UPDATE agents_registry SET settings=settings||jsonb_build_object('closer_ids',ids,'distribution_mode','round_robin'),version=version+1,updated_at=now() WHERE id=a.id RETURNING * INTO a;
 ELSIF p_action='credential' THEN
  IF p_data-ARRAY['credential_id']<>'{}' THEN RAISE EXCEPTION 'Configuração inválida' USING ERRCODE='22023';END IF;
  cred:=(p_data->>'credential_id')::uuid;
  IF cred IS NOT NULL AND NOT EXISTS(SELECT 1 FROM agents_provider_credentials WHERE id=cred AND tenant_id=tid AND is_active AND provider_type IN ('openai_api','anthropic_api','openai_codex')) THEN RAISE EXCEPTION 'Credencial indisponível nesta empresa' USING ERRCODE='42501';END IF;
  UPDATE agents_registry SET credential_id=cred,version=version+1,updated_at=now() WHERE id=a.id RETURNING * INTO a;
 ELSIF p_action<>'status' THEN RAISE EXCEPTION 'Ação inválida' USING ERRCODE='22023';END IF;
 SELECT jsonb_build_object('id',id,'session_id',session_id,'status',result->>'status','agent_version',request->>'agent_version','finished_at',finished_at) INTO trace FROM crm_mcp.agent_traces WHERE agent_id=a.id AND tenant_id=tid ORDER BY created_at DESC,id DESC LIMIT 1;
 RETURN jsonb_build_object('agent_id',a.id,'version',a.version,'is_active',a.is_active,'credential_id',a.credential_id,'rotation',(SELECT jsonb_build_object('member_ids',members,'last_member',last_member) FROM crm_mcp.agent_rotations WHERE agent_id=a.id),'last_execution',trace,'validation_status',CASE WHEN trace IS NULL THEN 'not_tested' WHEN (trace->>'agent_version')::integer IS DISTINCT FROM a.version THEN 'configuration_changed' WHEN trace->>'status'='success' THEN 'model_responded' ELSE 'execution_failed' END,'ready_for_playground',coalesce(trace->>'status'='success' AND (trace->>'agent_version')::integer=a.version,false),'readiness_note','Resposta do modelo não comprova formulário, canal e todas as habilidades; confira o teste completo e a conexão de entrada.');
END $$;
REVOKE ALL ON FUNCTION public.mcp_agent_operation(text,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mcp_agent_operation(text,uuid,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.agent_schedule_meeting(p_lead_id uuid,p_agent_id uuid,p_closer_id uuid,p_start_at timestamptz,p_duration_minutes integer DEFAULT 30,p_title text DEFAULT NULL,p_notes text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v_activity_id uuid; finish timestamptz; lead_name text; tid uuid;rotation crm_mcp.agent_rotations%ROWTYPE;candidate uuid;rotation_applied boolean:=false;
BEGIN
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id;
 IF tid IS NULL OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=tid AND is_active) OR NOT EXISTS(SELECT 1 FROM public.leads WHERE id=p_lead_id AND tenant_id=tid) OR (p_session_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.agents_sessions WHERE id=p_session_id AND agent_id=p_agent_id AND tenant_id=tid)) THEN RAISE EXCEPTION 'Contexto do agente inválido' USING ERRCODE='42501'; END IF;
 IF p_start_at IS NULL OR p_start_at<now() OR p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 5 AND 480 THEN RAISE EXCEPTION 'Horário ou duração inválidos' USING ERRCODE='22023'; END IF;
 SELECT * INTO rotation FROM crm_mcp.agent_rotations WHERE agent_id=p_agent_id AND tenant_id=tid FOR UPDATE;
 IF FOUND THEN
  SELECT ca.id,ca.responsavel_id INTO v_activity_id,candidate FROM company_activities ca WHERE ca.tenant_id=tid AND ca.lead_id=p_lead_id AND ca.metadata->>'agent_id'=p_agent_id::text AND ca.scheduled_at=p_start_at AND ca.task_type='meeting' AND NOT ca.completed AND ca.status IS DISTINCT FROM 'cancelled' ORDER BY ca.created_at DESC LIMIT 1;
  IF v_activity_id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'deduped',true,'activity_id',v_activity_id,'closer_id',candidate);END IF;
  p_closer_id:=NULL;
  FOR candidate IN SELECT x FROM unnest(rotation.members) WITH ORDINALITY q(x,ord) ORDER BY CASE WHEN ord>coalesce(array_position(rotation.members,rotation.last_member),0) THEN 0 ELSE 1 END,ord LOOP
   PERFORM pg_advisory_xact_lock(hashtextextended(candidate::text,1));
   IF crm_mcp.calendar_free(tid,candidate,p_start_at,p_start_at+make_interval(mins=>p_duration_minutes)) THEN p_closer_id:=candidate;EXIT;END IF;
  END LOOP;
  IF p_closer_id IS NULL THEN RETURN jsonb_build_object('ok',false,'error','Nenhum closer elegível está livre neste horário');END IF;
  rotation_applied:=true;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=p_closer_id AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_closer_id::text,1));
 finish:=p_start_at+make_interval(mins=>p_duration_minutes);
 SELECT ca.id INTO v_activity_id FROM public.company_activities ca WHERE ca.lead_id=p_lead_id AND ca.responsavel_id=p_closer_id AND ca.scheduled_at=p_start_at AND ca.task_type='meeting' AND ca.status IS DISTINCT FROM 'cancelled' AND NOT ca.completed AND ca.tenant_id=tid LIMIT 1;
 IF v_activity_id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'deduped',true,'activity_id',v_activity_id); END IF;
 IF EXISTS(SELECT 1 FROM public.company_activities ca WHERE ca.responsavel_id=p_closer_id AND ca.tenant_id=tid AND ca.status IS DISTINCT FROM 'cancelled' AND NOT ca.completed AND ca.task_type IN ('meeting','call') AND ca.scheduled_at<finish AND coalesce(ca.end_datetime,ca.scheduled_at+interval '30 minutes')>p_start_at) THEN
  RETURN jsonb_build_object('ok',false,'error','Horário ocupado para este responsável'); END IF;
 SELECT name INTO lead_name FROM public.leads WHERE public.leads.id=p_lead_id;
 INSERT INTO public.company_activities(lead_id,responsavel_id,task_type,name,description,scheduled_at,end_datetime,completed,team,tenant_id,metadata)
 VALUES(p_lead_id,p_closer_id,'meeting',coalesce(p_title,'Reunião com '||lead_name),p_notes,p_start_at,finish,false,'sales',tid,jsonb_build_object('created_by','agent_v2','agent_id',p_agent_id,'session_id',p_session_id)) RETURNING public.company_activities.id INTO v_activity_id;
 IF rotation_applied THEN UPDATE crm_mcp.agent_rotations SET last_member=p_closer_id,updated_at=now() WHERE agent_id=p_agent_id;END IF;
 RETURN jsonb_build_object('ok',true,'activity_id',v_activity_id,'scheduled_at',p_start_at,'end_at',finish,'closer_id',p_closer_id,'calendar','CRM','external_calendar_synced',false);
END $$;




CREATE OR REPLACE FUNCTION public.playground_schedule_meeting(p_lead_id uuid,p_agent_id uuid,p_closer_id uuid,p_start_at timestamptz,p_duration_minutes integer DEFAULT 30,p_title text DEFAULT NULL,p_notes text DEFAULT NULL,p_session_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.playground_assert_access(p_agent_id,p_lead_id);
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN PERFORM crm_mcp.context();END IF;
 RETURN public.agent_schedule_meeting(p_lead_id,p_agent_id,p_closer_id,p_start_at,p_duration_minutes,p_title,p_notes,p_session_id);
END $$;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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
CREATE OR REPLACE FUNCTION crm_mcp.agent_setup(p_action text,p_request_id uuid DEFAULT NULL,p_agent_id uuid DEFAULT NULL,p_config jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ctx jsonb:=crm_mcp.context(); tenant uuid:=(ctx->>'tenant_id')::uuid;
 a public.agents_registry%ROWTYPE; skill public.agents_skill_catalog%ROWTYPE;
 old crm_mcp.operations%ROWTYPE; payload jsonb; result jsonb; installed jsonb; inventory jsonb;
 selected text; keys text[]:=ARRAY[]::text[]; aid uuid; base jsonb; mode text;
BEGIN
 IF p_action='catalog' THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('slug',c.slug,'name',c.display_name,'description',c.description,
    'parameters_schema',c.parameters_schema,'provider',c.provider,'default_usage_mode',c.default_usage_mode,
    'installable',crm_mcp.skill_available(c.slug,c.action_type,c.action_config),
    'runtime_context',(SELECT coalesce(jsonb_agg(DISTINCT m[1]),'[]') FROM regexp_matches(c.action_config::text,'\{\{(lead_id|deal_id|user_id|session_id|agent_id|tenant_id|instance_id)\}\}','g') m))), '[]')
    INTO inventory FROM public.agents_skill_catalog c;
  SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (
   SELECT r.id,r.display_name AS name,coalesce(jsonb_agg(t.name ORDER BY t.name) FILTER(WHERE t.id IS NOT NULL),'[]') AS suggested_skills
   FROM public.agents_registry r LEFT JOIN public.agents_tools t ON t.agent_id=r.id
   WHERE r.is_template IS TRUE AND r.tenant_id IS NULL GROUP BY r.id,r.display_name
  ) x;
  RETURN jsonb_build_object('skills',inventory,'templates',result,'note','Disponível para configurar não significa testado. Escolha habilidades pelo processo; não copie todas automaticamente.');
 END IF;
 IF p_action='get' THEN
  SELECT * INTO a FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=tenant;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agente não encontrado nesta empresa' USING ERRCODE='42501'; END IF;
 ELSE
  IF p_action NOT IN ('create','attach') OR p_action IS NULL THEN RAISE EXCEPTION 'Operação inválida' USING ERRCODE='22023'; END IF;
  IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501'; END IF;
  IF p_request_id IS NULL OR p_config IS NULL OR jsonb_typeof(p_config) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_config->'tools') IS DISTINCT FROM 'array'
    OR jsonb_array_length(p_config->'tools') NOT BETWEEN 1 AND 30
    OR octet_length(p_config::text)>50000
    OR (p_config - CASE WHEN p_action='create' THEN ARRAY['template_id','name','system_prompt','tools'] ELSE ARRAY['tools'] END)<>'{}'::jsonb THEN
   RAISE EXCEPTION 'Informe de 1 a 30 habilidades do catálogo e somente campos permitidos' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(tenant::text,0));
  payload:=jsonb_build_object('operation','agent_setup','action',p_action,'agent_id',p_agent_id,'config',p_config);
  SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tenant AND request_id=p_request_id;
  IF FOUND THEN
   IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023'; END IF;
   RETURN old.result;
  END IF;
  -- Validate the whole selection before creating any resource.
  FOR selected IN SELECT jsonb_array_elements_text(p_config->'tools') LOOP
   IF selected=ANY(keys) THEN RAISE EXCEPTION 'Habilidade repetida' USING ERRCODE='22023'; END IF;
   keys:=array_append(keys,selected);
   SELECT * INTO skill FROM public.agents_skill_catalog WHERE slug=selected;
   IF NOT FOUND OR NOT crm_mcp.skill_available(skill.slug,skill.action_type,skill.action_config) THEN
    RAISE EXCEPTION 'Habilidade inexistente ou não disponível para instalação: %',selected USING ERRCODE='22023'; END IF;
  END LOOP;
  IF p_action='create' THEN
   base:=crm_mcp.create_agent_draft(md5('agent-base:'||p_request_id::text)::uuid,
    (p_config->>'template_id')::uuid,p_config->>'name',p_config->>'system_prompt');
   aid:=(base->>'agent_id')::uuid;
  ELSE aid:=p_agent_id; END IF;
  SELECT * INTO a FROM public.agents_registry WHERE id=aid AND tenant_id=tenant FOR UPDATE;
  IF NOT FOUND OR a.is_template THEN RAISE EXCEPTION 'Agente não encontrado nesta empresa' USING ERRCODE='42501'; END IF;
  IF a.is_active THEN RAISE EXCEPTION 'Pause o agente antes de configurar suas habilidades' USING ERRCODE='22023'; END IF;
  IF (SELECT count(*) FROM public.agents_tools WHERE agent_id=aid)+
    (SELECT count(*) FROM unnest(keys) k WHERE NOT EXISTS(SELECT 1 FROM public.agents_tools t WHERE t.agent_id=aid AND t.name=k))>50 THEN
   RAISE EXCEPTION 'Limite de 50 habilidades por agente' USING ERRCODE='22023'; END IF;
  FOREACH selected IN ARRAY keys LOOP
   SELECT * INTO skill FROM public.agents_skill_catalog WHERE slug=selected;
   IF EXISTS(SELECT 1 FROM public.agents_tools WHERE agent_id=aid AND name=selected) THEN
    IF EXISTS(SELECT 1 FROM public.agents_tools WHERE agent_id=aid AND name=selected
      AND (action_config IS DISTINCT FROM skill.action_config OR parameters_schema IS DISTINCT FROM skill.parameters_schema OR action_type IS DISTINCT FROM skill.action_type)) THEN
     RAISE EXCEPTION 'Habilidade já personalizada: %. A configuração existente foi preservada.',selected USING ERRCODE='22023'; END IF;
    CONTINUE;
   END IF;
   -- Approval-required actions stay disabled until the runtime approval flow is validated.
   mode:=CASE WHEN skill.default_usage_mode='always' THEN 'always' ELSE 'disabled' END;
   INSERT INTO public.agents_tools(tenant_id,agent_id,name,description,parameters_schema,action_type,action_config,usage_mode,is_active,requires_approval,provider)
    VALUES(tenant,aid,skill.slug,skill.description,skill.parameters_schema,skill.action_type,skill.action_config,mode,mode='always',skill.default_usage_mode='with_approval',skill.provider);
  END LOOP;
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('name',t.name,'description',t.description,'parameters_schema',t.parameters_schema,
  'provider',t.provider,'mode',t.usage_mode,'enabled',t.is_active,'requires_approval',t.requires_approval)), '[]') INTO installed
  FROM public.agents_tools t WHERE t.agent_id=a.id AND t.tenant_id=tenant;
 result:=jsonb_build_object('agent_id',a.id,'name',a.display_name,'is_active',a.is_active,'tools',installed,
  'validation_status',CASE WHEN EXISTS(SELECT 1 FROM crm_mcp.agent_traces tr WHERE tr.agent_id=a.id AND tr.tenant_id=tenant AND tr.created_at>=a.updated_at AND tr.result->>'status'='success') THEN 'model_responded' ELSE 'not_tested' END,'ready',EXISTS(SELECT 1 FROM crm_mcp.agent_traces tr WHERE tr.agent_id=a.id AND tr.tenant_id=tenant AND tr.created_at>=a.updated_at AND tr.result->>'status'='success'),'readiness_scope','playground_model_only',
  'pending',jsonb_build_array('Vincular credencial do modelo','Preparar conhecimento e contexto de contato/oportunidade','Validar provedores das habilidades e simular execução','Revisar habilidades desativadas que exigem aprovação','Ativar somente após validar o agente'));
 IF p_action<>'get' THEN
  INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tenant,p_request_id,auth.uid(),payload,result);
 END IF;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.agent_playground_context(p_lead_id uuid,p_deal_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE tenant uuid:=public.get_tenant_id(); lead public.leads%ROWTYPE; deal public.deals%ROWTYPE;
 notes jsonb; activities jsonb; stages jsonb; team jsonb; pipe jsonb; result jsonb;
BEGIN
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL AND NOT (crm_mcp.context()->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF auth.uid() IS NULL OR tenant IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=tenant AND is_active AND role='admin'
 ) THEN RAISE EXCEPTION 'Administrador da empresa obrigatório' USING ERRCODE='42501'; END IF;
 SELECT * INTO lead FROM public.leads WHERE id=p_lead_id AND tenant_id=tenant;
 IF NOT FOUND THEN RAISE EXCEPTION 'Contato não encontrado nesta empresa' USING ERRCODE='42501'; END IF;
 IF p_deal_id IS NOT NULL THEN
  SELECT * INTO deal FROM public.deals WHERE id=p_deal_id AND lead_id=lead.id AND tenant_id=tenant;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oportunidade não pertence ao contato selecionado' USING ERRCODE='42501'; END IF;
 END IF;
 SELECT coalesce(jsonb_agg(n),'[]') INTO notes FROM (
  SELECT id,content,note_type,created_at FROM public.sales_notes WHERE tenant_id=tenant
   AND (lead_id=lead.id OR (p_deal_id IS NOT NULL AND deal_id=p_deal_id)) ORDER BY created_at DESC LIMIT 20
 ) n;
 SELECT coalesce(jsonb_agg(n),'[]') INTO activities FROM (
  SELECT id,name,description,task_type,status,scheduled_at,end_datetime,responsavel_id,completed
  FROM public.company_activities WHERE tenant_id=tenant AND lead_id=lead.id ORDER BY created_at DESC LIMIT 20
 ) n;
 SELECT jsonb_build_object('id',p.id,'name',p.name) INTO pipe FROM public.sales_pipelines p
 WHERE p.id=deal.pipeline_id AND p.tenant_id=tenant;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'position',s.position,'won',s.is_won,'lost',s.is_lost) ORDER BY s.position),'[]')
 INTO stages FROM public.sales_pipeline_stages s WHERE s.pipeline_id=deal.pipeline_id AND s.tenant_id=tenant;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'role',m.role)),'[]') INTO team
 FROM public.team_members m WHERE m.tenant_id=tenant AND m.is_active;
 result:=jsonb_build_object('lead_id',lead.id,'deal_id',p_deal_id,'lead',to_jsonb(lead)-'tenant_id',
  'deal',CASE WHEN p_deal_id IS NULL THEN NULL ELSE to_jsonb(deal)-'tenant_id' END,
  'pipeline',pipe,'stages',stages,'notes',notes,'activities',activities,'team',team,
  'history_limit',20,'execution_mode','real','loaded_at',now());
 IF octet_length(result::text)>100000 THEN RAISE EXCEPTION 'Contexto excede 100 KB. Reduza notas/campos extensos antes de testar.' USING ERRCODE='22023'; END IF;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.playground_assert_access(p_agent_id uuid,p_lead_id uuid) RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.agent_playground_context(p_lead_id);
 IF NOT EXISTS(SELECT 1 FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=public.get_tenant_id() AND NOT is_template) THEN
  RAISE EXCEPTION 'Agente não pertence à empresa' USING ERRCODE='42501'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.playground_change_stage(p_deal_id uuid,p_agent_id uuid,p_stage_name text DEFAULT NULL,p_stage_id uuid DEFAULT NULL,p_reason text DEFAULT NULL,p_session_id uuid DEFAULT NULL,p_allow_regression boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d public.deals%ROWTYPE; target public.sales_pipeline_stages%ROWTYPE; pos integer;
BEGIN
 SELECT * INTO d FROM public.deals WHERE id=p_deal_id AND tenant_id=public.get_tenant_id() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Oportunidade não encontrada' USING ERRCODE='42501'; END IF;
 PERFORM public.playground_assert_access(p_agent_id,d.lead_id);
 SELECT * INTO target FROM public.sales_pipeline_stages WHERE pipeline_id=d.pipeline_id AND tenant_id=public.get_tenant_id()
  AND (CASE WHEN p_stage_id IS NOT NULL THEN id=p_stage_id ELSE lower(name)=lower(p_stage_name) END) ORDER BY position LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Etapa não pertence ao funil da oportunidade' USING ERRCODE='22023'; END IF;
 SELECT position INTO pos FROM public.sales_pipeline_stages WHERE id=d.pipeline_stage_id;
 IF NOT coalesce(p_allow_regression,false) AND target.position<pos THEN RETURN jsonb_build_object('ok',false,'error','regression_blocked'); END IF;
 UPDATE public.deals SET pipeline_stage_id=target.id,updated_at=now() WHERE id=d.id;
 RETURN jsonb_build_object('ok',true,'deal_id',d.id,'to_stage_id',target.id,'to_stage_name',target.name);
END $$;
CREATE OR REPLACE FUNCTION public.playground_update_lead(p_lead_id uuid,p_agent_id uuid,p_patch jsonb,p_reason text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k text; parts text[]:=ARRAY[]::text[]; allowed text[]:=ARRAY['name','email','phone','company_name','job_title','city','state','employee_count','website','instagram','linkedin','monthly_revenue_min','monthly_revenue_max','potential_revenue_brl','revenue_confidence','revenue_notes','challenges','goals','objections','lead_source','utm_source','utm_campaign'];
BEGIN
 PERFORM public.playground_assert_access(p_agent_id,p_lead_id);
 IF jsonb_typeof(p_patch) IS DISTINCT FROM 'object' OR p_patch='{}'::jsonb OR octet_length(p_patch::text)>10000 THEN RAISE EXCEPTION 'Atualização inválida' USING ERRCODE='22023'; END IF;
 IF p_patch?'company' THEN p_patch:=(p_patch-'company')||jsonb_build_object('company_name',p_patch->'company'); END IF;
 FOR k IN SELECT jsonb_object_keys(p_patch) LOOP
  IF NOT k=ANY(allowed) OR NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.leads'::regclass AND attname=k AND NOT attisdropped) THEN
   RAISE EXCEPTION 'Campo não permitido: %',k USING ERRCODE='22023'; END IF;
  parts:=array_append(parts,format('%I=(jsonb_populate_record(NULL::public.leads,$1)).%I',k,k));
 END LOOP;
 EXECUTE 'UPDATE public.leads SET '||array_to_string(parts,',')||',updated_at=now() WHERE id=$2 AND tenant_id=public.get_tenant_id()' USING p_patch,p_lead_id;
 RETURN jsonb_build_object('ok',true,'lead_id',p_lead_id,'applied',p_patch);
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;

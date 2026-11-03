BEGIN;
CREATE FUNCTION public.agent_crm_action(p_agent_id uuid,p_session_id uuid,p_lead_id uuid,p_deal_id uuid,p_action text,p_args jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid;mid uuid;aid uuid;noteid uuid;act public.company_activities%ROWTYPE;result jsonb;starts timestamptz;finish timestamptz;title text;reason text;pid uuid;st uuid;
BEGIN
 PERFORM public.agent_assert_session(p_agent_id,p_session_id,p_lead_id,p_deal_id);
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id;
 IF jsonb_typeof(p_args) IS DISTINCT FROM 'object' OR octet_length(p_args::text)>25000 THEN RAISE EXCEPTION 'Argumentos inválidos' USING ERRCODE='22023';END IF;
 reason:=nullif(btrim(p_args->>'p_reason'),'');
 PERFORM pg_advisory_xact_lock(hashtextextended(p_session_id::text,1));
 IF p_action IN ('task_create','followup') THEN
  title:=CASE WHEN p_action='followup' THEN 'Retomada interna: '||left(coalesce(p_args->>'p_message_brief','Contato'),120) ELSE p_args->>'p_name' END;
  IF length(btrim(coalesce(title,''))) NOT BETWEEN 2 AND 200 THEN RAISE EXCEPTION 'Nome de tarefa inválido' USING ERRCODE='22023';END IF;
  SELECT id INTO mid FROM public.team_members WHERE tenant_id=tid AND is_active AND id=coalesce(nullif(p_args->>'p_responsavel_id','')::uuid,(SELECT user_id FROM public.agents_sessions WHERE id=p_session_id));
  IF mid IS NULL THEN SELECT id INTO mid FROM public.team_members WHERE tenant_id=tid AND is_active AND role='admin' ORDER BY id LIMIT 1;END IF;
  IF mid IS NULL THEN RAISE EXCEPTION 'Responsável ativo obrigatório' USING ERRCODE='22023';END IF;
  IF p_args->>'p_responsavel_id' IS NOT NULL AND mid::text<>p_args->>'p_responsavel_id' THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501';END IF;
  starts:=coalesce(nullif(p_args->>'p_due_at','')::timestamptz,nullif(p_args->>'p_scheduled_for','')::timestamptz);
  IF p_action='followup' AND (starts IS NULL OR starts<now()) THEN RAISE EXCEPTION 'Informe data futura para a retomada interna' USING ERRCODE='22023';END IF;
  IF p_args->>'p_priority' IS NOT NULL AND p_args->>'p_priority' NOT IN ('low','medium','high','urgent') THEN RAISE EXCEPTION 'Prioridade inválida' USING ERRCODE='22023';END IF;
  SELECT id INTO aid FROM public.company_activities WHERE tenant_id=tid AND metadata->>'agent_session_id'=p_session_id::text AND metadata->>'action'=p_action AND name=title AND due_datetime IS NOT DISTINCT FROM starts AND NOT completed AND status<>'cancelled' ORDER BY created_at DESC LIMIT 1;
  IF aid IS NULL THEN
   INSERT INTO public.company_activities(tenant_id,lead_id,name,description,priority,task_type,status,completed,responsavel_id,due_datetime,metadata)
   VALUES(tid,p_lead_id,title,coalesce(p_args->>'p_description',p_args->>'p_message_brief'),coalesce(p_args->>'p_priority','medium'),'internal','pending',false,mid,starts,jsonb_build_object('agent_id',p_agent_id,'agent_session_id',p_session_id,'deal_id',p_deal_id,'action',p_action,'reason',reason)) RETURNING id INTO aid;
  END IF;
  result:=jsonb_build_object('ok',true,'task_id',aid,'scheduled_for',starts,'delivery','internal_task','external_message_sent',false);
 ELSIF p_action IN ('task_complete','meeting_confirm','meeting_reschedule','meeting_cancel') THEN
  aid:=coalesce(nullif(p_args->>'p_activity_id','')::uuid,nullif(p_args->>'p_task_id','')::uuid);
  SELECT * INTO act FROM public.company_activities WHERE id=aid AND tenant_id=tid AND lead_id=p_lead_id FOR UPDATE;
  IF NOT FOUND OR (act.metadata->>'deal_id' IS NOT NULL AND act.metadata->>'deal_id' IS DISTINCT FROM p_deal_id::text) THEN RAISE EXCEPTION 'Atividade não pertence ao contato/oportunidade da sessão' USING ERRCODE='42501';END IF;
  IF p_action<>'task_complete' AND act.task_type NOT IN ('meeting','call') THEN RAISE EXCEPTION 'Atividade não é uma reunião' USING ERRCODE='22023';END IF;
  IF p_action='task_complete' AND act.task_type IN ('meeting','call') THEN RAISE EXCEPTION 'Use a operação de reunião' USING ERRCODE='22023';END IF;
  IF p_action IN ('meeting_reschedule','meeting_cancel') AND length(coalesce(reason,'')) NOT BETWEEN 3 AND 2000 THEN RAISE EXCEPTION 'Informe o motivo' USING ERRCODE='22023';END IF;
  IF p_action IN ('meeting_confirm','meeting_reschedule') AND (act.status='cancelled' OR act.completed) THEN RAISE EXCEPTION 'Reunião encerrada não pode ser alterada' USING ERRCODE='22023';END IF;
  IF p_action='meeting_reschedule' THEN
   starts:=nullif(p_args->>'p_new_start_at','')::timestamptz;
   IF starts IS NULL OR starts<now() OR act.scheduled_at IS NULL OR act.end_datetime IS NULL THEN RAISE EXCEPTION 'Horário futuro e duração existente obrigatórios' USING ERRCODE='22023';END IF;
   finish:=starts+(act.end_datetime-act.scheduled_at);
   UPDATE public.company_activities SET scheduled_at=starts,end_datetime=finish,updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('reschedule_reason',reason) WHERE id=aid;
  ELSIF p_action='meeting_cancel' THEN
   UPDATE public.company_activities SET status='cancelled',updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('cancel_reason',reason,'cancelled_at',now()) WHERE id=aid;
  ELSIF p_action='meeting_confirm' THEN
   UPDATE public.company_activities SET confirmed_by_client=true,updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('confirmed',true,'confirmed_at',now()) WHERE id=aid;
  ELSE UPDATE public.company_activities SET completed=true,status='completed',completed_at=now(),updated_at=now() WHERE id=aid;END IF;
  result:=jsonb_build_object('ok',true,'activity_id',aid,'task_id',aid,'action',p_action,'scheduled_at',starts,'end_datetime',finish,'external_sync',false);
 ELSIF p_action='team' THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'role',role,'sub_role',sub_role)),'[]') INTO result FROM public.team_members WHERE tenant_id=tid AND is_active;
  RETURN jsonb_build_object('ok',true,'members',result);
 ELSIF p_action IN ('notes_list','notes_read','notes_search','notes_save') THEN
  IF p_action='notes_save' THEN
   title:=btrim(coalesce(p_args->>'p_title',''));
   IF length(title) NOT BETWEEN 2 AND 200 OR length(coalesce(p_args->>'p_content','')) NOT BETWEEN 1 AND 20000 THEN RAISE EXCEPTION 'Título/conteúdo inválidos' USING ERRCODE='22023';END IF;
   SELECT id INTO noteid FROM public.agent_notes WHERE agent_id=p_agent_id AND tenant_id=tid AND title=title AND NOT archived FOR UPDATE;
   IF noteid IS NULL THEN
    INSERT INTO public.agent_notes(tenant_id,agent_id,title,slug,content,metadata) VALUES(tid,p_agent_id,title,gen_random_uuid()::text,p_args->>'p_content',jsonb_build_object('last_author','agent')) RETURNING id INTO noteid;
   ELSE
    UPDATE public.agent_notes SET content=CASE WHEN p_args->>'p_mode'='append' THEN content||E'\n'||(p_args->>'p_content') ELSE p_args->>'p_content' END,metadata=coalesce(metadata,'{}')||jsonb_build_object('last_author','agent'),updated_at=now() WHERE id=noteid;
   END IF;
   result:=jsonb_build_object('ok',true,'note_id',noteid);
  ELSE
   SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (SELECT id,title,content,tags FROM public.agent_notes WHERE agent_id=p_agent_id AND tenant_id=tid AND NOT archived
   AND (p_action<>'notes_read' OR title=p_args->>'p_title')
   AND (p_action<>'notes_search' OR title ILIKE '%'||coalesce(p_args->>'p_query','')||'%' OR content ILIKE '%'||coalesce(p_args->>'p_query','')||'%')
   ORDER BY updated_at DESC LIMIT 20)x;
   RETURN jsonb_build_object('ok',true,'notes',result,'search_mode','text');
  END IF;
 ELSE RAISE EXCEPTION 'Ação não disponível' USING ERRCODE='22023';END IF;
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(tid,p_lead_id,'agent_action',coalesce(reason,p_action),jsonb_build_object('agent_id',p_agent_id,'session_id',p_session_id,'deal_id',p_deal_id,'action',p_action,'result',result));
 RETURN result;
END $$;
CREATE FUNCTION public.playground_crm_action(p_agent_id uuid,p_session_id uuid,p_lead_id uuid,p_deal_id uuid,p_action text,p_args jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM public.playground_assert_access(p_agent_id,p_lead_id);
 IF NOT EXISTS(SELECT 1 FROM public.agents_sessions WHERE id=p_session_id AND tenant_id=public.get_tenant_id() AND user_id IN(SELECT id FROM public.team_members WHERE tenant_id=public.get_tenant_id() AND auth_user_id=auth.uid() AND is_active)) THEN RAISE EXCEPTION 'Sessão não pertence ao usuário' USING ERRCODE='42501';END IF;
 RETURN public.agent_crm_action(p_agent_id,p_session_id,p_lead_id,p_deal_id,p_action,p_args);
END $$;
REVOKE ALL ON FUNCTION public.agent_crm_action(uuid,uuid,uuid,uuid,text,jsonb),public.playground_crm_action(uuid,uuid,uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.agent_crm_action(uuid,uuid,uuid,uuid,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.playground_crm_action(uuid,uuid,uuid,uuid,text,jsonb) TO authenticated;
INSERT INTO public.agents_skill_catalog(slug,display_name,description,category,emoji,parameters_schema,action_type,action_config,default_usage_mode,is_recommended)
VALUES('cancel_meeting','Cancelar reunião','Cancela reunião interna do contato selecionado, com motivo. Não cancela evento externo do Google automaticamente.','sales','📅','{"type":"object","required":["activity_id","reason"],"properties":{"activity_id":{"type":"string","format":"uuid"},"reason":{"type":"string"}}}','sql','{"function":"agent_cancel_meeting","params_map":{"p_activity_id":"{{activity_id}}","p_reason":"{{reason}}"}}','always',true);
UPDATE public.agents_skill_catalog SET default_usage_mode='always',description='Marca oportunidade selecionada como perdida, com motivo confirmado, status e etapa Perdido. Não cancela reuniões; use cancel_meeting para isso.' WHERE slug='mark_deal_lost';
UPDATE public.agents_skill_catalog SET description='Agenda uma tarefa interna de retomada para um humano. Não programa envio automático de mensagem.' WHERE slug='schedule_followup';
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
    'playground_supported',c.slug=ANY(ARRAY['mark_deal_lost','notify_human','change_stage','update_lead','qualify_lead','check_availability','schedule_meeting','current_time_br','criar_tarefa','concluir_tarefa','confirm_meeting','reschedule_meeting','cancel_meeting','schedule_followup','team_roster','listar_notas','ler_nota','buscar_nota','salvar_nota']),'installable',crm_mcp.skill_available(c.slug,c.action_type,c.action_config),
    'runtime_context',(SELECT coalesce(jsonb_agg(DISTINCT m[1]),'[]') FROM regexp_matches(c.action_config::text,'\{\{(lead_id|deal_id|user_id|session_id|agent_id|tenant_id|instance_id)\}\}','g') m))), '[]')
    INTO inventory FROM public.agents_skill_catalog c;
  SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (
   SELECT r.id,r.display_name AS name,coalesce(jsonb_agg(t.name ORDER BY t.name) FILTER(WHERE t.id IS NOT NULL),'[]') AS suggested_skills
   FROM public.agents_registry r LEFT JOIN public.agents_tools t ON t.agent_id=r.id
   WHERE r.is_template IS TRUE AND r.tenant_id IS NULL GROUP BY r.id,r.display_name
  ) x;
  RETURN jsonb_build_object('skills',inventory,'templates',result,'suggested_sdr_tools',jsonb_build_array('current_time_br','update_lead','qualify_lead','change_stage','mark_deal_lost','check_availability','schedule_meeting','confirm_meeting','reschedule_meeting','cancel_meeting','notify_human','criar_tarefa','concluir_tarefa','listar_notas','ler_nota'),'note','Disponível para configurar não significa testado. Escolha habilidades pelo processo; não copie todas automaticamente.');
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
    OR (p_config - CASE WHEN p_action='create' THEN ARRAY['template_id','name','system_prompt','tools','provider','model'] ELSE ARRAY['tools'] END)<>'{}'::jsonb THEN
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
   IF p_config->>'template_id' IS NULL THEN
    IF length(btrim(coalesce(p_config->>'name',''))) NOT BETWEEN 2 AND 120 OR length(btrim(coalesce(p_config->>'system_prompt',''))) NOT BETWEEN 20 AND 20000 THEN RAISE EXCEPTION 'Nome/instruções inválidos' USING ERRCODE='22023';END IF;
    IF (SELECT count(*) FROM public.agents_registry WHERE tenant_id=tenant)>=50 THEN RAISE EXCEPTION 'Limite de 50 agentes por empresa' USING ERRCODE='22023';END IF;
    IF p_config->>'provider' IS NULL OR p_config->>'model' IS NULL THEN RAISE EXCEPTION 'Sem template, informe provider e model do catálogo de modelos disponíveis' USING ERRCODE='22023';END IF;
    IF NOT EXISTS(SELECT 1 FROM public.agents_registry WHERE (tenant_id=tenant OR is_template AND tenant_id IS NULL) AND provider=p_config->>'provider' AND model=p_config->>'model') THEN RAISE EXCEPTION 'Selecione provider/model de listar_agentes ou use template_id' USING ERRCODE='22023';END IF;
    aid:=gen_random_uuid();
    INSERT INTO public.agents_registry(id,tenant_id,slug,display_name,provider,model,system_prompt,is_active,created_by,responsible_user_id,settings)
    VALUES(aid,tenant,'agente-'||aid,p_config->>'name',p_config->>'provider',p_config->>'model',p_config->>'system_prompt',false,(ctx->>'member_id')::uuid,(ctx->>'member_id')::uuid,'{}');
   ELSE
   base:=crm_mcp.create_agent_draft(md5('agent-base:'||p_request_id::text)::uuid,
    (p_config->>'template_id')::uuid,p_config->>'name',p_config->>'system_prompt');
   aid:=(base->>'agent_id')::uuid;
   END IF;
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
   -- Approval-required external actions stay disabled until the runtime approval flow is validated.
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

CREATE FUNCTION public.mcp_agent_admin(p_action text,p_agent_id uuid,p_request_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid; result jsonb;payload jsonb;old crm_mcp.operations%ROWTYPE;aid uuid;key text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=tid AND NOT is_template) THEN RAISE EXCEPTION 'Agente não encontrado' USING ERRCODE='42501';END IF;
 IF p_action='knowledge_list' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM(SELECT id,title,content,tags,archived,updated_at FROM public.agent_notes WHERE agent_id=p_agent_id AND tenant_id=tid ORDER BY updated_at DESC LIMIT 100)x;RETURN result;END IF;
 IF p_action='settings_get' THEN SELECT jsonb_build_object('agent_id',id,'version',version,'responsible_user_id',responsible_user_id,'daily_token_limit',daily_token_limit,'daily_cost_limit_brl',daily_cost_limit_brl,'settings',crm_mcp.redact(settings)) INTO result FROM public.agents_registry WHERE id=p_agent_id;RETURN result;END IF;
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_request_id IS NULL OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>50000 THEN RAISE EXCEPTION 'Dados inválidos' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(tid::text,0));
 payload:=jsonb_build_object('operation','agent_admin','action',p_action,'agent_id',p_agent_id,'id',p_id,'data',p_data);
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tid AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023';END IF;RETURN old.result;END IF;
 IF p_action='knowledge_save' THEN
  IF p_data-ARRAY['title','content','tags','archived']<>'{}' OR length(coalesce(p_data->>'title','')) NOT BETWEEN 2 AND 200 OR length(coalesce(p_data->>'content','')) NOT BETWEEN 1 AND 20000 THEN RAISE EXCEPTION 'Título/conteúdo inválidos' USING ERRCODE='22023';END IF;
  IF p_id IS NOT NULL THEN
   UPDATE public.agent_notes SET title=p_data->>'title',content=p_data->>'content',tags=ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'tags','[]'))),archived=coalesce((p_data->>'archived')::boolean,false),updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('last_author','human','author_id',auth.uid()) WHERE id=p_id AND agent_id=p_agent_id AND tenant_id=tid RETURNING id INTO aid;
   IF aid IS NULL THEN RAISE EXCEPTION 'Conhecimento não pertence ao agente' USING ERRCODE='42501';END IF;
  ELSE
   INSERT INTO public.agent_notes(tenant_id,agent_id,owner_user_id,title,slug,content,tags,metadata) VALUES(tid,p_agent_id,(ctx->>'member_id')::uuid,p_data->>'title',gen_random_uuid()::text,p_data->>'content',ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'tags','[]'))),jsonb_build_object('last_author','human')) RETURNING id INTO aid;
  END IF;
  result:=jsonb_build_object('note_id',aid,'saved',true);
 ELSIF p_action='settings_save' THEN
  IF p_data-ARRAY['responsible_user_id','icp_criteria','working_hours','working_days','max_tool_iterations','max_tokens','temperature']<>'{}' THEN RAISE EXCEPTION 'Configuração não permitida; credenciais/canais têm fluxo próprio' USING ERRCODE='22023';END IF;
  IF p_data?'responsible_user_id' AND NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=(p_data->>'responsible_user_id')::uuid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável inválido' USING ERRCODE='42501';END IF;
  IF p_data?'max_tool_iterations' AND (p_data->>'max_tool_iterations')::integer NOT BETWEEN 1 AND 30 OR p_data?'max_tokens' AND (p_data->>'max_tokens')::integer NOT BETWEEN 100 AND 32000 OR p_data?'temperature' AND (p_data->>'temperature')::numeric NOT BETWEEN 0 AND 2 THEN RAISE EXCEPTION 'Limites inválidos' USING ERRCODE='22023';END IF;
  UPDATE public.agents_registry SET responsible_user_id=coalesce((p_data->>'responsible_user_id')::uuid,responsible_user_id),daily_token_limit=coalesce((p_data->>'daily_token_limit')::integer,daily_token_limit),daily_cost_limit_brl=coalesce((p_data->>'daily_cost_limit_brl')::numeric,daily_cost_limit_brl),settings=coalesce(settings,'{}')||(p_data-ARRAY['responsible_user_id','daily_token_limit','daily_cost_limit_brl']) WHERE id=p_agent_id;
  result:=jsonb_build_object('agent_id',p_agent_id,'saved',true);
 ELSIF p_action='skill_set' THEN
  IF p_data-ARRAY['skill','enabled']<>'{}' OR jsonb_typeof(p_data->'enabled') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Habilidade inválida' USING ERRCODE='22023';END IF;
  UPDATE public.agents_tools SET is_active=(p_data->>'enabled')::boolean,usage_mode=CASE WHEN (p_data->>'enabled')::boolean THEN 'always' ELSE 'disabled' END WHERE agent_id=p_agent_id AND tenant_id=tid AND name=p_data->>'skill' AND NOT requires_approval;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vincule a habilidade primeiro. Aprovação externa obrigatória não pode ser ignorada.' USING ERRCODE='22023';END IF;
  result:=jsonb_build_object('agent_id',p_agent_id,'skill',p_data->>'skill','enabled',(p_data->>'enabled')::boolean);
 ELSE RAISE EXCEPTION 'Operação inválida' USING ERRCODE='22023';END IF;
 UPDATE public.agents_registry SET version=version+1,updated_at=now() WHERE id=p_agent_id AND tenant_id=tid;
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tid,p_request_id,auth.uid(),payload,result);
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.mcp_agent_admin(text,uuid,uuid,jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mcp_agent_admin(text,uuid,uuid,jsonb,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_agent_admin','rpc/playground_crm_action','rpc/mcp_configure_operational_skill','rpc/playground_mark_deal_lost','rpc/playground_notify_human','rpc/mcp_playground_job','rpc/playground_qualify_lead','rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

BEGIN;
CREATE FUNCTION crm_mcp.crm_resource(p_resource text) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $catalog$
 SELECT ($resources${"contato": {"table": "leads", "plural": "contatos", "search": "name", "fields": ["name", "email", "phone", "phone2", "instagram", "company_name", "job_title", "source", "context", "city_name", "state", "country", "tags", "status", "sales_rep_id", "expected_revenue", "bant_budget", "bant_authority", "bant_need", "bant_timeline", "qualification", "monthly_revenue", "lead_temperature", "email_opted_out"], "required": ["name"], "read": ["id", "name", "email", "phone", "phone2", "instagram", "company_name", "job_title", "source", "context", "city_name", "state", "country", "tags", "status", "sales_rep_id", "expected_revenue", "bant_budget", "bant_authority", "bant_need", "bant_timeline", "qualification", "monthly_revenue", "lead_temperature", "email_opted_out", "created_at", "updated_at"]}, "oportunidade": {"table": "deals", "plural": "oportunidades", "search": "title", "fields": ["lead_id", "title", "description", "pipeline_id", "pipeline_stage_id", "sales_rep_id", "sdr_id", "product_id", "original_price", "negotiated_price", "expected_close_date", "notes", "labels", "lost_reason"], "required": ["lead_id", "title", "pipeline_id", "pipeline_stage_id"], "read": ["id", "lead_id", "title", "description", "pipeline_id", "pipeline_stage_id", "sales_rep_id", "sdr_id", "product_id", "original_price", "negotiated_price", "expected_close_date", "notes", "labels", "lost_reason", "status", "won_at", "lost_at", "stage_changed_at", "created_at", "updated_at"]}, "tarefa": {"table": "company_activities", "plural": "tarefas", "search": "name", "fields": ["name", "description", "lead_id", "responsavel_id", "priority", "task_type", "due_datetime", "scheduled_at", "end_datetime", "notes", "completed", "outcome", "meeting_link", "status"], "required": ["name"], "read": ["id", "name", "description", "lead_id", "responsavel_id", "priority", "task_type", "due_datetime", "scheduled_at", "end_datetime", "notes", "completed", "outcome", "meeting_link", "created_at", "updated_at", "status", "completed_at"]}, "nota": {"table": "sales_notes", "plural": "notas", "search": "content", "fields": ["lead_id", "deal_id", "content", "note_type"], "required": ["content"], "read": ["id", "lead_id", "deal_id", "content", "note_type", "created_at", "updated_at"]}, "etapa": {"table": "sales_pipeline_stages", "plural": "etapas", "search": "name", "fields": ["pipeline_id", "name", "description", "position", "color", "is_won", "is_lost"], "required": ["pipeline_id", "name", "position"], "read": ["id", "pipeline_id", "name", "description", "position", "color", "is_won", "is_lost", "created_at", "updated_at"]}, "funil": {"table": "sales_pipelines", "plural": "funis", "search": "name", "fields": ["name", "description", "is_active", "color", "default_sales_rep_id"], "required": ["name"], "read": ["id", "name", "description", "is_active", "color", "default_sales_rep_id", "created_at", "updated_at"]}, "produto": {"table": "products", "plural": "produtos", "search": "name", "fields": ["name", "slug", "description", "price", "category", "sku", "is_active"], "required": ["name", "slug"], "read": ["id", "name", "slug", "description", "price", "category", "sku", "is_active", "created_at", "updated_at"]}, "campanha_email": {"table": "email_campaigns", "plural": "campanhas_email", "search": "name", "fields": ["name", "description", "subject", "from_name", "from_email", "reply_to", "html_content", "preheader", "template_id"], "required": ["name"], "read": ["id", "name", "description", "subject", "from_name", "from_email", "reply_to", "html_content", "preheader", "template_id", "status", "created_at", "updated_at"]}, "campanha_whatsapp": {"table": "campaigns", "plural": "campanhas_whatsapp", "search": "name", "fields": ["name", "description", "message_content"], "required": ["name", "message_content"], "read": ["id", "name", "description", "message_content", "status", "created_at", "updated_at"]}, "template_email": {"table": "email_templates", "plural": "templates_email", "search": "name", "fields": ["name", "subject", "html_content", "text_content", "preheader", "category", "variables", "is_active"], "required": ["name"], "read": ["id", "name", "subject", "html_content", "text_content", "preheader", "category", "variables", "is_active", "created_at", "updated_at"]}, "automacao_email": {"table": "email_automations", "plural": "automacoes_email", "search": "name", "fields": ["name", "description", "trigger_event", "trigger_filter", "flow_json"], "required": ["name", "trigger_event"], "read": ["id", "name", "description", "trigger_event", "trigger_filter", "flow_json", "is_active", "created_at", "updated_at"]}, "automacao_comercial": {"table": "sales_automation_rules", "plural": "automacoes_comerciais", "search": "name", "fields": ["name", "description", "trigger_type", "trigger_conditions", "action_type", "action_config", "priority"], "required": ["name", "trigger_type", "action_type"], "read": ["id", "name", "description", "trigger_type", "trigger_conditions", "action_type", "action_config", "priority", "is_active", "created_at", "updated_at"]}, "lista_email": {"table": "email_lists", "plural": "listas_email", "search": "name", "fields": ["name", "description", "criteria", "is_dynamic", "is_active"], "required": ["name"], "read": ["id", "name", "description", "criteria", "is_dynamic", "is_active", "created_at", "updated_at"]}, "membro": {"table": "team_members", "plural": "membros", "search": "name", "fields": ["name", "email", "role", "team", "is_active"], "required": [], "read": ["id", "name", "email", "role", "team", "is_active", "created_at", "updated_at"]}}$resources$::jsonb)->p_resource;
$catalog$;
REVOKE ALL ON FUNCTION crm_mcp.crm_resource(text) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION crm_mcp.crm_operation(p_resource text,p_action text,p_id text DEFAULT NULL,p_request_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_filters jsonb DEFAULT '{}',p_limit integer DEFAULT 30,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE ctx jsonb:=crm_mcp.context(); tenant uuid:=(ctx->>'tenant_id')::uuid; cfg jsonb:=crm_mcp.crm_resource(p_resource);
 tab text; cols text; vals text; assignments text; projection text; result jsonb; before_row jsonb; merged jsonb;
 payload jsonb; old crm_mcp.operations%ROWTYPE; k text; ref text; ref_table text; found_ref boolean; new_id text;
 target public.sales_pipeline_stages%ROWTYPE; related public.deals%ROWTYPE; start_time timestamptz; finish_time timestamptz;
BEGIN
 IF cfg IS NULL OR p_resource IS NULL OR p_action IS NULL OR p_action NOT IN ('list','get','create','update','move','complete') THEN RAISE EXCEPTION 'Operação não disponível' USING ERRCODE='22023'; END IF;
 tab:=cfg->>'table';
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000 OR p_data IS NULL OR p_filters IS NULL OR jsonb_typeof(p_data)<>'object' OR jsonb_typeof(p_filters)<>'object' OR octet_length(p_data::text)>100000 OR octet_length(p_filters::text)>4000 THEN RAISE EXCEPTION 'Parâmetros inválidos' USING ERRCODE='22023'; END IF;
 SELECT string_agg(format('%L,t.%I',value,value),',') INTO projection FROM jsonb_array_elements_text(cfg->'read');
 IF p_action IN ('list','get') THEN
  IF p_filters - ARRAY['query','lead_id','deal_id','pipeline_id','pipeline_stage_id','responsavel_id','sales_rep_id','status','completed'] <> '{}'::jsonb THEN RAISE EXCEPTION 'Filtro não permitido' USING ERRCODE='22023'; END IF;
  IF p_action='get' AND p_id IS NULL THEN RAISE EXCEPTION 'Informe o ID' USING ERRCODE='22023'; END IF;
  -- Structured exact filters apply to the row; free text only searches the documented name field (and email/phone for contacts).
  EXECUTE format('SELECT coalesce(jsonb_agg(x.row),''[]''::jsonb) FROM (SELECT jsonb_build_object(%s) row FROM public.%I t WHERE t.tenant_id=$1 AND ($2 IS NULL OR t.id::text=$2) AND to_jsonb(t) @> ($3-''query'') AND ($3->>''query'' IS NULL OR t.%I ILIKE ''%%''||($3->>''query'')||''%%'' %s) ORDER BY t.created_at DESC,t.id LIMIT $4 OFFSET $5) x',projection,tab,cfg->>'search',CASE WHEN p_resource='contato' THEN 'OR t.email ILIKE ''%''||($3->>''query'')||''%'' OR t.phone ILIKE ''%''||($3->>''query'')||''%''' ELSE '' END)
   INTO result USING tenant,p_id,p_filters,p_limit,p_offset;
  IF p_action='get' THEN IF jsonb_array_length(result)=0 THEN RAISE EXCEPTION 'Registro não encontrado nesta empresa' USING ERRCODE='P0002'; END IF; RETURN result->0; END IF;
  RETURN jsonb_build_object('items',result,'limit',p_limit,'offset',p_offset,'next_offset',CASE WHEN jsonb_array_length(result)=p_limit THEN p_offset+p_limit ELSE NULL END);
 END IF;
 IF NOT (ctx->>'can_write')::boolean OR p_resource='membro' THEN RAISE EXCEPTION 'Operação de escrita não autorizada' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'request_id obrigatório para repetir sem duplicar' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(tenant::text,0));
 payload:=jsonb_build_object('resource',p_resource,'action',p_action,'id',p_id,'data',p_data);
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tenant AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado com outro conteúdo' USING ERRCODE='22023'; END IF; RETURN old.result; END IF;
 IF p_action<>'create' THEN
  EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE t.tenant_id=$1 AND t.id::text=$2 FOR UPDATE',tab) INTO before_row USING tenant,p_id;
  IF before_row IS NULL THEN RAISE EXCEPTION 'Registro não encontrado nesta empresa' USING ERRCODE='P0002'; END IF;
 END IF;
 IF p_action='move' THEN
  IF p_resource<>'oportunidade' OR p_data-ARRAY['pipeline_stage_id','lost_reason']<>'{}'::jsonb OR NOT p_data?'pipeline_stage_id' THEN RAISE EXCEPTION 'Informe a etapa de destino' USING ERRCODE='22023'; END IF;
 ELSIF p_action='complete' THEN
  IF p_resource<>'tarefa' OR p_data-ARRAY['outcome','notes']<>'{}'::jsonb THEN RAISE EXCEPTION 'Conclusão inválida' USING ERRCODE='22023'; END IF;
  p_data:=p_data||jsonb_build_object('completed',true);
 END IF;
 IF p_data='{}'::jsonb THEN RAISE EXCEPTION 'Informe os campos a alterar' USING ERRCODE='22023'; END IF;
 FOR k IN SELECT jsonb_object_keys(p_data) LOOP
  IF NOT (cfg->'fields')?k THEN RAISE EXCEPTION 'Campo não permitido: %',k USING ERRCODE='22023'; END IF;
 END LOOP;
 merged:=coalesce(before_row,'{}')||p_data;
 FOR k IN SELECT jsonb_array_elements_text(cfg->'required') LOOP
  IF nullif(btrim(merged->>k),'') IS NULL THEN RAISE EXCEPTION 'Campo obrigatório: %',k USING ERRCODE='22023'; END IF;
 END LOOP;
 -- Every foreign reference is checked against the authenticated tenant, even in JSON-derived updates.
 FOR k,ref_table IN SELECT * FROM (VALUES ('lead_id','leads'),('deal_id','deals'),('sales_rep_id','team_members'),('sdr_id','team_members'),('responsavel_id','team_members'),('default_sales_rep_id','team_members'),('pipeline_id','sales_pipelines'),('pipeline_stage_id','sales_pipeline_stages'),('product_id','products'),('template_id','email_templates')) refs(field_name,table_name) LOOP
  ref:=merged->>k;
  IF ref IS NOT NULL THEN
   EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I WHERE tenant_id=$1 AND id::text=$2)',ref_table) INTO found_ref USING tenant,ref;
   IF NOT found_ref THEN RAISE EXCEPTION 'Referência inválida nesta empresa: %',k USING ERRCODE='42501'; END IF;
  END IF;
 END LOOP;
 IF p_resource='oportunidade' THEN
  SELECT * INTO target FROM public.sales_pipeline_stages WHERE tenant_id=tenant AND id=(merged->>'pipeline_stage_id')::uuid;
  IF target.pipeline_id IS DISTINCT FROM (merged->>'pipeline_id')::uuid THEN RAISE EXCEPTION 'Etapa não pertence ao funil informado' USING ERRCODE='22023'; END IF;
  IF p_action='create' OR p_data?'pipeline_stage_id' THEN
   p_data:=p_data||jsonb_build_object('status',CASE WHEN target.is_won THEN 'won' WHEN target.is_lost THEN 'lost' ELSE 'negotiation' END,'won_at',CASE WHEN target.is_won THEN now() ELSE NULL END,'lost_at',CASE WHEN target.is_lost THEN now() ELSE NULL END,'stage_changed_at',now());
  END IF;
 END IF;
 IF p_resource='nota' THEN
  IF merged->>'lead_id' IS NULL AND merged->>'deal_id' IS NULL THEN RAISE EXCEPTION 'Vincule a nota a um contato ou oportunidade' USING ERRCODE='22023'; END IF;
  IF merged->>'deal_id' IS NOT NULL THEN
   SELECT * INTO related FROM public.deals WHERE id=(merged->>'deal_id')::uuid AND tenant_id=tenant;
   IF merged->>'lead_id' IS NOT NULL AND related.lead_id IS DISTINCT FROM (merged->>'lead_id')::uuid THEN RAISE EXCEPTION 'Oportunidade não pertence ao contato' USING ERRCODE='22023'; END IF;
   p_data:=p_data||jsonb_build_object('lead_id',related.lead_id);
  END IF;
 END IF;
 IF p_resource='etapa' THEN
  IF coalesce((merged->>'is_won')::boolean,false) AND coalesce((merged->>'is_lost')::boolean,false) THEN RAISE EXCEPTION 'Etapa não pode ser ganho e perda' USING ERRCODE='22023'; END IF;
  IF p_action='update' AND p_data?'pipeline_id' AND p_data->>'pipeline_id'<>before_row->>'pipeline_id' THEN RAISE EXCEPTION 'Não transfira etapas entre funis; crie uma nova' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_resource IN ('campanha_email','campanha_whatsapp') THEN
  IF p_action='update' AND before_row->>'status'<>'draft' THEN RAISE EXCEPTION 'Somente campanhas em rascunho podem ser editadas aqui' USING ERRCODE='22023'; END IF;
  IF p_action='create' THEN p_data:=p_data||jsonb_build_object('status','draft'); END IF;
 END IF;
 IF p_resource IN ('automacao_email','automacao_comercial') THEN
  IF p_action='update' AND (before_row->>'is_active')::boolean THEN RAISE EXCEPTION 'Pause a automação antes de editar' USING ERRCODE='22023'; END IF;
  p_data:=p_data||jsonb_build_object('is_active',false);
 END IF;
 IF p_resource='tarefa' THEN
  IF coalesce(merged->>'task_type','internal') NOT IN ('internal','meeting','call','follow_up','email','whatsapp','onboarding','support','checkin','review','renewal','upsell','rescue','nps') THEN RAISE EXCEPTION 'Tipo de tarefa inválido' USING ERRCODE='22023'; END IF;
  IF merged->>'responsavel_id' IS NULL THEN p_data:=p_data||jsonb_build_object('responsavel_id',ctx->>'member_id'); merged:=merged||p_data; END IF;
  IF coalesce(merged->>'status','not_started') NOT IN ('not_started','in_progress','completed','cancelled') THEN RAISE EXCEPTION 'Status de tarefa inválido' USING ERRCODE='22023'; END IF;
  IF p_data?'status' AND p_data->>'status'='completed' THEN p_data:=p_data||jsonb_build_object('completed',true); merged:=merged||p_data; END IF;
  IF merged->>'task_type' IN ('meeting','call') AND coalesce(merged->>'status','not_started')<>'cancelled' AND NOT coalesce((merged->>'completed')::boolean,false) THEN
   start_time:=(merged->>'scheduled_at')::timestamptz; finish_time:=(merged->>'end_datetime')::timestamptz;
   IF start_time IS NULL OR finish_time IS NULL OR finish_time<=start_time THEN RAISE EXCEPTION 'Informe início e fim válidos da reunião/ligação' USING ERRCODE='22023'; END IF;
   PERFORM pg_advisory_xact_lock(hashtextextended(merged->>'responsavel_id',1));
   IF EXISTS(SELECT 1 FROM public.company_activities a WHERE a.tenant_id=tenant AND a.responsavel_id=(merged->>'responsavel_id')::uuid AND NOT a.completed AND coalesce(a.status,'not_started')<>'cancelled' AND a.task_type IN ('meeting','call') AND (p_id IS NULL OR a.id::text<>p_id) AND a.scheduled_at<finish_time AND coalesce(a.end_datetime,a.scheduled_at+interval '30 minutes')>start_time) THEN RAISE EXCEPTION 'Responsável já ocupado neste horário' USING ERRCODE='22023'; END IF;
  END IF;
  IF p_data?'completed' THEN p_data:=p_data||jsonb_build_object('status',CASE WHEN (p_data->>'completed')::boolean THEN 'completed' ELSE coalesce(p_data->>'status','not_started') END,'completed_at',CASE WHEN (p_data->>'completed')::boolean THEN now() ELSE NULL END); END IF;
  IF p_action='create' THEN p_data:=p_data||jsonb_build_object('team','sales','created_by_id',ctx->>'member_id'); END IF;
 END IF;
 IF p_action='create' THEN
  new_id:=gen_random_uuid()::text;
  p_data:=p_data||jsonb_build_object('id',new_id,'tenant_id',tenant);
  SELECT string_agg(format('%I',key),','),string_agg(format('v.%I',key),',') INTO cols,vals FROM jsonb_object_keys(p_data) AS f(key);
  EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I,$1) v',tab,cols,vals,tab) USING p_data;
 ELSE
  new_id:=p_id;p_data:=p_data||jsonb_build_object('updated_at',now());
  SELECT string_agg(format('%I=v.%I',key,key),',') INTO assignments FROM jsonb_object_keys(p_data) AS f(key);
  EXECUTE format('UPDATE public.%I t SET %s FROM jsonb_populate_record(NULL::public.%I,$1) v WHERE t.tenant_id=$2 AND t.id::text=$3',tab,assignments,tab) USING p_data,tenant,p_id;
 END IF;
 EXECUTE format('SELECT jsonb_build_object(%s) FROM public.%I t WHERE t.tenant_id=$1 AND t.id::text=$2',projection,tab) INTO result USING tenant,new_id;
 result:=jsonb_build_object('ok',true,'resource',p_resource,'record',result,'external_messages_sent',false);
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tenant,p_request_id,auth.uid(),payload,result);
 RETURN result;
END $$;
CREATE FUNCTION public.mcp_crm(p_resource text,p_action text,p_id text DEFAULT NULL,p_request_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_filters jsonb DEFAULT '{}',p_limit integer DEFAULT 30,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT crm_mcp.crm_operation(p_resource,p_action,p_id,p_request_id,p_data,p_filters,p_limit,p_offset); $$;
REVOKE ALL ON FUNCTION crm_mcp.crm_operation(text,text,text,uuid,jsonb,jsonb,integer,integer),public.mcp_crm(text,text,text,uuid,jsonb,jsonb,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION crm_mcp.crm_operation(text,text,text,uuid,jsonb,jsonb,integer,integer),public.mcp_crm(text,text,text,uuid,jsonb,jsonb,integer,integer) TO authenticated;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

NOTIFY pgrst, 'reload schema';
COMMIT;

BEGIN;
CREATE FUNCTION crm_mcp.skill_available(slug text,action_type text,config jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT coalesce(slug NOT IN ('execute_sql','list_tables','describe_table','meta_api')
 AND NOT (config ? 'query') AND action_type IN ('sql','http','edge_function')
 AND (action_type<>'sql' OR (config->>'function' LIKE 'agent_%' AND config->>'function' NOT IN ('agent_execute_readonly','agent_describe_table','agent_list_tables'))),false);
$$;
REVOKE ALL ON FUNCTION crm_mcp.skill_available(text,text,jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION crm_mcp.agent_setup(p_action text,p_request_id uuid DEFAULT NULL,p_agent_id uuid DEFAULT NULL,p_config jsonb DEFAULT NULL)
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
  'validation_status','not_tested','ready',false,
  'pending',jsonb_build_array('Vincular credencial do modelo','Preparar conhecimento e contexto de contato/oportunidade','Validar provedores das habilidades e simular execução','Revisar habilidades desativadas que exigem aprovação','Ativar somente após validar o agente'));
 IF p_action<>'get' THEN
  INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tenant,p_request_id,auth.uid(),payload,result);
 END IF;
 RETURN result;
END $$;
CREATE FUNCTION public.mcp_agent_setup(p_action text,p_request_id uuid DEFAULT NULL,p_agent_id uuid DEFAULT NULL,p_config jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT crm_mcp.agent_setup(p_action,p_request_id,p_agent_id,p_config); $$;
REVOKE ALL ON FUNCTION crm_mcp.agent_setup(text,uuid,uuid,jsonb),public.mcp_agent_setup(text,uuid,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION crm_mcp.agent_setup(text,uuid,uuid,jsonb),public.mcp_agent_setup(text,uuid,uuid,jsonb) TO authenticated;
CREATE OR REPLACE FUNCTION crm_mcp.implementation(p_action text,p_plan_id uuid DEFAULT NULL,p_request_id uuid DEFAULT NULL,
 p_version integer DEFAULT NULL,p_document jsonb DEFAULT NULL,p_item_id uuid DEFAULT NULL,p_approval text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ctx jsonb:=crm_mcp.context(); tenant uuid:=(ctx->>'tenant_id')::uuid;
 plan crm_mcp.plans%ROWTYPE; old crm_mcp.operations%ROWTYPE;
 payload jsonb; result jsonb; item jsonb; step jsonb; dep text; seen text[]:=ARRAY[]::text[];
 item_key text; operation_id uuid; outcome jsonb; result_count integer;
BEGIN
 IF p_action='list' THEN
  SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (
   SELECT id,version,document->>'title' AS title,approval IS NOT NULL AS approved,
     jsonb_array_length(document->'items') AS total_items,results,updated_at
   FROM crm_mcp.plans WHERE tenant_id=tenant ORDER BY updated_at DESC,id LIMIT 50
  ) x;
  RETURN jsonb_build_object('plans',result,'limit',50);
 END IF;
 IF p_action NOT IN ('get','save','approve','apply') OR p_action IS NULL OR p_plan_id IS NULL THEN
  RAISE EXCEPTION 'Operação ou plano inválido' USING ERRCODE='22023'; END IF;
 IF p_action='get' THEN
  SELECT * INTO plan FROM crm_mcp.plans WHERE tenant_id=tenant AND id=p_plan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Plano não encontrado nesta empresa' USING ERRCODE='P0002'; END IF;
  SELECT coalesce(jsonb_agg(h),'[]') INTO result FROM (SELECT version,action,actor_id,created_at FROM crm_mcp.plan_events WHERE tenant_id=tenant AND plan_id=p_plan_id ORDER BY id DESC LIMIT 50) h;
  RETURN (to_jsonb(plan)-'tenant_id') || jsonb_build_object('history',result);
 END IF;
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'request_id obrigatório' USING ERRCODE='22023'; END IF;
 -- Same lock order as pipeline/agent creation, serializing mutation and retry per tenant.
 PERFORM pg_advisory_xact_lock(hashtextextended(tenant::text,0));
 payload:=jsonb_build_object('operation','implementation','action',p_action,'plan',p_plan_id,'version',p_version,
  'document',p_document,'item',p_item_id,'approval',p_approval);
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tenant AND request_id=p_request_id;
 IF FOUND THEN
  IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023'; END IF;
  RETURN old.result;
 END IF;
 SELECT * INTO plan FROM crm_mcp.plans WHERE tenant_id=tenant AND id=p_plan_id FOR UPDATE;
 IF NOT FOUND AND p_action<>'save' THEN RAISE EXCEPTION 'Plano não encontrado nesta empresa' USING ERRCODE='P0002'; END IF;
 IF p_version IS DISTINCT FROM coalesce(plan.version,0) THEN
  RAISE EXCEPTION 'Versão desatualizada. Consulte o plano antes de alterar.' USING ERRCODE='40001'; END IF;
 IF p_action='save' THEN
  IF p_document IS NULL OR jsonb_typeof(p_document)<>'object' OR octet_length(p_document::text)>60000
   OR coalesce(length(btrim(p_document->>'title')),0) NOT BETWEEN 2 AND 120
   OR coalesce(length(p_document->>'process'),0) NOT BETWEEN 10 AND 20000
   OR jsonb_typeof(p_document->'items') IS DISTINCT FROM 'array'
   OR jsonb_array_length(p_document->'items') NOT BETWEEN 1 AND 50
   OR (p_document - ARRAY['title','process','items'])<>'{}'::jsonb THEN
   RAISE EXCEPTION 'Documento inválido: título, processo e até 50 itens; máximo 60 KB.' USING ERRCODE='22023'; END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(p_document->'items') LOOP
   item_key:=item->>'id';
   IF item_key IS NULL OR item_key !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR item_key=ANY(seen) OR coalesce(length(item->>'title'),0) NOT BETWEEN 2 AND 120
    OR coalesce(item->>'kind','') NOT IN ('pipeline','agent_draft','campaign','automation','integration','knowledge','task')
    OR jsonb_typeof(item->'config') IS DISTINCT FROM 'object'
    OR jsonb_typeof(item->'depends_on') IS DISTINCT FROM 'array'
    OR (item - ARRAY['id','title','kind','config','depends_on'])<>'{}'::jsonb THEN
    RAISE EXCEPTION 'Item inválido ou identificador repetido' USING ERRCODE='22023'; END IF;
   FOR dep IN SELECT jsonb_array_elements_text(item->'depends_on') LOOP
    IF NOT dep=ANY(seen) THEN RAISE EXCEPTION 'Dependências devem aparecer antes do item no plano' USING ERRCODE='22023'; END IF;
   END LOOP;
   seen:=array_append(seen,item_key);
  END LOOP;
  -- Applied resources are immutable here; editing real resources needs a specific future executor.
  FOR item IN SELECT value FROM jsonb_array_elements(coalesce(plan.document->'items','[]')) LOOP
   IF plan.results->(item->>'id')->>'status'='applied' AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_document->'items') n WHERE n=item) THEN
    RAISE EXCEPTION 'Um item aplicado não pode ser removido ou alterado. Preserve-o e acrescente novos itens.' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF plan.id IS NULL THEN
   IF (SELECT count(*) FROM crm_mcp.plans WHERE tenant_id=tenant)>=50 THEN
    RAISE EXCEPTION 'Limite de 50 planos por empresa' USING ERRCODE='22023'; END IF;
   INSERT INTO crm_mcp.plans(tenant_id,id,document,created_by,updated_by)
    VALUES(tenant,p_plan_id,p_document,auth.uid(),auth.uid()) RETURNING * INTO plan;
  ELSE
   -- Clear failed/pending results when the proposal changes; preserve only applied outcomes.
   SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO result FROM jsonb_each(plan.results) WHERE value->>'status'='applied';
   UPDATE crm_mcp.plans SET document=p_document,version=version+1,approval=NULL,results=result,
    updated_by=auth.uid(),updated_at=now() WHERE tenant_id=tenant AND id=p_plan_id RETURNING * INTO plan;
  END IF;
 ELSIF p_action='approve' THEN
  IF coalesce(length(btrim(p_approval)),0) NOT BETWEEN 10 AND 2000 THEN
   RAISE EXCEPTION 'Registre a confirmação explícita do usuário sobre esta versão' USING ERRCODE='22023'; END IF;
  UPDATE crm_mcp.plans SET approval=jsonb_build_object('version',version,'user_id',auth.uid(),'at',now(),'confirmation',p_approval),
   updated_by=auth.uid(),updated_at=now() WHERE tenant_id=tenant AND id=p_plan_id RETURNING * INTO plan;
 ELSIF p_action='apply' THEN
  IF plan.approval IS NULL OR (plan.approval->>'version')::integer<>plan.version THEN
   RAISE EXCEPTION 'Esta versão precisa de aprovação antes de aplicar' USING ERRCODE='42501'; END IF;
  SELECT value INTO step FROM jsonb_array_elements(plan.document->'items') WHERE value->>'id'=p_item_id::text;
  IF NOT FOUND THEN RAISE EXCEPTION 'Item não encontrado no plano' USING ERRCODE='22023'; END IF;
  item_key:=p_item_id::text;
  IF plan.results->item_key->>'status' IS DISTINCT FROM 'applied' THEN
   FOR dep IN SELECT jsonb_array_elements_text(step->'depends_on') LOOP
    IF plan.results->dep->>'status' IS DISTINCT FROM 'applied' THEN
     RAISE EXCEPTION 'Aplique as dependências antes deste item' USING ERRCODE='22023'; END IF;
   END LOOP;
   operation_id:=md5(p_plan_id::text||':'||item_key)::uuid;
   BEGIN
    IF step->>'kind'='pipeline' THEN
     outcome:=crm_mcp.create_pipeline(operation_id,step->'config');
    ELSIF step->>'kind'='agent_draft' THEN
     outcome:=crm_mcp.agent_setup('create',operation_id,NULL,step->'config');
    ELSE
     outcome:=jsonb_build_object('status','pending_capability','reason','Configuração registrada. Este tipo ainda não possui executor MCP; não foi aplicado.');
    END IF;
    IF step->>'kind' IN ('pipeline','agent_draft') THEN
     outcome:=jsonb_build_object('status','applied','resource',outcome,'at',now()); END IF;
   EXCEPTION WHEN OTHERS THEN
    outcome:=jsonb_build_object('status','failed','reason','Configuração recusada. Confira modelo, limites e parâmetros; consulte os recursos antes de tentar novamente.','at',now());
   END;
   UPDATE crm_mcp.plans SET results=jsonb_set(results,ARRAY[item_key],outcome),updated_at=now(),updated_by=auth.uid()
    WHERE tenant_id=tenant AND id=p_plan_id RETURNING * INTO plan;
  END IF;
 END IF;
 result:=to_jsonb(plan)-'tenant_id';
 INSERT INTO crm_mcp.plan_events(tenant_id,plan_id,version,actor_id,action,request_id,snapshot)
  VALUES(tenant,p_plan_id,plan.version,auth.uid(),p_action,p_request_id,result);
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tenant,p_request_id,auth.uid(),payload,result);
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

BEGIN;
CREATE FUNCTION crm_mcp.list_agents()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE ctx jsonb := crm_mcp.context(); v_result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(item ORDER BY name,id),'[]') INTO v_result FROM (
    SELECT r.display_name AS name,r.id,jsonb_build_object('id',r.id,'name',r.display_name,
      'description',r.description,'is_template',r.is_template,'is_active',r.is_active,
      'provider',r.provider,'model',r.model) AS item
    FROM public.agents_registry r WHERE r.tenant_id=(ctx->>'tenant_id')::uuid
      OR (r.tenant_id IS NULL AND r.is_template IS TRUE)
    ORDER BY r.is_template DESC,r.display_name,r.id LIMIT 100
  ) bounded;
  RETURN v_result;
END;
$$;
CREATE FUNCTION public.mcp_list_agents()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT crm_mcp.list_agents(); $$;

CREATE FUNCTION crm_mcp.create_agent_draft(p_request_id uuid,p_template_id uuid,p_name text,p_system_prompt text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ctx jsonb := crm_mcp.context(); t public.agents_registry%ROWTYPE;
  v_tenant uuid := (ctx->>'tenant_id')::uuid; v_id uuid := gen_random_uuid();
  v_payload jsonb; v_result jsonb; previous crm_mcp.operations%ROWTYPE;
BEGIN
  IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501'; END IF;
  IF p_request_id IS NULL OR p_template_id IS NULL OR coalesce(length(btrim(p_name)),0) NOT BETWEEN 2 AND 120
    OR coalesce(length(btrim(p_system_prompt)),0) NOT BETWEEN 20 AND 20000 THEN
    RAISE EXCEPTION 'Rascunho inválido' USING ERRCODE='22023'; END IF;
  v_payload:=jsonb_build_object('operation','create_agent_draft','template_id',p_template_id,'name',btrim(p_name),'system_prompt',btrim(p_system_prompt));
  PERFORM pg_advisory_xact_lock(hashtextextended(v_tenant::text,0));
  SELECT * INTO previous FROM crm_mcp.operations WHERE tenant_id=v_tenant AND request_id=p_request_id;
  IF FOUND THEN
    IF previous.payload<>v_payload OR previous.user_id<>auth.uid() THEN
      RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023'; END IF;
    RETURN previous.result;
  END IF;
  IF (SELECT count(*) FROM public.agents_registry WHERE tenant_id=v_tenant) >= 50 THEN
    RAISE EXCEPTION 'Limite de 50 agentes por empresa atingido' USING ERRCODE='22023'; END IF;
  SELECT * INTO t FROM public.agents_registry WHERE id=p_template_id AND is_template IS TRUE AND tenant_id IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Modelo global não encontrado' USING ERRCODE='42501'; END IF;
  INSERT INTO public.agents_registry(id,tenant_id,slug,display_name,description,emoji,provider,model,system_prompt,
    settings,is_active,created_by,responsible_user_id,is_template,avatar_color,tier)
    VALUES(v_id,v_tenant,'agente-'||v_id::text,btrim(p_name),'Rascunho criado pela implantação MCP',t.emoji,t.provider,t.model,btrim(p_system_prompt),
      '{}'::jsonb,false,auth.uid(),auth.uid(),false,coalesce(t.avatar_color,'amber'),'specialist');
  v_result:=jsonb_build_object('agent_id',v_id,'slug','agente-'||v_id::text,'name',btrim(p_name),'is_active',false,
    'pending',jsonb_build_array('credencial do provedor','ferramentas permitidas','canais','teste e ativação pelo administrador'));
  INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(v_tenant,p_request_id,auth.uid(),v_payload,v_result);
  RETURN v_result;
END;
$$;
CREATE FUNCTION public.mcp_create_agent_draft(p_request_id uuid,p_template_id uuid,p_name text,p_system_prompt text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
  SELECT crm_mcp.create_agent_draft(p_request_id,p_template_id,p_name,p_system_prompt);
$$;
REVOKE ALL ON FUNCTION crm_mcp.list_agents(),crm_mcp.create_agent_draft(uuid,uuid,text,text),public.mcp_list_agents(),public.mcp_create_agent_draft(uuid,uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION crm_mcp.list_agents(),crm_mcp.create_agent_draft(uuid,uuid,text,text),public.mcp_list_agents(),public.mcp_create_agent_draft(uuid,uuid,text,text) TO authenticated;
COMMIT;

BEGIN;
CREATE TABLE crm_mcp.whatsapp_requests (
 tenant_id uuid NOT NULL REFERENCES public.tenants(id), request_id uuid NOT NULL,
 name text NOT NULL, instance_id uuid REFERENCES public.whatsapp_instances(id),
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,request_id)
);
ALTER TABLE crm_mcp.whatsapp_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON crm_mcp.whatsapp_requests FROM PUBLIC,anon,authenticated;
-- Called only by the authenticated MCP Edge adapter. IDs derive from mcp_context.
CREATE FUNCTION public.mcp_whatsapp_admin(p_tenant_id uuid,p_user_id uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,crm_mcp AS $$
DECLARE r crm_mcp.whatsapp_requests; i public.whatsapp_instances; a public.agents_registry;
 d public.agents_deployments; rid uuid; created boolean; active boolean; result jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM team_members m JOIN tenants t ON t.id=m.tenant_id
 WHERE m.tenant_id=p_tenant_id AND m.auth_user_id=p_user_id AND m.is_active AND m.role='admin' AND t.is_active)
 THEN RAISE EXCEPTION 'Administrador ativo obrigatório' USING ERRCODE='42501'; END IF;
 IF p_action='reserve' THEN
  rid:=(p_data->>'request_id')::uuid;
  IF length(trim(p_data->>'name')) NOT BETWEEN 1 AND 100 OR rid IS NULL THEN RAISE EXCEPTION 'Nome/request_id inválido'; END IF;
  INSERT INTO crm_mcp.whatsapp_requests(tenant_id,request_id,name) VALUES(p_tenant_id,rid,trim(p_data->>'name')) ON CONFLICT DO NOTHING;
  created:=FOUND;
  SELECT * INTO r FROM crm_mcp.whatsapp_requests WHERE tenant_id=p_tenant_id AND request_id=rid;
  IF r.name<>trim(p_data->>'name') THEN RAISE EXCEPTION 'request_id já utilizado com outro nome'; END IF;
  RETURN jsonb_build_object('should_create',created,'instance_id',r.instance_id,'name',r.name);
 ELSIF p_action='finish' THEN
  SELECT * INTO r FROM crm_mcp.whatsapp_requests WHERE tenant_id=p_tenant_id AND request_id=(p_data->>'request_id')::uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solicitação inexistente'; END IF;
  IF r.instance_id IS NOT NULL THEN RETURN jsonb_build_object('instance_id',r.instance_id); END IF;
  IF nullif(p_data->>'token','') IS NULL OR nullif(p_data->>'api_url','') IS NULL THEN RAISE EXCEPTION 'Credencial ausente'; END IF;
  INSERT INTO whatsapp_instances(tenant_id,name,api_url,api_key,status,purpose,teams,metadata)
  VALUES(p_tenant_id,r.name,p_data->>'api_url',p_data->>'token','disconnected','inbox',ARRAY['comercial'],jsonb_build_object('uazapi_instance_id',p_data->>'provider_id','mcp_request_id',r.request_id)) RETURNING * INTO i;
  UPDATE crm_mcp.whatsapp_requests SET instance_id=i.id WHERE tenant_id=p_tenant_id AND request_id=r.request_id;
  RETURN jsonb_build_object('instance_id',i.id);
 ELSIF p_action='bind' THEN
  SELECT * INTO i FROM whatsapp_instances WHERE id=(p_data->>'instance_id')::uuid AND tenant_id=p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Instância não encontrada' USING ERRCODE='42501'; END IF;
  SELECT * INTO a FROM agents_registry WHERE id=(p_data->>'agent_id')::uuid AND tenant_id=p_tenant_id AND NOT is_template;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agente não encontrado' USING ERRCODE='42501'; END IF;
  active:=coalesce((p_data->>'active')::boolean,false);
  IF active AND (i.status<>'connected' OR NOT a.is_active) THEN RAISE EXCEPTION 'Conecte o WhatsApp e ative o agente validado antes de ativar o canal'; END IF;
  IF active AND EXISTS(SELECT 1 FROM agents_deployments x WHERE x.tenant_id=p_tenant_id AND x.channel='whatsapp' AND x.is_active AND x.agent_id<>a.id AND (nullif(x.config->>'instance_id','') IS NULL OR x.config->>'instance_id'=i.id::text)) THEN
   RAISE EXCEPTION 'Outro agente já atende esta instância. Pause o canal anterior primeiro'; END IF;
  SELECT * INTO d FROM agents_deployments WHERE tenant_id=p_tenant_id AND agent_id=a.id AND channel='whatsapp' ORDER BY created_at LIMIT 1 FOR UPDATE;
  IF FOUND AND nullif(d.config->>'instance_id','') IS NOT NULL AND d.config->>'instance_id'<>i.id::text THEN RAISE EXCEPTION 'Agente já vinculado a outra instância; use outro agente'; END IF;
  IF d.id IS NULL THEN
   INSERT INTO agents_deployments(tenant_id,agent_id,channel,config,is_active) VALUES(p_tenant_id,a.id,'whatsapp',jsonb_build_object('instance_id',i.id,'access_mode','open','priority',100),active) RETURNING * INTO d;
  ELSE
   UPDATE agents_deployments SET config=d.config || jsonb_build_object('instance_id',i.id),is_active=active WHERE id=d.id RETURNING * INTO d;
  END IF;
  IF active THEN
   INSERT INTO tenant_config_overrides(tenant_id,key,value,updated_at) VALUES(p_tenant_id,'agent_platform_v2_enabled','{"enabled":true}',now()) ON CONFLICT(tenant_id,key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at;
  END IF;
  result:=jsonb_build_object('deployment_id',d.id,'instance_id',i.id,'agent_id',a.id,'active',d.is_active,'agent_active',a.is_active,'connection_status',i.status,'delivery_tested',false);
  INSERT INTO agents_action_log(tenant_id,agent_id,user_id,tool_name,status,input,output) VALUES(p_tenant_id,a.id,p_user_id,'mcp_bind_whatsapp','completed',p_data,result);
  RETURN result;
 END IF;
 RAISE EXCEPTION 'Ação inválida';
END $$;
REVOKE ALL ON FUNCTION public.mcp_whatsapp_admin(uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.mcp_whatsapp_admin(uuid,uuid,text,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

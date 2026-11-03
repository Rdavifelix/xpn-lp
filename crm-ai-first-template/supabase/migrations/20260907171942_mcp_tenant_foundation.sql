-- PREPARADA LOCALMENTE. Antes de aplicar: backup, vincular os usuários legítimos
-- a team_members.auth_user_id + app_metadata.tenant_id e testar em staging.
-- Não ativa cadastro público nem OAuth. Clientes começam sem acesso.
BEGIN;
CREATE SCHEMA IF NOT EXISTS crm_mcp;
REVOKE ALL ON SCHEMA crm_mcp FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA crm_mcp TO authenticated, supabase_auth_admin;

CREATE TABLE crm_mcp.clients (
  client_id text PRIMARY KEY,
  resource text NOT NULL CHECK (resource ~ '^https?://[^?#]+/mcp$'),
  can_write boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT false
);
CREATE TABLE crm_mcp.operations (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id),
  request_id uuid NOT NULL,
  user_id uuid NOT NULL,
  payload jsonb NOT NULL,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, request_id)
);
ALTER TABLE crm_mcp.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_mcp.operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA crm_mcp FROM PUBLIC, anon, authenticated;

-- Ausência de vínculo falha fechada, inclusive no modo single-tenant.
-- SECURITY DEFINER é necessário para não recursar pelas policies de team_members.
CREATE OR REPLACE FUNCTION public.get_tenant_id()
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NULL; END IF;
  BEGIN
    v_tenant := nullif(auth.jwt()->'app_metadata'->>'tenant_id', '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN RETURN NULL;
  END;
  IF v_tenant IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.team_members m JOIN public.tenants t ON t.id = m.tenant_id
    WHERE m.auth_user_id = auth.uid() AND m.tenant_id = v_tenant
      AND m.is_active IS TRUE AND t.is_active IS TRUE
  ) THEN RETURN NULL; END IF;
  RETURN v_tenant;
END;
$$;
REVOKE ALL ON FUNCTION public.get_tenant_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_tenant_id() TO anon, authenticated, service_role;

-- Hook opcional a registrar em Authentication > Hooks. Configurar clientes
-- aprovados em crm_mcp.clients antes de ativá-lo. Não aceita dados user_metadata.
CREATE FUNCTION public.mcp_access_token_hook(event jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE claims jsonb := event->'claims'; v_resource text;
BEGIN
  IF nullif(event->>'client_id', '') IS NOT NULL THEN
    SELECT resource INTO v_resource FROM crm_mcp.clients
      WHERE client_id = event->>'client_id' AND is_active;
    IF v_resource IS NOT NULL THEN
      claims := jsonb_set(claims, '{aud}', to_jsonb(v_resource));
      claims := jsonb_set(claims, '{client_id}', to_jsonb(event->>'client_id'));
    END IF;
  END IF;
  RETURN jsonb_build_object('claims', claims);
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_access_token_hook(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mcp_access_token_hook(jsonb) TO supabase_auth_admin;

CREATE FUNCTION crm_mcp.context()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid := public.get_tenant_id(); v_member record; v_client record;
BEGIN
  IF auth.uid() IS NULL OR v_tenant IS NULL THEN RAISE EXCEPTION 'Empresa não provisionada' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.sessions WHERE id::text = auth.jwt()->>'session_id' AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Sessão revogada' USING ERRCODE = '42501'; END IF;
  SELECT * INTO v_client FROM crm_mcp.clients
    WHERE client_id = auth.jwt()->>'client_id' AND is_active
      AND to_jsonb(resource) = auth.jwt()->'aud';
  IF NOT FOUND THEN RAISE EXCEPTION 'Cliente MCP não autorizado' USING ERRCODE = '42501'; END IF;
  SELECT m.id, m.role, t.name INTO STRICT v_member
    FROM public.team_members m JOIN public.tenants t ON t.id = m.tenant_id
    WHERE m.auth_user_id = auth.uid() AND m.tenant_id = v_tenant AND m.is_active AND t.is_active;
  RETURN jsonb_build_object('user_id', auth.uid(), 'tenant_id', v_tenant,
    'member_id', v_member.id, 'tenant_name', v_member.name, 'role', v_member.role,
    'can_write', v_member.role = 'admin' AND v_client.can_write);
END;
$$;
CREATE FUNCTION public.mcp_context()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT crm_mcp.context(); $$;

CREATE FUNCTION crm_mcp.list_pipelines()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE ctx jsonb := crm_mcp.context(); v_result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(pipeline ORDER BY position, id), '[]') INTO v_result FROM (
    SELECT p.position, p.id, jsonb_build_object('id', p.id, 'name', p.name, 'is_active', p.is_active,
      'stages', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name,
        'position', s.position, 'color', s.color, 'is_won', s.is_won, 'is_lost', s.is_lost) ORDER BY s.position), '[]')
        FROM public.sales_pipeline_stages s WHERE s.pipeline_id = p.id AND s.tenant_id = p.tenant_id)) AS pipeline
    FROM public.sales_pipelines p WHERE p.tenant_id = (ctx->>'tenant_id')::uuid
    ORDER BY p.position, p.id LIMIT 100
  ) bounded;
  RETURN v_result;
END;
$$;
CREATE FUNCTION public.mcp_list_pipelines()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT crm_mcp.list_pipelines(); $$;

CREATE FUNCTION crm_mcp.create_pipeline(p_request_id uuid, p_pipeline jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE ctx jsonb := crm_mcp.context(); v_tenant uuid := (ctx->>'tenant_id')::uuid;
  previous crm_mcp.operations%ROWTYPE; v_pipeline uuid; v_result jsonb; s jsonb; i integer := 0;
BEGIN
  IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Somente administrador autorizado' USING ERRCODE = '42501'; END IF;
  IF p_request_id IS NULL OR p_pipeline IS NULL OR jsonb_typeof(p_pipeline) <> 'object'
    OR coalesce(length(btrim(p_pipeline->>'name')), 0) NOT BETWEEN 2 AND 120
    OR jsonb_typeof(p_pipeline->'name') <> 'string'
    OR jsonb_typeof(p_pipeline->'stages') IS DISTINCT FROM 'array'
    OR p_pipeline - ARRAY['name', 'stages'] <> '{}'::jsonb
    THEN RAISE EXCEPTION 'Funil inválido' USING ERRCODE = '22023'; END IF;
  IF jsonb_array_length(p_pipeline->'stages') NOT BETWEEN 2 AND 30 THEN
    RAISE EXCEPTION 'Entre 2 e 30 etapas são necessárias' USING ERRCODE = '22023'; END IF;
  FOR s IN SELECT value FROM jsonb_array_elements(p_pipeline->'stages') LOOP
    IF jsonb_typeof(s) <> 'object' OR coalesce(length(btrim(s->>'name')), 0) NOT BETWEEN 1 AND 80
      OR jsonb_typeof(s->'name') <> 'string'
      OR s - ARRAY['name','color','is_won','is_lost'] <> '{}'::jsonb
      OR coalesce(s->>'color', '') !~ '^#[0-9a-fA-F]{6}$'
      OR jsonb_typeof(s->'is_won') IS DISTINCT FROM 'boolean'
      OR jsonb_typeof(s->'is_lost') IS DISTINCT FROM 'boolean'
      OR ((s->>'is_won')::boolean AND (s->>'is_lost')::boolean)
      THEN RAISE EXCEPTION 'Etapa inválida' USING ERRCODE = '22023'; END IF;
  END LOOP;
  IF (SELECT count(DISTINCT lower(btrim(value->>'name'))) FROM jsonb_array_elements(p_pipeline->'stages'))
    <> jsonb_array_length(p_pipeline->'stages') THEN RAISE EXCEPTION 'Etapas repetidas' USING ERRCODE = '22023'; END IF;
  -- Serializa operações do tenant para impedir duplicatas por retries concorrentes.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_tenant::text, 0));
  SELECT * INTO previous FROM crm_mcp.operations WHERE tenant_id = v_tenant AND request_id = p_request_id;
  IF FOUND THEN
    IF previous.payload <> p_pipeline OR previous.user_id <> auth.uid() THEN
      RAISE EXCEPTION 'request_id já usado com outro conteúdo ou usuário' USING ERRCODE = '22023'; END IF;
    RETURN previous.result;
  END IF;
  IF (SELECT count(*) FROM public.sales_pipelines WHERE tenant_id=v_tenant) >= 100 THEN
    RAISE EXCEPTION 'Limite de 100 funis por empresa atingido' USING ERRCODE='22023'; END IF;
  INSERT INTO public.sales_pipelines (tenant_id, name, is_default)
    VALUES (v_tenant, btrim(p_pipeline->>'name'), false) RETURNING id INTO v_pipeline;
  FOR s IN SELECT value FROM jsonb_array_elements(p_pipeline->'stages') LOOP
    i := i + 1;
    INSERT INTO public.sales_pipeline_stages (tenant_id, pipeline_id, name, position, color, is_won, is_lost)
    VALUES (v_tenant, v_pipeline, btrim(s->>'name'), i, s->>'color', (s->>'is_won')::boolean, (s->>'is_lost')::boolean);
  END LOOP;
  v_result := jsonb_build_object('pipeline_id', v_pipeline, 'name', btrim(p_pipeline->>'name'), 'stages_created', i);
  INSERT INTO crm_mcp.operations (tenant_id, request_id, user_id, payload, result)
    VALUES (v_tenant, p_request_id, auth.uid(), p_pipeline, v_result);
  RETURN v_result;
END;
$$;
CREATE FUNCTION public.mcp_create_pipeline(p_request_id uuid, p_pipeline jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT crm_mcp.create_pipeline(p_request_id, p_pipeline); $$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA crm_mcp FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA crm_mcp TO authenticated;
REVOKE ALL ON FUNCTION public.mcp_context(), public.mcp_list_pipelines(), public.mcp_create_pipeline(uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mcp_context(), public.mcp_list_pipelines(), public.mcp_create_pipeline(uuid,jsonb) TO authenticated;

-- Tokens OAuth não ganham acesso direto às tabelas já protegidas por RLS.
CREATE FUNCTION public.mcp_authorization_info(p_client_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid := public.get_tenant_id(); v_info jsonb;
BEGIN
  IF v_tenant IS NULL OR auth.uid() IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'Entre com uma conta vinculada ao CRM' USING ERRCODE = '42501'; END IF;
  SELECT jsonb_build_object('tenant_name', t.name, 'can_write', m.role = 'admin' AND c.can_write)
    INTO STRICT v_info FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id
    CROSS JOIN crm_mcp.clients c
    WHERE m.auth_user_id=auth.uid() AND m.tenant_id=v_tenant AND m.is_active AND t.is_active
      AND c.client_id=p_client_id AND c.is_active;
  RETURN v_info;
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_authorization_info(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mcp_authorization_info(text) TO authenticated;

-- Tokens OAuth não ganham acesso direto às tabelas já protegidas por RLS.
-- As RPCs MCP acima operam em escopo fechado. Auditoria de RPCs legadas,
-- views, Storage e tabelas SEM RLS ainda é pré-requisito de publicação.
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r','p') AND c.relrowsecurity LOOP
    EXECUTE format('CREATE POLICY mcp_deny_direct_oauth ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((auth.jwt()->>''client_id'') IS NULL) WITH CHECK ((auth.jwt()->>''client_id'') IS NULL)', r.relname);
  END LOOP;
END $$;
COMMIT;

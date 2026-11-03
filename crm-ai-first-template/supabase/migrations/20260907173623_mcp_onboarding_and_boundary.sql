BEGIN;
-- Usuários recém-criados não possuem empresa até terminar o onboarding.
-- O profile pode existir sem tenant, mas nenhuma policy por tenant o libera.
ALTER TABLE public.profiles ALTER COLUMN tenant_id DROP NOT NULL;
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.profiles(id,email,name,tenant_id)
  VALUES (NEW.id, NEW.email, coalesce(nullif(left(NEW.raw_user_meta_data->>'name',120),''),split_part(NEW.email,'@',1)),
    nullif(NEW.raw_app_meta_data->>'tenant_id','')::uuid);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.tenant_onboard(p_organization_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE u auth.users%ROWTYPE; v_tenant uuid; v_name text := btrim(p_organization_name);
BEGIN
  IF auth.uid() IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'Entre com sua conta do CRM' USING ERRCODE='42501'; END IF;
  -- Lock da conta serializa duas tentativas simultâneas, sem criar empresas órfãs.
  SELECT * INTO STRICT u FROM auth.users WHERE id=auth.uid() FOR UPDATE;
  SELECT tenant_id INTO v_tenant FROM public.team_members
    WHERE auth_user_id=u.id AND is_active IS TRUE LIMIT 1;
  IF v_tenant IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id=v_tenant AND is_active) THEN
      RAISE EXCEPTION 'Empresa inativa' USING ERRCODE='42501'; END IF;
    RETURN jsonb_build_object('tenant_id',v_tenant,'already_provisioned',true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.config WHERE key='multi_tenant_enabled' AND value='true') THEN
    RAISE EXCEPTION 'Cadastro de empresas ainda não liberado' USING ERRCODE='42501'; END IF;
  IF u.email_confirmed_at IS NULL THEN RAISE EXCEPTION 'Confirme seu e-mail antes de continuar' USING ERRCODE='42501'; END IF;
  IF v_name IS NULL OR length(v_name) NOT BETWEEN 2 AND 120 THEN
    RAISE EXCEPTION 'Informe um nome de empresa entre 2 e 120 caracteres' USING ERRCODE='22023'; END IF;
  IF nullif(u.raw_app_meta_data->>'tenant_id','') IS NOT NULL OR EXISTS (
    SELECT 1 FROM public.team_members WHERE auth_user_id=u.id OR lower(email)=lower(u.email)
  ) THEN RAISE EXCEPTION 'Conta com vínculo existente. Solicite a regularização ao administrador' USING ERRCODE='42501'; END IF;
  INSERT INTO public.tenants(name,slug,owner_user_id)
    VALUES(v_name,'empresa-'||gen_random_uuid()::text,u.id) RETURNING id INTO v_tenant;
  INSERT INTO public.team_members(tenant_id,email,name,role,team,auth_user_id,is_active)
    VALUES(v_tenant,u.email,coalesce(nullif(left(u.raw_user_meta_data->>'name',120),''),split_part(u.email,'@',1)), 'admin','admin',u.id,true);
  UPDATE auth.users SET raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||jsonb_build_object('tenant_id',v_tenant)
    WHERE id=u.id;
  INSERT INTO public.profiles(id,email,name,tenant_id)
    VALUES(u.id,u.email,coalesce(nullif(left(u.raw_user_meta_data->>'name',120),''),split_part(u.email,'@',1)),v_tenant)
    ON CONFLICT(id) DO UPDATE SET tenant_id=EXCLUDED.tenant_id;
  PERFORM public.tenant_seed_defaults(v_tenant);
  RETURN jsonb_build_object('tenant_id',v_tenant,'already_provisioned',false);
END;
$$;
REVOKE ALL ON FUNCTION public.tenant_onboard(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tenant_onboard(text) TO authenticated;

-- Apenas tokens OAuth: restringir chamadas diretas à Data API às RPCs MCP.
-- Usuário não provisionado só pode concluir cadastro ou ler a flag pública.
CREATE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

-- Não sobrescrever silenciosamente um pre-request que já exista.
DO $$ DECLARE previous text; BEGIN
  SELECT split_part(option,'=',2) INTO previous FROM pg_roles r,
    unnest(coalesce(r.rolconfig,ARRAY[]::text[])) option
    WHERE r.rolname='authenticator' AND option LIKE 'pgrst.db_pre_request=%';
  IF previous IS NOT NULL AND previous <> 'public.mcp_request_guard' THEN
    RAISE EXCEPTION 'Já existe pre-request %. Integre-o ao guard MCP antes de aplicar.',previous;
  END IF;
END $$;
ALTER ROLE authenticator SET pgrst.db_pre_request='public.mcp_request_guard';
NOTIFY pgrst, 'reload config';

DO $$ DECLARE r record; BEGIN
  IF to_regclass('public._deal_stage_audit') IS NOT NULL THEN
    ALTER TABLE public._deal_stage_audit ENABLE ROW LEVEL SECURITY;
    REVOKE ALL ON public._deal_stage_audit FROM anon,authenticated;
  END IF;
  -- Storage não executa o pre-request do PostgREST.
  FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='storage' AND c.relname IN ('objects','buckets')
      AND c.relkind IN ('r','p') AND c.relrowsecurity LOOP
    EXECUTE format('CREATE POLICY mcp_deny_oauth ON storage.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((auth.jwt()->>''client_id'') IS NULL) WITH CHECK ((auth.jwt()->>''client_id'') IS NULL)',r.relname);
  END LOOP;
END $$;
COMMIT;

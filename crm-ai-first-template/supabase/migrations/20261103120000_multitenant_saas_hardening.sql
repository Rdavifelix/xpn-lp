-- ============================================================================
-- MULTI-TENANT SAAS HARDENING — resultado da auditoria de 2026-11-03
-- ============================================================================
-- Fecha as lacunas encontradas na auditoria (docs/AUDITORIA_MULTITENANT.md)
-- e torna o modo SaaS (várias empresas no mesmo banco) o padrão do template.
--
--  1. 42 policies permissivas (USING true / auth.role()='authenticated') em
--     18 tabelas de negócio com tenant_id passam a exigir tenant_id = get_tenant_id().
--     Vazamento confirmado em laboratório: usuário da empresa B lia e alterava
--     linhas da empresa A em email_templates, sales_playbook, lead_interactions,
--     transactions, commission_rules e config_audit_log.
--  2. Módulo cs_event_* (8 tabelas filhas sem tenant_id) ganha tenant_id
--     derivado do evento/RSVP, backfill e policies por tenant.
--  3. Constraints UNIQUE globais em colunas escolhidas pelo usuário (slug,
--     label, provider, google_event_id) passam a ser únicas POR TENANT.
--  4. Storage: objetos passam a viver em pastas <tenant_id>/... e as policies
--     exigem a pasta do próprio tenant (buckets call-recordings e agent-uploads).
--  5. tenants ganha plano, status de suspensão, limites e metadados; novas
--     RPCs de plataforma (superadmin) para listar/suspender/editar empresas.
--  6. tenant_onboard v2: slug legível, tenant_config, BOOKING_PUBLIC_TOKEN
--     exclusivo e limite opcional de usuários por plano.
--  7. multi_tenant_enabled = 'true' (modo SaaS ligado por padrão).
--
-- Idempotente: pode rodar novamente sem efeitos colaterais.
-- NÃO reaplica baseline e não altera migrations históricas.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. Helpers
-- ----------------------------------------------------------------------------

-- Expressão padrão de isolamento por tenant usada em todas as policies novas.
-- Service role ignora RLS, então crons/webhooks continuam funcionando.
CREATE OR REPLACE FUNCTION public.tenant_policy_sql(p_table text)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  EXECUTE format('DROP POLICY IF EXISTS tenant_isolation_all ON public.%I', p_table);
  EXECUTE format(
    'CREATE POLICY tenant_isolation_all ON public.%I FOR ALL TO authenticated
       USING (tenant_id = public.get_tenant_id())
       WITH CHECK (tenant_id = public.get_tenant_id())', p_table);
END $$;
REVOKE ALL ON FUNCTION public.tenant_policy_sql(text) FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1. Policies permissivas → isolamento por tenant
-- ----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('asaas_customers', 'Authenticated users can insert asaas_customers'),
    ('asaas_customers', 'Authenticated users can update asaas_customers'),
    ('asaas_customers', 'Authenticated users can view asaas_customers'),
    ('asaas_webhooks', 'Authenticated users can view asaas_webhooks'),
    ('asaas_webhooks', 'Service role can insert asaas_webhooks'),
    ('asaas_webhooks', 'Service role can update asaas_webhooks'),
    ('call_history', 'Users can insert call history'),
    ('call_history', 'Users can update call history'),
    ('call_history', 'Users can view call history'),
    ('commission_rules', 'Authenticated users can delete commission_rules'),
    ('commission_rules', 'Authenticated users can insert commission_rules'),
    ('commission_rules', 'Authenticated users can update commission_rules'),
    ('commission_rules', 'Authenticated users can view commission_rules'),
    ('commissions', 'Authenticated users can insert commissions'),
    ('commissions', 'Authenticated users can update commissions'),
    ('commissions', 'Authenticated users can view commissions'),
    ('config_audit_log', 'config_audit_authenticated_read'),
    ('cs_event_rsvps', 'CS RSVPs podem ser deletados por autenticados'),
    ('cs_event_rsvps', 'CS RSVPs podem ser modificados por autenticados'),
    ('cs_event_rsvps', 'CS RSVPs são visíveis para autenticados'),
    ('cs_events', 'CS Events podem ser modificados por autenticados'),
    ('cs_events', 'CS Events são visíveis para todos'),
    ('deal_payment_installments', 'Authenticated users can insert deal_payment_installments'),
    ('deal_payment_installments', 'Authenticated users can update deal_payment_installments'),
    ('deal_payment_installments', 'Authenticated users can view deal_payment_installments'),
    ('deal_payments', 'Authenticated users can delete deal_payments'),
    ('deal_payments', 'Authenticated users can insert deal_payments'),
    ('deal_payments', 'Authenticated users can update deal_payments'),
    ('deal_payments', 'Authenticated users can view deal_payments'),
    ('dropdown_options', 'dropdown_options_all'),
    ('dropdown_options', 'dropdown_options_select'),
    ('email_automation_runs', 'email_automation_runs_authenticated_read'),
    ('email_templates', 'email_templates_authenticated_all'),
    ('lead_interactions', 'lead_interactions_all'),
    ('sales_playbook', 'sales_playbook_all'),
    ('sales_playbook', 'sales_playbook_select'),
    ('scheduled_messages', 'scheduled_messages_all'),
    ('transactions', 'transactions_all'),
    ('wavoip_devices', 'Users can manage their own devices'),
    ('wavoip_devices', 'Users can view their own devices')
  ) AS v(tbl, pol)
  LOOP
    IF to_regclass('public.' || r.tbl) IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.pol, r.tbl);
    END IF;
  END LOOP;

  -- Tabelas que ficaram sem policy de leitura/escrita para authenticated
  -- após a remoção acima recebem a policy padrão de isolamento.
  FOREACH r.tbl IN ARRAY ARRAY[
    'config_audit_log', 'dropdown_options', 'email_automation_runs',
    'lead_interactions', 'sales_playbook', 'scheduled_messages', 'transactions',
    'cs_events', 'cs_event_rsvps'
  ] LOOP
    IF to_regclass('public.' || r.tbl) IS NOT NULL THEN
      PERFORM public.tenant_policy_sql(r.tbl);
    END IF;
  END LOOP;
END $$;

-- config_audit_log: linhas antigas sem tenant pertencem ao tenant default.
UPDATE public.config_audit_log SET tenant_id = '00000000-0000-0000-0000-000000000001'
 WHERE tenant_id IS NULL;
ALTER TABLE public.config_audit_log ALTER COLUMN tenant_id SET DEFAULT public.get_tenant_id();

-- RSVP público (página /evento) continua podendo ser criado por visitantes,
-- mas o tenant é derivado do evento no servidor — nunca do cliente.
CREATE OR REPLACE FUNCTION public.cs_event_rsvp_set_tenant()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid;
BEGIN
  SELECT tenant_id INTO v_tenant FROM public.cs_events WHERE id = NEW.event_id;
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'Evento inexistente' USING ERRCODE = '42501';
  END IF;
  NEW.tenant_id := v_tenant;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cs_event_rsvp_set_tenant() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS cs_event_rsvp_set_tenant ON public.cs_event_rsvps;
CREATE TRIGGER cs_event_rsvp_set_tenant BEFORE INSERT ON public.cs_event_rsvps
  FOR EACH ROW EXECUTE FUNCTION public.cs_event_rsvp_set_tenant();

-- ----------------------------------------------------------------------------
-- 2. cs_event_* filhas: tenant_id derivado + policies por tenant
-- ----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('cs_event_connections',          'event_id', NULL,     'connections_auth_all',        'connections_select_all'),
    ('cs_event_feed_posts',           'event_id', NULL,     'feed_posts_auth_all',         'feed_posts_select_all'),
    ('cs_event_materials',            'event_id', NULL,     'materials_auth_all',          'materials_select_all'),
    ('cs_event_participant_profiles', 'event_id', NULL,     'profiles_auth_all',           'profiles_select_all'),
    ('cs_event_participant_sessions', 'event_id', NULL,     'sessions_auth_all',           'sessions_anon_select'),
    ('cs_event_schedule_items',       'event_id', NULL,     'schedule_items_auth_all',     'schedule_items_select_all'),
    ('cs_event_feed_likes',           NULL,       'rsvp_id','feed_likes_auth_all',         'feed_likes_select_all'),
    ('cs_event_schedule_bookmarks',   NULL,       'rsvp_id','schedule_bookmarks_auth_all', 'schedule_bookmarks_select_all')
  ) AS v(tbl, event_col, rsvp_col, legacy_policy, select_all_policy)
  LOOP
    CONTINUE WHEN to_regclass('public.' || r.tbl) IS NULL;
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenants(id)', r.tbl);
    IF r.event_col IS NOT NULL THEN
      EXECUTE format('UPDATE public.%I c SET tenant_id = e.tenant_id FROM public.cs_events e WHERE e.id = c.%I AND c.tenant_id IS NULL', r.tbl, r.event_col);
    ELSE
      EXECUTE format('UPDATE public.%I c SET tenant_id = v.tenant_id FROM public.cs_event_rsvps v WHERE v.id = c.%I AND c.tenant_id IS NULL', r.tbl, r.rsvp_col);
    END IF;
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_tenant ON public.%I (tenant_id)', r.tbl, r.tbl);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.legacy_policy, r.tbl);
    -- Leitura pública ("*_select_all", PUBLIC + USING true) passa a valer só para
    -- visitantes do app do participante (anon); usuários logados ficam no tenant.
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.select_all_policy, r.tbl);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO anon USING (true)', r.select_all_policy, r.tbl);
    PERFORM public.tenant_policy_sql(r.tbl);
  END LOOP;
END $$;

-- Preenche tenant_id automaticamente nas filhas (app público do participante
-- insere como anon, sem tenant no JWT).
CREATE OR REPLACE FUNCTION public.cs_event_child_set_tenant()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid; v_row jsonb := to_jsonb(NEW);
BEGIN
  IF v_row ? 'event_id' AND (v_row->>'event_id') IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant FROM public.cs_events WHERE id = (v_row->>'event_id')::uuid;
  ELSIF v_row ? 'rsvp_id' AND (v_row->>'rsvp_id') IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant FROM public.cs_event_rsvps WHERE id = (v_row->>'rsvp_id')::uuid;
  ELSIF v_row ? 'post_id' AND (v_row->>'post_id') IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant FROM public.cs_event_feed_posts WHERE id = (v_row->>'post_id')::uuid;
  END IF;
  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'Registro de evento sem empresa identificável' USING ERRCODE = '42501';
  END IF;
  NEW.tenant_id := v_tenant;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cs_event_child_set_tenant() FROM PUBLIC, anon, authenticated;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['cs_event_connections','cs_event_feed_posts','cs_event_materials',
    'cs_event_participant_profiles','cs_event_participant_sessions','cs_event_schedule_items',
    'cs_event_feed_likes','cs_event_schedule_bookmarks'] LOOP
    CONTINUE WHEN to_regclass('public.' || t) IS NULL;
    EXECUTE format('DROP TRIGGER IF EXISTS cs_event_child_set_tenant ON public.%I', t);
    EXECUTE format('CREATE TRIGGER cs_event_child_set_tenant BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.cs_event_child_set_tenant()', t);
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 3. Unicidade por tenant (colunas escolhidas pelo usuário)
--    Antes: uma empresa não conseguia criar o produto "mentoria" se outra já
--    tivesse — e descobria, pela violação, o que a outra empresa cadastrou.
-- ----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('agents_registry',        'agents_registry_slug_key',                 'slug'),
    ('chat_configs',           'chat_configs_slug_key',                    'slug'),
    ('cs_events',              'cs_events_slug_key',                       'slug'),
    ('deal_loss_reasons',      'deal_loss_reasons_label_key',              'label'),
    ('organizations',          'organizations_slug_key',                   'slug'),
    ('payment_gateways',       'payment_gateways_slug_key',                'slug'),
    ('products',               'products_slug_key',                        'slug'),
    ('social_seller_stages',   'social_seller_stages_slug_key',            'slug'),
    ('wa_community_campaigns', 'wa_community_campaigns_slug_key',          'slug'),
    ('integration_settings',   'integration_settings_provider_key',        'provider'),
    ('calendar_events',        'calendar_events_google_event_id_key',      'google_event_id'),
    ('company_activities',     'company_activities_google_event_id_unique','google_event_id')
  ) AS v(tbl, con, col)
  LOOP
    CONTINUE WHEN to_regclass('public.' || r.tbl) IS NULL;
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', r.tbl, r.con);
    EXECUTE format('DROP INDEX IF EXISTS public.%I', r.con);
    -- NULLS NOT DISTINCT: templates globais (tenant_id NULL) continuam únicos entre si.
    EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS uq_%s_tenant_%s ON public.%I (tenant_id, %I) NULLS NOT DISTINCT',
      r.tbl, r.col, r.tbl, r.col);
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 4. Storage por tenant
--    Convenção: <tenant_id>/<subpasta>/<arquivo>. Objetos antigos em
--    "recordings/..." permanecem acessíveis apenas via service_role (URLs
--    assinadas já emitidas continuam válidas).
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS call_recordings_authenticated_all ON storage.objects;
DROP POLICY IF EXISTS call_recordings_tenant_all ON storage.objects;
CREATE POLICY call_recordings_tenant_all ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'call-recordings' AND (storage.foldername(name))[1] = public.get_tenant_id()::text)
  WITH CHECK (bucket_id = 'call-recordings' AND (storage.foldername(name))[1] = public.get_tenant_id()::text);

DROP POLICY IF EXISTS agent_uploads_authenticated_write ON storage.objects;
DROP POLICY IF EXISTS agent_uploads_tenant_write ON storage.objects;
CREATE POLICY agent_uploads_tenant_write ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'agent-uploads' AND (storage.foldername(name))[1] = public.get_tenant_id()::text)
  WITH CHECK (bucket_id = 'agent-uploads' AND (storage.foldername(name))[1] = public.get_tenant_id()::text);
-- agent_uploads_public_read permanece: bucket público por desenho (URLs servidas ao WhatsApp).

-- ----------------------------------------------------------------------------
-- 5. tenants: plano, suspensão, limites
-- ----------------------------------------------------------------------------
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS plan text NOT NULL DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS max_users integer,
  ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz,
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz,
  ADD COLUMN IF NOT EXISTS suspended_reason text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS uq_tenants_slug ON public.tenants (slug);

-- Leitura do próprio tenant já é garantida por tenant_directory_scope (restritiva).
-- Dono/admin pode editar nome e metadados do próprio tenant; plano/suspensão só via plataforma.
CREATE OR REPLACE FUNCTION public.tenants_protect_platform_columns()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.is_active IS DISTINCT FROM OLD.is_active
       OR NEW.plan IS DISTINCT FROM OLD.plan OR NEW.max_users IS DISTINCT FROM OLD.max_users
       OR NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at
       OR NEW.suspended_at IS DISTINCT FROM OLD.suspended_at
       OR NEW.suspended_reason IS DISTINCT FROM OLD.suspended_reason
       OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
       OR NEW.slug IS DISTINCT FROM OLD.slug THEN
      RAISE EXCEPTION 'Campos de plataforma só podem ser alterados pelo superadmin' USING ERRCODE = '42501';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.tenants_protect_platform_columns() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS tenants_protect_platform_columns ON public.tenants;
CREATE TRIGGER tenants_protect_platform_columns BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.tenants_protect_platform_columns();

DROP POLICY IF EXISTS tenant_admin_update_own ON public.tenants;
CREATE POLICY tenant_admin_update_own ON public.tenants
  FOR UPDATE TO authenticated
  USING (id = public.get_tenant_id() AND public.is_admin())
  WITH CHECK (id = public.get_tenant_id() AND public.is_admin());

-- ----------------------------------------------------------------------------
-- 6. Plataforma (superadmin do SaaS)
--    saas_ai.is_superadmin(): team_member ativo com is_superadmin no tenant atual.
--    O instalador marca o primeiro administrador como superadmin.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_assert_superadmin()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT saas_ai.is_superadmin() THEN
    RAISE EXCEPTION 'Somente superadmin da plataforma' USING ERRCODE = '42501';
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.platform_assert_superadmin() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.platform_list_tenants(p_search text DEFAULT NULL, p_limit integer DEFAULT 200)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE result jsonb;
BEGIN
  PERFORM public.platform_assert_superadmin();
  SELECT coalesce(jsonb_agg(row_to_json(x) ORDER BY x.created_at DESC), '[]'::jsonb) INTO result
  FROM (
    SELECT t.id, t.name, t.slug, t.is_active, t.plan, t.max_users, t.trial_ends_at,
           t.suspended_at, t.suspended_reason, t.created_at, t.owner_user_id,
           (SELECT email FROM public.team_members m WHERE m.tenant_id = t.id AND m.role = 'admin' AND m.is_active ORDER BY m.created_at LIMIT 1) AS admin_email,
           (SELECT count(*) FROM public.team_members m WHERE m.tenant_id = t.id AND m.is_active) AS active_users,
           (SELECT count(*) FROM public.leads l WHERE l.tenant_id = t.id) AS leads_count,
           (SELECT count(*) FROM public.deals d WHERE d.tenant_id = t.id) AS deals_count,
           (SELECT max(created_at) FROM public.whatsapp_messages w WHERE w.tenant_id = t.id) AS last_message_at
    FROM public.tenants t
    WHERE p_search IS NULL OR t.name ILIKE '%' || p_search || '%' OR t.slug ILIKE '%' || p_search || '%'
    LIMIT greatest(1, least(coalesce(p_limit, 200), 1000))
  ) x;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.platform_list_tenants(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_list_tenants(text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.platform_update_tenant(p_tenant_id uuid, p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE t public.tenants%ROWTYPE; v_active boolean;
BEGIN
  PERFORM public.platform_assert_superadmin();
  IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'Dados inválidos' USING ERRCODE = '22023';
  END IF;
  IF p_data - ARRAY['name','plan','max_users','trial_ends_at','is_active','suspended_reason','metadata'] <> '{}'::jsonb THEN
    RAISE EXCEPTION 'Campo não permitido' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO t FROM public.tenants WHERE id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Empresa não encontrada' USING ERRCODE = '22023'; END IF;
  IF p_tenant_id = public.get_tenant_id() AND p_data ? 'is_active' AND (p_data->>'is_active')::boolean IS FALSE THEN
    RAISE EXCEPTION 'Não é possível suspender a própria empresa da plataforma' USING ERRCODE = '42501';
  END IF;
  v_active := coalesce((p_data->>'is_active')::boolean, t.is_active);
  UPDATE public.tenants SET
    name = coalesce(nullif(btrim(p_data->>'name'), ''), name),
    plan = coalesce(nullif(p_data->>'plan', ''), plan),
    max_users = CASE WHEN p_data ? 'max_users' THEN nullif(p_data->>'max_users','')::integer ELSE max_users END,
    trial_ends_at = CASE WHEN p_data ? 'trial_ends_at' THEN nullif(p_data->>'trial_ends_at','')::timestamptz ELSE trial_ends_at END,
    metadata = CASE WHEN p_data ? 'metadata' AND jsonb_typeof(p_data->'metadata') = 'object' THEN p_data->'metadata' ELSE metadata END,
    is_active = v_active,
    suspended_at = CASE WHEN v_active THEN NULL WHEN suspended_at IS NULL THEN now() ELSE suspended_at END,
    suspended_reason = CASE WHEN v_active THEN NULL ELSE coalesce(nullif(p_data->>'suspended_reason',''), suspended_reason) END,
    updated_at = now()
  WHERE id = p_tenant_id
  RETURNING * INTO t;
  RETURN to_jsonb(t);
END $$;
REVOKE ALL ON FUNCTION public.platform_update_tenant(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_update_tenant(uuid, jsonb) TO authenticated;

-- Resumo para o painel da plataforma.
CREATE OR REPLACE FUNCTION public.platform_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM public.platform_assert_superadmin();
  RETURN jsonb_build_object(
    'tenants_total', (SELECT count(*) FROM public.tenants),
    'tenants_active', (SELECT count(*) FROM public.tenants WHERE is_active),
    'tenants_suspended', (SELECT count(*) FROM public.tenants WHERE NOT is_active),
    'users_active', (SELECT count(*) FROM public.team_members WHERE is_active),
    'leads_total', (SELECT count(*) FROM public.leads),
    'multi_tenant_enabled', (SELECT value = 'true' FROM public.config WHERE key = 'multi_tenant_enabled'),
    'is_superadmin', true
  );
END $$;
REVOKE ALL ON FUNCTION public.platform_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_overview() TO authenticated;

-- Liga/desliga o cadastro self-service sem precisar de SQL.
CREATE OR REPLACE FUNCTION public.platform_set_multi_tenant(p_enabled boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM public.platform_assert_superadmin();
  INSERT INTO public.config (key, value) VALUES ('multi_tenant_enabled', CASE WHEN p_enabled THEN 'true' ELSE 'false' END)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
  RETURN jsonb_build_object('multi_tenant_enabled', p_enabled);
END $$;
REVOKE ALL ON FUNCTION public.platform_set_multi_tenant(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_set_multi_tenant(boolean) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. tenant_onboard v2
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tenant_slugify(p_name text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT nullif(btrim(regexp_replace(lower(extensions.unaccent(coalesce(p_name,''))), '[^a-z0-9]+', '-', 'g'), '-'), '')
$$;

CREATE OR REPLACE FUNCTION public.tenant_onboard(p_organization_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE u auth.users%ROWTYPE; v_tenant uuid; v_name text := btrim(p_organization_name);
        v_slug text; v_base text; v_i int := 0; v_display text;
BEGIN
  IF auth.uid() IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'Entre com sua conta do CRM' USING ERRCODE='42501'; END IF;
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

  -- slug legível e único (empresa, empresa-2, ...)
  v_base := coalesce(public.tenant_slugify(v_name), 'empresa');
  v_slug := left(v_base, 60);
  WHILE EXISTS (SELECT 1 FROM public.tenants WHERE slug = v_slug) LOOP
    v_i := v_i + 1; v_slug := left(v_base, 56) || '-' || v_i;
  END LOOP;
  v_display := coalesce(nullif(left(u.raw_user_meta_data->>'name',120),''), split_part(u.email,'@',1));

  INSERT INTO public.tenants(name,slug,owner_user_id,plan,trial_ends_at)
    VALUES(v_name,v_slug,u.id,'trial',now() + interval '14 days') RETURNING id INTO v_tenant;
  INSERT INTO public.team_members(tenant_id,email,name,role,team,auth_user_id,is_active)
    VALUES(v_tenant,u.email,v_display,'admin','admin',u.id,true);
  UPDATE auth.users SET raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||jsonb_build_object('tenant_id',v_tenant)
    WHERE id=u.id;
  INSERT INTO public.profiles(id,email,name,tenant_id)
    VALUES(u.id,u.email,v_display,v_tenant)
    ON CONFLICT(id) DO UPDATE SET tenant_id=EXCLUDED.tenant_id;
  -- Identidade visual/remetente por empresa (tabela já existente no baseline).
  INSERT INTO public.tenant_config(tenant_id, company_name)
    VALUES (v_tenant, v_name) ON CONFLICT DO NOTHING;
  -- Token público do agendamento exclusivo desta empresa (antes era da instalação).
  INSERT INTO public.tenant_config_overrides(tenant_id,key,value)
    VALUES (v_tenant,'BOOKING_PUBLIC_TOKEN', encode(extensions.gen_random_bytes(24),'hex')),
           (v_tenant,'COMPANY_NAME', v_name)
    ON CONFLICT (tenant_id,key) DO NOTHING;
  PERFORM public.tenant_seed_defaults(v_tenant);
  RETURN jsonb_build_object('tenant_id',v_tenant,'slug',v_slug,'already_provisioned',false);
END;
$$;
REVOKE ALL ON FUNCTION public.tenant_onboard(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tenant_onboard(text) TO authenticated;

-- Limite de usuários por plano: aplicado no INSERT de team_members ativos.
CREATE OR REPLACE FUNCTION public.team_members_enforce_plan_limit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_max integer; v_count integer;
BEGIN
  IF NEW.is_active IS NOT TRUE THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.is_active IS TRUE THEN RETURN NEW; END IF;
  SELECT max_users INTO v_max FROM public.tenants WHERE id = NEW.tenant_id;
  IF v_max IS NULL THEN RETURN NEW; END IF;
  SELECT count(*) INTO v_count FROM public.team_members WHERE tenant_id = NEW.tenant_id AND is_active AND id IS DISTINCT FROM NEW.id;
  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Limite de % usuários do plano atingido', v_max USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.team_members_enforce_plan_limit() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS team_members_enforce_plan_limit ON public.team_members;
CREATE TRIGGER team_members_enforce_plan_limit BEFORE INSERT OR UPDATE OF is_active ON public.team_members
  FOR EACH ROW EXECUTE FUNCTION public.team_members_enforce_plan_limit();

-- Tenant default herda o nome informado no setup e ganha token de agendamento
-- em override caso ainda não tenha (instalações antigas).
INSERT INTO public.tenant_config(tenant_id, company_name)
  SELECT id, name FROM public.tenants WHERE id = '00000000-0000-0000-0000-000000000001'
  ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 7b. Superadmin legado sem escopo de tenant + catálogos globais
-- ----------------------------------------------------------------------------
-- public.is_superadmin() do baseline não filtrava tenant: um superadmin de
-- qualquer empresa escrevia em tenant_config/onboarding_stages de todas.
CREATE OR REPLACE FUNCTION public.is_superadmin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL
     AND nullif(auth.jwt()->>'client_id','') IS NULL
     AND EXISTS (
       SELECT 1 FROM public.team_members m
       WHERE m.auth_user_id = auth.uid() AND m.is_active AND m.is_superadmin
         AND m.tenant_id = public.get_tenant_id()
     );
$$;

-- tenant_config: identidade visual/remetente da PRÓPRIA empresa (admin do tenant).
DROP POLICY IF EXISTS tenant_config_insert ON public.tenant_config;
DROP POLICY IF EXISTS tenant_config_update ON public.tenant_config;
DROP POLICY IF EXISTS tenant_config_select ON public.tenant_config;
CREATE POLICY tenant_config_select ON public.tenant_config FOR SELECT TO authenticated
  USING (tenant_id = public.get_tenant_id());
CREATE POLICY tenant_config_insert ON public.tenant_config FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.get_tenant_id() AND public.is_admin());
CREATE POLICY tenant_config_update ON public.tenant_config FOR UPDATE TO authenticated
  USING (tenant_id = public.get_tenant_id() AND public.is_admin())
  WITH CHECK (tenant_id = public.get_tenant_id() AND public.is_admin());

DROP POLICY IF EXISTS onboarding_stages_admin ON public.onboarding_stages;
DROP POLICY IF EXISTS onboarding_stages_select ON public.onboarding_stages;
CREATE POLICY onboarding_stages_select ON public.onboarding_stages FOR SELECT TO authenticated
  USING (tenant_id = public.get_tenant_id());
CREATE POLICY onboarding_stages_admin ON public.onboarding_stages FOR ALL TO authenticated
  USING (tenant_id = public.get_tenant_id() AND public.is_admin())
  WITH CHECK (tenant_id = public.get_tenant_id() AND public.is_admin());

-- Empresas só nascem por tenant_onboard (SECURITY DEFINER) ou service_role.
DROP POLICY IF EXISTS tenants_insert_superadmin ON public.tenants;
-- tenants_select_superadmin (USING true) é neutralizada pela restritiva
-- tenant_directory_scope; removida para não confundir auditorias futuras.
DROP POLICY IF EXISTS tenants_select_superadmin ON public.tenants;

-- tenant_sales_config: usar o helper padrão em vez de subselect em team_members.
DROP POLICY IF EXISTS tenant_sales_config_select ON public.tenant_sales_config;
DROP POLICY IF EXISTS tenant_sales_config_insert ON public.tenant_sales_config;
DROP POLICY IF EXISTS tenant_sales_config_update ON public.tenant_sales_config;
CREATE POLICY tenant_sales_config_select ON public.tenant_sales_config FOR SELECT TO authenticated
  USING (tenant_id = public.get_tenant_id());
CREATE POLICY tenant_sales_config_insert ON public.tenant_sales_config FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.get_tenant_id() AND public.is_admin());
CREATE POLICY tenant_sales_config_update ON public.tenant_sales_config FOR UPDATE TO authenticated
  USING (tenant_id = public.get_tenant_id() AND public.is_admin())
  WITH CHECK (tenant_id = public.get_tenant_id() AND public.is_admin());

-- Catálogos compartilhados por TODAS as empresas: escrita só pelo superadmin
-- da plataforma (antes qualquer admin de qualquer empresa editava).
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('agents_skill_catalog',         'ap_admin_write'),
    ('agents_integration_providers', 'ap_admin_write'),
    ('prospeccao_templates_nicho',   'ptn_admin_write'),
    ('prospeccao_prompts_config',    'ppc_admin_write')
  ) AS v(tbl, pol) LOOP
    CONTINUE WHEN to_regclass('public.' || r.tbl) IS NULL;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.pol, r.tbl);
    EXECUTE format('DROP POLICY IF EXISTS platform_superadmin_write ON public.%I', r.tbl);
    EXECUTE format('CREATE POLICY platform_superadmin_write ON public.%I FOR ALL TO authenticated USING (public.is_superadmin()) WITH CHECK (public.is_superadmin())', r.tbl);
  END LOOP;
END $$;

-- Histórico de config guarda segredos antigos/novos: só admin da própria empresa.
DROP POLICY IF EXISTS tenant_isolation_all ON public.config_audit_log;
DROP POLICY IF EXISTS config_audit_tenant_admin_read ON public.config_audit_log;
CREATE POLICY config_audit_tenant_admin_read ON public.config_audit_log FOR SELECT TO authenticated
  USING (tenant_id = public.get_tenant_id() AND public.is_admin());

-- Realtime: módulo de eventos (morto) não precisa transmitir para anon.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['cs_event_connections','cs_event_feed_posts','cs_event_schedule_items'] LOOP
    IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 8. Modo SaaS ligado por padrão
-- ----------------------------------------------------------------------------
INSERT INTO public.config (key, value) VALUES ('multi_tenant_enabled', 'true')
ON CONFLICT (key) DO UPDATE SET value = 'true';

-- ----------------------------------------------------------------------------
-- 9. Verificação final: nenhuma policy permissiva sem guarda de tenant pode
--    restar em tabela com tenant_id (falha a migration se restar).
-- ----------------------------------------------------------------------------
DO $$
DECLARE v_count integer; v_list text;
BEGIN
  SELECT count(*), string_agg(c.relname || '.' || p.polname, ', ')
    INTO v_count, v_list
  FROM pg_policy p
  JOIN pg_class c ON c.oid = p.polrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND p.polpermissive
    AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped)
    AND 'authenticated' IN (SELECT rolname FROM pg_roles WHERE oid = ANY(p.polroles) UNION SELECT 'authenticated' WHERE p.polroles = '{0}')
    AND coalesce(pg_get_expr(p.polqual, p.polrelid), '') !~ 'tenant_id|get_tenant_id|is_admin\(\)|is_superadmin|is_tenant_admin|is_marketing_manager|crm_mcp|saas_ai'
    AND coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') !~ 'tenant_id|get_tenant_id|is_admin\(\)|is_superadmin|is_tenant_admin|is_marketing_manager|crm_mcp|saas_ai'
    -- exceções deliberadas: RSVP público de evento (tenant derivado por trigger)
    AND NOT (c.relname = 'cs_event_rsvps' AND p.polcmd = 'a');
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Policies permissivas sem isolamento de tenant: %', v_list;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;

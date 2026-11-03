-- ============================================================================
-- ONDA B2 — CONFIG MULTI-TENANT (retrocompatível)
-- ============================================================================
-- DECISÃO DE DESIGN (validada no banco de teste em 2026-07-09):
--   O frontend salva config via PostgREST upsert `onConflict: "key"`, que gera
--   `INSERT ... ON CONFLICT (key)`. Isso EXIGE constraint/índice único
--   NÃO-parcial em (key). Testado no banco de teste: com apenas índices únicos
--   parciais (`WHERE tenant_id IS NULL` / `WHERE tenant_id IS NOT NULL`), o
--   comando falha com `42P10: there is no unique or exclusion constraint
--   matching the ON CONFLICT specification`.
--   → Abordagem escolhida: a tabela `config` fica INTACTA (PK em `key`,
--     linhas = valores GLOBAIS/default da instalação) e os valores por tenant
--     vivem numa tabela nova `tenant_config_overrides(tenant_id, key)`.
--   Single-tenant continua idêntico: UI escreve na `config` global como sempre.
--   Multi-tenant: helper `getIntegrationKey(supabase, key, tenantId)` busca o
--   override do tenant primeiro e cai na linha global como fallback.
--
-- Também nesta migration:
--   - Defaults legacy `current_setting('app.settings.tenant_id')` → get_tenant_id()
--   - is_admin() passa a ser escopado por tenant
--   - Escrita na `config` global restrita ao admin do tenant default (0001) —
--     tenants adicionais usam overrides; linha global só muda via service_role
--     ou pelo tenant default (que é o caso das instalações single-tenant).
--
-- Idempotente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tabela de overrides por tenant
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_config_overrides (
    tenant_id  uuid NOT NULL,
    key        text NOT NULL,
    value      text,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT tenant_config_overrides_pkey PRIMARY KEY (tenant_id, key)
);

ALTER TABLE public.tenant_config_overrides ENABLE ROW LEVEL SECURITY;

-- Leitura: mesmo modelo da `config` (admin tudo; demais roles só allowlist
-- pública), sempre restrito ao PRÓPRIO tenant.
DROP POLICY IF EXISTS tco_read_public_or_admin ON public.tenant_config_overrides;
CREATE POLICY tco_read_public_or_admin ON public.tenant_config_overrides
  FOR SELECT TO authenticated
  USING (
    tenant_id = get_tenant_id()
    AND (
      is_admin()
      OR key IN (
        'enabled_modules',
        'PIPELINE_ROLES',
        'COMPANY_NAME',
        'COMPANY_DOMAIN',
        'CERTIFICATE_SIGNATURE_NAME',
        'INTERNAL_AGENT_TEAM_MEMBER_ID',
        'DEFAULT_MEETING_OWNER_ID',
        'agent_platform_v2_enabled',
        'SUPABASE_PROJECT_URL',
        'UAZAPI_ADMIN_URL'
      )
      OR key LIKE 'social_selling_%'
      OR key LIKE 'prospeccao_%'
    )
  );

-- Escrita: só admin, só no próprio tenant.
DROP POLICY IF EXISTS tco_insert_admin ON public.tenant_config_overrides;
CREATE POLICY tco_insert_admin ON public.tenant_config_overrides
  FOR INSERT TO authenticated
  WITH CHECK (is_admin() AND tenant_id = get_tenant_id());

DROP POLICY IF EXISTS tco_update_admin ON public.tenant_config_overrides;
CREATE POLICY tco_update_admin ON public.tenant_config_overrides
  FOR UPDATE TO authenticated
  USING (is_admin() AND tenant_id = get_tenant_id())
  WITH CHECK (is_admin() AND tenant_id = get_tenant_id());

DROP POLICY IF EXISTS tco_delete_admin ON public.tenant_config_overrides;
CREATE POLICY tco_delete_admin ON public.tenant_config_overrides
  FOR DELETE TO authenticated
  USING (is_admin() AND tenant_id = get_tenant_id());

-- ----------------------------------------------------------------------------
-- 2. is_admin() escopado por tenant
--    (team_members.tenant_id existe e é NOT NULL desde a Onda B1; em
--     single-tenant get_tenant_id() = 0001 = backfill → comportamento idêntico)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE auth_user_id = auth.uid()
      AND role = 'admin'
      AND is_active
      AND tenant_id = get_tenant_id()
  );
$$;

-- ----------------------------------------------------------------------------
-- 3. Escrita na config GLOBAL: só admin do tenant default (0001).
--    Instalações single-tenant resolvem get_tenant_id() = 0001 → UI de
--    Integrações continua funcionando sem mudança. Tenants adicionais NÃO
--    podem alterar a config global (usam tenant_config_overrides).
--    Leitura (config_read_public_or_admin) fica como está: a linha global é o
--    fallback compartilhado da instalação.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS config_insert_admin ON public.config;
CREATE POLICY config_insert_admin ON public.config
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    AND get_tenant_id() = '00000000-0000-0000-0000-000000000001'::uuid
  );

DROP POLICY IF EXISTS config_update_admin ON public.config;
CREATE POLICY config_update_admin ON public.config
  FOR UPDATE TO authenticated
  USING (
    is_admin()
    AND get_tenant_id() = '00000000-0000-0000-0000-000000000001'::uuid
  )
  WITH CHECK (
    is_admin()
    AND get_tenant_id() = '00000000-0000-0000-0000-000000000001'::uuid
  );

DROP POLICY IF EXISTS config_delete_admin ON public.config;
CREATE POLICY config_delete_admin ON public.config
  FOR DELETE TO authenticated
  USING (
    is_admin()
    AND get_tenant_id() = '00000000-0000-0000-0000-000000000001'::uuid
  );

-- ----------------------------------------------------------------------------
-- 4. GUC legacy: defaults `current_setting('app.settings.tenant_id')` →
--    get_tenant_id() (o GUC nunca é setado em produção; get_tenant_id() lê o
--    JWT e cai em 0001 — mesmo modelo de todas as outras tabelas)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  t text;
  guc_tables text[] := ARRAY[
    'ai_agent_cadence_enrollments',
    'ai_agent_scheduled_followups',
    'ai_agent_send_counts'
  ];
BEGIN
  FOREACH t IN ARRAY guc_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format(
        'ALTER TABLE public.%I ALTER COLUMN tenant_id SET DEFAULT get_tenant_id()',
        t
      );
    END IF;
  END LOOP;
END $$;

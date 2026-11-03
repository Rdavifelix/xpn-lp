-- ============================================================
-- Segurança: secrets da tabela `config` deixam de ser legíveis
-- por qualquer usuário autenticado.
--  - Leitura: admins tudo; demais roles só keys públicas (allowlist)
--  - Escrita: só admins
--  - Edge functions (service_role) não são afetadas
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE auth_user_id = auth.uid() AND role = 'admin' AND is_active
  );
$$;

DROP POLICY IF EXISTS config_all_authenticated ON config;
DROP POLICY IF EXISTS config_read_public_or_admin ON config;
DROP POLICY IF EXISTS config_insert_admin ON config;
DROP POLICY IF EXISTS config_update_admin ON config;
DROP POLICY IF EXISTS config_delete_admin ON config;

DROP POLICY IF EXISTS config_read_public_or_admin ON config;

CREATE POLICY config_read_public_or_admin ON config FOR SELECT TO authenticated
USING (
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
);

DROP POLICY IF EXISTS config_insert_admin ON config;

CREATE POLICY config_insert_admin ON config FOR INSERT TO authenticated
WITH CHECK (is_admin());

DROP POLICY IF EXISTS config_update_admin ON config;

CREATE POLICY config_update_admin ON config FOR UPDATE TO authenticated
USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS config_delete_admin ON config;

CREATE POLICY config_delete_admin ON config FOR DELETE TO authenticated
USING (is_admin());

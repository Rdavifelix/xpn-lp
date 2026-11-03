-- ============================================================
-- Segurança: credenciais de provider dos agentes (tokens
-- Anthropic/Codex/UAZAPI) deixam de ser legíveis/editáveis por
-- qualquer usuário autenticado.
--  - Leitura/escrita: admin OU dono da credencial
--  - Edge functions (service_role) não são afetadas
-- Depende de: is_admin() (criada em 20260708000001_config_secrets_admin_only)
-- Nota: a tabela agents_provider_credentials pertence ao
-- agents-platform-pack (instalado à parte). Em instalação nova,
-- se o pack ainda não foi aplicado, esta migration é no-op.
-- ============================================================
DO $$
BEGIN
  IF to_regclass('public.agents_provider_credentials') IS NULL THEN
    RETURN;
  END IF;

  EXECUTE 'DROP POLICY IF EXISTS ap_authenticated_read ON agents_provider_credentials';
  EXECUTE 'DROP POLICY IF EXISTS ap_authenticated_write ON agents_provider_credentials';
  EXECUTE 'DROP POLICY IF EXISTS apc_read_admin_or_owner ON agents_provider_credentials';
  EXECUTE 'DROP POLICY IF EXISTS apc_write_admin_or_owner ON agents_provider_credentials';

  EXECUTE 'CREATE POLICY apc_read_admin_or_owner ON agents_provider_credentials FOR SELECT TO authenticated
    USING (is_admin() OR owner_user_id = auth.uid())';

  EXECUTE 'CREATE POLICY apc_write_admin_or_owner ON agents_provider_credentials FOR ALL TO authenticated
    USING (is_admin() OR owner_user_id = auth.uid())
    WITH CHECK (is_admin() OR owner_user_id = auth.uid())';
END $$;

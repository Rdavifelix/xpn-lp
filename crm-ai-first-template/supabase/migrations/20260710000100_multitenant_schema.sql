-- ============================================================================
-- ONDA B1 — MULTI-TENANT SCHEMA (retrocompatível)
-- ============================================================================
-- Objetivo: todas as tabelas de negócio ganham tenant_id + RLS por tenant.
-- Retrocompatibilidade: dados existentes viram tenant DEFAULT
--   '00000000-0000-0000-0000-000000000001' (mesmo fallback de get_tenant_id(),
--   que retorna 0001 quando o JWT não tem app_metadata.tenant_id) —
--   instalação single-tenant continua funcionando sem nenhuma mudança.
--
-- Classificação:
--   TENANT-SCOPED  → ganha tenant_id DEFAULT get_tenant_id() + backfill 0001
--                    + policies trocadas de `true` p/ `tenant_id = get_tenant_id()`
--   CATÁLOGO GLOBAL→ sem tenant_id; leitura authenticated; escrita só is_admin()
--                    (agents_skill_catalog, agents_integration_providers,
--                     prospeccao_templates_nicho, prospeccao_prompts_config)
--   SISTEMA        → não mexe (tenants, config [Onda B2], cs_event_* [módulo morto])
--
-- Decisão TEMPLATES DE AGENTE: agents_registry com is_template=true (e suas
--   agents_tools) ficam com tenant_id = NULL e são visíveis (SELECT) para
--   TODOS os tenants. Escrita continua restrita ao próprio tenant — templates
--   só são alterados via service_role (migrations/seeds).
--
-- Idempotente: ADD COLUMN IF NOT EXISTS / DROP POLICY IF EXISTS / DO blocks.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SEÇÃO 0 — Helper: adiciona tenant_id + backfill + índice
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  t text;
  tenant_tables text[] := ARRAY[
    -- Plataforma de agentes
    'agents_registry', 'agents_tools', 'agents_deployments', 'agents_sessions',
    'agents_messages', 'agents_logs', 'agents_action_log', 'agents_core_memory',
    'agents_versions', 'agents_provider_credentials',
    'agent_jobs', 'agent_notes', 'agent_note_versions', 'agent_reminders',
    'agent_routing_log', 'ai_agent_chat_events',
    -- Prospecção (dados de negócio)
    'prospeccao_buscas', 'prospeccao_leads_descobertos', 'prospeccao_diagnosticos',
    'prospeccao_uso_api',
    -- WhatsApp communities / sequences
    'wa_communities', 'wa_community_groups', 'wa_community_campaigns',
    'wa_community_campaign_items', 'wa_message_sequences', 'wa_sequence_steps',
    'wa_sequence_enrollments', 'wa_scheduled_messages',
    -- Outros módulos de negócio
    'noshow_followups', 'twilio_call_logs', 'nps_survey_schedule'
  ];
BEGIN
  FOREACH t IN ARRAY tenant_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS tenant_id uuid DEFAULT get_tenant_id()',
        t
      );
      EXECUTE format(
        'CREATE INDEX IF NOT EXISTS idx_%s_tenant ON public.%I (tenant_id)',
        t, t
      );
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- SEÇÃO 1 — Backfill: dados existentes pertencem ao tenant default (0001)
-- Exceção: templates de agente (is_template=true) e suas tools → tenant NULL
--          (visíveis para todos os tenants — ver decisão no cabeçalho)
-- ----------------------------------------------------------------------------
UPDATE public.agents_registry
   SET tenant_id = '00000000-0000-0000-0000-000000000001'
 WHERE tenant_id IS NULL AND is_template IS NOT TRUE;

UPDATE public.agents_registry
   SET tenant_id = NULL
 WHERE is_template IS TRUE AND tenant_id IS NOT NULL;

UPDATE public.agents_tools at
   SET tenant_id = '00000000-0000-0000-0000-000000000001'
 WHERE at.tenant_id IS NULL
   AND NOT EXISTS (
     SELECT 1 FROM public.agents_registry r
     WHERE r.id = at.agent_id AND r.is_template IS TRUE
   );

UPDATE public.agents_tools at
   SET tenant_id = NULL
 WHERE at.tenant_id IS NOT NULL
   AND EXISTS (
     SELECT 1 FROM public.agents_registry r
     WHERE r.id = at.agent_id AND r.is_template IS TRUE
   );

DO $$
DECLARE
  t text;
  backfill_tables text[] := ARRAY[
    'agents_deployments', 'agents_sessions', 'agents_messages', 'agents_logs',
    'agents_action_log', 'agents_core_memory', 'agents_versions',
    'agents_provider_credentials',
    'agent_jobs', 'agent_notes', 'agent_note_versions', 'agent_reminders',
    'agent_routing_log', 'ai_agent_chat_events',
    'prospeccao_buscas', 'prospeccao_leads_descobertos', 'prospeccao_diagnosticos',
    'prospeccao_uso_api',
    'wa_communities', 'wa_community_groups', 'wa_community_campaigns',
    'wa_community_campaign_items', 'wa_message_sequences', 'wa_sequence_steps',
    'wa_sequence_enrollments', 'wa_scheduled_messages',
    'noshow_followups', 'twilio_call_logs', 'nps_survey_schedule'
  ];
BEGIN
  FOREACH t IN ARRAY backfill_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format(
        'UPDATE public.%I SET tenant_id = ''00000000-0000-0000-0000-000000000001'' WHERE tenant_id IS NULL',
        t
      );
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- SEÇÃO 2 — Defaults fixos ('...0001'::uuid) → get_tenant_id()
-- (tabelas que já tinham tenant_id, mas com default hardcoded)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  t text;
  fixed_default_tables text[] := ARRAY[
    'dropdown_options', 'franchise_campaigns', 'franchise_distribution_log',
    'franchise_members', 'lead_interactions', 'marketing_forms',
    'sales_playbook', 'scheduled_messages', 'social_selling_known_followers',
    'transactions'
  ];
BEGIN
  FOREACH t IN ARRAY fixed_default_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format(
        'ALTER TABLE public.%I ALTER COLUMN tenant_id SET DEFAULT get_tenant_id()',
        t
      );
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- SEÇÃO 3 — Policies: plataforma de agentes
-- ----------------------------------------------------------------------------

-- agents_registry: SELECT vê templates globais + agentes do tenant;
--                  escrita só no próprio tenant (templates = só service_role)
DROP POLICY IF EXISTS ap_authenticated_read ON public.agents_registry;
CREATE POLICY ap_authenticated_read ON public.agents_registry
  FOR SELECT TO authenticated
  USING (is_template IS TRUE OR tenant_id = get_tenant_id());
DROP POLICY IF EXISTS ap_authenticated_write ON public.agents_registry;
CREATE POLICY ap_authenticated_write ON public.agents_registry
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

-- agents_tools: SELECT vê tools do tenant + tools de agentes template
DROP POLICY IF EXISTS ap_authenticated_read ON public.agents_tools;
CREATE POLICY ap_authenticated_read ON public.agents_tools
  FOR SELECT TO authenticated
  USING (
    tenant_id = get_tenant_id()
    OR EXISTS (
      SELECT 1 FROM public.agents_registry r
      WHERE r.id = agents_tools.agent_id AND r.is_template IS TRUE
    )
  );
DROP POLICY IF EXISTS ap_authenticated_write ON public.agents_tools;
CREATE POLICY ap_authenticated_write ON public.agents_tools
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

-- Demais tabelas de agentes: read tenant-scoped; write tenant-scoped onde existia
DO $$
DECLARE
  t text;
  -- tabelas que hoje têm ap_authenticated_read (SELECT true)
  read_tables text[] := ARRAY[
    'agents_deployments', 'agents_sessions', 'agents_messages', 'agents_logs',
    'agents_action_log', 'agents_core_memory', 'agents_versions',
    'agent_jobs', 'agent_notes', 'agent_note_versions', 'agent_reminders',
    'agent_routing_log'
  ];
  -- subconjunto que hoje também tem ap_authenticated_write (ALL true)
  write_tables text[] := ARRAY[
    'agents_deployments', 'agents_core_memory', 'agents_versions',
    'agent_notes', 'agent_reminders'
  ];
BEGIN
  FOREACH t IN ARRAY read_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS ap_authenticated_read ON public.%I', t);
      EXECUTE format(
        'CREATE POLICY ap_authenticated_read ON public.%I FOR SELECT TO authenticated USING (tenant_id = get_tenant_id())',
        t
      );
    END IF;
  END LOOP;
  FOREACH t IN ARRAY write_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS ap_authenticated_write ON public.%I', t);
      EXECUTE format(
        'CREATE POLICY ap_authenticated_write ON public.%I FOR ALL TO authenticated USING (tenant_id = get_tenant_id()) WITH CHECK (tenant_id = get_tenant_id())',
        t
      );
    END IF;
  END LOOP;
END $$;

-- agents_provider_credentials: exceção deliberada preservada
-- (admin OU dono) E MESMO TENANT
DROP POLICY IF EXISTS apc_read_admin_or_owner ON public.agents_provider_credentials;
CREATE POLICY apc_read_admin_or_owner ON public.agents_provider_credentials
  FOR SELECT TO authenticated
  USING (
    (is_admin() OR owner_user_id = auth.uid())
    AND tenant_id = get_tenant_id()
  );
DROP POLICY IF EXISTS apc_write_admin_or_owner ON public.agents_provider_credentials;
CREATE POLICY apc_write_admin_or_owner ON public.agents_provider_credentials
  FOR ALL TO authenticated
  USING (
    (is_admin() OR owner_user_id = auth.uid())
    AND tenant_id = get_tenant_id()
  )
  WITH CHECK (
    (is_admin() OR owner_user_id = auth.uid())
    AND tenant_id = get_tenant_id()
  );

-- ai_agent_chat_events / noshow_followups: RLS habilitado SEM policies
-- (acesso só via service_role) — mantido assim; só ganharam tenant_id acima.

-- ----------------------------------------------------------------------------
-- SEÇÃO 4 — Policies: prospecção (dados de negócio)
-- Nota: as policies "anon read by id" (páginas públicas de diagnóstico) são
-- exceção deliberada e ficam como estão. Pendência B2/B3: escopar por token.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS pb_authenticated_all ON public.prospeccao_buscas;
CREATE POLICY pb_authenticated_all ON public.prospeccao_buscas
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

DROP POLICY IF EXISTS pld_authenticated_all ON public.prospeccao_leads_descobertos;
CREATE POLICY pld_authenticated_all ON public.prospeccao_leads_descobertos
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

DROP POLICY IF EXISTS pd_authenticated_all ON public.prospeccao_diagnosticos;
CREATE POLICY pd_authenticated_all ON public.prospeccao_diagnosticos
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

DROP POLICY IF EXISTS pua_authenticated_all ON public.prospeccao_uso_api;
CREATE POLICY pua_authenticated_all ON public.prospeccao_uso_api
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

-- ----------------------------------------------------------------------------
-- SEÇÃO 5 — Policies: wa_* (WhatsApp communities / sequences)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  rec record;
BEGIN
  FOR rec IN
    SELECT * FROM (VALUES
      ('wa_communities',              'wa_communities authenticated all'),
      ('wa_community_groups',         'wa_community_groups authenticated all'),
      ('wa_community_campaigns',      'wa_campaigns authenticated all'),
      ('wa_community_campaign_items', 'wa_campaign_items authenticated all'),
      ('wa_message_sequences',        'wa_message_sequences authenticated all'),
      ('wa_sequence_steps',           'wa_sequence_steps authenticated all'),
      ('wa_sequence_enrollments',     'wa_sequence_enrollments authenticated all'),
      ('wa_scheduled_messages',       'wa_scheduled_messages authenticated all')
    ) AS v(tbl, pol)
  LOOP
    IF to_regclass('public.' || rec.tbl) IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', rec.pol, rec.tbl);
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (tenant_id = get_tenant_id()) WITH CHECK (tenant_id = get_tenant_id())',
        rec.pol, rec.tbl);
    END IF;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- SEÇÃO 6 — Policies: outros módulos de negócio
-- ----------------------------------------------------------------------------

-- twilio_call_logs
DROP POLICY IF EXISTS authenticated_access ON public.twilio_call_logs;
CREATE POLICY authenticated_access ON public.twilio_call_logs
  FOR ALL TO authenticated
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

-- nps_survey_schedule: policy antiga "Service role full access" era (ALL, public,
-- USING true) — na prática abria pra todo mundo (service_role já ignora RLS).
-- Agora: tenant-scoped. Single-tenant continua idêntico (fallback 0001).
DROP POLICY IF EXISTS "Service role full access" ON public.nps_survey_schedule;
CREATE POLICY nps_tenant_all ON public.nps_survey_schedule
  FOR ALL
  USING (tenant_id = get_tenant_id())
  WITH CHECK (tenant_id = get_tenant_id());

-- ----------------------------------------------------------------------------
-- SEÇÃO 7 — Catálogos globais: leitura authenticated, escrita só admin
-- (sem tenant_id — compartilhados entre todos os tenants)
-- ----------------------------------------------------------------------------

-- agents_skill_catalog: escrita era authenticated true → agora só admin
DROP POLICY IF EXISTS ap_authenticated_write ON public.agents_skill_catalog;
CREATE POLICY ap_admin_write ON public.agents_skill_catalog
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
-- leitura (ap_authenticated_read, SELECT true) fica como está

-- agents_integration_providers: só tinha leitura; escrita explícita p/ admin
DROP POLICY IF EXISTS ap_admin_write ON public.agents_integration_providers;
CREATE POLICY ap_admin_write ON public.agents_integration_providers
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- prospeccao_templates_nicho: era ALL authenticated true → read all / write admin
DROP POLICY IF EXISTS ptn_authenticated_all ON public.prospeccao_templates_nicho;
DROP POLICY IF EXISTS ptn_authenticated_read ON public.prospeccao_templates_nicho;
CREATE POLICY ptn_authenticated_read ON public.prospeccao_templates_nicho
  FOR SELECT TO authenticated
  USING (true);
DROP POLICY IF EXISTS ptn_admin_write ON public.prospeccao_templates_nicho;
CREATE POLICY ptn_admin_write ON public.prospeccao_templates_nicho
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- prospeccao_prompts_config: idem
DROP POLICY IF EXISTS ppc_authenticated_all ON public.prospeccao_prompts_config;
DROP POLICY IF EXISTS ppc_authenticated_read ON public.prospeccao_prompts_config;
CREATE POLICY ppc_authenticated_read ON public.prospeccao_prompts_config
  FOR SELECT TO authenticated
  USING (true);
DROP POLICY IF EXISTS ppc_admin_write ON public.prospeccao_prompts_config;
CREATE POLICY ppc_admin_write ON public.prospeccao_prompts_config
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ----------------------------------------------------------------------------
-- SEÇÃO 8 — SISTEMA (documentação — nada alterado aqui)
-- ----------------------------------------------------------------------------
-- tenants           → tabela de tenants em si, não recebe tenant_id
-- config            → fica para a Onda B2 (chaves globais vs por-tenant)
-- cs_event_*        → módulo morto (8 tabelas), não mexido
-- ai_critical_decisions → NÃO existe no schema atual (listada por engano)

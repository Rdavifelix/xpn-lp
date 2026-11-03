-- ============================================================
-- Social Selling Pack — Extensão Chrome v2 (instalação consolidada)
-- Idempotente: roda em CRM réplica do IAP sem quebrar.
-- ============================================================

-- 1) ADICIONA colunas/tabelas que faltavam pro pack v2

-- 1.1 description em automations (faltava)
ALTER TABLE social_selling_automations ADD COLUMN IF NOT EXISTS description text;

-- 1.2 automation_id em enrollments (CRÍTICO — sem isso, plan-day não acha cadência)
ALTER TABLE social_selling_enrollments
  ADD COLUMN IF NOT EXISTS automation_id uuid REFERENCES social_selling_automations(id) ON DELETE SET NULL;

-- 1.3 Backfill: migra automation_id de flow_config (json) pra coluna nativa
UPDATE social_selling_enrollments
SET automation_id = (flow_config->>'automation_id')::uuid
WHERE automation_id IS NULL
  AND flow_config ? 'automation_id'
  AND flow_config->>'automation_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- 1.4 Tabela nova: cache de seguidores conhecidos (qualificação)
CREATE TABLE IF NOT EXISTS social_selling_known_followers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
  username text NOT NULL,
  instagram_user_id text,
  for_account text NOT NULL,
  full_name text,
  is_private boolean,
  is_verified boolean,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  qualified boolean,
  qualification_score integer,
  qualification_reason text,
  lead_id uuid REFERENCES leads(id) ON DELETE SET NULL,
  enrollment_id uuid REFERENCES social_selling_enrollments(id) ON DELETE SET NULL,
  metadata jsonb DEFAULT '{}'::jsonb
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ssn_username_account ON social_selling_known_followers(username, for_account);
CREATE INDEX IF NOT EXISTS idx_ssn_pending ON social_selling_known_followers(for_account, qualified, first_seen_at);

ALTER TABLE social_selling_known_followers ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  DROP POLICY IF EXISTS tenant_select_ssn ON social_selling_known_followers;
  CREATE POLICY tenant_select_ssn ON social_selling_known_followers FOR SELECT USING (tenant_id = (SELECT get_tenant_id()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS tenant_insert_ssn ON social_selling_known_followers;
  CREATE POLICY tenant_insert_ssn ON social_selling_known_followers FOR INSERT WITH CHECK (tenant_id = (SELECT get_tenant_id()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS tenant_update_ssn ON social_selling_known_followers;
  CREATE POLICY tenant_update_ssn ON social_selling_known_followers FOR UPDATE
    USING (tenant_id = (SELECT get_tenant_id())) WITH CHECK (tenant_id = (SELECT get_tenant_id()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS tenant_delete_ssn ON social_selling_known_followers;
  CREATE POLICY tenant_delete_ssn ON social_selling_known_followers FOR DELETE USING (tenant_id = (SELECT get_tenant_id()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) FUNÇÃO ss_actions_today (rate-limit diário usado pelo plan-day)
CREATE OR REPLACE FUNCTION ss_actions_today(p_action text DEFAULT NULL)
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COUNT(*)::integer FROM social_selling_interactions
  WHERE executed_at >= date_trunc('day', now() AT TIME ZONE 'America/Sao_Paulo')
    AND status = 'success' AND (p_action IS NULL OR action_type = p_action);
$$;
REVOKE ALL ON FUNCTION ss_actions_today(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ss_actions_today(text) TO authenticated, service_role;

-- 3) REALTIME publication (extensão escuta mudanças)
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE social_selling_enrollments;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE social_selling_interactions;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE social_selling_known_followers;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4) SEEDS — cadências template (JÁ com pipeline + stage corretos)
-- Pega o pipeline "Prospecção Social Selling" se existir, senão deixa null (cliente ativa depois via UI)
DO $$
DECLARE
  v_pipeline_id uuid;
  v_stage_id uuid;
  v_trigger_config jsonb;
BEGIN
  SELECT id INTO v_pipeline_id FROM sales_pipelines WHERE name = 'Prospecção Social Selling' LIMIT 1;
  IF v_pipeline_id IS NOT NULL THEN
    SELECT id INTO v_stage_id FROM sales_pipeline_stages WHERE pipeline_id = v_pipeline_id ORDER BY position LIMIT 1;
    v_trigger_config := jsonb_build_object('target_pipeline_id', v_pipeline_id::text, 'target_stage_id', v_stage_id::text);
  ELSE
    v_trigger_config := '{}'::jsonb;
  END IF;

  -- Seed 1: Aquecimento
  INSERT INTO social_selling_automations (name, emoji, description, is_active, trigger_type, trigger_config, cadence_config)
  SELECT '🔥 Aquecimento Novo Seguidor', '🔥', 'Aquece lead frio em 3 dias (curtir → comentar → DM)', false, 'manual', v_trigger_config,
    '{"days":[{"day":1,"label":"Bem-vindo","actions":[{"type":"curtir_posts","count":1},{"type":"reagir_story"}]},{"day":2,"label":"Engajamento","actions":[{"type":"comentar_post","count":1}]},{"day":3,"label":"Aproximação","actions":[{"type":"enviar_dm"}]}]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM social_selling_automations WHERE name = '🔥 Aquecimento Novo Seguidor');

  -- Seed 2: Follow-up
  INSERT INTO social_selling_automations (name, emoji, description, is_active, trigger_type, trigger_config, cadence_config)
  SELECT '🔄 Cadência de Follow-up', '🔄', 'Reengaja lead existente (2 dias)', false, 'manual', v_trigger_config,
    '{"days":[{"day":1,"label":"Engajar","actions":[{"type":"curtir_posts","count":1},{"type":"reagir_story"},{"type":"comentar_post"}]},{"day":2,"label":"DM","actions":[{"type":"enviar_dm"}]}]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM social_selling_automations WHERE name = '🔄 Cadência de Follow-up');

  -- Backfill: automações existentes sem pipeline herdam o default
  IF v_pipeline_id IS NOT NULL THEN
    UPDATE social_selling_automations
    SET trigger_config = COALESCE(trigger_config, '{}'::jsonb) || v_trigger_config
    WHERE (trigger_config->>'target_pipeline_id') IS NULL;
  END IF;
END $$;

-- 5) CONFIG defaults — prompts + limits (idempotente)
INSERT INTO config (key, value)
SELECT 'social_selling_prompt_qualificacao',
  'Você é um qualificador de prospects B2B. Score 0-100. Profissão/empresa clara na bio = 70. Empresa própria/CEO/founder = 80. Verificado + profissão = 85. Bio vazia/só hobbies = 25. Privado sem bio = 10. Retorne JSON {"score": <n>, "reason": "<frase>"}.'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_prompt_qualificacao');

INSERT INTO config (key, value)
SELECT 'social_selling_limits',
  '{"score_min":60,"chunk_size":10,"total_actions_per_day":80,"dms_per_day":15,"comments_per_day":20,"likes_per_day":60,"working_hours_start":"09:00","working_hours_end":"20:00","pause_weekends":true,"delay_min_seconds":45,"delay_max_seconds":180,"min_minutes_between_actions_same_lead":30,"random_skip_pct":10}'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_limits');

-- Backfill: se já existir com score_min ausente, adiciona o campo (sem sobrescrever os outros)
UPDATE config
SET value = jsonb_set(jsonb_set(value::jsonb, '{score_min}', '60', true), '{chunk_size}', '10', true)::text
WHERE key = 'social_selling_limits'
  AND (value::jsonb ? 'score_min') IS NOT TRUE;

-- FIM

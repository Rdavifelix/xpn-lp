-- ============================================================================
-- Pipeline Webinário: novas etapas no início pra rastrear entrada na comunidade.
-- Vincula campanhas de distribuição (wa_community_campaigns) a webinários
-- pra automação de matching ler.
-- ============================================================================

-- 1) Vincula campanha de distribuição → webinário
ALTER TABLE wa_community_campaigns
  ADD COLUMN IF NOT EXISTS webinar_config_id UUID
  REFERENCES webinar_config(id) ON DELETE SET NULL;

-- 2-4) Ajustes no pipeline Webinário — só rodam se o pipeline existir
-- (em instalação nova/limpa o pipeline ainda não foi criado; nada a fazer)
DO $$
DECLARE pid uuid;
BEGIN
  SELECT id INTO pid FROM sales_pipelines WHERE name = 'Webinário';
  IF pid IS NULL THEN RETURN; END IF;

  UPDATE sales_pipeline_stages SET name = 'Lead capturado'
  WHERE pipeline_id = pid AND name = 'Novo';

  UPDATE sales_pipeline_stages SET position = position + 2
  WHERE pipeline_id = pid AND position >= 2;

  IF NOT EXISTS (SELECT 1 FROM sales_pipeline_stages WHERE pipeline_id = pid AND name = 'Entrou na comunidade') THEN
    INSERT INTO sales_pipeline_stages (pipeline_id, name, position, color, is_won, is_lost)
    VALUES
      (pid, 'Entrou na comunidade', 2, '#10B981', false, false),
      (pid, 'Não entrou na comunidade', 3, '#F97316', false, false);
  END IF;
END $$;

COMMENT ON COLUMN wa_community_campaigns.webinar_config_id IS
  'Vincula a campanha de distribuição ao webinário ativo. Usado pelo worker sync-community-members.';

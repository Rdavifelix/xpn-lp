-- Linked Leads Mirror: bidirectional pipeline stage sync trigger + fix existing data

-- 1. Create/replace bidirectional sync function
CREATE OR REPLACE FUNCTION sync_partner_pipeline_stage()
RETURNS trigger AS $$
BEGIN
  -- Avoid infinite loop: only fire at depth < 2
  IF pg_trigger_depth() >= 2 THEN RETURN NEW; END IF;

  IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
    -- Sync children (leads that point to me via partner_lead_id)
    UPDATE leads
    SET pipeline_stage_id = NEW.pipeline_stage_id
    WHERE partner_lead_id = NEW.id
      AND pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id;

    -- Sync parent (if I point to someone via partner_lead_id)
    IF NEW.partner_lead_id IS NOT NULL THEN
      UPDATE leads
      SET pipeline_stage_id = NEW.pipeline_stage_id
      WHERE id = NEW.partner_lead_id
        AND pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_sync_partner_pipeline_stage ON leads;
DROP TRIGGER IF EXISTS trg_sync_partner_pipeline_stage ON leads;
CREATE TRIGGER trg_sync_partner_pipeline_stage
  AFTER UPDATE OF pipeline_stage_id ON leads
  FOR EACH ROW EXECUTE FUNCTION sync_partner_pipeline_stage();

-- (data-fixes pontuais de produção removidos do template)

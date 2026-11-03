-- ============================================================
-- Sincronia automática leads.instagram <-> leads.instagram_username
-- O CRM legado popula APENAS `instagram` (tela de cadastro de lead).
-- O módulo Social Selling lê APENAS `instagram_username`.
-- Trigger garante que escrever em qualquer um popula o outro.
-- ============================================================

CREATE OR REPLACE FUNCTION sync_lead_instagram_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- Normaliza: remove @ e lowercase
  IF NEW.instagram IS NOT NULL THEN
    NEW.instagram := LOWER(TRIM(REGEXP_REPLACE(NEW.instagram, '^@+', '')));
  END IF;
  IF NEW.instagram_username IS NOT NULL THEN
    NEW.instagram_username := LOWER(TRIM(REGEXP_REPLACE(NEW.instagram_username, '^@+', '')));
  END IF;

  -- Sincronização bidirecional
  IF NEW.instagram IS NOT NULL AND NEW.instagram_username IS NULL THEN
    NEW.instagram_username := NEW.instagram;
  ELSIF NEW.instagram_username IS NOT NULL AND NEW.instagram IS NULL THEN
    NEW.instagram := NEW.instagram_username;
  ELSIF NEW.instagram IS NOT NULL AND NEW.instagram_username IS NOT NULL
        AND NEW.instagram <> NEW.instagram_username THEN
    -- Conflito: o que foi alterado nesse UPDATE tem prioridade.
    -- Se nenhum mudou (insert) prioriza instagram (campo legado, vem do cadastro).
    IF TG_OP = 'UPDATE' THEN
      IF NEW.instagram IS DISTINCT FROM OLD.instagram THEN
        NEW.instagram_username := NEW.instagram;
      ELSIF NEW.instagram_username IS DISTINCT FROM OLD.instagram_username THEN
        NEW.instagram := NEW.instagram_username;
      END IF;
    ELSE
      NEW.instagram_username := NEW.instagram;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_lead_instagram ON leads;
DROP TRIGGER IF EXISTS trg_sync_lead_instagram ON leads;
CREATE TRIGGER trg_sync_lead_instagram
  BEFORE INSERT OR UPDATE OF instagram, instagram_username ON leads
  FOR EACH ROW
  EXECUTE FUNCTION sync_lead_instagram_fields();

-- Backfill: garante consistência nos leads existentes
UPDATE leads
SET instagram_username = LOWER(TRIM(REGEXP_REPLACE(instagram, '^@+', '')))
WHERE instagram IS NOT NULL AND instagram_username IS NULL;

UPDATE leads
SET instagram = LOWER(TRIM(REGEXP_REPLACE(instagram_username, '^@+', '')))
WHERE instagram_username IS NOT NULL AND instagram IS NULL;

-- FIM

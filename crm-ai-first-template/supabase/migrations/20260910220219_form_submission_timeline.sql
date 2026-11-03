BEGIN;
CREATE OR REPLACE FUNCTION crm_inbound.form_timeline_snapshot() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE receipt crm_inbound.receipts%ROWTYPE; title text; answers jsonb;
BEGIN
 IF NEW.interaction_type<>'form_submission' THEN RETURN NEW;END IF;
 IF NEW.metadata->>'receipt_id' IS NOT NULL THEN
  SELECT r.* INTO receipt FROM crm_inbound.receipts r JOIN crm_inbound.channels c ON c.id=r.channel_id WHERE r.id::text=NEW.metadata->>'receipt_id' AND c.tenant_id=NEW.tenant_id;
  IF FOUND THEN
   SELECT name INTO title FROM crm_inbound.channels WHERE id=receipt.channel_id AND tenant_id=NEW.tenant_id;
   NEW.metadata:=coalesce(NEW.metadata,'{}')||jsonb_build_object('form_name',title,'answers',receipt.payload,'submission_source','external_page');
  END IF;
 ELSIF NEW.metadata->>'form_id' IS NOT NULL THEN
  -- Native forms already keep the submitted labels and answers in content.
  BEGIN
   answers:=substring(NEW.content FROM strpos(NEW.content,E'\n')+1)::jsonb;
   IF jsonb_typeof(answers)='object' THEN
    title:=regexp_replace(split_part(NEW.content,E'\n',1),'^Formulário: ','');
    NEW.metadata:=coalesce(NEW.metadata,'{}')||jsonb_build_object('form_name',title,'answers',answers,'submission_source','crm_form');
   END IF;
  EXCEPTION WHEN invalid_text_representation THEN NULL;
  END;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION crm_inbound.form_timeline_snapshot() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER form_timeline_snapshot BEFORE INSERT OR UPDATE OF metadata,content ON public.lead_interactions FOR EACH ROW WHEN (NEW.interaction_type='form_submission') EXECUTE FUNCTION crm_inbound.form_timeline_snapshot();
UPDATE public.lead_interactions SET metadata=coalesce(metadata,'{}') WHERE interaction_type='form_submission' AND NOT coalesce(metadata,'{}')?'answers';
COMMIT;

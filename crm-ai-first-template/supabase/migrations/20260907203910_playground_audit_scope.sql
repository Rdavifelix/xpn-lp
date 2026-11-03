BEGIN;
-- Trigger runs only after a deal update already authorized by RLS.
CREATE OR REPLACE FUNCTION public._audit_deal_stage_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
  INSERT INTO public._deal_stage_audit(deal_id,old_stage_id,new_stage_id,old_stage_name,new_stage_name)
  VALUES(NEW.id,OLD.pipeline_stage_id,NEW.pipeline_stage_id,
   (SELECT name FROM public.sales_pipeline_stages WHERE id=OLD.pipeline_stage_id),
   (SELECT name FROM public.sales_pipeline_stages WHERE id=NEW.pipeline_stage_id));
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public._audit_deal_stage_change() FROM PUBLIC,anon,authenticated;
COMMIT;

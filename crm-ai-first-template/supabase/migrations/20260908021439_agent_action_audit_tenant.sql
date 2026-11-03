BEGIN;
UPDATE public.agents_action_log l SET tenant_id=a.tenant_id FROM public.agents_registry a WHERE l.agent_id=a.id AND a.tenant_id IS NOT NULL AND l.tenant_id IS DISTINCT FROM a.tenant_id;
CREATE OR REPLACE FUNCTION crm_mcp.operational_event_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ev text;did uuid;sid uuid;BEGIN
 IF pg_trigger_depth()>1 OR NOT EXISTS(SELECT 1 FROM public.sales_automation_rules WHERE tenant_id=NEW.tenant_id AND is_active AND action_config->>'executor'='mcp_sql') THEN RETURN NEW;END IF;
 IF TG_TABLE_NAME='deals' THEN
  IF TG_OP='INSERT' THEN ev:='deal_created';ELSIF NEW.pipeline_stage_id IS DISTINCT FROM OLD.pipeline_stage_id THEN ev:='deal_stage_changed';ELSE RETURN NEW;END IF;
  PERFORM crm_mcp.run_operational_rules(NEW.tenant_id,ev,NEW.id,NEW.lead_id,NEW.id,NEW.pipeline_stage_id,NULL,false);
 ELSE
  IF TG_OP='INSERT' THEN ev:=CASE WHEN NEW.task_type IN ('meeting','call') AND NEW.scheduled_at IS NOT NULL THEN 'meeting_scheduled' ELSE 'task_created' END;
  ELSIF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' AND NEW.task_type IN ('meeting','call') THEN ev:='meeting_cancelled';
  ELSIF NEW.completed AND NOT OLD.completed THEN ev:='task_completed';
  ELSIF NEW.scheduled_at IS DISTINCT FROM OLD.scheduled_at AND NEW.task_type IN ('meeting','call') THEN ev:='meeting_rescheduled';ELSE RETURN NEW;END IF;
  IF coalesce(NEW.metadata->>'deal_id','')~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN did:=(NEW.metadata->>'deal_id')::uuid;END IF;
  IF did IS NOT NULL THEN SELECT pipeline_stage_id INTO sid FROM public.deals WHERE id=did AND tenant_id=NEW.tenant_id AND lead_id=NEW.lead_id;END IF;
  PERFORM crm_mcp.run_operational_rules(NEW.tenant_id,ev,NEW.id,NEW.lead_id,did,sid,NEW.task_type,NEW.scheduled_at IS NOT NULL);
 END IF;
 RETURN NEW;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

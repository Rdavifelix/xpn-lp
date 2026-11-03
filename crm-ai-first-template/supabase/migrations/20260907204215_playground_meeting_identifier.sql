BEGIN;
CREATE OR REPLACE FUNCTION public.playground_schedule_meeting(p_lead_id uuid,p_agent_id uuid,p_closer_id uuid,p_start_at timestamptz,p_duration_minutes integer DEFAULT 30,p_title text DEFAULT NULL,p_notes text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,public AS $$
DECLARE v_activity_id uuid; finish timestamptz; lead_name text;
BEGIN
 PERFORM public.playground_assert_access(p_agent_id,p_lead_id);
 IF p_start_at IS NULL OR p_start_at<now() OR p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 5 AND 480 THEN RAISE EXCEPTION 'Horário ou duração inválidos' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=p_closer_id AND tenant_id=public.get_tenant_id() AND is_active) THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_closer_id::text,1));
 finish:=p_start_at+make_interval(mins=>p_duration_minutes);
 SELECT ca.id INTO v_activity_id FROM public.company_activities ca WHERE ca.lead_id=p_lead_id AND ca.responsavel_id=p_closer_id AND ca.scheduled_at=p_start_at AND ca.task_type='meeting' AND NOT ca.completed AND ca.tenant_id=public.get_tenant_id() LIMIT 1;
 IF v_activity_id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'deduped',true,'activity_id',v_activity_id); END IF;
 IF EXISTS(SELECT 1 FROM public.company_activities ca WHERE ca.responsavel_id=p_closer_id AND ca.tenant_id=public.get_tenant_id() AND NOT ca.completed AND ca.task_type IN ('meeting','call') AND ca.scheduled_at<finish AND coalesce(ca.end_datetime,ca.scheduled_at+interval '30 minutes')>p_start_at) THEN
  RETURN jsonb_build_object('ok',false,'error','Horário ocupado para este responsável'); END IF;
 SELECT name INTO lead_name FROM public.leads WHERE public.leads.id=p_lead_id;
 INSERT INTO public.company_activities(lead_id,responsavel_id,task_type,name,description,scheduled_at,end_datetime,completed,team,tenant_id,metadata)
 VALUES(p_lead_id,p_closer_id,'meeting',coalesce(p_title,'Reunião com '||lead_name),p_notes,p_start_at,finish,false,'sales',public.get_tenant_id(),jsonb_build_object('created_by','playground','agent_id',p_agent_id)) RETURNING public.company_activities.id INTO v_activity_id;
 RETURN jsonb_build_object('ok',true,'activity_id',v_activity_id,'scheduled_at',p_start_at,'end_at',finish,'closer_id',p_closer_id,'calendar','CRM','external_calendar_synced',false);
END $$;

COMMIT;

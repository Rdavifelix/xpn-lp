BEGIN;
CREATE OR REPLACE FUNCTION public.agent_schedule_meeting(p_lead_id uuid,p_agent_id uuid,p_closer_id uuid,p_start_at timestamptz,p_duration_minutes integer DEFAULT 30,p_title text DEFAULT NULL,p_notes text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE v_activity_id uuid; finish timestamptz; lead_name text; tid uuid;
BEGIN
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id;
 IF tid IS NULL OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=tid AND is_active) OR NOT EXISTS(SELECT 1 FROM public.leads WHERE id=p_lead_id AND tenant_id=tid) OR (p_session_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.agents_sessions WHERE id=p_session_id AND agent_id=p_agent_id AND tenant_id=tid)) THEN RAISE EXCEPTION 'Contexto do agente inválido' USING ERRCODE='42501'; END IF;
 IF p_start_at IS NULL OR p_start_at<now() OR p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 5 AND 480 THEN RAISE EXCEPTION 'Horário ou duração inválidos' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=p_closer_id AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_closer_id::text,1));
 finish:=p_start_at+make_interval(mins=>p_duration_minutes);
 SELECT ca.id INTO v_activity_id FROM public.company_activities ca WHERE ca.lead_id=p_lead_id AND ca.responsavel_id=p_closer_id AND ca.scheduled_at=p_start_at AND ca.task_type='meeting' AND ca.status IS DISTINCT FROM 'cancelled' AND NOT ca.completed AND ca.tenant_id=tid LIMIT 1;
 IF v_activity_id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'deduped',true,'activity_id',v_activity_id); END IF;
 IF EXISTS(SELECT 1 FROM public.company_activities ca WHERE ca.responsavel_id=p_closer_id AND ca.tenant_id=tid AND ca.status IS DISTINCT FROM 'cancelled' AND NOT ca.completed AND ca.task_type IN ('meeting','call') AND ca.scheduled_at<finish AND coalesce(ca.end_datetime,ca.scheduled_at+interval '30 minutes')>p_start_at) THEN
  RETURN jsonb_build_object('ok',false,'error','Horário ocupado para este responsável'); END IF;
 SELECT name INTO lead_name FROM public.leads WHERE public.leads.id=p_lead_id;
 INSERT INTO public.company_activities(lead_id,responsavel_id,task_type,name,description,scheduled_at,end_datetime,completed,team,tenant_id,metadata)
 VALUES(p_lead_id,p_closer_id,'meeting',coalesce(p_title,'Reunião com '||lead_name),p_notes,p_start_at,finish,false,'sales',tid,jsonb_build_object('created_by','agent_v2','agent_id',p_agent_id,'session_id',p_session_id)) RETURNING public.company_activities.id INTO v_activity_id;
 RETURN jsonb_build_object('ok',true,'activity_id',v_activity_id,'scheduled_at',p_start_at,'end_at',finish,'closer_id',p_closer_id,'calendar','CRM','external_calendar_synced',false);
END $$;



REVOKE ALL ON FUNCTION public.agent_schedule_meeting(uuid,uuid,uuid,timestamptz,integer,text,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.agent_schedule_meeting(uuid,uuid,uuid,timestamptz,integer,text,text,uuid) TO service_role;


COMMIT;

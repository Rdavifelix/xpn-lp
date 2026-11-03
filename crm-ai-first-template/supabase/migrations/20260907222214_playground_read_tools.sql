BEGIN;
CREATE FUNCTION public.playground_now_br() RETURNS TABLE(now_br timestamptz,date_br text,time_br text,weekday text) LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT now(),to_char(now() AT TIME ZONE 'America/Sao_Paulo','DD/MM/YYYY'),to_char(now() AT TIME ZONE 'America/Sao_Paulo','HH24:MI'),to_char(now() AT TIME ZONE 'America/Sao_Paulo','Day');
$$;
CREATE FUNCTION public.playground_check_availability(p_closer_ids uuid[],p_days_ahead integer DEFAULT 7,p_duration_minutes integer DEFAULT 30,p_working_hour_start text DEFAULT '08:00',p_working_hour_end text DEFAULT '18:00',p_buffer_minutes integer DEFAULT 15,p_max_slots integer DEFAULT 5) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid:=public.get_tenant_id(); slots jsonb; BEGIN
 IF auth.uid() IS NULL OR tid IS NULL OR NOT EXISTS(SELECT 1 FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Usuário inválido' USING ERRCODE='42501'; END IF;
 IF p_closer_ids IS NULL OR coalesce(cardinality(p_closer_ids),0) NOT BETWEEN 1 AND 30 OR p_days_ahead IS NULL OR p_days_ahead NOT BETWEEN 0 AND 60 OR p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 5 AND 480 OR p_buffer_minutes IS NULL OR p_buffer_minutes NOT BETWEEN 0 AND 120 OR p_max_slots IS NULL OR p_max_slots NOT BETWEEN 1 AND 100 OR p_working_hour_start IS NULL OR p_working_hour_end IS NULL OR p_working_hour_start!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR p_working_hour_end!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR p_working_hour_start>=p_working_hour_end THEN RAISE EXCEPTION 'Parâmetros inválidos' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(p_closer_ids) c WHERE c IS NULL OR NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=c AND tenant_id=tid AND is_active)) THEN RAISE EXCEPTION 'Responsável fora da empresa' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(x),'[]') INTO slots FROM (
  SELECT v.start_at AS start,v.start_at+make_interval(mins=>p_duration_minutes) AS "end",p_duration_minutes duration_minutes,count(*) available_closers,jsonb_agg(c.id ORDER BY c.id) closer_ids
  FROM generate_series(0,p_days_ahead) day_offset
  CROSS JOIN LATERAL generate_series(((now() AT TIME ZONE 'America/Sao_Paulo')::date+day_offset)+p_working_hour_start::time,((now() AT TIME ZONE 'America/Sao_Paulo')::date+day_offset)+p_working_hour_end::time-make_interval(mins=>p_duration_minutes),interval '30 minutes') local_slot
  CROSS JOIN LATERAL (SELECT local_slot AT TIME ZONE 'America/Sao_Paulo' start_at) v
  CROSS JOIN (SELECT DISTINCT unnest(p_closer_ids) id)c
  WHERE extract(isodow FROM local_slot)<6 AND v.start_at>now()+interval '30 minutes' AND NOT EXISTS(
   SELECT 1 FROM public.company_activities ca WHERE ca.tenant_id=tid AND ca.responsavel_id=c.id AND ca.task_type IN ('meeting','call') AND NOT ca.completed AND ca.status IS DISTINCT FROM 'cancelled' AND ca.scheduled_at<v.start_at+make_interval(mins=>p_duration_minutes+p_buffer_minutes) AND coalesce(ca.end_datetime,ca.scheduled_at+interval '30 minutes')>v.start_at-make_interval(mins=>p_buffer_minutes))
  GROUP BY v.start_at ORDER BY v.start_at LIMIT p_max_slots
 )x;
 RETURN jsonb_build_object('ok',true,'timezone','America/Sao_Paulo','slots',slots,'total_found',jsonb_array_length(slots));
END $$;
REVOKE ALL ON FUNCTION public.playground_now_br(),public.playground_check_availability(uuid[],integer,integer,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.playground_now_br(),public.playground_check_availability(uuid[],integer,integer,text,text,integer,integer) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

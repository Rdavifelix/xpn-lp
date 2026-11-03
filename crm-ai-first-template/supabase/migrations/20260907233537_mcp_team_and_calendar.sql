BEGIN;
CREATE TABLE crm_mcp.team_provisions(tenant_id uuid NOT NULL REFERENCES public.tenants(id),request_id uuid NOT NULL,actor_id uuid NOT NULL,payload jsonb NOT NULL,member_id uuid,created_at timestamptz DEFAULT now(),PRIMARY KEY(tenant_id,request_id));
ALTER TABLE crm_mcp.team_provisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON crm_mcp.team_provisions FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.mcp_team(p_action text,p_id uuid DEFAULT NULL,p_request_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid;uid uuid:=(ctx->>'user_id')::uuid;m public.team_members%ROWTYPE;b public.calendar_blocks%ROWTYPE;v jsonb;k text;item jsonb;old crm_mcp.operations%ROWTYPE;payload jsonb;result jsonb;pr crm_mcp.team_provisions%ROWTYPE;BEGIN
 IF p_action NOT IN ('get','update','hours','block_create','block_remove','provision') OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>10000 THEN RAISE EXCEPTION 'Operação inválida' USING ERRCODE='22023';END IF;
 IF p_action='get' THEN
  SELECT * INTO m FROM team_members WHERE id=p_id AND tenant_id=tid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membro não encontrado' USING ERRCODE='42501';END IF;
  RETURN jsonb_build_object('member',crm_mcp.safe_fields(to_jsonb(m),ARRAY['id','name','email','role','sub_role','team','phone','is_active','working_hours','meeting_duration_minutes','google_calendar_connected']),'timezone','America/Sao_Paulo','blocks',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') FROM (SELECT id,title,block_type,start_datetime,end_datetime,recurrence_days,recurrence_start_time,recurrence_end_time,is_active FROM calendar_blocks WHERE team_member_id=p_id AND tenant_id=tid AND is_active ORDER BY created_at DESC LIMIT 100)x));
 END IF;
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'request_id obrigatório' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('team:'||tid::text,0));
 IF p_action='provision' THEN
  IF p_data-ARRAY['name','email','role','team','phone']<>'{}' OR length(btrim(coalesce(p_data->>'name',''))) NOT BETWEEN 2 AND 120 OR coalesce(p_data->>'email','')!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' OR length(p_data->>'email')>254 OR coalesce(p_data->>'role','') NOT IN ('sdr','closer','admin','comercial') THEN RAISE EXCEPTION 'Nome, email e função válidos são obrigatórios' USING ERRCODE='22023';END IF;
  SELECT * INTO pr FROM crm_mcp.team_provisions WHERE tenant_id=tid AND request_id=p_request_id;
  IF FOUND AND (pr.payload<>p_data OR pr.actor_id<>uid) THEN RAISE EXCEPTION 'request_id já utilizado' USING ERRCODE='22023';END IF;
  IF NOT FOUND THEN
   IF EXISTS(SELECT 1 FROM auth.users WHERE lower(email)=lower(p_data->>'email')) OR EXISTS(SELECT 1 FROM team_members WHERE lower(email)=lower(p_data->>'email')) THEN RAISE EXCEPTION 'Email já cadastrado. Não será criado outro acesso nem alterado o existente.' USING ERRCODE='22023';END IF;
   INSERT INTO crm_mcp.team_provisions VALUES(tid,p_request_id,uid,p_data,NULL,now()) RETURNING * INTO pr;
  END IF;
  RETURN jsonb_build_object('tenant_id',tid,'request_id',p_request_id,'member_id',pr.member_id);
 END IF;
 payload:=jsonb_build_object('action',p_action,'id',p_id,'data',p_data);
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tid AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload THEN RAISE EXCEPTION 'request_id já utilizado' USING ERRCODE='22023';END IF;RETURN old.result;END IF;
 SELECT * INTO m FROM team_members WHERE id=p_id AND tenant_id=tid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Membro não encontrado' USING ERRCODE='42501';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_id::text,1));
 IF p_action='update' THEN
  IF p_data-ARRAY['name','role','team','phone','is_active']<>'{}' OR p_data='{}' THEN RAISE EXCEPTION 'Campos inválidos' USING ERRCODE='22023';END IF;
  IF p_data?'role' AND p_data->>'role' NOT IN ('sdr','closer','admin','comercial') OR p_data?'name' AND length(btrim(coalesce(p_data->>'name',''))) NOT BETWEEN 2 AND 120 OR p_data?'is_active' AND jsonb_typeof(p_data->'is_active')<>'boolean' THEN RAISE EXCEPTION 'Valores inválidos' USING ERRCODE='22023';END IF;
  IF (p_data?'role' OR p_data->>'is_active'='false') AND (m.auth_user_id=uid OR m.is_superadmin OR EXISTS(SELECT 1 FROM tenants WHERE id=tid AND owner_user_id=m.auth_user_id)) THEN RAISE EXCEPTION 'Não altere o acesso do proprietário ou seu próprio acesso por esta ferramenta' USING ERRCODE='42501';END IF;
  IF m.role='admin' AND (p_data->>'role' IS NOT NULL AND p_data->>'role'<>'admin' OR p_data->>'is_active'='false') AND NOT EXISTS(SELECT 1 FROM team_members WHERE tenant_id=tid AND role='admin' AND is_active AND id<>p_id) THEN RAISE EXCEPTION 'Mantenha um administrador ativo' USING ERRCODE='22023';END IF;
  UPDATE team_members SET name=coalesce(p_data->>'name',name),role=CASE WHEN p_data?'role' THEN CASE WHEN p_data->>'role' IN ('sdr','closer') THEN 'comercial' ELSE p_data->>'role' END ELSE role END,sub_role=CASE WHEN p_data?'role' THEN CASE WHEN p_data->>'role' IN ('sdr','closer') THEN p_data->>'role' ELSE NULL END ELSE sub_role END,team=coalesce(p_data->>'team',team),phone=coalesce(p_data->>'phone',phone),is_active=coalesce((p_data->>'is_active')::boolean,is_active),updated_at=now() WHERE id=p_id RETURNING * INTO m;
  IF NOT m.is_active THEN DELETE FROM auth.sessions WHERE user_id=m.auth_user_id;END IF;
 ELSIF p_action='hours' THEN
  IF p_data-ARRAY['working_hours','meeting_duration_minutes']<>'{}' OR jsonb_typeof(p_data->'working_hours') IS DISTINCT FROM 'object' OR coalesce((p_data->>'meeting_duration_minutes')::integer,30) NOT BETWEEN 5 AND 480 THEN RAISE EXCEPTION 'Horários inválidos' USING ERRCODE='22023';END IF;
  FOR k,item IN SELECT * FROM jsonb_each(p_data->'working_hours') LOOP
   IF k!~'^[0-6]$' OR item<>'null' AND (jsonb_typeof(item)<>'object' OR item-ARRAY['start','end']<>'{}' OR coalesce(item->>'start','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR coalesce(item->>'end','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR item->>'start'>=item->>'end') THEN RAISE EXCEPTION 'Use dias 0 a 6 com start/end HH:MM ou null' USING ERRCODE='22023';END IF;
  END LOOP;
  UPDATE team_members SET working_hours=p_data->'working_hours',meeting_duration_minutes=coalesce((p_data->>'meeting_duration_minutes')::integer,meeting_duration_minutes),updated_at=now() WHERE id=p_id RETURNING * INTO m;
 ELSIF p_action='block_create' THEN
  IF p_data-ARRAY['title','block_type','start_datetime','end_datetime','recurrence_days','recurrence_start_time','recurrence_end_time']<>'{}' OR length(btrim(coalesce(p_data->>'title',''))) NOT BETWEEN 1 AND 150 OR coalesce(p_data->>'block_type','') NOT IN ('one_time','recurring') THEN RAISE EXCEPTION 'Bloqueio inválido' USING ERRCODE='22023';END IF;
  IF p_data->>'block_type'='one_time' THEN
   IF p_data->>'start_datetime' IS NULL OR p_data->>'end_datetime' IS NULL OR (p_data->>'start_datetime')::timestamptz>=(p_data->>'end_datetime')::timestamptz THEN RAISE EXCEPTION 'Intervalo inválido' USING ERRCODE='22023';END IF;
  ELSE
   IF jsonb_typeof(p_data->'recurrence_days') IS DISTINCT FROM 'array' OR jsonb_array_length(p_data->'recurrence_days') NOT BETWEEN 1 AND 7 OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(p_data->'recurrence_days') x WHERE x!~'^[0-6]$') OR coalesce(p_data->>'recurrence_start_time','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR coalesce(p_data->>'recurrence_end_time','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR p_data->>'recurrence_start_time'>=p_data->>'recurrence_end_time' THEN RAISE EXCEPTION 'Recorrência inválida' USING ERRCODE='22023';END IF;
  END IF;
  INSERT INTO calendar_blocks(tenant_id,team_member_id,title,block_type,start_datetime,end_datetime,recurrence_days,recurrence_start_time,recurrence_end_time) VALUES(tid,p_id,p_data->>'title',p_data->>'block_type',(p_data->>'start_datetime')::timestamptz,(p_data->>'end_datetime')::timestamptz,ARRAY(SELECT value::integer FROM jsonb_array_elements_text(coalesce(p_data->'recurrence_days','[]'))),(p_data->>'recurrence_start_time')::time,(p_data->>'recurrence_end_time')::time) RETURNING * INTO b;
 ELSIF p_action='block_remove' THEN
  IF p_data-ARRAY['block_id']<>'{}' THEN RAISE EXCEPTION 'Bloqueio inválido' USING ERRCODE='22023';END IF;
  UPDATE calendar_blocks SET is_active=false,updated_at=now() WHERE id=(p_data->>'block_id')::uuid AND tenant_id=tid AND team_member_id=p_id RETURNING * INTO b;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bloqueio não encontrado' USING ERRCODE='42501';END IF;
 END IF;
 result:=CASE WHEN p_action LIKE 'block_%' THEN to_jsonb(b) ELSE crm_mcp.safe_fields(to_jsonb(m),ARRAY['id','name','email','role','sub_role','team','phone','is_active','working_hours','meeting_duration_minutes']) END;
 INSERT INTO crm_mcp.operations VALUES(tid,p_request_id,uid,payload,result,now());RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.mcp_team(text,uuid,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mcp_team(text,uuid,uuid,jsonb) TO authenticated;

CREATE FUNCTION public.team_provision_finish(p_tenant_id uuid,p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE pr crm_mcp.team_provisions%ROWTYPE;u auth.users%ROWTYPE;m public.team_members%ROWTYPE;BEGIN
 SELECT * INTO pr FROM crm_mcp.team_provisions WHERE tenant_id=p_tenant_id AND request_id=p_request_id FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM team_members tm JOIN tenants t ON t.id=tm.tenant_id WHERE tm.auth_user_id=pr.actor_id AND tm.tenant_id=p_tenant_id AND tm.role='admin' AND tm.is_active AND t.is_active) THEN RAISE EXCEPTION 'Provisionamento inválido' USING ERRCODE='42501';END IF;
 SELECT * INTO u FROM auth.users WHERE lower(email)=lower(pr.payload->>'email') AND raw_app_meta_data->>'tenant_id'=p_tenant_id::text AND raw_app_meta_data->>'team_request_id'=p_request_id::text;
 IF NOT FOUND THEN RETURN jsonb_build_object('needs_create',true);END IF;
 IF pr.member_id IS NULL THEN
 INSERT INTO team_members(tenant_id,auth_user_id,name,email,role,sub_role,team,phone,is_active) VALUES(p_tenant_id,u.id,pr.payload->>'name',lower(pr.payload->>'email'),CASE WHEN pr.payload->>'role' IN ('sdr','closer') THEN 'comercial' ELSE pr.payload->>'role' END,CASE WHEN pr.payload->>'role' IN ('sdr','closer') THEN pr.payload->>'role' END,coalesce(pr.payload->>'team','comercial'),pr.payload->>'phone',true) RETURNING * INTO m;
 UPDATE crm_mcp.team_provisions SET member_id=m.id WHERE tenant_id=p_tenant_id AND request_id=p_request_id;
 ELSE SELECT * INTO m FROM team_members WHERE id=pr.member_id AND tenant_id=p_tenant_id;END IF;
 IF NOT m.is_active OR u.last_sign_in_at IS NOT NULL THEN RETURN jsonb_build_object('member',crm_mcp.safe_fields(to_jsonb(m),ARRAY['id','name','email','role','sub_role','team','is_active']),'access_already_used',true);END IF;
 RETURN jsonb_build_object('member',crm_mcp.safe_fields(to_jsonb(m),ARRAY['id','name','email','role','sub_role','team','is_active']),'email',u.email,'needs_create',false);
END $$;
REVOKE ALL ON FUNCTION public.team_provision_finish(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.team_provision_finish(uuid,uuid) TO service_role;
CREATE FUNCTION crm_mcp.calendar_free(tid uuid,member uuid,starts timestamptz,ends timestamptz,exclude_id uuid DEFAULT NULL,buffer_minutes integer DEFAULT 0) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE m public.team_members%ROWTYPE;s timestamp:=starts AT TIME ZONE 'America/Sao_Paulo';e timestamp:=ends AT TIME ZONE 'America/Sao_Paulo';hours jsonb;day integer:=extract(dow FROM s);BEGIN
 SELECT * INTO m FROM team_members WHERE id=member AND tenant_id=tid AND is_active;
 IF NOT FOUND OR starts IS NULL OR ends IS NULL OR starts>=ends OR s::date<>e::date THEN RETURN false;END IF;
 hours:=coalesce(m.working_hours->day::text,m.working_hours->(ARRAY['sun','mon','tue','wed','thu','fri','sat'])[day+1]);
 IF hours IS NULL OR hours='null' OR hours->>'start' IS NULL OR hours->>'end' IS NULL OR s::time<(hours->>'start')::time OR e::time>(hours->>'end')::time THEN RETURN false;END IF;
 IF EXISTS(SELECT 1 FROM calendar_blocks b WHERE b.tenant_id=tid AND b.team_member_id=member AND b.is_active AND ((b.block_type='one_time' AND b.start_datetime<ends AND b.end_datetime>starts) OR (b.block_type='recurring' AND day=ANY(b.recurrence_days) AND b.recurrence_start_time<e::time AND b.recurrence_end_time>s::time))) THEN RETURN false;END IF;
 IF EXISTS(SELECT 1 FROM company_activities a WHERE a.tenant_id=tid AND a.responsavel_id=member AND a.id IS DISTINCT FROM exclude_id AND a.task_type IN ('meeting','call') AND NOT coalesce(a.completed,false) AND a.status IS DISTINCT FROM 'cancelled' AND a.scheduled_at<ends+make_interval(mins=>buffer_minutes) AND coalesce(a.end_datetime,a.scheduled_at+make_interval(mins=>coalesce(m.meeting_duration_minutes,30)))>starts-make_interval(mins=>buffer_minutes)) THEN RETURN false;END IF;
 IF EXISTS(SELECT 1 FROM calendar_events ev WHERE ev.tenant_id=tid AND ev.team_member_id=m.auth_user_id AND ev.status IS DISTINCT FROM 'cancelled' AND ev.start_datetime<ends+make_interval(mins=>buffer_minutes) AND ev.end_datetime>starts-make_interval(mins=>buffer_minutes)) THEN RETURN false;END IF;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.calendar_free(uuid,uuid,timestamptz,timestamptz,uuid,integer) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION crm_mcp.enforce_calendar() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF NEW.task_type NOT IN ('meeting','call') OR coalesce(NEW.completed,false) OR NEW.status='cancelled' OR NEW.scheduled_at IS NULL OR NEW.responsavel_id IS NULL THEN RETURN NEW;END IF;
 IF TG_OP='UPDATE' AND NEW.scheduled_at IS NOT DISTINCT FROM OLD.scheduled_at AND NEW.end_datetime IS NOT DISTINCT FROM OLD.end_datetime AND NEW.responsavel_id IS NOT DISTINCT FROM OLD.responsavel_id AND NEW.tenant_id IS NOT DISTINCT FROM OLD.tenant_id AND NEW.task_type IS NOT DISTINCT FROM OLD.task_type AND NEW.completed IS NOT DISTINCT FROM OLD.completed AND NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW;END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.responsavel_id::text,1));
 IF NOT crm_mcp.calendar_free(NEW.tenant_id,NEW.responsavel_id,NEW.scheduled_at,coalesce(NEW.end_datetime,NEW.scheduled_at+interval '30 minutes'),NEW.id) THEN RAISE EXCEPTION 'Horário indisponível: verifique expediente, bloqueios e reuniões do responsável' USING ERRCODE='22023';END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.enforce_calendar() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER enforce_team_calendar BEFORE INSERT OR UPDATE ON public.company_activities FOR EACH ROW EXECUTE FUNCTION crm_mcp.enforce_calendar();
CREATE FUNCTION crm_mcp.calendar_slots(tid uuid,ids uuid[],days integer,duration integer,hstart text,hend text,buffer integer,max_slots integer) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE slots jsonb;BEGIN
 IF ids IS NULL OR coalesce(cardinality(ids),0) NOT BETWEEN 1 AND 30 OR days IS NULL OR days NOT BETWEEN 0 AND 60 OR duration IS NULL OR duration NOT BETWEEN 5 AND 480 OR buffer IS NULL OR buffer NOT BETWEEN 0 AND 120 OR max_slots IS NULL OR max_slots NOT BETWEEN 1 AND 100 OR hstart IS NULL OR hend IS NULL OR hstart!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR hend!~'^([01][0-9]|2[0-3]):[0-5][0-9]$' OR hstart>=hend THEN RAISE EXCEPTION 'Parâmetros inválidos' USING ERRCODE='22023';END IF;
 IF EXISTS(SELECT 1 FROM unnest(ids)c WHERE c IS NULL OR NOT EXISTS(SELECT 1 FROM team_members WHERE id=c AND tenant_id=tid AND is_active)) THEN RAISE EXCEPTION 'Responsável fora da empresa' USING ERRCODE='42501';END IF;
 SELECT coalesce(jsonb_agg(x),'[]') INTO slots FROM (
 SELECT v.start_at AS start,v.start_at+make_interval(mins=>duration) AS "end",duration duration_minutes,count(*) available_closers,jsonb_agg(c.id ORDER BY c.id) closer_ids
 FROM generate_series(0,days) day_offset CROSS JOIN LATERAL generate_series(((now() AT TIME ZONE 'America/Sao_Paulo')::date+day_offset)+hstart::time,((now() AT TIME ZONE 'America/Sao_Paulo')::date+day_offset)+hend::time-make_interval(mins=>duration),interval '15 minutes') local_slot
 CROSS JOIN LATERAL (SELECT local_slot AT TIME ZONE 'America/Sao_Paulo' start_at)v CROSS JOIN (SELECT DISTINCT unnest(ids) id)c
 WHERE v.start_at>now()+interval '30 minutes' AND crm_mcp.calendar_free(tid,c.id,v.start_at,v.start_at+make_interval(mins=>duration),NULL,buffer)
 GROUP BY v.start_at ORDER BY v.start_at LIMIT max_slots)x;
 RETURN jsonb_build_object('ok',true,'timezone','America/Sao_Paulo','slots',slots,'total_found',jsonb_array_length(slots),'external_calendar','Somente eventos já sincronizados no CRM');
END $$;
REVOKE ALL ON FUNCTION crm_mcp.calendar_slots(uuid,uuid[],integer,integer,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.playground_check_availability(p_closer_ids uuid[],p_days_ahead integer DEFAULT 7,p_duration_minutes integer DEFAULT 30,p_working_hour_start text DEFAULT '08:00',p_working_hour_end text DEFAULT '18:00',p_buffer_minutes integer DEFAULT 15,p_max_slots integer DEFAULT 5) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid:=public.get_tenant_id();BEGIN
 IF auth.uid() IS NULL OR tid IS NULL THEN RAISE EXCEPTION 'Usuário inválido' USING ERRCODE='42501';END IF;
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN tid:=(crm_mcp.context()->>'tenant_id')::uuid;END IF;
 RETURN crm_mcp.calendar_slots(tid,p_closer_ids,p_days_ahead,p_duration_minutes,p_working_hour_start,p_working_hour_end,p_buffer_minutes,p_max_slots);
END $$;
CREATE OR REPLACE FUNCTION public.agent_check_availability(p_closer_ids uuid[],p_days_ahead integer DEFAULT 7,p_duration_minutes integer DEFAULT 30,p_working_hour_start text DEFAULT '08:00',p_working_hour_end text DEFAULT '18:00',p_buffer_minutes integer DEFAULT 15,p_max_slots integer DEFAULT 5) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid;BEGIN
 SELECT tenant_id INTO tid FROM team_members WHERE id=p_closer_ids[1] AND is_active;
 IF tid IS NULL THEN RAISE EXCEPTION 'Responsável inválido' USING ERRCODE='42501';END IF;
 RETURN crm_mcp.calendar_slots(tid,p_closer_ids,p_days_ahead,p_duration_minutes,p_working_hour_start,p_working_hour_end,p_buffer_minutes,p_max_slots);
END $$;
REVOKE ALL ON FUNCTION public.agent_check_availability(uuid[],integer,integer,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.agent_check_availability(uuid[],integer,integer,text,text,integer,integer) TO service_role;

CREATE FUNCTION public.agent_calendar_slots(p_agent_id uuid,p_closer_ids uuid[],p_days_ahead integer DEFAULT 7,p_duration_minutes integer DEFAULT 30,p_working_hour_start text DEFAULT '08:00',p_working_hour_end text DEFAULT '18:00',p_buffer_minutes integer DEFAULT 15,p_max_slots integer DEFAULT 5) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid;BEGIN
 SELECT tenant_id INTO tid FROM agents_registry WHERE id=p_agent_id;
 IF tid IS NULL THEN RAISE EXCEPTION 'Agente inválido' USING ERRCODE='42501';END IF;
 RETURN crm_mcp.calendar_slots(tid,p_closer_ids,p_days_ahead,p_duration_minutes,p_working_hour_start,p_working_hour_end,p_buffer_minutes,p_max_slots);
END $$;
REVOKE ALL ON FUNCTION public.agent_calendar_slots(uuid,uuid[],integer,integer,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.agent_calendar_slots(uuid,uuid[],integer,integer,text,text,integer,integer) TO service_role;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
      RAISE EXCEPTION 'Esta conexão só pode usar as operações MCP autorizadas' USING ERRCODE='42501'; END IF;
    PERFORM crm_mcp.context();
  ELSIF auth.jwt()->>'role'='authenticated' AND public.get_tenant_id() IS NULL
    AND p NOT IN ('rpc/tenant_onboard','config') THEN
    RAISE EXCEPTION 'Conclua o cadastro da sua empresa' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_request_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mcp_request_guard() TO anon,authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

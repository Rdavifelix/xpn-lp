BEGIN;
CREATE OR REPLACE FUNCTION public.agent_playground_context(p_lead_id uuid,p_deal_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE tenant uuid:=public.get_tenant_id(); lead public.leads%ROWTYPE; deal public.deals%ROWTYPE;
 notes jsonb; activities jsonb; stages jsonb; team jsonb; pipe jsonb; result jsonb;
BEGIN
 IF auth.uid() IS NULL OR tenant IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL OR NOT EXISTS(
  SELECT 1 FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=tenant AND is_active AND role='admin'
 ) THEN RAISE EXCEPTION 'Administrador da empresa obrigatório' USING ERRCODE='42501'; END IF;
 SELECT * INTO lead FROM public.leads WHERE id=p_lead_id AND tenant_id=tenant;
 IF NOT FOUND THEN RAISE EXCEPTION 'Contato não encontrado nesta empresa' USING ERRCODE='42501'; END IF;
 IF p_deal_id IS NOT NULL THEN
  SELECT * INTO deal FROM public.deals WHERE id=p_deal_id AND lead_id=lead.id AND tenant_id=tenant;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oportunidade não pertence ao contato selecionado' USING ERRCODE='42501'; END IF;
 END IF;
 SELECT coalesce(jsonb_agg(n),'[]') INTO notes FROM (
  SELECT id,content,note_type,created_at FROM public.sales_notes WHERE tenant_id=tenant
   AND (lead_id=lead.id OR (p_deal_id IS NOT NULL AND deal_id=p_deal_id)) ORDER BY created_at DESC LIMIT 20
 ) n;
 SELECT coalesce(jsonb_agg(n),'[]') INTO activities FROM (
  SELECT id,name,description,task_type,status,scheduled_at,end_datetime,responsavel_id,completed
  FROM public.company_activities WHERE tenant_id=tenant AND lead_id=lead.id ORDER BY created_at DESC LIMIT 20
 ) n;
 SELECT jsonb_build_object('id',p.id,'name',p.name) INTO pipe FROM public.sales_pipelines p
 WHERE p.id=deal.pipeline_id AND p.tenant_id=tenant;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'position',s.position,'won',s.is_won,'lost',s.is_lost) ORDER BY s.position),'[]')
 INTO stages FROM public.sales_pipeline_stages s WHERE s.pipeline_id=deal.pipeline_id AND s.tenant_id=tenant;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'role',m.role)),'[]') INTO team
 FROM public.team_members m WHERE m.tenant_id=tenant AND m.is_active;
 result:=jsonb_build_object('lead_id',lead.id,'deal_id',p_deal_id,'lead',to_jsonb(lead)-'tenant_id',
  'deal',CASE WHEN p_deal_id IS NULL THEN NULL ELSE to_jsonb(deal)-'tenant_id' END,
  'pipeline',pipe,'stages',stages,'notes',notes,'activities',activities,'team',team,
  'history_limit',20,'execution_mode','real','loaded_at',now());
 IF octet_length(result::text)>100000 THEN RAISE EXCEPTION 'Contexto excede 100 KB. Reduza notas/campos extensos antes de testar.' USING ERRCODE='22023'; END IF;
 RETURN result;
END $$;
CREATE FUNCTION public.playground_assert_access(p_agent_id uuid,p_lead_id uuid) RETURNS void LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$
BEGIN
 PERFORM public.agent_playground_context(p_lead_id);
 IF NOT EXISTS(SELECT 1 FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=public.get_tenant_id() AND NOT is_template) THEN
  RAISE EXCEPTION 'Agente não pertence à empresa' USING ERRCODE='42501'; END IF;
END $$;
CREATE FUNCTION public.playground_change_stage(p_deal_id uuid,p_agent_id uuid,p_stage_name text DEFAULT NULL,p_stage_id uuid DEFAULT NULL,p_reason text DEFAULT NULL,p_session_id uuid DEFAULT NULL,p_allow_regression boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE d public.deals%ROWTYPE; target public.sales_pipeline_stages%ROWTYPE; pos integer;
BEGIN
 SELECT * INTO d FROM public.deals WHERE id=p_deal_id AND tenant_id=public.get_tenant_id() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Oportunidade não encontrada' USING ERRCODE='42501'; END IF;
 PERFORM public.playground_assert_access(p_agent_id,d.lead_id);
 SELECT * INTO target FROM public.sales_pipeline_stages WHERE pipeline_id=d.pipeline_id AND tenant_id=public.get_tenant_id()
  AND (CASE WHEN p_stage_id IS NOT NULL THEN id=p_stage_id ELSE lower(name)=lower(p_stage_name) END) ORDER BY position LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Etapa não pertence ao funil da oportunidade' USING ERRCODE='22023'; END IF;
 SELECT position INTO pos FROM public.sales_pipeline_stages WHERE id=d.pipeline_stage_id;
 IF NOT coalesce(p_allow_regression,false) AND target.position<pos THEN RETURN jsonb_build_object('ok',false,'error','regression_blocked'); END IF;
 UPDATE public.deals SET pipeline_stage_id=target.id,updated_at=now() WHERE id=d.id;
 RETURN jsonb_build_object('ok',true,'deal_id',d.id,'to_stage_id',target.id,'to_stage_name',target.name);
END $$;
CREATE FUNCTION public.playground_update_lead(p_lead_id uuid,p_agent_id uuid,p_patch jsonb,p_reason text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE k text; parts text[]:=ARRAY[]::text[]; allowed text[]:=ARRAY['name','email','phone','company_name','job_title','city','state','employee_count','website','instagram','linkedin','monthly_revenue_min','monthly_revenue_max','potential_revenue_brl','revenue_confidence','revenue_notes','challenges','goals','objections','lead_source','utm_source','utm_campaign'];
BEGIN
 PERFORM public.playground_assert_access(p_agent_id,p_lead_id);
 IF jsonb_typeof(p_patch) IS DISTINCT FROM 'object' OR p_patch='{}'::jsonb OR octet_length(p_patch::text)>10000 THEN RAISE EXCEPTION 'Atualização inválida' USING ERRCODE='22023'; END IF;
 IF p_patch?'company' THEN p_patch:=(p_patch-'company')||jsonb_build_object('company_name',p_patch->'company'); END IF;
 FOR k IN SELECT jsonb_object_keys(p_patch) LOOP
  IF NOT k=ANY(allowed) OR NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.leads'::regclass AND attname=k AND NOT attisdropped) THEN
   RAISE EXCEPTION 'Campo não permitido: %',k USING ERRCODE='22023'; END IF;
  parts:=array_append(parts,format('%I=(jsonb_populate_record(NULL::public.leads,$1)).%I',k,k));
 END LOOP;
 EXECUTE 'UPDATE public.leads SET '||array_to_string(parts,',')||',updated_at=now() WHERE id=$2 AND tenant_id=public.get_tenant_id()' USING p_patch,p_lead_id;
 RETURN jsonb_build_object('ok',true,'lead_id',p_lead_id,'applied',p_patch);
END $$;
CREATE FUNCTION public.playground_schedule_meeting(p_lead_id uuid,p_agent_id uuid,p_closer_id uuid,p_start_at timestamptz,p_duration_minutes integer DEFAULT 30,p_title text DEFAULT NULL,p_notes text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE id uuid; finish timestamptz; lead_name text;
BEGIN
 PERFORM public.playground_assert_access(p_agent_id,p_lead_id);
 IF p_start_at IS NULL OR p_start_at<now() OR p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 5 AND 480 THEN RAISE EXCEPTION 'Horário ou duração inválidos' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=p_closer_id AND tenant_id=public.get_tenant_id() AND is_active) THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_closer_id::text,1));
 finish:=p_start_at+make_interval(mins=>p_duration_minutes);
 SELECT ca.id INTO id FROM public.company_activities ca WHERE ca.lead_id=p_lead_id AND ca.responsavel_id=p_closer_id AND ca.scheduled_at=p_start_at AND ca.task_type='meeting' AND NOT ca.completed AND ca.tenant_id=public.get_tenant_id() LIMIT 1;
 IF id IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'deduped',true,'activity_id',id); END IF;
 IF EXISTS(SELECT 1 FROM public.company_activities ca WHERE ca.responsavel_id=p_closer_id AND ca.tenant_id=public.get_tenant_id() AND NOT ca.completed AND ca.task_type IN ('meeting','call') AND ca.scheduled_at<finish AND coalesce(ca.end_datetime,ca.scheduled_at+interval '30 minutes')>p_start_at) THEN
  RETURN jsonb_build_object('ok',false,'error','Horário ocupado para este responsável'); END IF;
 SELECT name INTO lead_name FROM public.leads WHERE public.leads.id=p_lead_id;
 INSERT INTO public.company_activities(lead_id,responsavel_id,task_type,name,description,scheduled_at,end_datetime,completed,team,tenant_id,metadata)
 VALUES(p_lead_id,p_closer_id,'meeting',coalesce(p_title,'Reunião com '||lead_name),p_notes,p_start_at,finish,false,'sales',public.get_tenant_id(),jsonb_build_object('created_by','playground','agent_id',p_agent_id)) RETURNING public.company_activities.id INTO id;
 RETURN jsonb_build_object('ok',true,'activity_id',id,'scheduled_at',p_start_at,'end_at',finish,'closer_id',p_closer_id,'calendar','CRM','external_calendar_synced',false);
END $$;
REVOKE ALL ON FUNCTION public.playground_assert_access(uuid,uuid), public.playground_change_stage(uuid,uuid,text,uuid,text,uuid,boolean),public.playground_update_lead(uuid,uuid,jsonb,text,uuid),public.playground_schedule_meeting(uuid,uuid,uuid,timestamptz,integer,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.playground_assert_access(uuid,uuid), public.playground_change_stage(uuid,uuid,text,uuid,text,uuid,boolean),public.playground_update_lead(uuid,uuid,jsonb,text,uuid),public.playground_schedule_meeting(uuid,uuid,uuid,timestamptz,integer,text,text,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

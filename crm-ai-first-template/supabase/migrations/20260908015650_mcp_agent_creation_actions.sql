BEGIN;
CREATE OR REPLACE FUNCTION public.agent_crm_action(p_agent_id uuid,p_session_id uuid,p_lead_id uuid,p_deal_id uuid,p_action text,p_args jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid;mid uuid;aid uuid;noteid uuid;act public.company_activities%ROWTYPE;result jsonb;starts timestamptz;finish timestamptz;v_title text;reason text;pid uuid;st uuid;
BEGIN
 PERFORM public.agent_assert_session(p_agent_id,p_session_id,p_lead_id,p_deal_id);
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id;
 IF jsonb_typeof(p_args) IS DISTINCT FROM 'object' OR octet_length(p_args::text)>25000 THEN RAISE EXCEPTION 'Argumentos inválidos' USING ERRCODE='22023';END IF;
 reason:=nullif(btrim(p_args->>'p_reason'),'');
 PERFORM pg_advisory_xact_lock(hashtextextended(p_session_id::text,1));
 IF p_action IN ('lead_create','deal_create') THEN
  IF p_action='lead_create' THEN
   IF length(btrim(coalesce(p_args->>'p_name',''))) NOT BETWEEN 2 AND 200 OR length(coalesce(p_args->>'p_email',''))>254 OR length(coalesce(p_args->>'p_phone',''))>40 THEN RAISE EXCEPTION 'Nome/email/telefone inválidos' USING ERRCODE='22023';END IF;
   IF nullif(p_args->>'p_email','') IS NULL AND nullif(p_args->>'p_phone','') IS NULL THEN RAISE EXCEPTION 'Email ou telefone obrigatório para evitar duplicação' USING ERRCODE='22023';END IF;
   PERFORM pg_advisory_xact_lock(hashtextextended(tid::text,2));
   SELECT id INTO aid FROM public.leads WHERE tenant_id=tid AND ((nullif(p_args->>'p_email','') IS NOT NULL AND lower(email)=lower(p_args->>'p_email')) OR (nullif(p_args->>'p_phone','') IS NOT NULL AND phone=p_args->>'p_phone')) ORDER BY created_at LIMIT 1;
   IF aid IS NULL THEN INSERT INTO public.leads(tenant_id,name,email,phone,lead_source) VALUES(tid,btrim(p_args->>'p_name'),nullif(p_args->>'p_email',''),nullif(p_args->>'p_phone',''),p_args->>'p_source') RETURNING id INTO aid;END IF;
   result:=jsonb_build_object('ok',true,'lead_id',aid,'context_unchanged',true);
  ELSE aid:=p_lead_id;END IF;
  IF p_action='deal_create' OR coalesce((p_args->>'p_create_deal')::boolean,false) THEN
   SELECT pipeline_id INTO pid FROM public.deals WHERE id=p_deal_id AND tenant_id=tid;
   IF pid IS NULL THEN SELECT nullif(settings->>'pipeline_id','')::uuid INTO pid FROM public.agents_registry WHERE id=p_agent_id;END IF;
   IF pid IS NULL AND (SELECT count(*) FROM public.sales_pipelines WHERE tenant_id=tid)=1 THEN SELECT id INTO pid FROM public.sales_pipelines WHERE tenant_id=tid;END IF;
   SELECT id INTO st FROM public.sales_pipeline_stages WHERE tenant_id=tid AND pipeline_id=pid AND NOT is_lost AND NOT is_won ORDER BY position LIMIT 1;
   IF st IS NULL THEN RAISE EXCEPTION 'Selecione um funil no contexto/configuração antes de criar a oportunidade' USING ERRCODE='22023';END IF;
   IF coalesce((p_args->>'p_value')::numeric,0)<0 THEN RAISE EXCEPTION 'Valor inválido' USING ERRCODE='22023';END IF;
   v_title:=coalesce(p_args->>'p_title',p_args->>'p_deal_title','Nova oportunidade');
   SELECT id INTO noteid FROM public.deals WHERE tenant_id=tid AND lead_id=aid AND pipeline_id=pid AND status NOT IN ('won','lost') ORDER BY created_at LIMIT 1;
   IF noteid IS NULL THEN INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,original_price,status) VALUES(tid,aid,v_title,pid,st,coalesce((p_args->>'p_value')::numeric,0),'open') RETURNING id INTO noteid;END IF;
   result:=jsonb_build_object('ok',true,'lead_id',aid,'deal_id',noteid,'context_unchanged',true);
  END IF;
 ELSIF p_action IN ('hot_leads','my_deals','pipeline_summary') THEN
  IF p_action='hot_leads' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (SELECT id,name,company_name,lead_temperature FROM public.leads WHERE tenant_id=tid AND lead_temperature='hot' ORDER BY updated_at DESC LIMIT 30)x;
  ELSIF p_action='my_deals' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (SELECT id,lead_id,title,status,pipeline_id,pipeline_stage_id FROM public.deals WHERE tenant_id=tid AND sales_rep_id=(SELECT user_id FROM public.agents_sessions WHERE id=p_session_id) ORDER BY updated_at DESC LIMIT 30)x;
  ELSE SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (SELECT pipeline_id,pipeline_stage_id,status,count(*) AS count FROM public.deals WHERE tenant_id=tid GROUP BY pipeline_id,pipeline_stage_id,status LIMIT 100)x;END IF;
  RETURN jsonb_build_object('ok',true,'items',result);
 ELSIF p_action IN ('task_create','followup') THEN
  v_title:=CASE WHEN p_action='followup' THEN 'Retomada interna: '||left(coalesce(p_args->>'p_message_brief','Contato'),120) ELSE p_args->>'p_name' END;
  IF length(btrim(coalesce(v_title,''))) NOT BETWEEN 2 AND 200 THEN RAISE EXCEPTION 'Nome de tarefa inválido' USING ERRCODE='22023';END IF;
  SELECT id INTO mid FROM public.team_members WHERE tenant_id=tid AND is_active AND id=coalesce(nullif(p_args->>'p_responsavel_id','')::uuid,(SELECT user_id FROM public.agents_sessions WHERE id=p_session_id));
  IF mid IS NULL THEN SELECT id INTO mid FROM public.team_members WHERE tenant_id=tid AND is_active AND role='admin' ORDER BY id LIMIT 1;END IF;
  IF mid IS NULL THEN RAISE EXCEPTION 'Responsável ativo obrigatório' USING ERRCODE='22023';END IF;
  IF p_args->>'p_responsavel_id' IS NOT NULL AND mid::text<>p_args->>'p_responsavel_id' THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501';END IF;
  starts:=coalesce(nullif(p_args->>'p_due_at','')::timestamptz,nullif(p_args->>'p_scheduled_for','')::timestamptz);
  IF p_action='followup' AND (starts IS NULL OR starts<now()) THEN RAISE EXCEPTION 'Informe data futura para a retomada interna' USING ERRCODE='22023';END IF;
  IF p_args->>'p_priority' IS NOT NULL AND p_args->>'p_priority' NOT IN ('low','medium','high','urgent') THEN RAISE EXCEPTION 'Prioridade inválida' USING ERRCODE='22023';END IF;
  SELECT id INTO aid FROM public.company_activities WHERE tenant_id=tid AND metadata->>'agent_session_id'=p_session_id::text AND metadata->>'action'=p_action AND name=v_title AND due_datetime IS NOT DISTINCT FROM starts AND NOT completed AND status<>'cancelled' ORDER BY created_at DESC LIMIT 1;
  IF aid IS NULL THEN
   INSERT INTO public.company_activities(tenant_id,lead_id,name,description,priority,task_type,status,completed,responsavel_id,due_datetime,metadata)
   VALUES(tid,p_lead_id,v_title,coalesce(p_args->>'p_description',p_args->>'p_message_brief'),coalesce(p_args->>'p_priority','medium'),'internal','pending',false,mid,starts,jsonb_build_object('agent_id',p_agent_id,'agent_session_id',p_session_id,'deal_id',p_deal_id,'action',p_action,'reason',reason)) RETURNING id INTO aid;
  END IF;
  result:=jsonb_build_object('ok',true,'task_id',aid,'scheduled_for',starts,'delivery','internal_task','external_message_sent',false);
 ELSIF p_action IN ('task_complete','meeting_confirm','meeting_reschedule','meeting_cancel') THEN
  aid:=coalesce(nullif(p_args->>'p_activity_id','')::uuid,nullif(p_args->>'p_task_id','')::uuid);
  SELECT * INTO act FROM public.company_activities WHERE id=aid AND tenant_id=tid AND lead_id=p_lead_id FOR UPDATE;
  IF NOT FOUND OR (act.metadata->>'deal_id' IS NOT NULL AND act.metadata->>'deal_id' IS DISTINCT FROM p_deal_id::text) THEN RAISE EXCEPTION 'Atividade não pertence ao contato/oportunidade da sessão' USING ERRCODE='42501';END IF;
  IF p_action<>'task_complete' AND act.task_type NOT IN ('meeting','call') THEN RAISE EXCEPTION 'Atividade não é uma reunião' USING ERRCODE='22023';END IF;
  IF p_action='task_complete' AND act.task_type IN ('meeting','call') THEN RAISE EXCEPTION 'Use a operação de reunião' USING ERRCODE='22023';END IF;
  IF p_action IN ('meeting_reschedule','meeting_cancel') AND length(coalesce(reason,'')) NOT BETWEEN 3 AND 2000 THEN RAISE EXCEPTION 'Informe o motivo' USING ERRCODE='22023';END IF;
  IF p_action IN ('meeting_confirm','meeting_reschedule') AND (act.status='cancelled' OR act.completed) THEN RAISE EXCEPTION 'Reunião encerrada não pode ser alterada' USING ERRCODE='22023';END IF;
  IF p_action='meeting_reschedule' THEN
   starts:=nullif(p_args->>'p_new_start_at','')::timestamptz;
   IF starts IS NULL OR starts<now() OR act.scheduled_at IS NULL OR act.end_datetime IS NULL THEN RAISE EXCEPTION 'Horário futuro e duração existente obrigatórios' USING ERRCODE='22023';END IF;
   finish:=starts+(act.end_datetime-act.scheduled_at);
   UPDATE public.company_activities SET scheduled_at=starts,end_datetime=finish,updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('reschedule_reason',reason) WHERE id=aid;
  ELSIF p_action='meeting_cancel' THEN
   UPDATE public.company_activities SET status='cancelled',updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('cancel_reason',reason,'cancelled_at',now()) WHERE id=aid;
  ELSIF p_action='meeting_confirm' THEN
   UPDATE public.company_activities SET confirmed_by_client=true,updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('confirmed',true,'confirmed_at',now()) WHERE id=aid;
  ELSE UPDATE public.company_activities SET completed=true,status='completed',completed_at=now(),updated_at=now() WHERE id=aid;END IF;
  result:=jsonb_build_object('ok',true,'activity_id',aid,'task_id',aid,'action',p_action,'scheduled_at',starts,'end_datetime',finish,'external_sync',false);
 ELSIF p_action='team' THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'role',role,'sub_role',sub_role)),'[]') INTO result FROM public.team_members WHERE tenant_id=tid AND is_active;
  RETURN jsonb_build_object('ok',true,'members',result);
 ELSIF p_action IN ('notes_list','notes_read','notes_search','notes_save') THEN
  IF p_action='notes_save' THEN
   v_title:=btrim(coalesce(p_args->>'p_title',''));
   IF length(v_title) NOT BETWEEN 2 AND 200 OR length(coalesce(p_args->>'p_content','')) NOT BETWEEN 1 AND 20000 THEN RAISE EXCEPTION 'Título/conteúdo inválidos' USING ERRCODE='22023';END IF;
   SELECT id INTO noteid FROM public.agent_notes WHERE agent_id=p_agent_id AND tenant_id=tid AND title=v_title AND NOT archived FOR UPDATE;
   IF noteid IS NULL THEN
    INSERT INTO public.agent_notes(tenant_id,agent_id,title,slug,content,metadata) VALUES(tid,p_agent_id,v_title,gen_random_uuid()::text,p_args->>'p_content',jsonb_build_object('last_author','agent')) RETURNING id INTO noteid;
   ELSE
    UPDATE public.agent_notes SET content=CASE WHEN p_args->>'p_mode'='append' THEN content||E'\n'||(p_args->>'p_content') ELSE p_args->>'p_content' END,metadata=coalesce(metadata,'{}')||jsonb_build_object('last_author','agent'),updated_at=now() WHERE id=noteid;
   END IF;
   result:=jsonb_build_object('ok',true,'note_id',noteid);
  ELSE
   SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (SELECT id,title,content,tags FROM public.agent_notes WHERE agent_id=p_agent_id AND tenant_id=tid AND NOT archived
   AND (p_action<>'notes_read' OR title=p_args->>'p_title')
   AND (p_action<>'notes_search' OR title ILIKE '%'||coalesce(p_args->>'p_query','')||'%' OR content ILIKE '%'||coalesce(p_args->>'p_query','')||'%')
   ORDER BY updated_at DESC LIMIT 20)x;
   RETURN jsonb_build_object('ok',true,'notes',result,'search_mode','text');
  END IF;
 ELSE RAISE EXCEPTION 'Ação não disponível' USING ERRCODE='22023';END IF;
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(tid,p_lead_id,'agent_action',coalesce(reason,p_action),jsonb_build_object('agent_id',p_agent_id,'session_id',p_session_id,'deal_id',p_deal_id,'action',p_action,'result',result));
 RETURN result;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

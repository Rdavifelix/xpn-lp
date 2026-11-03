BEGIN;
CREATE OR REPLACE FUNCTION public.agent_qualify_lead(p_lead_id uuid, p_agent_id uuid, p_monthly_revenue_min numeric DEFAULT NULL::numeric, p_monthly_revenue_max numeric DEFAULT NULL::numeric, p_potential_revenue numeric DEFAULT NULL::numeric, p_revenue_confidence text DEFAULT 'low'::text, p_revenue_notes text DEFAULT NULL::text, p_authority text DEFAULT NULL::text, p_timeline_months integer DEFAULT NULL::integer, p_need_score integer DEFAULT NULL::integer, p_icp_decision text DEFAULT 'unknown'::text, p_reason text DEFAULT NULL::text, p_session_id uuid DEFAULT NULL::uuid, p_criteria_used jsonb DEFAULT NULL::jsonb, p_llm_input jsonb DEFAULT NULL::jsonb, p_llm_output jsonb DEFAULT NULL::jsonb, p_llm_model text DEFAULT NULL::text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid;did uuid;decision uuid:=gen_random_uuid();q jsonb;BEGIN
 SELECT tenant_id INTO tid FROM public.agents_registry WHERE id=p_agent_id;
 IF tid IS NULL OR NOT EXISTS(SELECT 1 FROM public.leads WHERE id=p_lead_id AND tenant_id=tid) OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=tid AND is_active) THEN RAISE EXCEPTION 'Contexto inválido' USING ERRCODE='42501';END IF;
 IF p_session_id IS NOT NULL THEN
  SELECT nullif(playground_context->>'deal_id','')::uuid INTO did FROM public.agents_sessions WHERE id=p_session_id AND agent_id=p_agent_id AND tenant_id=tid AND (playground_context IS NULL OR playground_context->>'lead_id'=p_lead_id::text);
  IF NOT FOUND THEN RAISE EXCEPTION 'Sessão incompatível' USING ERRCODE='42501';END IF;
 END IF;
 IF did IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.deals WHERE id=did AND tenant_id=tid AND lead_id=p_lead_id AND status NOT IN ('won','lost')) THEN RAISE EXCEPTION 'Oportunidade encerrada ou incompatível' USING ERRCODE='22023';END IF;
 IF nullif(btrim(p_reason),'') IS NULL OR length(p_reason)>3000 OR coalesce(p_icp_decision,'') NOT IN ('qualified','borderline','rejected','unknown') OR p_monthly_revenue_min<0 OR p_monthly_revenue_max<0 OR p_monthly_revenue_min>p_monthly_revenue_max OR p_potential_revenue<0 OR p_need_score NOT BETWEEN 0 AND 100 OR p_timeline_months<0 OR p_authority IS NOT NULL AND p_authority NOT IN ('decisor','influenciador','usuario') OR p_revenue_confidence IS NOT NULL AND p_revenue_confidence NOT IN ('high','medium','low') THEN RAISE EXCEPTION 'Dados de qualificação inválidos; informe motivo e valores declarados' USING ERRCODE='22023';END IF;
 q:=jsonb_strip_nulls(jsonb_build_object('icp_decision',p_icp_decision,'reason',p_reason,'monthly_revenue_min',p_monthly_revenue_min,'monthly_revenue_max',p_monthly_revenue_max,'potential_revenue',p_potential_revenue,'authority',p_authority,'timeline_months',p_timeline_months,'need_score',p_need_score,'revenue_notes',p_revenue_notes,'revenue_confidence',p_revenue_confidence,'decision_id',decision,'agent_id',p_agent_id,'updated_at',now()));
 UPDATE public.leads SET monthly_revenue=CASE WHEN p_monthly_revenue_min=p_monthly_revenue_max THEN p_monthly_revenue_min ELSE monthly_revenue END,qualification=coalesce(qualification,'{}')||q,bant_authority=CASE WHEN p_authority IS NULL THEN bant_authority ELSE p_authority IN ('decisor','influenciador') END,bant_need=CASE WHEN p_need_score IS NULL THEN bant_need ELSE p_need_score>=50 END,bant_timeline=CASE WHEN p_timeline_months IS NULL THEN bant_timeline ELSE p_timeline_months<=3 END,updated_at=now() WHERE id=p_lead_id AND tenant_id=tid;
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(tid,p_lead_id,'qualification',p_reason,q||jsonb_build_object('deal_id',did,'session_id',p_session_id));
 RETURN jsonb_build_object('ok',true,'lead_id',p_lead_id,'classification',p_icp_decision,'decision_id',decision,'next_action',CASE p_icp_decision WHEN 'qualified' THEN 'schedule_meeting' WHEN 'rejected' THEN 'soft_decline' ELSE 'continue_conversation' END);
END
$$;
CREATE FUNCTION public.playground_qualify_lead(p_lead_id uuid, p_agent_id uuid, p_monthly_revenue_min numeric DEFAULT NULL::numeric, p_monthly_revenue_max numeric DEFAULT NULL::numeric, p_potential_revenue numeric DEFAULT NULL::numeric, p_revenue_confidence text DEFAULT 'low'::text, p_revenue_notes text DEFAULT NULL::text, p_authority text DEFAULT NULL::text, p_timeline_months integer DEFAULT NULL::integer, p_need_score integer DEFAULT NULL::integer, p_icp_decision text DEFAULT 'unknown'::text, p_reason text DEFAULT NULL::text, p_session_id uuid DEFAULT NULL::uuid, p_criteria_used jsonb DEFAULT NULL::jsonb, p_llm_input jsonb DEFAULT NULL::jsonb, p_llm_output jsonb DEFAULT NULL::jsonb, p_llm_model text DEFAULT NULL::text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN PERFORM public.playground_assert_access(p_agent_id,p_lead_id); RETURN public.agent_qualify_lead(p_lead_id,p_agent_id,p_monthly_revenue_min,p_monthly_revenue_max,p_potential_revenue,p_revenue_confidence,p_revenue_notes,p_authority,p_timeline_months,p_need_score,p_icp_decision,p_reason,p_session_id,p_criteria_used,p_llm_input,p_llm_output,p_llm_model);END $$;
REVOKE ALL ON FUNCTION public.agent_qualify_lead(uuid,uuid,numeric,numeric,numeric,text,text,text,integer,integer,text,text,uuid,jsonb,jsonb,jsonb,text),public.playground_qualify_lead(uuid,uuid,numeric,numeric,numeric,text,text,text,integer,integer,text,text,uuid,jsonb,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.agent_qualify_lead(uuid,uuid,numeric,numeric,numeric,text,text,text,integer,integer,text,text,uuid,jsonb,jsonb,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.playground_qualify_lead(uuid,uuid,numeric,numeric,numeric,text,text,text,integer,integer,text,text,uuid,jsonb,jsonb,jsonb,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/playground_qualify_lead','rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

CREATE OR REPLACE FUNCTION public.playground_update_lead(p_lead_id uuid,p_agent_id uuid,p_patch jsonb,p_reason text DEFAULT NULL,p_session_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE k text; parts text[]:=ARRAY[]::text[]; allowed text[]:=ARRAY['name','email','phone','company_name','job_title','city','state','employee_count','website','instagram','linkedin','monthly_revenue_min','monthly_revenue_max','potential_revenue_brl','revenue_confidence','revenue_notes','challenges','goals','objections','lead_source','utm_source','utm_campaign','context','qualification','monthly_revenue','city_name'];
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

NOTIFY pgrst,'reload schema';
COMMIT;

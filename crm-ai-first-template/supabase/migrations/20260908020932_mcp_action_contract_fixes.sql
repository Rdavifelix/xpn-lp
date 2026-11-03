BEGIN;
CREATE OR REPLACE FUNCTION public.mcp_automation(p_action text,p_id uuid,p_request_id uuid DEFAULT NULL,p_active boolean DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid;r public.sales_automation_rules%ROWTYPE;payload jsonb;old crm_mcp.operations%ROWTYPE;result jsonb;s uuid;target public.sales_pipeline_stages%ROWTYPE;
BEGIN
 SELECT * INTO r FROM public.sales_automation_rules WHERE id=p_id AND tenant_id=tid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Automação não encontrada' USING ERRCODE='42501';END IF;
 IF p_action='runs' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM(SELECT ar.id,ar.event,ar.entity_id,ar.status,ar.result,ar.created_at FROM crm_mcp.automation_runs ar WHERE ar.tenant_id=tid AND ar.rule_id=p_id ORDER BY ar.created_at DESC LIMIT 100)x;RETURN result;END IF;
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_action<>'activate' OR p_request_id IS NULL OR p_active IS NULL THEN RAISE EXCEPTION 'Operação inválida' USING ERRCODE='22023';END IF;
 payload:=jsonb_build_object('operation','automation_activate','id',p_id,'active',p_active);
 PERFORM pg_advisory_xact_lock(hashtextextended(tid::text,0));
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tid AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023';END IF;RETURN old.result;END IF;
 IF p_active THEN
  IF r.trigger_type NOT IN ('deal_created','deal_stage_changed','task_created','task_completed','meeting_scheduled','meeting_cancelled','meeting_rescheduled') OR r.action_type NOT IN ('move_deal_stage','create_task') THEN RAISE EXCEPTION 'Este executor suporta eventos de oportunidade/tarefa/reunião e ações internas move_deal_stage/create_task. Envios e temporizadores exigem outro executor.' USING ERRCODE='22023';END IF;
  IF coalesce(r.trigger_conditions,'{}')-ARRAY['stage_ids','exclude_stages','task_types','has_scheduled_date']<>'{}' THEN RAISE EXCEPTION 'Condições não suportadas pelo executor' USING ERRCODE='22023';END IF;
  FOR s IN SELECT x::uuid FROM jsonb_array_elements_text(coalesce(r.trigger_conditions->'stage_ids','[]')||coalesce(r.trigger_conditions->'exclude_stages','[]')) x LOOP
   IF NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=s AND tenant_id=tid) THEN RAISE EXCEPTION 'Etapa de outra empresa' USING ERRCODE='42501';END IF;
  END LOOP;
  IF r.action_type='move_deal_stage' THEN
   IF r.action_config-ARRAY['target_stage_id','only_if_position_less_than','executor','owner_id']<>'{}' THEN RAISE EXCEPTION 'Configuração de movimentação inválida' USING ERRCODE='22023';END IF;
   SELECT * INTO target FROM public.sales_pipeline_stages WHERE id=(r.action_config->>'target_stage_id')::uuid AND tenant_id=tid;
   IF NOT FOUND OR target.is_won OR target.is_lost THEN RAISE EXCEPTION 'Selecione etapa intermediária da empresa; encerramento exige ação explícita' USING ERRCODE='22023';END IF;
  ELSE
   IF length(coalesce(r.action_config->'task_template'->>'name','')) NOT BETWEEN 2 AND 200 OR r.action_config-ARRAY['task_template','executor','owner_id']<>'{}' OR (r.action_config->'task_template')-ARRAY['name','description','days_offset','task_type','responsavel_id']<>'{}' OR coalesce(r.action_config->'task_template'->>'task_type','internal') NOT IN ('internal','follow_up') OR coalesce((r.action_config->'task_template'->>'days_offset')::integer,0) NOT BETWEEN 0 AND 365 THEN RAISE EXCEPTION 'Template de tarefa interna inválido' USING ERRCODE='22023';END IF;
   IF r.action_config->'task_template'->>'responsavel_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=(r.action_config->'task_template'->>'responsavel_id')::uuid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável não pertence à empresa' USING ERRCODE='42501';END IF;
  END IF;
 END IF;
 UPDATE public.sales_automation_rules SET is_active=p_active,action_config=coalesce(action_config,'{}')||jsonb_build_object('executor','mcp_sql','owner_id',(ctx->>'member_id')),updated_at=now() WHERE id=p_id AND tenant_id=tid;
 result:=jsonb_build_object('id',p_id,'active',p_active,'executor','mcp_sql','external_messages',false,'note','Execução em novos eventos; não reaplica ao histórico. Sem encadeamento recursivo de regras.');
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tid,p_request_id,auth.uid(),payload,result);RETURN result;
END $$;
WITH old AS (SELECT parameters_schema FROM public.agents_skill_catalog WHERE slug='reschedule_meeting'),
updated AS (UPDATE public.agents_skill_catalog SET parameters_schema=jsonb_set(jsonb_set(parameters_schema,'{properties,activity_id}','{"type":"string","format":"uuid","description":"ID real da reunião a remarcar"}'),'{required}',coalesce(parameters_schema->'required','[]')||'"activity_id"'::jsonb) WHERE slug='reschedule_meeting' AND NOT parameters_schema->'properties'?'activity_id' RETURNING parameters_schema),
tools AS (UPDATE public.agents_tools SET parameters_schema=updated.parameters_schema FROM old,updated WHERE name='reschedule_meeting' AND agents_tools.parameters_schema=old.parameters_schema RETURNING agent_id)
UPDATE public.agents_registry SET version=version+1,updated_at=now() WHERE id IN(SELECT agent_id FROM tools);
NOTIFY pgrst,'reload schema';
COMMIT;

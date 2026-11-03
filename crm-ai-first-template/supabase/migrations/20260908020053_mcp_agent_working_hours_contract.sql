BEGIN;
CREATE OR REPLACE FUNCTION public.mcp_agent_admin(p_action text,p_agent_id uuid,p_request_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE ctx jsonb:=crm_mcp.context();tid uuid:=(ctx->>'tenant_id')::uuid; result jsonb;payload jsonb;old crm_mcp.operations%ROWTYPE;aid uuid;key text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.agents_registry WHERE id=p_agent_id AND tenant_id=tid AND NOT is_template) THEN RAISE EXCEPTION 'Agente não encontrado' USING ERRCODE='42501';END IF;
 IF p_action='knowledge_list' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM(SELECT id,title,content,tags,archived,updated_at FROM public.agent_notes WHERE agent_id=p_agent_id AND tenant_id=tid ORDER BY updated_at DESC LIMIT 100)x;RETURN result;END IF;
 IF p_action='settings_get' THEN SELECT jsonb_build_object('agent_id',id,'version',version,'responsible_user_id',responsible_user_id,'daily_token_limit',daily_token_limit,'daily_cost_limit_brl',daily_cost_limit_brl,'settings',crm_mcp.redact(settings)) INTO result FROM public.agents_registry WHERE id=p_agent_id;RETURN result;END IF;
 IF NOT (ctx->>'can_write')::boolean THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_request_id IS NULL OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR octet_length(p_data::text)>50000 THEN RAISE EXCEPTION 'Dados inválidos' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(tid::text,0));
 payload:=jsonb_build_object('operation','agent_admin','action',p_action,'agent_id',p_agent_id,'id',p_id,'data',p_data);
 SELECT * INTO old FROM crm_mcp.operations WHERE tenant_id=tid AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload OR old.user_id<>auth.uid() THEN RAISE EXCEPTION 'request_id já usado' USING ERRCODE='22023';END IF;RETURN old.result;END IF;
 IF p_action='knowledge_save' THEN
  IF p_data-ARRAY['title','content','tags','archived']<>'{}' OR length(coalesce(p_data->>'title','')) NOT BETWEEN 2 AND 200 OR length(coalesce(p_data->>'content','')) NOT BETWEEN 1 AND 20000 THEN RAISE EXCEPTION 'Título/conteúdo inválidos' USING ERRCODE='22023';END IF;
  IF p_id IS NOT NULL THEN
   UPDATE public.agent_notes SET title=p_data->>'title',content=p_data->>'content',tags=ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'tags','[]'))),archived=coalesce((p_data->>'archived')::boolean,false),updated_at=now(),metadata=coalesce(metadata,'{}')||jsonb_build_object('last_author','human','author_id',auth.uid()) WHERE id=p_id AND agent_id=p_agent_id AND tenant_id=tid RETURNING id INTO aid;
   IF aid IS NULL THEN RAISE EXCEPTION 'Conhecimento não pertence ao agente' USING ERRCODE='42501';END IF;
  ELSE
   INSERT INTO public.agent_notes(tenant_id,agent_id,owner_user_id,title,slug,content,tags,metadata) VALUES(tid,p_agent_id,(ctx->>'member_id')::uuid,p_data->>'title',gen_random_uuid()::text,p_data->>'content',ARRAY(SELECT jsonb_array_elements_text(coalesce(p_data->'tags','[]'))),jsonb_build_object('last_author','human')) RETURNING id INTO aid;
  END IF;
  result:=jsonb_build_object('note_id',aid,'saved',true);
 ELSIF p_action='settings_save' THEN
  IF p_data-ARRAY['responsible_user_id','icp_criteria','working_hours_start','working_hours_end','working_days','max_tool_iterations','max_tokens','temperature']<>'{}' THEN RAISE EXCEPTION 'Configuração não permitida; credenciais/canais têm fluxo próprio' USING ERRCODE='22023';END IF;
  IF p_data?'responsible_user_id' AND NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=(p_data->>'responsible_user_id')::uuid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável inválido' USING ERRCODE='42501';END IF;
  IF p_data?'max_tool_iterations' AND (p_data->>'max_tool_iterations')::integer NOT BETWEEN 1 AND 30 OR p_data?'max_tokens' AND (p_data->>'max_tokens')::integer NOT BETWEEN 100 AND 32000 OR p_data?'temperature' AND (p_data->>'temperature')::numeric NOT BETWEEN 0 AND 2 THEN RAISE EXCEPTION 'Limites inválidos' USING ERRCODE='22023';END IF;
  IF (p_data?'working_hours_start' AND coalesce(p_data->>'working_hours_start','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$') OR (p_data?'working_hours_end' AND coalesce(p_data->>'working_hours_end','')!~'^([01][0-9]|2[0-3]):[0-5][0-9]$') OR (p_data?'working_days' AND (jsonb_typeof(p_data->'working_days') IS DISTINCT FROM 'array' OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(p_data->'working_days') d WHERE d!~'^[0-6]$'))) THEN RAISE EXCEPTION 'Horários/dias inválidos' USING ERRCODE='22023';END IF;
  UPDATE public.agents_registry SET responsible_user_id=coalesce((p_data->>'responsible_user_id')::uuid,responsible_user_id),daily_token_limit=coalesce((p_data->>'daily_token_limit')::integer,daily_token_limit),daily_cost_limit_brl=coalesce((p_data->>'daily_cost_limit_brl')::numeric,daily_cost_limit_brl),settings=coalesce(settings,'{}')||(p_data-ARRAY['responsible_user_id','daily_token_limit','daily_cost_limit_brl']) WHERE id=p_agent_id;
  result:=jsonb_build_object('agent_id',p_agent_id,'saved',true);
 ELSIF p_action='skill_set' THEN
  IF p_data-ARRAY['skill','enabled']<>'{}' OR jsonb_typeof(p_data->'enabled') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Habilidade inválida' USING ERRCODE='22023';END IF;
  UPDATE public.agents_tools SET is_active=(p_data->>'enabled')::boolean,usage_mode=CASE WHEN (p_data->>'enabled')::boolean THEN 'always' ELSE 'disabled' END WHERE agent_id=p_agent_id AND tenant_id=tid AND name=p_data->>'skill' AND NOT requires_approval;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vincule a habilidade primeiro. Aprovação externa obrigatória não pode ser ignorada.' USING ERRCODE='22023';END IF;
  result:=jsonb_build_object('agent_id',p_agent_id,'skill',p_data->>'skill','enabled',(p_data->>'enabled')::boolean);
 ELSE RAISE EXCEPTION 'Operação inválida' USING ERRCODE='22023';END IF;
 UPDATE public.agents_registry SET version=version+1,updated_at=now() WHERE id=p_agent_id AND tenant_id=tid;
 INSERT INTO crm_mcp.operations(tenant_id,request_id,user_id,payload,result) VALUES(tid,p_request_id,auth.uid(),payload,result);
 RETURN result;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

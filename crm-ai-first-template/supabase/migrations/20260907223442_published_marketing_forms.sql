BEGIN;
CREATE SCHEMA crm_forms;
REVOKE ALL ON SCHEMA crm_forms FROM PUBLIC,anon,authenticated;
ALTER TABLE public.marketing_forms ADD COLUMN revision integer NOT NULL DEFAULT 1,ADD COLUMN published_revision integer,ADD COLUMN published_snapshot jsonb,ADD COLUMN published_at timestamptz;
ALTER TABLE public.marketing_forms ALTER COLUMN is_active SET DEFAULT false;
DROP POLICY marketing_forms_anon_update_stats ON public.marketing_forms;
DROP POLICY marketing_forms_public_read ON public.marketing_forms;
DROP POLICY marketing_forms_tenant ON public.marketing_forms;
CREATE POLICY forms_own_read ON public.marketing_forms FOR SELECT TO authenticated USING(tenant_id=public.get_tenant_id());
REVOKE ALL ON public.marketing_forms FROM anon;
REVOKE INSERT,UPDATE,DELETE ON public.marketing_forms FROM authenticated;
CREATE TABLE crm_forms.submissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),form_id uuid NOT NULL REFERENCES public.marketing_forms(id),tenant_id uuid NOT NULL REFERENCES public.tenants(id),request_id uuid NOT NULL,payload jsonb NOT NULL,answers jsonb NOT NULL DEFAULT '{}',lead_id uuid NOT NULL REFERENCES public.leads(id),deal_id uuid REFERENCES public.deals(id),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(form_id,request_id));
CREATE INDEX form_submissions_tenant ON crm_forms.submissions(tenant_id,form_id,created_at);
CREATE TABLE crm_forms.rate_limits(form_id uuid NOT NULL,client_hash text NOT NULL,bucket timestamptz NOT NULL,hits integer NOT NULL,PRIMARY KEY(form_id,client_hash,bucket));
ALTER TABLE crm_forms.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_forms.rate_limits ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION crm_forms.validate(f public.marketing_forms) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE field jsonb; keys text[]:='{}'; maps text[]:='{}'; key text; mapping text; pipe uuid; stage uuid; owner uuid; BEGIN
 IF jsonb_typeof(f.fields) IS DISTINCT FROM 'array' OR jsonb_array_length(f.fields) NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'Adicione entre 1 e 50 campos' USING ERRCODE='22023';END IF;
 FOR field IN SELECT value FROM jsonb_array_elements(f.fields) LOOP
  key:=field->>'id';mapping:=nullif(field->>'map_to','');
  IF key IS NULL OR key!~'^[a-zA-Z0-9_-]{1,100}$' OR key=ANY(keys) OR length(btrim(coalesce(field->>'label',''))) NOT BETWEEN 1 AND 200 OR coalesce(field->>'type','') NOT IN ('text','email','phone','number','select','state','city','capital','textarea','hidden') OR jsonb_typeof(field->'required') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Campo inválido ou repetido' USING ERRCODE='22023'; END IF;
  keys:=array_append(keys,key);
  IF mapping IS NOT NULL THEN
   IF mapping=ANY(maps) OR mapping NOT IN ('nome','email','phone','cidade','estado','capital_disponivel','ocupacao','melhor_horario','utm_source','utm_medium','utm_campaign','utm_content','utm_term') THEN RAISE EXCEPTION 'Mapeamento inválido ou repetido' USING ERRCODE='22023'; END IF;maps:=array_append(maps,mapping);
  END IF;
  IF field->>'type'='select' AND (jsonb_typeof(field->'options') IS DISTINCT FROM 'array' OR jsonb_array_length(field->'options') NOT BETWEEN 1 AND 100) THEN RAISE EXCEPTION 'Configure opções da seleção' USING ERRCODE='22023';END IF;
 END LOOP;
 IF NOT 'nome'=ANY(maps) OR NOT ('email'=ANY(maps) OR 'phone'=ANY(maps)) THEN RAISE EXCEPTION 'Mapeie Nome e Email ou Telefone antes de publicar' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(f.fields) x WHERE x->>'map_to'='nome' AND (x->>'required')::boolean) OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(f.fields) x WHERE x->>'map_to' IN ('email','phone') AND (x->>'required')::boolean) THEN RAISE EXCEPTION 'Nome e um meio de contato devem ser obrigatórios' USING ERRCODE='22023';END IF;
 pipe:=(f.settings->>'pipeline_id')::uuid; stage:=(f.settings->>'stage_id')::uuid; owner:=(f.settings->>'responsible_id')::uuid;
 IF NOT EXISTS(SELECT 1 FROM public.sales_pipelines WHERE id=pipe AND tenant_id=f.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=stage AND pipeline_id=pipe AND tenant_id=f.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Escolha um funil ativo e sua etapa inicial' USING ERRCODE='22023';END IF;
 IF owner IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=owner AND tenant_id=f.tenant_id AND is_active) THEN RAISE EXCEPTION 'Responsável inválido' USING ERRCODE='22023';END IF;
 IF nullif(f.redirect_url,'') IS NOT NULL AND f.redirect_url!~'^https://[^/[:space:]]+' THEN RAISE EXCEPTION 'Redirecionamento exige URL HTTPS' USING ERRCODE='22023';END IF;
END $$;
CREATE FUNCTION public.forms_admin(p_action text,p_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_revision integer DEFAULT NULL,p_limit integer DEFAULT 30,p_offset integer DEFAULT 0) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE tid uuid:=public.get_tenant_id(); uid uuid; can_write boolean; ctx jsonb; f public.marketing_forms%ROWTYPE; r jsonb; BEGIN
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN ctx:=crm_mcp.context();tid:=(ctx->>'tenant_id')::uuid;uid:=(ctx->>'member_id')::uuid;can_write:=(ctx->>'can_write')::boolean;
 ELSE SELECT m.id,m.role='admin' INTO uid,can_write FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id WHERE m.auth_user_id=auth.uid() AND m.tenant_id=tid AND m.is_active AND t.is_active; END IF;
 IF uid IS NULL OR tid IS NULL THEN RAISE EXCEPTION 'Usuário sem empresa ativa' USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR p_offset IS NULL OR p_offset NOT BETWEEN 0 AND 100000 THEN RAISE EXCEPTION 'Paginação inválida' USING ERRCODE='22023';END IF;
 IF p_action='list' THEN SELECT coalesce(jsonb_agg(to_jsonb(x)-'published_snapshot'),'[]') INTO r FROM(SELECT * FROM public.marketing_forms WHERE tenant_id=tid ORDER BY created_at DESC,id LIMIT p_limit OFFSET p_offset)x;RETURN jsonb_build_object('items',r,'next_offset',CASE WHEN jsonb_array_length(r)=p_limit THEN p_offset+p_limit ELSE NULL END);END IF;
 IF p_id IS NOT NULL THEN SELECT * INTO f FROM public.marketing_forms WHERE id=p_id AND tenant_id=tid FOR UPDATE;IF NOT FOUND THEN RAISE EXCEPTION 'Formulário não encontrado' USING ERRCODE='42501';END IF;END IF;
 IF p_action='get' THEN RETURN to_jsonb(f)-'published_snapshot';END IF;
 IF p_action='submissions' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO r FROM(SELECT s.id,s.lead_id,s.deal_id,s.payload,s.answers,s.created_at,l.name lead_name,l.email lead_email,l.phone lead_phone FROM crm_forms.submissions s JOIN public.leads l ON l.id=s.lead_id AND l.tenant_id=s.tenant_id WHERE s.form_id=p_id AND s.tenant_id=tid ORDER BY s.created_at DESC,s.id LIMIT p_limit OFFSET p_offset)x;RETURN jsonb_build_object('items',r,'next_offset',CASE WHEN jsonb_array_length(r)=p_limit THEN p_offset+p_limit ELSE NULL END);END IF;
 IF NOT coalesce(can_write,false) THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_id IS NOT NULL AND p_revision IS DISTINCT FROM f.revision THEN RAISE EXCEPTION 'Formulário mudou. Reabra antes de salvar.' USING ERRCODE='40001';END IF;
 IF p_action IN ('save','save_publish') THEN
  IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>100000 OR p_data-ARRAY['name','description','fields','style','settings','redirect_url','success_message']<>'{}' OR length(btrim(coalesce(p_data->>'name',''))) NOT BETWEEN 1 AND 150 OR jsonb_typeof(p_data->'fields') IS DISTINCT FROM 'array' OR jsonb_typeof(p_data->'settings') IS DISTINCT FROM 'object' OR jsonb_typeof(p_data->'style') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Rascunho inválido' USING ERRCODE='22023';END IF;
  IF p_id IS NULL THEN INSERT INTO public.marketing_forms(tenant_id,name,created_by,is_active) VALUES(tid,p_data->>'name',uid,false) RETURNING * INTO f;END IF;
  UPDATE public.marketing_forms SET name=p_data->>'name',description=p_data->>'description',fields=p_data->'fields',style=p_data->'style',settings=(p_data->'settings')-'distribution_key',redirect_url=nullif(p_data->>'redirect_url',''),success_message=coalesce(p_data->>'success_message','Obrigado! Entraremos em contato.'),revision=revision+1,updated_at=now() WHERE id=f.id RETURNING * INTO f;
 END IF;
 IF p_action IN ('publish','save_publish') THEN
  PERFORM crm_forms.validate(f);
  UPDATE public.marketing_forms SET is_active=true,published_at=now(),published_revision=revision,published_snapshot=jsonb_build_object('id',id,'name',name,'description',description,'fields',fields,'style',style,'settings',settings,'redirect_url',redirect_url,'success_message',success_message) WHERE id=f.id RETURNING * INTO f;
 ELSIF p_action='unpublish' THEN UPDATE public.marketing_forms SET is_active=false,revision=revision+1 WHERE id=f.id RETURNING * INTO f;
 ELSIF p_action<>'save' THEN RAISE EXCEPTION 'Ação inválida' USING ERRCODE='22023'; END IF;
 RETURN to_jsonb(f)-'published_snapshot';
END $$;
REVOKE ALL ON FUNCTION public.forms_admin(text,uuid,jsonb,integer,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.forms_admin(text,uuid,jsonb,integer,integer,integer) TO authenticated;
CREATE FUNCTION public.forms_public_get(p_id uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT (f.published_snapshot-'settings')||jsonb_build_object('settings',crm_mcp.safe_fields(f.published_snapshot->'settings',ARRAY['show_logo','compact_mode','auto_capture_utm'])) FROM public.marketing_forms f JOIN public.tenants t ON t.id=f.tenant_id WHERE f.id=p_id AND f.is_active AND t.is_active AND f.published_snapshot IS NOT NULL;
$$;
CREATE FUNCTION public.forms_public_submit(p_id uuid,p_request_id uuid,p_values jsonb,p_tracking jsonb DEFAULT '{}',p_client_hash text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE f public.marketing_forms%ROWTYPE; field jsonb; val text; mapping text; mapped jsonb:='{}'; answers jsonb:='{}'; lid uuid; did uuid; pipe uuid; stage uuid; owner uuid; contact_email text; contact_phone text; n integer; old crm_forms.submissions%ROWTYPE; window_start timestamptz:=date_trunc('hour',now()); count_hits integer; payload jsonb;
BEGIN
 IF p_request_id IS NULL OR p_values IS NULL OR jsonb_typeof(p_values)<>'object' OR octet_length(p_values::text)>50000 OR p_tracking IS NULL OR jsonb_typeof(p_tracking)<>'object' OR octet_length(p_tracking::text)>8000 OR length(p_client_hash)<>64 THEN RAISE EXCEPTION 'Envio inválido' USING ERRCODE='22023'; END IF;
 SELECT * INTO f FROM public.marketing_forms WHERE id=p_id AND is_active AND published_snapshot IS NOT NULL;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=f.tenant_id AND is_active) THEN RAISE EXCEPTION 'Formulário indisponível' USING ERRCODE='P0002'; END IF;
 payload:=jsonb_build_object('values',p_values,'tracking',p_tracking);
 PERFORM pg_advisory_xact_lock(hashtextextended('form-submit:'||f.tenant_id::text,0));
 SELECT * INTO old FROM crm_forms.submissions WHERE form_id=p_id AND request_id=p_request_id;
 IF FOUND THEN IF old.payload<>payload THEN RAISE EXCEPTION 'Tentativa já utilizada' USING ERRCODE='22023';END IF; RETURN '{"ok":true}'::jsonb; END IF;
 f.fields:=f.published_snapshot->'fields';f.settings:=f.published_snapshot->'settings';f.redirect_url:=f.published_snapshot->>'redirect_url';f.name:=f.published_snapshot->>'name';
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_values) k WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(f.fields) x WHERE x->>'id'=k)) THEN RAISE EXCEPTION 'Campo não permitido' USING ERRCODE='22023'; END IF;
 FOR field IN SELECT value FROM jsonb_array_elements(f.fields) LOOP
  IF p_values?(field->>'id') AND jsonb_typeof(p_values->(field->>'id'))<>'string' THEN RAISE EXCEPTION 'Valor inválido' USING ERRCODE='22023'; END IF;
  val:=btrim(coalesce(p_values->>(field->>'id'),''));mapping:=field->>'map_to';
  IF (field->>'required')::boolean AND val='' THEN RAISE EXCEPTION 'Preencha: %',field->>'label' USING ERRCODE='22023'; END IF;
  IF length(val)>5000 THEN RAISE EXCEPTION 'Resposta muito longa' USING ERRCODE='22023'; END IF;
  IF val<>'' AND (field->>'type'='email' OR mapping='email') AND val!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE EXCEPTION 'Email inválido' USING ERRCODE='22023'; END IF;
  IF val<>'' AND (field->>'type'='phone' OR mapping='phone') AND length(regexp_replace(val,'\D','','g')) NOT BETWEEN 10 AND 15 THEN RAISE EXCEPTION 'Telefone inválido' USING ERRCODE='22023'; END IF;
  IF val<>'' AND field->>'type'='number' AND val!~'^-?[0-9]+([.,][0-9]+)?$' THEN RAISE EXCEPTION 'Número inválido' USING ERRCODE='22023'; END IF;
  IF val<>'' AND field->>'type' IN ('select','capital') AND NOT coalesce(field->'options','[]')?val THEN RAISE EXCEPTION 'Opção inválida' USING ERRCODE='22023'; END IF;
  answers:=answers||jsonb_build_object(field->>'label',val);
  IF nullif(mapping,'') IS NOT NULL THEN mapped:=mapped||jsonb_build_object(mapping,val); END IF;
 END LOOP;
 pipe:=(f.settings->>'pipeline_id')::uuid;stage:=(f.settings->>'stage_id')::uuid;owner:=(f.settings->>'responsible_id')::uuid;
 PERFORM crm_forms.validate(f);
 INSERT INTO crm_forms.rate_limits VALUES(p_id,p_client_hash,window_start,1) ON CONFLICT(form_id,client_hash,bucket) DO UPDATE SET hits=crm_forms.rate_limits.hits+1 RETURNING hits INTO count_hits;
 IF count_hits>20 THEN RAISE EXCEPTION 'Limite de envios atingido. Tente mais tarde.' USING ERRCODE='P0001';END IF;
 contact_email:=nullif(lower(mapped->>'email'),'');contact_phone:=nullif(regexp_replace(coalesce(mapped->>'phone',''),'\D','','g'),'');
 SELECT count(*),(array_agg(id))[1] INTO n,lid FROM public.leads WHERE tenant_id=f.tenant_id AND ((contact_email IS NOT NULL AND lower(public.leads.email)=contact_email) OR (contact_phone IS NOT NULL AND regexp_replace(coalesce(public.leads.phone,''),'\D','','g')=contact_phone));
 IF n>1 THEN RAISE EXCEPTION 'Não foi possível processar o contato. Fale com a equipe.' USING ERRCODE='22023'; END IF;
 IF lid IS NULL THEN INSERT INTO public.leads(tenant_id,name,email,phone,source,sales_rep_id,city_name,state,job_title,context) VALUES(f.tenant_id,mapped->>'nome',contact_email,contact_phone,'Formulário | '||f.name,owner,mapped->>'cidade',mapped->>'estado',mapped->>'ocupacao',answers::text) RETURNING id INTO lid; END IF;
 SELECT id INTO did FROM public.deals WHERE tenant_id=f.tenant_id AND lead_id=lid AND pipeline_id=pipe AND status NOT IN ('won','lost') ORDER BY created_at DESC LIMIT 1;
 IF did IS NULL THEN INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,sales_rep_id,status,description) VALUES(f.tenant_id,lid,coalesce(mapped->>'nome','Contato')||' — '||f.name,pipe,stage,owner,'negotiation','Captado pelo formulário '||f.name) RETURNING id INTO did; END IF;
 INSERT INTO crm_forms.submissions(form_id,tenant_id,request_id,payload,answers,lead_id,deal_id) VALUES(p_id,f.tenant_id,p_request_id,payload,answers,lid,did);
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(f.tenant_id,lid,'form_submission','Formulário: '||f.name||E'\n'||answers::text,jsonb_build_object('form_id',p_id,'deal_id',did,'tracking',p_tracking));
 UPDATE public.marketing_forms SET submissions_count=coalesce(submissions_count,0)+1,last_submission_at=now() WHERE id=p_id;
 RETURN '{"ok":true}'::jsonb;
END $$;
REVOKE ALL ON FUNCTION public.forms_public_get(uuid),public.forms_public_submit(uuid,uuid,jsonb,jsonb,text),crm_forms.validate(public.marketing_forms) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.forms_public_get(uuid),public.forms_public_submit(uuid,uuid,jsonb,jsonb,text) TO service_role;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
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

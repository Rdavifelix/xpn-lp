BEGIN;
CREATE OR REPLACE FUNCTION crm_inbound.validate(c crm_inbound.channels) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE m jsonb;dest text;seen text[]:='{}'; BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.sales_pipelines WHERE id=c.pipeline_id AND tenant_id=c.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=c.stage_id AND pipeline_id=c.pipeline_id AND tenant_id=c.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Escolha funil ativo e etapa inicial válida' USING ERRCODE='22023'; END IF;
 IF cardinality(c.members) NOT BETWEEN 1 AND 50 OR (c.method='fixed' AND cardinality(c.members)<>1) OR (SELECT count(DISTINCT x) FROM unnest(c.members)x)<>cardinality(c.members) OR EXISTS(SELECT 1 FROM unnest(c.members)x WHERE NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=x AND tenant_id=c.tenant_id AND is_active)) THEN RAISE EXCEPTION 'Escolha responsáveis ativos da empresa; fixo exige um membro' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(c.mappings) IS DISTINCT FROM 'array' OR jsonb_array_length(c.mappings) NOT BETWEEN 2 AND 50 THEN RAISE EXCEPTION 'Configure entre 2 e 50 mapeamentos' USING ERRCODE='22023'; END IF;
 FOR m IN SELECT value FROM jsonb_array_elements(c.mappings) LOOP
  dest:=m->>'target';
  IF coalesce(m->>'source','') !~ '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$' OR length(m->>'source')>200 OR dest IS NULL OR dest=ANY(seen) OR jsonb_typeof(m->'required') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Mapeamento inválido ou destino repetido' USING ERRCODE='22023'; END IF;
  IF dest NOT IN('name','email','phone','company','city','state','job_title','source','utm_source','utm_medium','utm_campaign','utm_content','utm_term') AND NOT EXISTS(SELECT 1 FROM crm_inbound.fields WHERE 'custom:'||id::text=dest AND tenant_id=c.tenant_id AND pipeline_id=c.pipeline_id) THEN RAISE EXCEPTION 'Campo de destino não pertence a este funil' USING ERRCODE='22023';END IF;
  seen:=array_append(seen,dest);
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.mappings) entry WHERE entry->>'target'='name' AND (entry->>'required')::boolean) OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.mappings) entry WHERE entry->>'target' IN('email','phone') AND (entry->>'required')::boolean) THEN RAISE EXCEPTION 'Nome e Email ou Telefone precisam ser mapeados e obrigatórios' USING ERRCODE='22023';END IF;
END $$;
CREATE OR REPLACE FUNCTION public.inbound_admin(p_action text,p_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_revision int DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid:=public.get_tenant_id();ctx jsonb;mid uuid;w boolean;c crm_inbound.channels;f crm_inbound.fields;r jsonb;did uuid;BEGIN
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN ctx:=crm_mcp.context();tid:=(ctx->>'tenant_id')::uuid;mid:=(ctx->>'member_id')::uuid;w:=(ctx->>'can_write')::boolean;
 ELSE SELECT m.id,m.role='admin' INTO mid,w FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id WHERE m.auth_user_id=auth.uid() AND m.tenant_id=tid AND m.is_active AND t.is_active;END IF;
 IF mid IS NULL THEN RAISE EXCEPTION 'Empresa ativa obrigatória' USING ERRCODE='42501';END IF;
 IF p_action='values' THEN
  SELECT d.id INTO did FROM public.deals d WHERE d.id=p_id AND d.tenant_id=tid;
  IF did IS NULL THEN RAISE EXCEPTION 'Oportunidade não encontrada' USING ERRCODE='42501';END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',fld.id,'name',fld.name,'type',fld.type,'value',d.metadata->'custom_fields'->fld.id::text) ORDER BY fld.name),'[]') INTO r FROM public.deals d JOIN crm_inbound.fields fld ON fld.pipeline_id=d.pipeline_id AND fld.tenant_id=tid WHERE d.id=did;RETURN r;
 END IF;
 IF NOT coalesce(w,false) THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
 IF p_action='list' THEN SELECT coalesce(jsonb_agg(to_jsonb(x)-'token'),'[]') INTO r FROM(SELECT * FROM crm_inbound.channels WHERE tenant_id=tid ORDER BY created_at DESC LIMIT 100)x;RETURN r;END IF;
 IF p_action='options' THEN RETURN jsonb_build_object('pipelines',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)),'[]') FROM public.sales_pipelines WHERE tenant_id=tid AND is_active),'stages',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'pipeline_id',pipeline_id) ORDER BY position),'[]') FROM public.sales_pipeline_stages WHERE tenant_id=tid AND NOT is_won AND NOT is_lost),'members',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)),'[]') FROM public.team_members WHERE tenant_id=tid AND is_active),'fields',(SELECT coalesce(jsonb_agg(to_jsonb(fld)),'[]') FROM crm_inbound.fields fld WHERE tenant_id=tid));END IF;
 IF p_action='field_create' THEN
  IF p_id IS NULL OR length(btrim(coalesce(p_data->>'name',''))) NOT BETWEEN 1 AND 100 OR coalesce(p_data->>'type','') NOT IN('text','number','date','boolean','select') OR NOT EXISTS(SELECT 1 FROM public.sales_pipelines WHERE id=(p_data->>'pipeline_id')::uuid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Definição de campo inválida' USING ERRCODE='22023';END IF;
  IF p_data->>'type'='select' AND (jsonb_typeof(p_data->'options') IS DISTINCT FROM 'array' OR jsonb_array_length(p_data->'options') NOT BETWEEN 1 AND 100 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'options')v WHERE jsonb_typeof(v)<>'string' OR length(v#>>'{}') NOT BETWEEN 1 AND 200)) THEN RAISE EXCEPTION 'Informe opções de texto para a seleção' USING ERRCODE='22023';END IF;
  INSERT INTO crm_inbound.fields(id,tenant_id,pipeline_id,name,type,options) VALUES(p_id,tid,(p_data->>'pipeline_id')::uuid,btrim(p_data->>'name'),p_data->>'type',coalesce(p_data->'options','[]')) ON CONFLICT(id) DO NOTHING;
  SELECT * INTO f FROM crm_inbound.fields WHERE id=p_id AND tenant_id=tid;
  IF NOT FOUND OR f.name<>btrim(p_data->>'name') OR f.pipeline_id<>(p_data->>'pipeline_id')::uuid OR f.type<>p_data->>'type' OR f.options<>coalesce(p_data->'options','[]') THEN RAISE EXCEPTION 'ID de campo já utilizado' USING ERRCODE='22023';END IF;RETURN to_jsonb(f);
 END IF;
 IF p_action='create' THEN
  IF p_id IS NULL OR length(btrim(coalesce(p_data->>'name',''))) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Informe nome e ID estável' USING ERRCODE='22023';END IF;
  INSERT INTO crm_inbound.channels(id,tenant_id,name) VALUES(p_id,tid,btrim(p_data->>'name')) ON CONFLICT(id) DO NOTHING;
 END IF;
 SELECT * INTO c FROM crm_inbound.channels WHERE id=p_id AND tenant_id=tid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Canal não encontrado' USING ERRCODE='42501';END IF;
 IF p_action IN('get','create') THEN RETURN to_jsonb(c);END IF;
 IF p_action='receipts' THEN SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO r FROM(SELECT * FROM crm_inbound.receipts WHERE channel_id=c.id ORDER BY created_at DESC LIMIT 30)x;RETURN r;END IF;
 IF p_action='save' THEN
  IF c.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'Canal mudou; reabra antes de salvar' USING ERRCODE='40001';END IF;
  c.pipeline_id:=(p_data->>'pipeline_id')::uuid;c.stage_id:=(p_data->>'stage_id')::uuid;c.method:=p_data->>'method';c.mappings:=p_data->'mappings';c.name:=btrim(p_data->>'name');
  IF c.method IS NULL OR c.method NOT IN('fixed','round_robin') OR length(coalesce(c.name,'')) NOT BETWEEN 1 AND 100 OR jsonb_typeof(p_data->'members') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Configuração inválida' USING ERRCODE='22023';END IF;
  SELECT coalesce(array_agg(x::uuid),'{}') INTO c.members FROM jsonb_array_elements_text(p_data->'members')x;
  PERFORM crm_inbound.validate(c);
  UPDATE crm_inbound.channels SET name=c.name,pipeline_id=c.pipeline_id,stage_id=c.stage_id,method=c.method,members=c.members,mappings=c.mappings,status='capture',revision=revision+1,updated_at=now() WHERE id=c.id RETURNING * INTO c;
 ELSIF p_action='status' THEN
  IF c.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'Canal mudou; reabra antes de alterar' USING ERRCODE='40001';END IF;
  IF p_data->>'status'='active' THEN PERFORM crm_inbound.validate(c);END IF;
  IF coalesce(p_data->>'status','') NOT IN('capture','active','paused') THEN RAISE EXCEPTION 'Status inválido' USING ERRCODE='22023';END IF;
  UPDATE crm_inbound.channels SET status=p_data->>'status',revision=revision+1,updated_at=now() WHERE id=c.id RETURNING * INTO c;
 ELSIF p_action='preview' THEN PERFORM crm_inbound.validate(c);RETURN jsonb_build_object('mapped',crm_inbound.map_payload(c,p_data),'writes',false);
 ELSE RAISE EXCEPTION 'Ação inválida' USING ERRCODE='22023';END IF;
 RETURN to_jsonb(c);
END $$;
CREATE OR REPLACE FUNCTION public.inbound_receive(p_token uuid,p_request_id uuid,p_payload jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE c crm_inbound.channels;r crm_inbound.receipts;m jsonb;custom jsonb:='{}';lid uuid;did uuid;owner uuid;n int;em text;ph text;new_deal boolean:=false; BEGIN
 IF p_request_id IS NULL OR jsonb_typeof(p_payload) IS DISTINCT FROM 'object' OR octet_length(p_payload::text)>50000 THEN RAISE EXCEPTION 'Payload inválido' USING ERRCODE='22023';END IF;
 SELECT * INTO c FROM crm_inbound.channels WHERE token=p_token FOR UPDATE;
 IF NOT FOUND OR c.status='paused' OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=c.tenant_id AND is_active) THEN RAISE EXCEPTION 'Canal indisponível' USING ERRCODE='P0002';END IF;
 SELECT * INTO r FROM crm_inbound.receipts WHERE channel_id=c.id AND request_id=p_request_id;
 IF FOUND THEN
  IF r.payload<>p_payload THEN RAISE EXCEPTION 'request_id já utilizado com outro payload' USING ERRCODE='22023';END IF;
  RETURN jsonb_build_object('ok',r.status<>'failed','receipt_id',r.id,'status',r.status,'error',r.detail,'replayed',true);
 END IF;
 IF (SELECT count(*) FROM crm_inbound.receipts WHERE channel_id=c.id AND created_at>now()-interval '1 hour')>=200 THEN RAISE EXCEPTION 'Limite do canal atingido; tente mais tarde' USING ERRCODE='P0001';END IF;
 INSERT INTO crm_inbound.receipts(channel_id,request_id,payload,status) VALUES(c.id,p_request_id,p_payload,'captured') RETURNING * INTO r;
 IF c.status='capture' THEN RETURN jsonb_build_object('ok',true,'receipt_id',r.id,'status','captured','message','Amostra recebida. Canal em modo de captura; nenhum contato criado.');END IF;
 BEGIN
  PERFORM crm_inbound.validate(c);m:=crm_inbound.map_payload(c,p_payload);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('inbound:'||c.tenant_id::text,0));
  em:=m->>'email';ph:=m->>'phone';
  SELECT count(*),(array_agg(id))[1] INTO n,lid FROM public.leads WHERE tenant_id=c.tenant_id AND ((em IS NOT NULL AND lower(email)=em) OR (ph IS NOT NULL AND regexp_replace(coalesce(phone,''),'\D','','g')=ph));
  IF n>1 THEN RAISE EXCEPTION 'Email e telefone identificam contatos diferentes; revise o cadastro' USING ERRCODE='22023';END IF;
  IF lid IS NOT NULL THEN
   SELECT count(*),(array_agg(id))[1] INTO n,did FROM public.deals WHERE tenant_id=c.tenant_id AND lead_id=lid AND pipeline_id=c.pipeline_id AND status NOT IN('won','lost');
   IF n>1 THEN RAISE EXCEPTION 'Contato possui várias oportunidades abertas neste funil; revise antes de reenviar' USING ERRCODE='22023';END IF;
  END IF;
  IF did IS NULL THEN owner:=c.members[CASE WHEN c.method='fixed' THEN 1 ELSE (c.cursor%cardinality(c.members))::int+1 END];new_deal:=true;
  ELSE SELECT sales_rep_id INTO owner FROM public.deals WHERE id=did;END IF;
  IF lid IS NULL THEN INSERT INTO public.leads(tenant_id,name,email,phone,company_name,city_name,state,job_title,source,sales_rep_id) VALUES(c.tenant_id,m->>'name',em,ph,m->>'company',m->>'city',m->>'state',m->>'job_title',coalesce(m->>'source',c.name),owner) RETURNING id INTO lid;
  ELSE UPDATE public.leads SET name=m->>'name',email=coalesce(em,email),phone=coalesce(ph,phone),company_name=coalesce(m->>'company',company_name),city_name=coalesce(m->>'city',city_name),state=coalesce(m->>'state',state),job_title=coalesce(m->>'job_title',job_title) WHERE id=lid AND tenant_id=c.tenant_id;END IF;
  SELECT coalesce(jsonb_object_agg(substring(key from 8),value),'{}') INTO custom FROM jsonb_each(m) WHERE key LIKE 'custom:%';
  IF did IS NULL THEN INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,sales_rep_id,status,metadata) VALUES(c.tenant_id,lid,(m->>'name')||' — '||c.name,c.pipeline_id,c.stage_id,owner,'negotiation',jsonb_build_object('custom_fields',custom,'inbound_channel_id',c.id)) RETURNING id INTO did;
  ELSE UPDATE public.deals SET metadata=coalesce(metadata,'{}')||jsonb_build_object('custom_fields',coalesce(metadata->'custom_fields','{}')||custom) WHERE id=did AND tenant_id=c.tenant_id;END IF;
  IF new_deal AND c.method='round_robin' THEN UPDATE crm_inbound.channels SET cursor=cursor+1 WHERE id=c.id;END IF;
  INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(c.tenant_id,lid,'form_submission','Entrada: '||c.name,jsonb_build_object('channel_id',c.id,'receipt_id',r.id,'deal_id',did,'mapped',m));
  UPDATE crm_inbound.receipts SET status='processed',mapped=m,lead_id=lid,deal_id=did,owner_id=owner WHERE id=r.id;
 EXCEPTION WHEN OTHERS THEN
  UPDATE crm_inbound.receipts SET status='failed',detail=CASE WHEN SQLSTATE IN('22023','22007','22008') THEN left(SQLERRM,300) ELSE 'Não foi possível gravar a entrada; revise destino e configuração.' END WHERE id=r.id;
 END;
 SELECT * INTO r FROM crm_inbound.receipts WHERE id=r.id;
 RETURN jsonb_build_object('ok',r.status='processed','receipt_id',r.id,'status',r.status,'error',r.detail);
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;

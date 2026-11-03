BEGIN;
CREATE OR REPLACE FUNCTION public.normalize_instagram(value text) RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE h text:=lower(btrim(value));BEGIN
 IF coalesce(h,'')='' THEN RETURN NULL;END IF;
 h:=regexp_replace(h,'^https?://(www[.])?instagram[.]com/','');
 h:=regexp_replace(h,'[/?#].*$','');h:=regexp_replace(h,'^@','');
 IF h!~'^[a-z0-9_][a-z0-9_.]{0,29}$' OR h IN ('p','reel','reels','stories','explore','accounts') THEN RAISE EXCEPTION 'Informe um @ ou link de perfil Instagram válido' USING ERRCODE='22023';END IF;RETURN h;
END $$;
REVOKE ALL ON FUNCTION public.normalize_instagram(text) FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION public.normalize_instagram(text) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.forms_public_submit(p_id uuid, p_request_id uuid, p_values jsonb, p_tracking jsonb DEFAULT '{}'::jsonb, p_client_hash text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
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
  IF mapping='instagram' THEN val:=coalesce(public.normalize_instagram(val),'');END IF;
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
 IF nullif(mapped->>'instagram','') IS NOT NULL THEN UPDATE public.leads SET instagram=mapped->>'instagram' WHERE id=lid AND tenant_id=f.tenant_id; END IF;
 SELECT id INTO did FROM public.deals WHERE tenant_id=f.tenant_id AND lead_id=lid AND pipeline_id=pipe AND status NOT IN ('won','lost') ORDER BY created_at DESC LIMIT 1;
 IF did IS NULL THEN INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,sales_rep_id,status,description) VALUES(f.tenant_id,lid,coalesce(mapped->>'nome','Contato')||' — '||f.name,pipe,stage,owner,'negotiation','Captado pelo formulário '||f.name) RETURNING id INTO did; END IF;
 INSERT INTO crm_forms.submissions(form_id,tenant_id,request_id,payload,answers,lead_id,deal_id) VALUES(p_id,f.tenant_id,p_request_id,payload,answers,lid,did);
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,metadata) VALUES(f.tenant_id,lid,'form_submission','Formulário: '||f.name||E'\n'||answers::text,jsonb_build_object('form_id',p_id,'deal_id',did,'tracking',p_tracking));
 UPDATE public.marketing_forms SET submissions_count=coalesce(submissions_count,0)+1,last_submission_at=now() WHERE id=p_id;
 RETURN '{"ok":true}'::jsonb;
END $function$
;
CREATE OR REPLACE FUNCTION public.inbound_receive(p_token uuid, p_request_id uuid, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
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
  IF nullif(m->>'instagram','') IS NOT NULL THEN UPDATE public.leads SET instagram=m->>'instagram' WHERE id=lid AND tenant_id=c.tenant_id;END IF;
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
END $function$
;
CREATE OR REPLACE FUNCTION crm_inbound.map_payload(c crm_inbound.channels, p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE m jsonb;v jsonb;s text;dest text;f crm_inbound.fields;result jsonb:='{}'; BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR octet_length(p::text)>50000 THEN RAISE EXCEPTION 'Envie objeto JSON de até 50 KB' USING ERRCODE='22023';END IF;
 FOR m IN SELECT value FROM jsonb_array_elements(c.mappings) LOOP
  dest:=m->>'target';v:=p#>string_to_array(m->>'source','.');s:=nullif(btrim(v#>>'{}'),'');
  IF v IS NULL OR v='null'::jsonb OR s IS NULL THEN
   IF (m->>'required')::boolean THEN RAISE EXCEPTION 'Campo obrigatório ausente: %',m->>'source' USING ERRCODE='22023';END IF;CONTINUE;
  END IF;
  IF jsonb_typeof(v) NOT IN('string','number','boolean') OR length(s)>5000 THEN RAISE EXCEPTION 'Valor deve ser simples e ter até 5000 caracteres: %',m->>'source' USING ERRCODE='22023';END IF;
  IF dest LIKE 'custom:%' THEN
   SELECT * INTO STRICT f FROM crm_inbound.fields WHERE 'custom:'||id::text=dest AND tenant_id=c.tenant_id AND pipeline_id=c.pipeline_id;
   IF f.type='number' THEN IF s!~'^-?[0-9]+([.,][0-9]+)?$' THEN RAISE EXCEPTION 'Número inválido: %',f.name USING ERRCODE='22023';END IF;v:=to_jsonb(replace(s,',','.')::numeric);
   ELSIF f.type='boolean' THEN IF lower(s) NOT IN('true','false','sim','não','nao') THEN RAISE EXCEPTION 'Booleano inválido: %',f.name USING ERRCODE='22023';END IF;v:=to_jsonb(lower(s) IN('true','sim'));
   ELSIF f.type='date' THEN IF s!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'Data deve ser AAAA-MM-DD: %',f.name USING ERRCODE='22023';END IF;v:=to_jsonb(s::date);
   ELSIF f.type='select' THEN IF NOT f.options?s THEN RAISE EXCEPTION 'Opção inválida: %',f.name USING ERRCODE='22023';END IF;v:=to_jsonb(s);
   ELSE v:=to_jsonb(s);END IF;
  ELSE
   IF dest='email' THEN s:=lower(s);IF s!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE EXCEPTION 'Email inválido' USING ERRCODE='22023';END IF;
   ELSIF dest='instagram' THEN s:=public.normalize_instagram(s);
   ELSIF dest='phone' THEN s:=regexp_replace(s,'\D','','g');IF length(s) NOT BETWEEN 10 AND 15 THEN RAISE EXCEPTION 'Telefone inválido' USING ERRCODE='22023';END IF;END IF;
   v:=to_jsonb(s);
  END IF;
  result:=result||jsonb_build_object(dest,v);
 END LOOP;RETURN result;
END $function$
;
CREATE OR REPLACE FUNCTION crm_forms.validate(f marketing_forms)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE field jsonb; keys text[]:='{}'; maps text[]:='{}'; key text; mapping text; pipe uuid; stage uuid; owner uuid; BEGIN
 IF jsonb_typeof(f.fields) IS DISTINCT FROM 'array' OR jsonb_array_length(f.fields) NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'Adicione entre 1 e 50 campos' USING ERRCODE='22023';END IF;
 FOR field IN SELECT value FROM jsonb_array_elements(f.fields) LOOP
  key:=field->>'id';mapping:=nullif(field->>'map_to','');
  IF key IS NULL OR key!~'^[a-zA-Z0-9_-]{1,100}$' OR key=ANY(keys) OR length(btrim(coalesce(field->>'label',''))) NOT BETWEEN 1 AND 200 OR coalesce(field->>'type','') NOT IN ('text','email','phone','number','select','state','city','capital','textarea','hidden','instagram') OR jsonb_typeof(field->'required') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Campo inválido ou repetido' USING ERRCODE='22023'; END IF;
  keys:=array_append(keys,key);
  IF mapping IS NOT NULL THEN
   IF mapping=ANY(maps) OR mapping NOT IN ('nome','email','phone','cidade','estado','capital_disponivel','ocupacao','melhor_horario','utm_source','utm_medium','utm_campaign','utm_content','utm_term','instagram') THEN RAISE EXCEPTION 'Mapeamento inválido ou repetido' USING ERRCODE='22023'; END IF;maps:=array_append(maps,mapping);
  END IF;
  IF field->>'type'='select' AND (jsonb_typeof(field->'options') IS DISTINCT FROM 'array' OR jsonb_array_length(field->'options') NOT BETWEEN 1 AND 100) THEN RAISE EXCEPTION 'Configure opções da seleção' USING ERRCODE='22023';END IF;
 END LOOP;
 IF NOT 'nome'=ANY(maps) OR NOT ('email'=ANY(maps) OR 'phone'=ANY(maps)) THEN RAISE EXCEPTION 'Mapeie Nome e Email ou Telefone antes de publicar' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(f.fields) x WHERE x->>'map_to'='nome' AND (x->>'required')::boolean) OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(f.fields) x WHERE x->>'map_to' IN ('email','phone') AND (x->>'required')::boolean) THEN RAISE EXCEPTION 'Nome e um meio de contato devem ser obrigatórios' USING ERRCODE='22023';END IF;
 pipe:=(f.settings->>'pipeline_id')::uuid; stage:=(f.settings->>'stage_id')::uuid; owner:=(f.settings->>'responsible_id')::uuid;
 IF NOT EXISTS(SELECT 1 FROM public.sales_pipelines WHERE id=pipe AND tenant_id=f.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=stage AND pipeline_id=pipe AND tenant_id=f.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Escolha um funil ativo e sua etapa inicial' USING ERRCODE='22023';END IF;
 IF owner IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=owner AND tenant_id=f.tenant_id AND is_active) THEN RAISE EXCEPTION 'Responsável inválido' USING ERRCODE='22023';END IF;
 IF nullif(f.redirect_url,'') IS NOT NULL AND f.redirect_url!~'^https://[^/[:space:]]+' THEN RAISE EXCEPTION 'Redirecionamento exige URL HTTPS' USING ERRCODE='22023';END IF;
END $function$
;
CREATE OR REPLACE FUNCTION crm_inbound.validate(c crm_inbound.channels)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE m jsonb;dest text;seen text[]:='{}'; BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.sales_pipelines WHERE id=c.pipeline_id AND tenant_id=c.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=c.stage_id AND pipeline_id=c.pipeline_id AND tenant_id=c.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Escolha funil ativo e etapa inicial válida' USING ERRCODE='22023'; END IF;
 IF cardinality(c.members) NOT BETWEEN 1 AND 50 OR (c.method='fixed' AND cardinality(c.members)<>1) OR (SELECT count(DISTINCT x) FROM unnest(c.members)x)<>cardinality(c.members) OR EXISTS(SELECT 1 FROM unnest(c.members)x WHERE NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=x AND tenant_id=c.tenant_id AND is_active)) THEN RAISE EXCEPTION 'Escolha responsáveis ativos da empresa; fixo exige um membro' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(c.mappings) IS DISTINCT FROM 'array' OR jsonb_array_length(c.mappings) NOT BETWEEN 2 AND 50 THEN RAISE EXCEPTION 'Configure entre 2 e 50 mapeamentos' USING ERRCODE='22023'; END IF;
 FOR m IN SELECT value FROM jsonb_array_elements(c.mappings) LOOP
  dest:=m->>'target';
  IF coalesce(m->>'source','') !~ '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$' OR length(m->>'source')>200 OR dest IS NULL OR dest=ANY(seen) OR jsonb_typeof(m->'required') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Mapeamento inválido ou destino repetido' USING ERRCODE='22023'; END IF;
  IF dest NOT IN('name','email','phone','company','city','state','job_title','source','utm_source','utm_medium','utm_campaign','utm_content','utm_term','instagram') AND NOT EXISTS(SELECT 1 FROM crm_inbound.fields WHERE 'custom:'||id::text=dest AND tenant_id=c.tenant_id AND pipeline_id=c.pipeline_id) THEN RAISE EXCEPTION 'Campo de destino não pertence a este funil' USING ERRCODE='22023';END IF;
  seen:=array_append(seen,dest);
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.mappings) entry WHERE entry->>'target'='name' AND (entry->>'required')::boolean) OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.mappings) entry WHERE entry->>'target' IN('email','phone') AND (entry->>'required')::boolean) THEN RAISE EXCEPTION 'Nome e Email ou Telefone precisam ser mapeados e obrigatórios' USING ERRCODE='22023';END IF;
END $function$
;

CREATE TABLE public.instagram_enrichment_jobs (
 lead_id uuid PRIMARY KEY REFERENCES public.leads(id) ON DELETE CASCADE,tenant_id uuid NOT NULL REFERENCES public.tenants(id),
 username text NOT NULL,status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','completed','needs_configuration','failed')),
 attempts integer NOT NULL DEFAULT 0,detail text,updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.instagram_enrichment_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.instagram_enrichment_jobs FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.instagram_enrichment_jobs TO authenticated;GRANT ALL ON public.instagram_enrichment_jobs TO service_role;
CREATE POLICY tenant_read ON public.instagram_enrichment_jobs FOR SELECT TO authenticated USING(tenant_id=(SELECT public.get_tenant_id()));
CREATE FUNCTION crm_inbound.queue_instagram() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF nullif(new.instagram,'') IS NOT NULL AND (TG_OP='INSERT' OR new.instagram IS DISTINCT FROM old.instagram) THEN
  INSERT INTO public.instagram_enrichment_jobs(lead_id,tenant_id,username) VALUES(new.id,new.tenant_id,public.normalize_instagram(new.instagram))
  ON CONFLICT(lead_id) DO UPDATE SET username=excluded.username,status='pending',attempts=0,detail=NULL,updated_at=now();
 END IF;RETURN new;
END $$;
REVOKE ALL ON FUNCTION crm_inbound.queue_instagram() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER queue_instagram AFTER INSERT OR UPDATE OF instagram ON public.leads FOR EACH ROW EXECUTE FUNCTION crm_inbound.queue_instagram();
CREATE FUNCTION public.claim_instagram_jobs() RETURNS SETOF public.instagram_enrichment_jobs LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 UPDATE public.instagram_enrichment_jobs SET status='processing',attempts=attempts+1,updated_at=now()
 WHERE lead_id IN(SELECT j.lead_id FROM public.instagram_enrichment_jobs j JOIN public.tenants t ON t.id=j.tenant_id WHERE t.is_active AND j.attempts<3 AND (j.status='pending' OR j.status IN ('processing','failed') AND j.updated_at<now()-interval '10 minutes' OR j.status='needs_configuration' AND j.updated_at<now()-interval '1 hour') ORDER BY j.updated_at LIMIT 5 FOR UPDATE OF j SKIP LOCKED) RETURNING *;
$$;
REVOKE ALL ON FUNCTION public.claim_instagram_jobs() FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.claim_instagram_jobs() TO service_role;
create table public.social_accounts (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id),
  zernio_account_id     text not null,
  platform              text not null check (platform in ('instagram','youtube','linkedin','tiktok','whatsapp','facebook','twitter','threads')),
  username              text,
  display_name          text,
  profile_picture       text,
  profile_url           text,
  followers_count       integer,
  followers_updated_at  timestamptz,
  is_active             boolean not null default true,
  needs_reconnection    boolean not null default false,
  metadata              jsonb not null default '{}',
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on table public.social_accounts is 'Contas sociais conectadas no Zernio. Espelho local para a tela não depender da API a cada render.';

create table public.social_posts (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id),
  zernio_post_id        text not null,
  account_id            uuid references public.social_accounts(id) on delete cascade,
  platform              text not null,
  -- Formato normalizado. O Zernio devolve mediaType (image/video/carousel) e
  -- mediaProductType (FEED/REELS/STORY) — mas o product type só vem em ~20% dos
  -- posts, então a derivação usa heurística (ver resolveFormat na edge function).
  format                text not null check (format in ('reel','story','carousel','image','video','short','article','text','unknown')),
  format_confidence     text not null default 'exact' check (format_confidence in ('exact','inferred')),
  content               text,
  permalink             text,
  thumbnail_url         text,
  media_url             text,
  published_at          timestamptz,

  impressions           bigint  not null default 0,
  reach                 bigint  not null default 0,
  views                 bigint  not null default 0,
  likes                 integer not null default 0,
  comments              integer not null default 0,
  shares                integer not null default 0,
  saves                 integer not null default 0,
  follows               integer not null default 0,
  engagement_rate       numeric,
  video_duration_seconds integer,
  reels_avg_watch_time  integer,
  reels_skip_rate       numeric,

  -- Story expira em 24h: o Zernio só lista os ativos, então o sync diário
  -- acumula aqui. Sem isso não existe histórico de stories.
  is_story_snapshot     boolean not null default false,

  raw                   jsonb not null default '{}',
  metrics_updated_at    timestamptz,
  synced_at             timestamptz not null default now()
);
comment on column public.social_posts.format_confidence is 'exact = veio do mediaProductType; inferred = deduzido por heurística';

create table public.social_metrics_daily (
  id            uuid primary key default gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id),
  metric_date   date not null,
  platform      text not null,
  account_id    uuid references public.social_accounts(id) on delete cascade,
  post_count    integer not null default 0,
  impressions   bigint  not null default 0,
  reach         bigint  not null default 0,
  views         bigint  not null default 0,
  likes         integer not null default 0,
  comments      integer not null default 0,
  shares        integer not null default 0,
  saves         integer not null default 0,
  followers     integer,
  synced_at     timestamptz not null default now(),
  unique (metric_date, platform, account_id)
);


ALTER TABLE public.social_posts ADD COLUMN platform_post_id text;
ALTER TABLE public.social_accounts ADD UNIQUE(tenant_id,zernio_account_id),ADD UNIQUE(tenant_id,id);
ALTER TABLE public.social_posts ADD UNIQUE(tenant_id,zernio_post_id),ADD FOREIGN KEY(tenant_id,account_id) REFERENCES public.social_accounts(tenant_id,id);
ALTER TABLE public.social_metrics_daily ADD FOREIGN KEY(tenant_id,account_id) REFERENCES public.social_accounts(tenant_id,id);
ALTER TABLE public.social_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.social_accounts FROM PUBLIC,anon,authenticated;GRANT SELECT ON public.social_accounts TO authenticated;GRANT ALL ON public.social_accounts TO service_role;
CREATE POLICY tenant_read ON public.social_accounts FOR SELECT TO authenticated USING(tenant_id=(SELECT public.get_tenant_id()));
CREATE INDEX ON public.social_accounts(tenant_id);
ALTER TABLE public.social_posts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.social_posts FROM PUBLIC,anon,authenticated;GRANT SELECT ON public.social_posts TO authenticated;GRANT ALL ON public.social_posts TO service_role;
CREATE POLICY tenant_read ON public.social_posts FOR SELECT TO authenticated USING(tenant_id=(SELECT public.get_tenant_id()));
CREATE INDEX ON public.social_posts(tenant_id);
ALTER TABLE public.social_metrics_daily ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.social_metrics_daily FROM PUBLIC,anon,authenticated;GRANT SELECT ON public.social_metrics_daily TO authenticated;GRANT ALL ON public.social_metrics_daily TO service_role;
CREATE POLICY tenant_read ON public.social_metrics_daily FOR SELECT TO authenticated USING(tenant_id=(SELECT public.get_tenant_id()));
CREATE INDEX ON public.social_metrics_daily(tenant_id);
CREATE FUNCTION public.social_leads_por_rede(p_desde date,p_ate date) RETURNS TABLE(platform text,leads bigint,leads_qualificados bigint) LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT CASE WHEN lower(coalesce(utm_source,source)) IN ('instagram','ig','instagram_comment_campaign','instagram_agent') THEN 'instagram' WHEN lower(coalesce(utm_source,source)) IN ('youtube','yt') THEN 'youtube' ELSE lower(coalesce(utm_source,source)) END,count(*),count(*) FILTER(WHERE lead_temperature IN('hot','warm')) FROM public.leads WHERE tenant_id=(SELECT public.get_tenant_id()) AND created_at >= p_desde AND created_at < p_ate+1 AND lower(coalesce(utm_source,source)) IN('instagram','ig','instagram_comment_campaign','instagram_agent','youtube','yt','linkedin','tiktok') GROUP BY 1;
$$;
REVOKE ALL ON FUNCTION public.social_leads_por_rede(date,date) FROM PUBLIC,anon;GRANT EXECUTE ON FUNCTION public.social_leads_por_rede(date,date) TO authenticated;

CREATE FUNCTION public.complete_instagram_enrichment(p_lead uuid,p_username text,p_profile jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE l public.leads;pid uuid;BEGIN
 SELECT * INTO l FROM public.leads WHERE id=p_lead FOR UPDATE;
 IF l.id IS NULL OR public.normalize_instagram(l.instagram) IS DISTINCT FROM p_username THEN RETURN;END IF;
 INSERT INTO public.instagram_profiles(tenant_id,username,full_name,biography,external_url,instagram_user_id,profile_picture_url_hd,is_private,is_verified,follower_count,following_count,media_count,last_scraped_at)
 VALUES(l.tenant_id,p_username,p_profile->>'full_name',p_profile->>'biography',p_profile->>'external_url',p_profile->>'instagram_user_id',p_profile->>'profile_picture_url_hd',(p_profile->>'is_private')::boolean,(p_profile->>'is_verified')::boolean,(p_profile->>'follower_count')::int,(p_profile->>'following_count')::int,(p_profile->>'media_count')::int,now())
 ON CONFLICT(tenant_id,username) DO UPDATE SET full_name=excluded.full_name,biography=excluded.biography,external_url=excluded.external_url,instagram_user_id=excluded.instagram_user_id,profile_picture_url_hd=excluded.profile_picture_url_hd,is_private=excluded.is_private,is_verified=excluded.is_verified,follower_count=excluded.follower_count,following_count=excluded.following_count,media_count=excluded.media_count,last_scraped_at=now() RETURNING id INTO pid;
 UPDATE public.leads SET instagram_profile_id=pid WHERE id=l.id AND tenant_id=l.tenant_id;
 -- Never steal a conversation from another contact or choose between duplicate handles.
 IF (SELECT count(*) FROM public.leads WHERE tenant_id=l.tenant_id AND lower(regexp_replace(instagram,'^@',''))=p_username)=1 THEN
  UPDATE public.instagram_conversations SET lead_id=l.id WHERE tenant_id=l.tenant_id AND lead_id IS NULL AND lower(participant_username)=p_username;
  UPDATE public.zernio_conversations z SET lead_id=l.id FROM public.instagram_conversations i WHERE z.instagram_conversation_id=i.id AND z.tenant_id=l.tenant_id AND i.tenant_id=l.tenant_id AND i.lead_id=l.id AND z.lead_id IS NULL;
 END IF;
 UPDATE public.instagram_enrichment_jobs SET status='completed',detail=NULL,updated_at=now() WHERE lead_id=l.id AND username=p_username;
END $$;
REVOKE ALL ON FUNCTION public.complete_instagram_enrichment(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.complete_instagram_enrichment(uuid,text,jsonb) TO service_role;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM vault.secrets WHERE name='instagram_worker_secret') THEN PERFORM vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'instagram_worker_secret');END IF;END $$;
CREATE FUNCTION public.dispatch_instagram_enrichment() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE token text;url text;BEGIN
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE name='instagram_worker_secret';
 SELECT value INTO url FROM public.config WHERE key='SUPABASE_PROJECT_URL';
 IF token IS NOT NULL AND url ~ '^https://[a-z0-9]+[.]supabase[.]co$' THEN PERFORM net.http_post(url:=url||'/functions/v1/enrich-instagram-leads',headers:=jsonb_build_object('Content-Type','application/json','x-worker-secret',token),body:='{}'::jsonb,timeout_milliseconds:=1000);END IF;
END $$;
REVOKE ALL ON FUNCTION public.dispatch_instagram_enrichment() FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.dispatch_instagram_enrichment() TO service_role;
SELECT cron.schedule('enrich-instagram-leads','* * * * *','SELECT public.dispatch_instagram_enrichment()');
CREATE OR REPLACE FUNCTION public.social_record_interaction(p_account text, p_remote text, p_message jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE a public.zernio_accounts;c public.zernio_conversations;ig public.instagram_conversations;mid text:=p_message->>'id';
 outgoing boolean:=coalesce((p_message->>'outgoing')::boolean,false);kind text:=coalesce(p_message->>'kind','text');sender jsonb:=p_message->'sender';
 stamp timestamptz:=coalesce((p_message->>'sentAt')::timestamptz,now());txt text:=left(coalesce(p_message->>'text',''),10000);att jsonb:=p_message->'attachments'->0;
 lid uuid;did uuid;ignored boolean:=false;
BEGIN
 SELECT * INTO a FROM public.zernio_accounts WHERE id=p_account AND is_active;
 IF NOT FOUND OR a.platform<>'instagram' OR a.instagram_account_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=a.tenant_id AND is_active) THEN RAISE EXCEPTION 'Conexão Instagram inativa';END IF;
 IF mid IS NULL OR p_remote IS NULL THEN RAISE EXCEPTION 'Interação sem identificador';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('social:'||a.id,0));
 SELECT * INTO c FROM public.zernio_conversations WHERE tenant_id=a.tenant_id AND account_id=a.id AND remote_id=p_remote;
 IF c.id IS NULL AND outgoing AND p_message->>'parent_id' IS NOT NULL THEN
  SELECT zc.* INTO c FROM public.zernio_conversations zc JOIN public.instagram_messages im ON im.conversation_id=zc.instagram_conversation_id WHERE zc.account_id=a.id AND zc.tenant_id=a.tenant_id AND im.metadata->>'comment_id'=p_message->>'parent_id' LIMIT 1;
 END IF;
 IF c.id IS NULL AND NOT outgoing AND sender->>'id' IS NOT NULL THEN
  SELECT * INTO c FROM public.zernio_conversations WHERE tenant_id=a.tenant_id AND account_id=a.id AND participant_id=sender->>'id' ORDER BY created_at LIMIT 1;
 END IF;
 IF c.id IS NULL AND outgoing THEN RETURN jsonb_build_object('ignored',true);END IF;
 IF c.id IS NULL THEN
  INSERT INTO public.zernio_conversations(tenant_id,account_id,remote_id,participant_id,participant_name) VALUES(a.tenant_id,a.id,p_remote,sender->>'id',coalesce(sender->>'name',sender->>'username','Contato Instagram')) RETURNING * INTO c;
 ELSIF NOT outgoing AND p_remote NOT LIKE 'comment:%' AND c.remote_id LIKE 'comment:%' THEN
  UPDATE public.zernio_conversations SET remote_id=p_remote WHERE id=c.id RETURNING * INTO c;
 END IF;
 SELECT * INTO ig FROM public.instagram_conversations WHERE id=c.instagram_conversation_id AND tenant_id=a.tenant_id;
 IF ig.id IS NULL THEN
  SELECT * INTO ig FROM public.instagram_conversations WHERE account_id=a.instagram_account_id AND tenant_id=a.tenant_id AND participant_instagram_id=c.participant_id ORDER BY created_at LIMIT 1;
 END IF;
 IF ig.id IS NOT NULL AND EXISTS(SELECT 1 FROM public.instagram_messages WHERE conversation_id=ig.id AND instagram_message_id IN ('social:'||a.instagram_account_id||':'||mid,mid,'zernio:'||mid)) THEN
  RETURN jsonb_build_object('conversation',to_jsonb(c),'duplicate',true);
 END IF;
 lid:=coalesce(c.lead_id,ig.lead_id);did:=c.deal_id;
 IF NOT outgoing AND lid IS NULL AND nullif(sender->>'username','') IS NOT NULL THEN
  SELECT (array_agg(id))[1] INTO lid FROM public.leads WHERE tenant_id=a.tenant_id AND lower(regexp_replace(instagram,'^@',''))=lower(sender->>'username') HAVING count(*)=1;
  IF lid IS NOT NULL THEN SELECT id INTO did FROM public.deals WHERE tenant_id=a.tenant_id AND lead_id=lid AND pipeline_id=a.pipeline_id AND status NOT IN ('won','lost') ORDER BY created_at DESC LIMIT 1; END IF;
 END IF;
 IF NOT outgoing AND NOT coalesce((p_message->>'historical')::boolean,false) AND lid IS NULL AND a.pipeline_id IS NOT NULL AND a.stage_id IS NOT NULL AND a.member_id IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM public.team_members WHERE id=a.member_id AND tenant_id=a.tenant_id AND is_active) OR NOT EXISTS(SELECT 1 FROM public.sales_pipeline_stages WHERE id=a.stage_id AND pipeline_id=a.pipeline_id AND tenant_id=a.tenant_id AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Destino da entrada inválido';END IF;
  INSERT INTO public.leads(tenant_id,name,source,sales_rep_id,metadata) VALUES(a.tenant_id,c.participant_name,'instagram',a.member_id,jsonb_build_object('social_account_id',a.id,'social_participant_id',c.participant_id)) RETURNING id INTO lid;
  INSERT INTO public.deals(tenant_id,lead_id,title,pipeline_id,pipeline_stage_id,sales_rep_id,status) VALUES(a.tenant_id,lid,c.participant_name,a.pipeline_id,a.stage_id,a.member_id,'negotiation') RETURNING id INTO did;
 END IF;
 IF ig.id IS NULL THEN
  INSERT INTO public.instagram_conversations(tenant_id,account_id,thread_id,participant_instagram_id,participant_name,participant_username,lead_id,assigned_to) VALUES(a.tenant_id,a.instagram_account_id,'social:'||c.id,coalesce(c.participant_id,p_remote),c.participant_name,sender->>'username',lid,a.member_id) RETURNING * INTO ig;
 END IF;
 IF att IS NOT NULL AND kind='text' THEN
  kind:=CASE WHEN att->>'type' IN ('image','video','audio','sticker') THEN att->>'type' ELSE 'link' END;
 END IF;
 INSERT INTO public.instagram_messages(tenant_id,conversation_id,instagram_message_id,content,message_type,is_from_me,sent_at,status,sender_instagram_id,sender_username,media_url,reference_type,reference_id,reference_url,metadata)
 VALUES(a.tenant_id,ig.id,'social:'||a.instagram_account_id||':'||mid,txt,kind,outgoing,stamp,'delivered',sender->>'id',sender->>'username',att->>'url',p_message->>'reference_type',p_message->>'reference_id',p_message->>'reference_url',jsonb_build_object('provider',a.provider,'comment_id',p_message->>'comment_id','parent_id',p_message->>'parent_id','attachments',coalesce(p_message->'attachments','[]'::jsonb)));
 UPDATE public.instagram_conversations SET lead_id=lid,last_message=CASE WHEN last_message_at>stamp THEN last_message ELSE txt END,last_message_at=greatest(last_message_at,stamp),last_client_message_at=CASE WHEN outgoing OR kind IN ('post_comment','comment_reply') THEN last_client_message_at ELSE greatest(last_client_message_at,stamp) END,unread_count=coalesce(unread_count,0)+CASE WHEN outgoing THEN 0 ELSE 1 END,metadata=coalesce(metadata,'{}')||jsonb_build_object('social_account_id',a.id,'social_conversation_id',c.remote_id),updated_at=now() WHERE id=ig.id;
 UPDATE public.zernio_conversations SET lead_id=lid,deal_id=did,instagram_conversation_id=ig.id,last_message=CASE WHEN last_message_at>stamp THEN last_message ELSE txt END,last_message_at=greatest(last_message_at,stamp) WHERE id=c.id RETURNING * INTO c;
 RETURN jsonb_build_object('conversation',to_jsonb(c),'duplicate',false);
END $function$
;
CREATE FUNCTION crm_inbound.normalize_lead_instagram() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
 new.instagram:=public.normalize_instagram(new.instagram);
 IF TG_OP='UPDATE' AND new.instagram IS DISTINCT FROM old.instagram THEN new.instagram_profile_id:=NULL; END IF;
 RETURN new;END $$;
REVOKE ALL ON FUNCTION crm_inbound.normalize_lead_instagram() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER normalize_lead_instagram BEFORE INSERT OR UPDATE OF instagram ON public.leads FOR EACH ROW EXECUTE FUNCTION crm_inbound.normalize_lead_instagram();
CREATE INDEX leads_instagram_tenant_idx ON public.leads(tenant_id,lower(instagram)) WHERE instagram IS NOT NULL;
COMMIT;

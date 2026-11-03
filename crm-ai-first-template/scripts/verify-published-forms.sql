BEGIN;
UPDATE public.config SET value='true' WHERE key='multi_tenant_enabled';
INSERT INTO auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
VALUES ('ce8f8da2-0e18-4200-bb52-977aac215332','mcp-rollback-test@example.invalid',now(),'{}','{}');
SELECT set_config('request.jwt.claims','{"sub":"ce8f8da2-0e18-4200-bb52-977aac215332","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
SELECT public.tenant_onboard('MCP operações teste rollback');
RESET ROLE;
INSERT INTO auth.sessions(id,user_id) VALUES('a202a202-1111-4111-8111-222222222222','ce8f8da2-0e18-4200-bb52-977aac215332');
INSERT INTO crm_mcp.clients(client_id,resource,can_write,is_active) VALUES('test-crm-operations','https://test.example/mcp',true,true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','ce8f8da2-0e18-4200-bb52-977aac215332','role','authenticated','client_id','test-crm-operations','aud','https://test.example/mcp','session_id','a202a202-1111-4111-8111-222222222222','app_metadata',(SELECT raw_app_meta_data FROM auth.users WHERE id='ce8f8da2-0e18-4200-bb52-977aac215332'))::text,true);

RESET ROLE;
DO $$ DECLARE tid uuid:=public.get_tenant_id(); member uuid; pipe uuid; stage uuid; f jsonb; definition jsonb; fid uuid; request uuid:=gen_random_uuid(); r jsonb; before_count integer; BEGIN
 SELECT id INTO member FROM team_members WHERE auth_user_id=auth.uid() AND tenant_id=tid;
 SELECT id INTO pipe FROM sales_pipelines WHERE tenant_id=tid LIMIT 1;
 SELECT id INTO stage FROM sales_pipeline_stages WHERE tenant_id=tid AND pipeline_id=pipe ORDER BY position LIMIT 1;
 definition:=jsonb_build_object('name','QA Form','fields','[{"id":"nome","type":"text","label":"Nome","required":true,"map_to":"nome"},{"id":"email","type":"email","label":"Email","required":true,"map_to":"email"},{"id":"dor","type":"textarea","label":"Desafio","required":false}]'::jsonb,'style','{}'::jsonb,'settings',jsonb_build_object('pipeline_id',pipe,'stage_id',stage,'responsible_id',member,'distribution_key','secret-not-public'));
 f:=public.forms_admin('save',p_data=>definition);fid:=(f->>'id')::uuid;
 IF public.forms_public_get(fid) IS NOT NULL THEN RAISE EXCEPTION 'Rascunho público'; END IF;
 f:=public.forms_admin('publish',fid,p_revision=>(f->>'revision')::integer);
 r:=public.forms_public_get(fid); IF r::text LIKE '%secret-not-public%' OR r::text LIKE '%pipeline_id%' THEN RAISE EXCEPTION 'Configuração interna pública'; END IF;
 SELECT count(*) INTO before_count FROM leads WHERE tenant_id=tid;
 r:=public.forms_public_submit(fid,request,'{"nome":"Teste Form","email":"forms-qa@example.invalid","dor":"Qualificar leads"}','{"utm_source":"qa"}',repeat('a',64));
 PERFORM public.forms_public_submit(fid,request,'{"nome":"Teste Form","email":"forms-qa@example.invalid","dor":"Qualificar leads"}','{"utm_source":"qa"}',repeat('a',64));
 IF (SELECT count(*) FROM crm_forms.submissions WHERE form_id=fid)<>1 OR (SELECT count(*) FROM leads WHERE tenant_id=tid)<>before_count+1 THEN RAISE EXCEPTION 'Repetição duplicou';END IF;
 IF NOT EXISTS(SELECT 1 FROM crm_forms.submissions s JOIN deals d ON d.id=s.deal_id WHERE s.form_id=fid AND d.tenant_id=tid AND d.pipeline_id=pipe AND d.pipeline_stage_id=stage AND d.sales_rep_id=member) THEN RAISE EXCEPTION 'Destino não respeitado'; END IF;
 PERFORM public.forms_public_submit(fid,gen_random_uuid(),'{"nome":"Teste Form","email":"forms-qa@example.invalid","dor":"Novo envio"}','{}',repeat('a',64));
 IF (SELECT count(*) FROM leads WHERE tenant_id=tid)<>before_count+1 OR (SELECT count(DISTINCT deal_id) FROM crm_forms.submissions WHERE form_id=fid)<>1 THEN RAISE EXCEPTION 'Reconversão duplicou contato/deal';END IF;
 BEGIN PERFORM public.forms_public_submit(fid,gen_random_uuid(),'{"email":"bad"}','{}',repeat('a',64));RAISE EXCEPTION 'Inválido aceito';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;
 BEGIN PERFORM public.forms_public_submit(fid,gen_random_uuid(),'{"nome":"Teste","email":"valid@example.invalid","tenant_id":"alheio"}','{}',repeat('a',64));RAISE EXCEPTION 'Roteamento público aceito';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;
 f:=public.forms_admin('save',fid,definition||'{"name":"Rascunho novo"}',(f->>'revision')::integer);
 IF public.forms_public_get(fid)->>'name'<>'QA Form' THEN RAISE EXCEPTION 'Rascunho mudou publicação'; END IF;
 BEGIN PERFORM public.forms_admin('save',fid,definition,0);RAISE EXCEPTION 'Conflito ignorado';EXCEPTION WHEN serialization_failure THEN NULL;END;
 f:=public.forms_admin('publish',fid,p_revision=>(f->>'revision')::integer);
 IF public.forms_public_get(fid)->>'name'<>'Rascunho novo' THEN RAISE EXCEPTION 'Republicação falhou'; END IF;
 r:=public.forms_admin('submissions',fid);IF jsonb_array_length(r->'items')<>2 THEN RAISE EXCEPTION 'Respostas ausentes'; END IF;
 f:=public.forms_admin('unpublish',fid,p_revision=>(f->>'revision')::integer);
 IF public.forms_public_get(fid) IS NOT NULL THEN RAISE EXCEPTION 'Despublicação falhou';END IF;
 BEGIN PERFORM public.forms_public_submit(fid,gen_random_uuid(),'{"nome":"Teste","email":"valid@example.invalid"}','{}',repeat('a',64));RAISE EXCEPTION 'Inativo aceitou envio';EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL;END;
 BEGIN PERFORM public.forms_admin('get',gen_random_uuid());RAISE EXCEPTION 'ID estrangeiro aceito';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM 1 FROM public.marketing_forms;RAISE EXCEPTION 'Anon leu tabela';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM public.forms_public_submit(gen_random_uuid(),gen_random_uuid(),'{}');RAISE EXCEPTION 'Anon burlou endpoint';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
ROLLBACK;

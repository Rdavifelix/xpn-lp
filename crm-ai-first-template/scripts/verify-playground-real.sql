-- Executar após as migrations, com supabase db query --linked --project-ref <projeto> --file.
-- Todos os dados sintéticos são desfeitos com ROLLBACK.
BEGIN;
SELECT set_config('test.foreign_pipeline',(SELECT id::text FROM public.sales_pipelines WHERE tenant_id='00000000-0000-0000-0000-000000000001' LIMIT 1),true);
UPDATE public.config SET value='true' WHERE key='multi_tenant_enabled';
INSERT INTO auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
VALUES ('ce8f8da2-0e18-4200-bb52-977aac215332','mcp-rollback-test@example.invalid',now(),'{}','{}');
SELECT set_config('request.jwt.claims','{"sub":"ce8f8da2-0e18-4200-bb52-977aac215332","role":"authenticated","email":"mcp-rollback-test@example.invalid"}',true);
SET LOCAL ROLE authenticated;
SELECT public.tenant_onboard('Empresa teste rollback');
RESET ROLE;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','ce8f8da2-0e18-4200-bb52-977aac215332','role','authenticated','app_metadata',(SELECT raw_app_meta_data FROM auth.users WHERE id='ce8f8da2-0e18-4200-bb52-977aac215332'))::text,true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE l uuid; other_l uuid; d uuid; a uuid; p uuid; s1 uuid; s2 uuid; member uuid; result jsonb;
BEGIN
 SELECT id INTO member FROM public.team_members WHERE auth_user_id=auth.uid();
 INSERT INTO public.leads(name,tenant_id) VALUES('QA playground real',public.get_tenant_id()) RETURNING id INTO l;
 INSERT INTO public.leads(name,tenant_id) VALUES('QA outro contato',public.get_tenant_id()) RETURNING id INTO other_l;
 INSERT INTO public.sales_pipelines(name,tenant_id) VALUES('QA playground',public.get_tenant_id()) RETURNING id INTO p;
 INSERT INTO public.sales_pipeline_stages(name,position,pipeline_id,tenant_id) VALUES('Entrada',0,p,public.get_tenant_id()) RETURNING id INTO s1;
 INSERT INTO public.sales_pipeline_stages(name,position,pipeline_id,tenant_id) VALUES('Reunião',1,p,public.get_tenant_id()) RETURNING id INTO s2;
 INSERT INTO public.deals(lead_id,title,pipeline_id,pipeline_stage_id,tenant_id) VALUES(l,'QA negócio',p,s1,public.get_tenant_id()) RETURNING id INTO d;
 INSERT INTO public.agents_registry(slug,display_name,provider,model,system_prompt,is_active,tenant_id,created_by,responsible_user_id)
 VALUES('qa-pg-'||gen_random_uuid(),'QA Playground','anthropic','test','Teste SQL sem chamada de modelo',false,public.get_tenant_id(),member,member) RETURNING id INTO a;
 result:=public.agent_playground_context(l,d);
 IF result->>'lead_id'<>l::text OR result->'deal'->>'id'<>d::text THEN RAISE EXCEPTION 'Contexto incorreto'; END IF;
 BEGIN
  PERFORM public.agent_playground_context(other_l,d); RAISE EXCEPTION 'Deal de outro contato aceito';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.agent_playground_context('3635e2b9-ee5e-4e06-b204-e3efd2c822d5'); RAISE EXCEPTION 'Contato de outra empresa aceito';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 result:=public.playground_change_stage(d,a,p_stage_id=>s2);
 IF result->>'ok'<>'true' OR (SELECT pipeline_stage_id FROM public.deals WHERE id=d)<>s2 THEN RAISE EXCEPTION 'Movimentação falhou: %',result; END IF;
 result:=public.playground_update_lead(l,a,'{"name":"QA Nome atualizado"}');
 IF (SELECT name FROM public.leads WHERE id=l)<>'QA Nome atualizado' THEN RAISE EXCEPTION 'Atualização falhou'; END IF;
 result:=public.playground_schedule_meeting(l,a,member,now()+interval '2 days');
 IF result->>'ok'<>'true' OR NOT EXISTS(SELECT 1 FROM public.company_activities WHERE id=(result->>'activity_id')::uuid AND lead_id=l) THEN RAISE EXCEPTION 'Reunião não criada: %',result; END IF;
END $$;
RESET ROLE;
ROLLBACK;

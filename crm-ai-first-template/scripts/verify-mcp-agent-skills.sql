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
INSERT INTO auth.sessions(id,user_id) VALUES ('819d2a70-f109-48d1-8eac-c8a58709c4c1','ce8f8da2-0e18-4200-bb52-977aac215332');
INSERT INTO crm_mcp.clients(client_id,resource,is_active,can_write) VALUES ('qa-plan-rollback','https://crm.example.com/mcp',true,true);
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','ce8f8da2-0e18-4200-bb52-977aac215332','role','authenticated','client_id','qa-plan-rollback','session_id','819d2a70-f109-48d1-8eac-c8a58709c4c1','aud','https://crm.example.com/mcp','app_metadata',(SELECT raw_app_meta_data FROM auth.users WHERE id='ce8f8da2-0e18-4200-bb52-977aac215332'))::text,true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE template uuid; cfg jsonb; a jsonb; b jsonb; r uuid:=gen_random_uuid(); cat jsonb;
BEGIN
 SELECT (x->>'id')::uuid INTO template FROM jsonb_array_elements(public.mcp_list_agents()) x WHERE x->>'is_template'='true' AND x->>'name'='Atendente (Bella)' LIMIT 1;
 IF template IS NULL THEN RAISE EXCEPTION 'Template Bella ausente'; END IF;
 cat:=public.mcp_agent_setup('catalog');
 IF jsonb_array_length(cat->'skills')<1 THEN RAISE EXCEPTION 'Catálogo ausente'; END IF;
 cfg:=jsonb_build_object('template_id',template,'name','SDR QA habilidades','system_prompt','Qualifique os contatos segundo o processo aprovado e use as ferramentas disponíveis.','tools',jsonb_build_array('update_lead','qualify_lead','schedule_meeting'));
 a:=public.mcp_agent_setup('create',r,NULL,cfg);
 IF jsonb_array_length(a->'tools')<>3 OR a->>'is_active'<>'false' THEN RAISE EXCEPTION 'Ferramentas não instaladas'; END IF;
 b:=public.mcp_agent_setup('create',r,NULL,cfg);
 IF a<>b THEN RAISE EXCEPTION 'Retry divergente'; END IF;
 b:=public.mcp_agent_setup('attach',gen_random_uuid(),(a->>'agent_id')::uuid,jsonb_build_object('tools',jsonb_build_array('update_lead')));
 IF jsonb_array_length(b->'tools')<>3 THEN RAISE EXCEPTION 'Duplicação de habilidade'; END IF;
 b:=public.mcp_agent_setup('get',NULL,(a->>'agent_id')::uuid);
 IF b->>'validation_status'<>'not_tested' OR b->>'ready'<>'false' THEN RAISE EXCEPTION 'Prontidão incorreta'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(b->'tools') x WHERE x->>'name'='schedule_meeting' AND x->>'enabled'<>'true') THEN
  RAISE EXCEPTION 'Modo diferente do catálogo real'; END IF;
END $$;
RESET ROLE;
ROLLBACK;

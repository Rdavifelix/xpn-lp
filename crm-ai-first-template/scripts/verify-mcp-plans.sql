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
DECLARE plan_id uuid:=gen_random_uuid(); item_id uuid:=gen_random_uuid(); request uuid:=gen_random_uuid(); doc jsonb; a jsonb; b jsonb;
BEGIN
 doc:=jsonb_build_object('title','Plano QA rollback','process','Qualificar leads e validar avanço.', 'items',jsonb_build_array(jsonb_build_object('id',item_id,'title','Funil de teste','kind','pipeline','depends_on','[]'::jsonb,'config',jsonb_build_object('name','Funil QA plano','stages',jsonb_build_array(jsonb_build_object('name','Novo','color','#334455','is_won',false,'is_lost',false),jsonb_build_object('name','Ganho','color','#33aa55','is_won',true,'is_lost',false))))));
 a:=public.mcp_implementation('save',plan_id,request,0,doc);
 b:=public.mcp_implementation('save',plan_id,request,0,doc);
 IF a<>b THEN RAISE EXCEPTION 'Retry save divergiu'; END IF;
 BEGIN
  PERFORM public.mcp_implementation('apply',plan_id,gen_random_uuid(),1,NULL,item_id);
  RAISE EXCEPTION 'Aplicou sem aprovação';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.mcp_implementation('approve',plan_id,gen_random_uuid(),1,NULL,NULL,'Aprovo este plano sintético de teste.');
 a:=public.mcp_implementation('apply',plan_id,gen_random_uuid(),1,NULL,item_id);
 IF a->'results'->item_id::text->>'status'<>'applied' THEN RAISE EXCEPTION 'Aplicação não concluída: %',a->'results'; END IF;
 b:=public.mcp_implementation('apply',plan_id,gen_random_uuid(),1,NULL,item_id);
 IF a->'results'<>b->'results' THEN RAISE EXCEPTION 'Retry apply divergiu'; END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(public.mcp_list_pipelines()) x WHERE x->>'name'='Funil QA plano')<>1 THEN RAISE EXCEPTION 'Duplicação detectada'; END IF;
 a:=public.mcp_implementation('get',plan_id);
 IF jsonb_array_length(a->'history')<3 THEN RAISE EXCEPTION 'Histórico ausente'; END IF;
END $$;
RESET ROLE;
ROLLBACK;

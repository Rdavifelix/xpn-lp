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
DO $$ BEGIN
INSERT INTO public.sales_pipeline_stages(tenant_id,pipeline_id,name,position) SELECT public.get_tenant_id(),id,'Etapa teste própria',99 FROM public.sales_pipelines LIMIT 1;
BEGIN
 INSERT INTO public.sales_pipeline_stages(tenant_id,pipeline_id,name,position) VALUES(public.get_tenant_id(),current_setting('test.foreign_pipeline')::uuid,'Etapa indevida',100);
 RAISE EXCEPTION 'Referência cruzada permitida';
EXCEPTION WHEN insufficient_privilege THEN NULL; END;
IF (SELECT count(*) FROM public.sales_pipelines) <> 1 THEN RAISE EXCEPTION 'Isolamento pipeline falhou'; END IF;
IF (SELECT count(*) FROM public.tenants) <> 1 THEN RAISE EXCEPTION 'Isolamento empresas falhou'; END IF;
IF EXISTS (SELECT 1 FROM public.leads) THEN RAISE EXCEPTION 'Leads de outra empresa visíveis'; END IF;
BEGIN
 UPDATE public.team_members SET is_superadmin=true WHERE auth_user_id=auth.uid();
 RAISE EXCEPTION 'Elevação superadmin foi permitida';
EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;

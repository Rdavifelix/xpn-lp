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
SET LOCAL ROLE authenticated;
DO $$
DECLARE r jsonb; again jsonb; rid uuid:=gen_random_uuid(); lead text; deal text; task text; pipe text; stage text; won text; member text; res text; data jsonb; templates text;
BEGIN
 member:=public.mcp_context()->>'member_id';
 r:=public.mcp_crm('contato','create',p_request_id=>rid,p_data=>'{"name":"Teste MCP","email":"mcp@example.invalid","tags":["QA"]}');lead:=r->'record'->>'id';
 again:=public.mcp_crm('contato','create',p_request_id=>rid,p_data=>'{"name":"Teste MCP","email":"mcp@example.invalid","tags":["QA"]}');
 IF r<>again THEN RAISE EXCEPTION 'Replay não idempotente'; END IF;
 BEGIN PERFORM public.mcp_crm('contato','create',p_request_id=>rid,p_data=>'{"name":"Diferente"}'); RAISE EXCEPTION 'Replay diferente aceito'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 r:=public.mcp_crm('funil','create',p_request_id=>gen_random_uuid(),p_data=>'{"name":"Funil QA"}');pipe:=r->'record'->>'id';
 r:=public.mcp_crm('etapa','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('name','Novo','pipeline_id',pipe,'position',0));stage:=r->'record'->>'id';
 r:=public.mcp_crm('etapa','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('name','Ganho','pipeline_id',pipe,'position',1,'is_won',true));won:=r->'record'->>'id';
 r:=public.mcp_crm('oportunidade','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('lead_id',lead,'title','Proposta QA','pipeline_id',pipe,'pipeline_stage_id',stage,'negotiated_price',1500));deal:=r->'record'->>'id';
 r:=public.mcp_crm('oportunidade','move',p_id=>deal,p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('pipeline_stage_id',won));
 IF r->'record'->>'status'<>'won' OR r->'record'->>'won_at' IS NULL THEN RAISE EXCEPTION 'Ganho não persistido'; END IF;
 r:=public.mcp_crm('tarefa','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('name','Follow-up','lead_id',lead,'responsavel_id',member));task:=r->'record'->>'id';
 r:=public.mcp_crm('tarefa','complete',p_id=>task,p_request_id=>gen_random_uuid());
 IF r->'record'->>'status'<>'completed' OR r->'record'->>'completed'<>'true' THEN RAISE EXCEPTION 'Tarefa não concluída'; END IF;
 PERFORM public.mcp_crm('tarefa','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('name','Reunião QA','task_type','meeting','lead_id',lead,'responsavel_id',member,'scheduled_at',now()+interval '1 day','end_datetime',now()+interval '1 day 30 minutes'));
 BEGIN PERFORM public.mcp_crm('tarefa','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('name','Conflito QA','task_type','meeting','lead_id',lead,'responsavel_id',member,'scheduled_at',now()+interval '1 day','end_datetime',now()+interval '1 day 30 minutes')); RAISE EXCEPTION 'Conflito aceito'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 r:=public.mcp_crm('tarefa','update',p_id=>task,p_request_id=>gen_random_uuid(),p_data=>'{"status":"cancelled","completed":false}');
 IF r->'record'->>'status'<>'cancelled' THEN RAISE EXCEPTION 'Cancelamento não persistido'; END IF;
 PERFORM public.mcp_crm('nota','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('lead_id',lead,'deal_id',deal,'content','Nota QA'));
 FOR res,data IN SELECT * FROM (VALUES
 ('produto','{"name":"Produto QA","slug":"produto-qa","price":100}'::jsonb),
 ('template_email','{"name":"Template QA","subject":"Olá","html_content":"<p>Teste</p>"}'::jsonb),
 ('campanha_email','{"name":"Campanha QA","subject":"Olá"}'::jsonb),
 ('campanha_whatsapp','{"name":"Campanha WA QA","message_content":"Olá"}'::jsonb),
 ('automacao_email','{"name":"Automação QA","trigger_event":"lead_created"}'::jsonb),
 ('automacao_comercial','{"name":"Automação QA","trigger_type":"deal_created","action_type":"create_task","action_config":{"name":"Follow-up"}}'::jsonb),
 ('lista_email','{"name":"Lista QA"}'::jsonb)) v(resource,payload) LOOP
  r:=public.mcp_crm(res,'create',p_request_id=>gen_random_uuid(),p_data=>data);
  IF r->>'ok'<>'true' THEN RAISE EXCEPTION 'Criação falhou: %',res; END IF;
  PERFORM public.mcp_crm(res,'update',p_id=>r->'record'->>'id',p_request_id=>gen_random_uuid(),p_data=>'{"name":"Renomeado QA"}');
  PERFORM public.mcp_crm(res,'get',p_id=>r->'record'->>'id');
  PERFORM public.mcp_crm(res,'list');
 END LOOP;
 r:=public.mcp_crm('contato','list',p_filters=>'{"query":"mcp@example.invalid"}');
 IF jsonb_array_length(r->'items')<>1 THEN RAISE EXCEPTION 'Busca falhou'; END IF;
 r:=public.mcp_crm('membro','list');
 IF r::text LIKE '%google_access_token%' OR r::text LIKE '%password%' THEN RAISE EXCEPTION 'Segredo exposto'; END IF;
 BEGIN PERFORM public.mcp_crm('contato','update',p_id=>lead,p_request_id=>gen_random_uuid(),p_data=>'{"tenant_id":"00000000-0000-0000-0000-000000000001"}'); RAISE EXCEPTION 'Troca de tenant aceita'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
 BEGIN PERFORM public.mcp_crm('oportunidade','create',p_request_id=>gen_random_uuid(),p_data=>jsonb_build_object('lead_id','3635e2b9-ee5e-4e06-b204-e3efd2c822d5','title','Intrusão','pipeline_id',pipe,'pipeline_stage_id',stage)); RAISE EXCEPTION 'Referência externa aceita'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.mcp_crm('contato','get',p_id=>'3635e2b9-ee5e-4e06-b204-e3efd2c822d5'); RAISE EXCEPTION 'Contato externo visível'; EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
 PERFORM set_config('request.path','/rpc/mcp_crm',true);PERFORM public.mcp_request_guard();
END $$;
RESET ROLE;
UPDATE crm_mcp.clients SET can_write=false WHERE client_id='test-crm-operations';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 PERFORM public.mcp_crm('contato','list');
 BEGIN PERFORM public.mcp_crm('contato','create',p_request_id=>gen_random_uuid(),p_data=>'{"name":"Sem permissão"}'); RAISE EXCEPTION 'Readonly escreveu'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;

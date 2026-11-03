import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const tenantA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const tenantB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const userA = '11111111-1111-4111-8111-111111111111';
const userB = '22222222-2222-4222-8222-222222222222';
const sessionId = '33333333-3333-4333-8333-333333333333';
const requestId = '44444444-4444-4444-8444-444444444444';
const resource = 'https://mcp.example.com/mcp';
const pipeline = { name: 'Funil da imersão', stages: [
  { name: 'Novo', color: '#3b82f6', is_won: false, is_lost: false },
  { name: 'Ganho', color: '#00ff00', is_won: true, is_lost: false },
] };

test('planos: versão, aprovação, execução, recuperação e isolamento', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE ROLE supabase_auth_admin; CREATE ROLE authenticator;
      CREATE SCHEMA auth;
      CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT (auth.jwt()->>'sub')::uuid $$;
      GRANT USAGE ON SCHEMA auth TO authenticated, anon;
      GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO authenticated, anon;
      CREATE TABLE auth.oauth_clients(id uuid PRIMARY KEY,redirect_uris text,client_type text,registration_type text,token_endpoint_auth_method text,deleted_at timestamptz);
      CREATE TABLE auth.sessions (id uuid PRIMARY KEY, user_id uuid);
      CREATE TABLE auth.users (id uuid PRIMARY KEY,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb DEFAULT '{}',raw_app_meta_data jsonb DEFAULT '{}');
      CREATE TABLE public.tenants (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, name text,slug text,owner_user_id uuid, is_active boolean DEFAULT true);
      CREATE TABLE public.team_members (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, tenant_id uuid REFERENCES public.tenants, auth_user_id uuid, email text,name text,team text,role text, is_active boolean DEFAULT true);
      CREATE TABLE public.profiles(id uuid PRIMARY KEY,email text,name text,tenant_id uuid NOT NULL);
      CREATE TABLE public.config(key text PRIMARY KEY,value text);
      CREATE FUNCTION public.tenant_seed_defaults(tenant uuid) RETURNS void LANGUAGE plpgsql SET search_path=public AS $$ BEGIN
        IF EXISTS(SELECT 1 FROM tenants WHERE id=tenant AND name='Falha de seed') THEN RAISE EXCEPTION 'seed failed'; END IF;
        INSERT INTO sales_pipelines(tenant_id,name) VALUES(tenant,'Funil inicial');
      END $$;
      CREATE TABLE public.agents_registry(id uuid DEFAULT gen_random_uuid() PRIMARY KEY,tenant_id uuid,slug text UNIQUE,display_name text,description text,emoji text,provider text,model text,system_prompt text,settings jsonb,is_active boolean,created_by uuid,responsible_user_id uuid,is_template boolean,avatar_color text,tier text);
      CREATE TABLE public.sales_pipelines (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, tenant_id uuid REFERENCES public.tenants, name text NOT NULL, position int DEFAULT 0, is_default boolean DEFAULT false, is_active boolean DEFAULT true);
      CREATE TABLE public.sales_pipeline_stages (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, tenant_id uuid REFERENCES public.tenants, pipeline_id uuid REFERENCES public.sales_pipelines, name text NOT NULL, position int, color text, is_won boolean, is_lost boolean);
      ALTER TABLE public.sales_pipelines ENABLE ROW LEVEL SECURITY;
      CREATE POLICY legacy_allow ON public.sales_pipelines FOR ALL TO authenticated USING (true) WITH CHECK (true);
      GRANT SELECT, INSERT ON public.sales_pipelines TO authenticated;
    `);
    const migration = await readFile(new URL('../../supabase/migrations/20260907171942_mcp_tenant_foundation.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(await readFile(new URL('../../supabase/migrations/20260907173623_mcp_onboarding_and_boundary.sql',import.meta.url),'utf8'));
    await db.exec(await readFile(new URL('../../supabase/migrations/20260907174102_mcp_agent_drafts.sql',import.meta.url),'utf8'));
    for (const migration of ['20260907180939_mcp_oauth_claims_compatibility.sql','20260907181844_mcp_agent_member_ownership.sql','20260907182514_mcp_dynamic_clients.sql','20260907183209_mcp_authorization_denial.sql','20260907190621_mcp_portable_clients.sql','20260907192532_mcp_implementation_plans.sql']) {
      await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
    }
    await db.query('INSERT INTO tenants(id,name) VALUES ($1, $2), ($3, $4)', [tenantA, 'Empresa A', tenantB, 'Empresa B']);
    await db.query('INSERT INTO team_members(tenant_id,auth_user_id,role) VALUES ($1,$2,$3),($4,$5,$6)', [tenantA,userA,'admin',tenantB,userB,'admin']);
    await db.query('INSERT INTO auth.sessions VALUES ($1,$2)', [sessionId,userA]);
    await db.query('INSERT INTO crm_mcp.clients VALUES ($1,$2,true,true)', ['approved',resource]);
    for (const event of [{client_id:'approved',claims:{aud:'authenticated'}},{claims:{client_id:'approved',aud:'authenticated'}}]) {
      const hook=await db.query<{result:{claims:{aud:string}}}>('SELECT public.mcp_access_token_hook($1) AS result',[event]);
      assert.equal(hook.rows[0].result.claims.aud,resource);
    }
    await db.query('INSERT INTO crm_mcp.settings(resource,dynamic_clients_enabled) VALUES($1,true)',[resource]);
    const dynamic='77777777-7777-4777-8777-777777777777';
    await db.query("INSERT INTO auth.oauth_clients(id,redirect_uris,client_type,registration_type,token_endpoint_auth_method) VALUES($1,'https://chatgpt.com/connector/oauth/test-callback','public','dynamic','none')",[dynamic]);
    const resolved=await db.query<{resource:string}>('SELECT resource FROM crm_mcp.resolve_client($1)',[dynamic]);
    assert.equal(resolved.rows[0].resource,resource);
    for (const uri of ['https://claude.ai/api/mcp/auth_callback','https://another-client.example/oauth','http://127.0.0.1:53905/callback/u2SEdKL0Nrgr','http://localhost:1234/callback','http://[::1]:54321/callback']) {
      await db.query('UPDATE auth.oauth_clients SET redirect_uris=$1 WHERE id=$2',[uri,dynamic]);
      assert.equal((await db.query('SELECT resource FROM crm_mcp.resolve_client($1)',[dynamic])).rows[0].resource,resource,uri);
    }
    for (const uri of ['http://remote.example/callback','http://127.0.0.1.evil.example/callback','http://127.0.0.1@evil.example/callback','https://user@host.example/cb','https://host.example/cb#fragment','http://127.0.0.1:99999/cb','javascript:alert(1)','https://good.example/cb,http://remote.example/cb']) {
      await db.query('UPDATE auth.oauth_clients SET redirect_uris=$1 WHERE id=$2',[uri,dynamic]);
      assert.equal((await db.query('SELECT resource FROM crm_mcp.resolve_client($1)',[dynamic])).rows[0].resource,null,uri);
    }
    await db.query("UPDATE auth.oauth_clients SET redirect_uris='http://127.0.0.1:55555/callback/new-attempt' WHERE id=$1",[dynamic]);
    await db.query('INSERT INTO crm_mcp.clients VALUES($1,$2,true,false)',[dynamic,resource]);
    assert.equal((await db.query('SELECT is_active FROM crm_mcp.resolve_client($1)',[dynamic])).rows[0].is_active,false);
    await db.query('DELETE FROM crm_mcp.clients WHERE client_id=$1',[dynamic]);
    const claims = (extra = {}) => ({ sub: userA, role: 'authenticated', aud: resource, client_id: 'approved', session_id: sessionId, app_metadata: { tenant_id: tenantA }, ...extra });
    const setClaims = async (value: unknown) => { await db.query("SELECT set_config('request.jwt.claims',$1,false)", [JSON.stringify(value)]); };
    const call = async (name: string, args: unknown[] = []) => (await db.query<{ result: any }>(`SELECT public.${name}(${args.map((_, i) => '$' + (i + 1)).join(',')}) AS result`, args)).rows[0].result;
    await db.exec('SET ROLE authenticated');
    await setClaims(claims());
    assert.equal((await call('mcp_context')).tenant_id, tenantA);
    await db.query("SELECT set_config('request.path','/rpc/mcp_list_pipelines',false)");
    await call('mcp_request_guard');
    await db.query("SELECT set_config('request.path','/rpc/legacy_admin_function',false)");
    await assert.rejects(call('mcp_request_guard'),/operações MCP/);
    await assert.rejects(call('mcp_authorization_info', ['approved']), /Entre com uma conta/);
    await setClaims(claims({client_id:null}));
    assert.equal((await call('mcp_authorization_info',['approved'])).tenant_name,'Empresa A');
    await assert.rejects(call('mcp_authorization_info',['unknown']));
    await setClaims(claims());
    const planId=crypto.randomUUID(),itemId=crypto.randomUUID(),campaignId=crypto.randomUUID();
    const doc={title:'Operação comercial',process:'Qualificar leads e preparar atendimento.',items:[
      {id:itemId,title:'Funil',kind:'pipeline',config:pipeline,depends_on:[]},
      {id:campaignId,title:'Campanha',kind:'campaign',config:{objective:'Reativar oportunidades'},depends_on:[itemId]},
    ]};
    const invoke=(action:string,version:number,document:unknown=null,item:string|null=null,approval:string|null=null,request=crypto.randomUUID(),id=planId)=>call('mcp_implementation',[action,id,request,version,document,item,approval]);
    const saveId=crypto.randomUUID();
    const saved=await invoke('save',0,doc,null,null,saveId);
    assert.equal(saved.version,1);assert.equal(saved.approval,null);
    assert.deepEqual(await invoke('save',0,doc,null,null,saveId),saved);
    assert.equal((await call('mcp_implementation',['list'])).plans.length,1);
    await assert.rejects(invoke('apply',1,null,itemId),/aprovação/);
    await assert.rejects(invoke('save',0,doc),/Versão/);
    await invoke('approve',1,null,null,'Sim, aprovo esta configuração.');
    await assert.rejects(invoke('apply',1,null,campaignId),/dependências/);
    const applied=await invoke('apply',1,null,itemId);
    assert.equal(applied.results[itemId].status,'applied');
    assert.equal((await call('mcp_list_pipelines')).length,1);
    await invoke('apply',1,null,itemId);
    assert.equal((await call('mcp_list_pipelines')).length,1,'retry com novo request também não duplica item aplicado');
    const pending=await invoke('apply',1,null,campaignId);
    assert.equal(pending.results[campaignId].status,'pending_capability');
    await assert.rejects(invoke('save',1,{...doc,items:doc.items.slice(1)}),/Dependências|aplicado/);
    await assert.rejects(invoke('save',1,{...doc,items:[{...doc.items[0],config:{...pipeline,name:'Mudou'}},doc.items[1]]}),/aplicado/);
    const revised=await invoke('save',1,{...doc,process:'Processo revisado com critérios comerciais.'});
    assert.equal(revised.version,2);assert.equal(revised.approval,null);assert.equal(revised.results[itemId].status,'applied');
    await assert.rejects(invoke('apply',2,null,campaignId),/aprovação/);
    await assert.rejects(invoke('approve',1,null,null,'Sim, aprovo esta configuração.'),/Versão/);
    // An invalid executable payload cannot leave a partial pipeline behind.
    const badPlan=crypto.randomUUID(),badItem=crypto.randomUUID();
    await invoke('save',0,{title:'Falha recuperável',process:'Teste de retorno de falha.',items:[{id:badItem,title:'Inválido',kind:'pipeline',config:{name:'Erro',stages:[]},depends_on:[]}]},null,null,crypto.randomUUID(),badPlan);
    await invoke('approve',1,null,null,'Sim, aprovo o teste de falha.',crypto.randomUUID(),badPlan);
    const failed=await invoke('apply',1,null,badItem,null,crypto.randomUUID(),badPlan);
    assert.equal(failed.results[badItem].status,'failed');
    assert.equal((await call('mcp_list_pipelines')).length,1);
    assert.ok((await call('mcp_implementation',['get',planId])).history.length>=5);
    const agentPlan=crypto.randomUUID(),agentItem=crypto.randomUUID(),templateId=crypto.randomUUID();
    await db.exec('RESET ROLE');
    await db.query("INSERT INTO agents_registry(id,slug,display_name,is_template,provider,model,is_active) VALUES($1,'template-plan-test','Modelo',true,'test','test',true)",[templateId]);
    await db.exec('SET ROLE authenticated');
    await invoke('save',0,{title:'Agente comercial',process:'Preparar qualificação assistida.',items:[{id:agentItem,title:'Qualificador',kind:'agent_draft',config:{template_id:templateId,name:'Qualificador',system_prompt:'Qualifique os leads conforme o processo aprovado.'},depends_on:[]}]},null,null,crypto.randomUUID(),agentPlan);
    await invoke('approve',1,null,null,'Sim, aprovo este agente em rascunho.',crypto.randomUUID(),agentPlan);
    const agentResult=await invoke('apply',1,null,agentItem,null,crypto.randomUUID(),agentPlan);
    assert.equal(agentResult.results[agentItem].status,'applied');
    assert.equal(agentResult.results[agentItem].resource.is_active,false);
    await assert.rejects(db.query('SELECT * FROM crm_mcp.plans'),/permission/);
    await db.exec('RESET ROLE');
    await db.query("UPDATE team_members SET role='user' WHERE auth_user_id=$1",[userA]);
    await db.exec('SET ROLE authenticated');
    assert.equal((await call('mcp_implementation',['get',planId])).version,2);
    await assert.rejects(invoke('approve',2,null,null,'Sim, eu aprovo a revisão.'),/Administrador/);
    await db.exec('RESET ROLE');
    await db.query('INSERT INTO auth.sessions VALUES($1,$2)',[userB,userB]);
    await db.exec('SET ROLE authenticated');
    await setClaims(claims({sub:userB,session_id:userB,app_metadata:{tenant_id:tenantB}}));
    assert.deepEqual((await call('mcp_implementation',['list'])).plans,[]);
    await assert.rejects(call('mcp_implementation',['get',planId]),/não encontrado/);
    await assert.rejects(invoke('apply',2,null,itemId),/não encontrado/);
  } finally { await db.close(); }
});

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

test('migration em PostgreSQL: isolamento, recusa, atomicidade, retry e revogação', async () => {
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
    for (const migration of ['20260907180939_mcp_oauth_claims_compatibility.sql','20260907181844_mcp_agent_member_ownership.sql','20260907182514_mcp_dynamic_clients.sql','20260907183209_mcp_authorization_denial.sql','20260907190621_mcp_portable_clients.sql']) {
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
    const created = await call('mcp_create_pipeline', [requestId,pipeline]);
    assert.deepEqual(await call('mcp_create_pipeline', [requestId,pipeline]), created);
    assert.equal((await call('mcp_list_pipelines')).length, 1);
    await assert.rejects(call('mcp_create_pipeline', [requestId,{ ...pipeline, name: 'Different' }]));
    await assert.rejects(call('mcp_create_pipeline', [crypto.randomUUID(),{ ...pipeline, tenant_id: tenantB }]));
    await assert.rejects(call('mcp_create_pipeline', [crypto.randomUUID(),{ name: 'Inválido', stages: [pipeline.stages[0], {...pipeline.stages[1], color: 'bad'}] }]));
    assert.equal((await call('mcp_list_pipelines')).length, 1);
    assert.equal((await db.query('SELECT * FROM public.sales_pipelines')).rows.length, 0, 'OAuth sem acesso direto mesmo com policy antiga permissiva');
    await assert.rejects(db.query('INSERT INTO public.sales_pipelines(tenant_id,name) VALUES ($1,$2)', [tenantB,'Forbidden']));
    await setClaims(claims({ app_metadata: { tenant_id: tenantB } }));
    await assert.rejects(call('mcp_context'), /Empresa não provisionada/);
    await setClaims(claims({ app_metadata: {}, user_metadata: { tenant_id: tenantA } }));
    assert.equal(await call('get_tenant_id'), null);
    await assert.rejects(call('mcp_context'));
    await setClaims(claims({ client_id: 'unknown' }));
    await assert.rejects(call('mcp_context'));
    await setClaims(claims({ aud: 'authenticated' }));
    await assert.rejects(call('mcp_context'));
    await setClaims(claims());
    await db.exec('RESET ROLE');
    await db.query("UPDATE team_members SET role='user' WHERE auth_user_id=$1", [userA]);
    await db.exec('SET ROLE authenticated');
    await assert.rejects(call('mcp_create_pipeline',[crypto.randomUUID(),pipeline]));
    await db.exec('RESET ROLE');
    await db.query('INSERT INTO auth.sessions VALUES ($1,$2)', [userB,userB]);
    await db.exec('SET ROLE authenticated');
    await setClaims(claims({ sub:userB, session_id:userB, app_metadata:{tenant_id:tenantB} }));
    assert.deepEqual(await call('mcp_list_pipelines'), []);
    await call('mcp_create_pipeline',[requestId,pipeline]);
    assert.equal((await call('mcp_list_pipelines')).length,1);
    await db.exec('RESET ROLE');
    await db.query('UPDATE tenants SET is_active=false WHERE id=$1',[tenantB]);
    await db.exec('SET ROLE authenticated');
    await assert.rejects(call('mcp_context'));
    await setClaims(claims());
    await db.exec('RESET ROLE');
    await db.query('DELETE FROM auth.sessions WHERE id=$1',[sessionId]);
    await db.exec('SET ROLE authenticated');
    await assert.rejects(call('mcp_context'), /Sessão revogada/);
    await db.exec('RESET ROLE');
    assert.equal((await db.query('SELECT * FROM sales_pipeline_stages')).rows.length, 4);
    assert.equal((await db.query('SELECT * FROM crm_mcp.operations')).rows.length, 2);
    const hooked = await call('mcp_access_token_hook', [{client_id:'approved',claims:{sub:userA,aud:'authenticated'}}]);
    assert.equal(hooked.claims.aud,resource);
    // Fluxo de cadastro: profile sem empresa, seed transacional e retry.
    const newcomer='55555555-5555-4555-8555-555555555555';
    await db.exec('CREATE TRIGGER create_profile AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user()');
    await db.query('INSERT INTO auth.users(id,email,email_confirmed_at) VALUES($1,$2,now())',[newcomer,'novo@example.invalid']);
    assert.equal((await db.query<{tenant_id:string|null}>('SELECT tenant_id FROM profiles WHERE id=$1',[newcomer])).rows[0].tenant_id,null);
    await setClaims({sub:newcomer,role:'authenticated'});
    await db.exec('SET ROLE authenticated');
    await assert.rejects(call('tenant_onboard',['Minha empresa']),/ainda não liberado/);
    await db.exec('RESET ROLE');
    await db.exec("INSERT INTO config VALUES('multi_tenant_enabled','true')");
    await db.exec('SET ROLE authenticated');
    await assert.rejects(call('tenant_onboard',['Falha de seed']),/seed failed/);
    await db.exec('RESET ROLE');
    assert.equal((await db.query("SELECT * FROM tenants WHERE name='Falha de seed'")).rows.length,0);
    assert.equal((await db.query<{raw_app_meta_data:object}>('SELECT raw_app_meta_data FROM auth.users WHERE id=$1',[newcomer])).rows[0].raw_app_meta_data.tenant_id,undefined);
    await db.exec('SET ROLE authenticated');
    const onboarded=await call('tenant_onboard',['Empresa nova']);
    assert.equal((await call('tenant_onboard',['Empresa nova'])).tenant_id,onboarded.tenant_id);
    await db.exec('RESET ROLE');
    assert.equal((await db.query('SELECT * FROM tenants WHERE owner_user_id=$1',[newcomer])).rows.length,1);
    // Rascunho de agente: modelo público apenas, inativo e sem duplicação.
    await db.query('INSERT INTO auth.sessions VALUES($1,$2)',[sessionId,userA]);
    await db.query("UPDATE team_members SET role='admin' WHERE auth_user_id=$1",[userA]);
    const template='66666666-6666-4666-8666-666666666666';
    await db.query("INSERT INTO agents_registry(id,display_name,is_template,is_active,provider,model) VALUES($1,'Modelo',true,true,'provider-existing','model-existing')",[template]);
    await setClaims(claims());
    await db.exec('SET ROLE authenticated');
    const agentRequest=crypto.randomUUID();
    const draft=await call('mcp_create_agent_draft',[agentRequest,template,'Atendente','Atenda seguindo o processo validado pelo proprietário.']);
    assert.equal(draft.is_active,false);
    assert.deepEqual(await call('mcp_create_agent_draft',[agentRequest,template,'Atendente','Atenda seguindo o processo validado pelo proprietário.']),draft);
    await assert.rejects(call('mcp_create_agent_draft',[crypto.randomUUID(),draft.agent_id,'Outro','Atenda seguindo o processo validado pelo proprietário.']));
    assert.equal((await call('mcp_list_agents')).length,2);
    await db.exec('RESET ROLE');
    const owner=await db.query('SELECT r.created_by=m.id AND r.responsible_user_id=m.id AS correct FROM agents_registry r JOIN team_members m ON m.auth_user_id=$1 WHERE r.id=$2',[userA,draft.agent_id]);
    assert.equal(owner.rows[0].correct,true);
  } finally { await db.close(); }
});

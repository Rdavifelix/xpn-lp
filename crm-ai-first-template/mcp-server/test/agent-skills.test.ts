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

test('agentes com habilidades: catálogo, criação atômica, replay, isolamento e plano', async () => {
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
    await db.exec(`
      CREATE TABLE agents_skill_catalog(id uuid DEFAULT gen_random_uuid() PRIMARY KEY,slug text UNIQUE,display_name text,description text,parameters_schema jsonb,action_type text,action_config jsonb,default_usage_mode text,provider text);
      CREATE TABLE agents_tools(id uuid DEFAULT gen_random_uuid() PRIMARY KEY,tenant_id uuid,agent_id uuid,name text,description text,parameters_schema jsonb,action_type text,action_config jsonb,usage_mode text,is_active boolean,requires_approval boolean,provider text,UNIQUE(agent_id,name));
    `);
    const migration = await readFile(new URL('../../supabase/migrations/20260907171942_mcp_tenant_foundation.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(await readFile(new URL('../../supabase/migrations/20260907173623_mcp_onboarding_and_boundary.sql',import.meta.url),'utf8'));
    await db.exec(await readFile(new URL('../../supabase/migrations/20260907174102_mcp_agent_drafts.sql',import.meta.url),'utf8'));
    for (const migration of ['20260907180939_mcp_oauth_claims_compatibility.sql','20260907181844_mcp_agent_member_ownership.sql','20260907182514_mcp_dynamic_clients.sql','20260907183209_mcp_authorization_denial.sql','20260907190621_mcp_portable_clients.sql','20260907192532_mcp_implementation_plans.sql','20260907201406_mcp_agent_skills.sql']) {
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
    await db.exec('RESET ROLE');
    const tid=crypto.randomUUID();
    await db.query("INSERT INTO agents_registry(id,slug,display_name,is_template,provider,model,is_active) VALUES($1,'test-template','Atendente',true,'test','test',true)",[tid]);
    for(const [slug,mode] of [['update_lead','always'],['schedule_meeting','with_approval'],['execute_sql','always']])await db.query("INSERT INTO agents_skill_catalog(slug,display_name,description,parameters_schema,action_type,action_config,default_usage_mode) VALUES($1,$1,$1,'{}','sql',$2,$3)",[slug,{function:'agent_'+slug,params_map:{p_lead_id:'{{lead_id}}'}},mode]);
    await db.exec('SET ROLE authenticated');
    const config={template_id:tid,name:'SDR Teste',system_prompt:'Qualifique de acordo com as regras da empresa.',tools:['update_lead','schedule_meeting']};
    const create=(c:unknown,request=crypto.randomUUID())=>call('mcp_agent_setup',['create',request,null,c]);
    const catalog=await call('mcp_agent_setup',['catalog']);
    assert.equal(catalog.skills.find((x:any)=>x.slug==='execute_sql').installable,false);
    assert.deepEqual(catalog.skills.find((x:any)=>x.slug==='update_lead').runtime_context,['lead_id']);
    assert.ok(!JSON.stringify(catalog).includes('params_map'));
    await assert.rejects(create({...config,tools:['update_lead','missing']}),/inexistente/);
    await assert.rejects(create({...config,tools:['execute_sql']}),/disponível/);
    await assert.rejects(create({...config,tools:[]}),/habilidades/);
    assert.equal((await call('mcp_list_agents')).filter((a:any)=>!a.is_template).length,0);
    const request=crypto.randomUUID();const created=await create(config,request);
    assert.deepEqual(await create(config,request),created);
    assert.equal(created.tools.length,2);assert.equal(created.ready,false);assert.equal(created.is_active,false);
    assert.equal(created.tools.find((x:any)=>x.name==='update_lead').enabled,true);
    assert.equal(created.tools.find((x:any)=>x.name==='schedule_meeting').enabled,false);
    await assert.rejects(create({...config,name:'Outro'},request),/request_id/);
    const attach=()=>call('mcp_agent_setup',['attach',crypto.randomUUID(),created.agent_id,{tools:['update_lead']}]);
    assert.equal((await attach()).tools.length,2);
    const plan=crypto.randomUUID(),item=crypto.randomUUID();
    await call('mcp_implementation',['save',plan,crypto.randomUUID(),0,{title:'SDR da operação',process:'Atender e qualificar os leads.',items:[{id:item,title:'SDR',kind:'agent_draft',config,depends_on:[]}]}]);
    await call('mcp_implementation',['approve',plan,crypto.randomUUID(),1,null,null,'Aprovo o SDR com estas habilidades.']);
    const applied=await call('mcp_implementation',['apply',plan,crypto.randomUUID(),1,null,item]);
    assert.equal(applied.results[item].status,'applied');
    assert.equal(applied.results[item].resource.tools.length,2);
    await db.exec('RESET ROLE');
    await db.query("UPDATE agents_tools SET action_config='{}' WHERE agent_id=$1 AND name='update_lead'",[created.agent_id]);
    await db.exec('SET ROLE authenticated');
    await assert.rejects(attach(),/personalizada/);
    await db.exec('RESET ROLE');
    await db.query('UPDATE agents_registry SET is_active=true WHERE id=$1',[created.agent_id]);
    await db.exec('SET ROLE authenticated');
    await assert.rejects(attach(),/Pause/);
    await db.exec('RESET ROLE');
    await db.query('INSERT INTO auth.sessions VALUES($1,$2)',[userB,userB]);
    await db.exec('SET ROLE authenticated');
    await setClaims(claims({sub:userB,session_id:userB,app_metadata:{tenant_id:tenantB}}));
    await assert.rejects(call('mcp_agent_setup',['get',null,created.agent_id]),/não encontrado/);
    await assert.rejects(attach(),/não encontrado/);
  } finally {await db.close();}
});

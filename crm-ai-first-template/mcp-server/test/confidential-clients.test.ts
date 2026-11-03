import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';

test('OAuth: Claude confidencial, Codex público, redirects e bloqueios explícitos',async()=>{
 const db=new PGlite();
 const id='77777777-7777-4777-8777-777777777777';
 try{
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth; CREATE SCHEMA crm_mcp;
   CREATE TABLE crm_mcp.clients(client_id text PRIMARY KEY,resource text,can_write boolean,is_active boolean);
   CREATE TABLE crm_mcp.settings(singleton boolean,dynamic_clients_enabled boolean,resource text);
   CREATE TABLE auth.oauth_clients(id uuid PRIMARY KEY,client_type text,registration_type text,token_endpoint_auth_method text,redirect_uris text,deleted_at timestamptz);
   INSERT INTO crm_mcp.settings VALUES(true,true,'https://crm.example/mcp');`);
  const original=await readFile(new URL('../../supabase/migrations/20260907190621_mcp_portable_clients.sql',import.meta.url),'utf8');
  await db.exec(original.slice(original.indexOf('CREATE FUNCTION crm_mcp.valid_redirect'),original.indexOf('CREATE OR REPLACE FUNCTION crm_mcp.resolve_client')));
  await db.exec(await readFile(new URL('../../supabase/migrations/20260910190519_mcp_confidential_oauth_clients.sql',import.meta.url),'utf8'));
  await db.query(`INSERT INTO auth.oauth_clients VALUES($1,'confidential','dynamic','client_secret_post','https://claude.ai/api/mcp/auth_callback',null)`,[id]);
  const accepted=async()=> (await db.query<{active:boolean|null}>('SELECT (crm_mcp.resolve_client($1)).is_active AS active',[id])).rows[0].active===true;
  assert.equal(await accepted(),true,'Claude com client_secret_post');
  await db.query("UPDATE auth.oauth_clients SET token_endpoint_auth_method='client_secret_basic'");assert.equal(await accepted(),true);
  await db.query("UPDATE auth.oauth_clients SET token_endpoint_auth_method='none'");assert.equal(await accepted(),false,'Confidential sem autenticação recusado');
  await db.query("UPDATE auth.oauth_clients SET client_type='public'");assert.equal(await accepted(),true,'Público continua funcionando');
  await db.query("UPDATE auth.oauth_clients SET token_endpoint_auth_method='client_secret_post'");assert.equal(await accepted(),false,'Combinação inconsistente recusada');
  await db.query("UPDATE auth.oauth_clients SET client_type='confidential'");
  for(const uri of ['http://remote.example/cb','https://user:secret@example.com/cb','https://claude.ai/api/mcp/auth_callback#fragment']){
   await db.query('UPDATE auth.oauth_clients SET redirect_uris=$1',[uri]);assert.equal(await accepted(),false,uri);
  }
  await db.query("UPDATE auth.oauth_clients SET redirect_uris='https://claude.ai/api/mcp/auth_callback'");
  await db.query("INSERT INTO crm_mcp.clients VALUES($1,'https://crm.example/mcp',true,false)",[id]);assert.equal(await accepted(),false,'Bloqueio administrativo prevalece');
  await db.exec('DELETE FROM crm_mcp.clients; UPDATE crm_mcp.settings SET dynamic_clients_enabled=false');assert.equal(await accepted(),false);
  await db.exec('UPDATE crm_mcp.settings SET dynamic_clients_enabled=true; UPDATE auth.oauth_clients SET deleted_at=now()');assert.equal(await accepted(),false);
 }finally{await db.close();}
});

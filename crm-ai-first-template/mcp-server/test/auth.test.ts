import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, SignJWT } from 'jose';
import { tokenVerifier, readConfig, type Config } from '../src/auth.js';

export const config: Config = { publicUrl: 'https://mcp.example.com/mcp', supabaseUrl: 'https://project.supabase.co', publishableKey: 'sb_publishable_test', clientIds: ['client-approved'], port: 8081, host: '127.0.0.1' };
test('valida assinatura, destinatário, emissor, validade e cliente OAuth', async () => {
  const { privateKey, publicKey } = await generateKeyPair('ES256');
  const verify = tokenVerifier(config, async () => publicKey);
  const sign = (overrides = {}, key = privateKey) => new SignJWT({
    role: 'authenticated', client_id: 'client-approved', session_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    sub: '11111111-1111-4111-8111-111111111111', iss: `${config.supabaseUrl}/auth/v1`, aud: config.publicUrl,
    iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300, ...overrides,
  }).setProtectedHeader({ alg: 'ES256' }).sign(key);
  assert.equal((await verify(await sign())).client_id, 'client-approved');
  for (const overrides of [{ aud: 'authenticated' }, { iss: 'https://evil.example' }, { exp: 1 }, { client_id: 'other' }, { role: 'service_role' }, { sub: 'not-a-user' }, { session_id: null }]) {
    await assert.rejects(verify(await sign(overrides)));
  }
  const dynamicVerify=tokenVerifier({...config,allowDynamicClients:true},async()=>publicKey);
  assert.equal((await dynamicVerify(await sign({client_id:'77777777-7777-4777-8777-777777777777'}))).aud,config.publicUrl);
  await assert.rejects(dynamicVerify(await sign({client_id:'arbitrary'})));
  const other = await generateKeyPair('ES256');
  await assert.rejects(verify(await sign({}, other.privateKey)));
  await assert.rejects(verify('invalid'));
});
test('configuração recusa chave secreta e URL insegura', () => {
  const env = { SUPABASE_URL: config.supabaseUrl, SUPABASE_PUBLISHABLE_KEY: config.publishableKey, MCP_OAUTH_CLIENT_IDS: 'client-approved', MCP_PUBLIC_URL: config.publicUrl };
  assert.equal(readConfig(env).publicUrl, config.publicUrl);
  assert.throws(() => readConfig({ ...env, MCP_PUBLIC_URL: 'http://crm.example.com/mcp' }));
  assert.throws(() => readConfig({ ...env, MCP_PUBLIC_URL: 'https://crm.example.com/mcp?token=secret' }));
  assert.throws(() => readConfig({ ...env, SUPABASE_PUBLISHABLE_KEY: 'sb_secret_bad' }));
  assert.throws(() => readConfig({ ...env, MCP_OAUTH_CLIENT_IDS: '' }));
});

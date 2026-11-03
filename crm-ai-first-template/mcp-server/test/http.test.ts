import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { createApp } from '../src/app.js';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import type { Config } from '../src/auth.js';

test('MCP real HTTP: descoberta, 401, origem e separação por requisição', async () => {
  const config: Config = { publicUrl: 'http://127.0.0.1:1/mcp', supabaseUrl: 'https://project.supabase.co', publishableKey: 'sb_publishable_test', clientIds: ['test'], host: '127.0.0.1', port: 1 };
  const listener = createServer().listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const addr = listener.address() as { port: number };
  const base = `http://127.0.0.1:${addr.port}`;
  config.publicUrl = `${base}/mcp`;
  const app = createApp(config, async (token) => {
    if (!['admin-a', 'reader-b'].includes(token)) throw new Error();
    const tenant = token === 'admin-a' ? 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' : 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    return { context: { tenant_id: tenant, user_id: tenant, member_id: tenant, tenant_name: token, role: token === 'admin-a' ? 'admin' : 'user', can_write: token === 'admin-a' },
      rpc: async () => [{ tenant_id: tenant }] };
  });
  listener.on('request', app);
  const headers = {};
  try {
    assert.equal((await fetch(`${base}/.well-known/oauth-protected-resource/mcp`).then(r => r.json())).resource, config.publicUrl);
    const unauth = await fetch(`${base}/mcp`, { method: 'POST', headers });
    assert.equal(unauth.status, 401);
    assert.match(unauth.headers.get('www-authenticate')!, /resource_metadata/);
    assert.equal((await fetch(`${base}/mcp`, { method: 'POST', headers: { ...headers, Origin: 'https://evil.example' } })).status, 403);
    for (const token of ['admin-a', 'reader-b']) {
      const client = new Client({ name: 'integration-test', version: '1' });
      await client.connect(new StreamableHTTPClientTransport(new URL(`${base}/mcp`), { requestInit: { headers: { ...headers, Authorization: `Bearer ${token}` } } }));
      const tools = await client.listTools();
      assert.equal(tools.tools.some(t => t.name === 'criar_pipeline'), token === 'admin-a');
      for(const name of ['criar_contato','criar_oportunidade','mover_oportunidade','criar_tarefa','concluir_tarefa','cancelar_tarefa','agendar_reuniao']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      for(const name of ['configurar_alternancia_closers','listar_credenciais_agentes','vincular_credencial_agente','consultar_operacao_agente','testar_conversa_agente']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      for(const name of ['listar_instancias_whatsapp','criar_instancia_whatsapp','gerar_qrcode_whatsapp','consultar_conexao_whatsapp','vincular_whatsapp_agente']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      for(const name of ['listar_canais_entrada','consultar_opcoes_canal','criar_campo_personalizado','criar_canal_entrada','consultar_canal_entrada','salvar_mapeamento_canal','validar_payload_canal','ativar_canal_entrada','consultar_envios_canal']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      assert.ok(tools.tools.some(t=>t.name==='consultar_campos_oportunidade'));
      for(const name of ['responder_comentario_social','enviar_dm_do_comentario','importar_historico_social','conectar_rede_social','sincronizar_contas_zernio','enviar_mensagem_social','criar_publicacao_social','configurar_atendimento_social','criar_campanha_comentario_dm']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      for(const name of ['listar_contas_sociais','consultar_integracao_zernio','listar_contas_zernio','consultar_mensagens_sociais']) assert.ok(tools.tools.some(t=>t.name===name));
      assert.ok(tools.tools.some(t=>t.name==='listar_contatos'));
      for(const name of ['consultar_agenda_membro','consultar_horarios_livres']) assert.ok(tools.tools.some(t=>t.name===name));
      for(const name of ['criar_usuario_equipe','atualizar_membro_equipe','configurar_expediente','bloquear_agenda','remover_bloqueio_agenda']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      for(const name of ['listar_formularios','consultar_formulario','listar_respostas_formulario']) assert.ok(tools.tools.some(t=>t.name===name));
      for(const name of ['salvar_formulario','publicar_formulario','retirar_formulario_do_ar']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      for(const name of ['listar_conversas','consultar_conversa','consultar_timeline','consultar_contexto_contato']) assert.ok(tools.tools.some(t=>t.name===name));
      for(const name of ['consultar_diagnostico_agente','listar_execucoes_agente','consultar_execucao_agente','atualizar_agente']) assert.equal(tools.tools.some(t=>t.name===name),token==='admin-a');
      const result = await client.callTool({ name: 'consultar_empresa' });
      assert.match(JSON.stringify(result), new RegExp(token));
      const listing = await client.callTool({ name: 'listar_pipelines' });
      assert.match(JSON.stringify(listing), token === 'admin-a' ? /aaaaaaaa/ : /bbbbbbbb/);
      const invalid = await client.callTool({ name: 'criar_pipeline', arguments: { request_id: 'bad', pipeline: { tenant_id: 'foreign' } } });
      assert.equal(invalid.isError, true);
      await client.close();
    }
  } finally { listener.closeAllConnections(); await new Promise<void>(resolve => listener.close(() => resolve())); }
});

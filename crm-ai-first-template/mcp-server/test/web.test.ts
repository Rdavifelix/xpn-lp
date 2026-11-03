import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createWebHandler} from '../src/web.js';

test('adapter serverless: metadata, autenticação e chamada MCP',async()=>{
  const base='https://crm.example.com';
  const handler=createWebHandler({publicUrl:`${base}/mcp`,supabaseUrl:'https://project.supabase.co',publishableKey:'sb_publishable_test',clientIds:['approved'],port:1,host:'127.0.0.1'},async(token)=>{
    if(token!=='valid')throw new Error();
    return {context:{tenant_id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',user_id:'11111111-1111-4111-8111-111111111111',member_id:'22222222-2222-4222-8222-222222222222',tenant_name:'Empresa A',role:'admin',can_write:true},rpc:async()=>[]};
  });
  assert.equal((await handler(new Request(`${base}/.well-known/oauth-protected-resource/mcp`))).status,200);
  assert.equal((await handler(new Request(`${base}/mcp`,{method:'POST'}))).status,401);
  const headers={authorization:'Bearer valid','Content-Type':'application/json',Accept:'application/json, text/event-stream'};
  const response=await handler(new Request(`${base}/mcp`,{method:'POST',headers,body:JSON.stringify({jsonrpc:'2.0',id:1,method:'tools/list'})}));
  assert.equal(response.status,200);
  const result=await response.json();
  assert.ok(result.result.tools.some((t:{name:string})=>t.name==='criar_agente_rascunho'));
  for(const name of ['criar_contato','listar_contatos','atualizar_contato','criar_oportunidade','mover_oportunidade','criar_tarefa','concluir_tarefa','agendar_reuniao','criar_nota','criar_produto','criar_campanha_email','criar_campanha_whatsapp','consultar_capacidades_crm','listar_habilidades_agentes','consultar_agente_configurado','criar_agente','vincular_habilidades_agente','diagnosticar_operacao','consultar_implantacao','prever_implantacao','salvar_implantacao','aprovar_implantacao','aplicar_item_implantacao']) assert.ok(result.result.tools.some((t:{name:string})=>t.name===name));
  assert.ok(result.result.tools.find((t:{name:string})=>t.name==='criar_agente').inputSchema.required.includes('tools'));
  const preview=await handler(new Request(`${base}/mcp`,{method:'POST',headers,body:JSON.stringify({jsonrpc:'2.0',id:2,method:'tools/call',params:{name:'prever_implantacao',arguments:{document:{title:'Operação',process:'Mapeamento comercial de exemplo',items:[{id:'33333333-3333-4333-8333-333333333333',title:'Campanha inicial',kind:'campaign',config:{},depends_on:[]}]}}}})}));
  const previewResult=await preview.json();
  assert.equal(JSON.parse(previewResult.result.content[0].text).items[0].execution,'pending_capability');

  assert.equal((await handler(new Request(`${base}/mcp`,{method:'POST',headers,body:'bad json'}))).status,400);
  assert.equal((await handler(new Request(`${base}/mcp`,{method:'POST',headers:{...headers,origin:'https://evil.example'},body:'{}'}))).status,403);
});

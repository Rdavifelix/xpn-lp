import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StreamableHTTPClientTransport} from '@modelcontextprotocol/sdk/client/streamableHttp.js';
const token=JSON.parse(await readFile(process.env.CRM_OAUTH_SESSION_FILE,'utf8')).access_token;
const c=new Client({name:'crm-live-validation',version:'1.0.0'});
await c.connect(new StreamableHTTPClientTransport(new URL(process.env.MCP_PUBLIC_URL ?? 'https://crm.example.com/mcp'),{requestInit:{headers:{Authorization:`Bearer ${token}`}}}));
console.log('Ferramentas:',(await c.listTools()).tools.map(t=>t.name));
for (const name of ['consultar_empresa','listar_pipelines','listar_agentes']) {
 const r=await c.callTool({name,arguments:{}}); console.log(name,r.isError?'ERRO':'OK');
 if(r.isError) console.log(r.content);
}
const parse=r=>{ if(r.isError) throw new Error(JSON.stringify(r.content));return JSON.parse(r.content[0].text);};
const ctx=parse(await c.callTool({name:'consultar_empresa',arguments:{}}));
if(!process.env.CRM_TEST_TENANT_ID || ctx.tenant_id!==process.env.CRM_TEST_TENANT_ID) throw new Error('Configure CRM_TEST_TENANT_ID com uma empresa exclusiva de testes');
const pipeline={name:'QA — Processo da imersão',stages:[{name:'Entrada'},{name:'Qualificação'},{name:'Proposta'},{name:'Ganho',is_won:true},{name:'Perdido',is_lost:true}]};
const args={request_id:randomUUID(),pipeline};
parse(await c.callTool({name:'prever_pipeline',arguments:{pipeline}}));
const a=parse(await c.callTool({name:'criar_pipeline',arguments:args}));
const b=parse(await c.callTool({name:'criar_pipeline',arguments:args}));
if(JSON.stringify(a)!==JSON.stringify(b)) throw new Error('Idempotência falhou');
console.log('Pipeline e idempotência:',a);
const templates=parse(await c.callTool({name:'listar_agentes',arguments:{}})).filter(a=>a.is_template);
console.log('Templates disponíveis:',templates.length);
if(templates.length){
 const agent=parse(await c.callTool({name:'criar_agente_rascunho',arguments:{request_id:randomUUID(),template_id:templates[0].id,name:'QA — Qualificador da imersão',tools:['update_lead','qualify_lead'],system_prompt:'Você é um rascunho de teste. Qualifique necessidades e organize o processo comercial, sem enviar mensagens.'}}));
 console.log('Agente:',agent);
}
await c.close();

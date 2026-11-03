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
await c.close();

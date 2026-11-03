import { WebStandardStreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js';
import { contextSchema, rpcClient, tokenVerifier, type Config, type TenantContext } from './auth.js';
import { createServer } from './tools.js';

type Access = { context: TenantContext; rpc: ReturnType<typeof rpcClient> };
export function createWebHandler(config: Config, authenticate?: (token:string)=>Promise<Access>) {
  const resource=new URL(config.publicUrl);
  const metadata=`${resource.origin}/.well-known/oauth-protected-resource/mcp`;
  const verify=tokenVerifier(config);
  const authorize=authenticate ?? (async (token:string)=>{
    const claims=await verify(token);
    const rpc=rpcClient(config,token);
    const context=contextSchema.parse(await rpc('mcp_context'));
    if(context.user_id!==claims.sub) throw new Error('Contexto inválido');
    return {context,rpc};
  });
  const json=(body:unknown,status=200,headers:Record<string,string>={})=>Response.json(body,{status,headers:{'Cache-Control':'no-store',...headers}});
  return async (req:Request):Promise<Response>=>{
    const url=new URL(req.url);
    if(url.host!==resource.host || (req.headers.get('origin') && req.headers.get('origin')!==resource.origin)) return json({error:'Origem não permitida'},403);
    if(['/.well-known/oauth-protected-resource','/.well-known/oauth-protected-resource/mcp'].includes(url.pathname) && req.method==='GET') {
      return json({resource:config.publicUrl,authorization_servers:[`${config.supabaseUrl}/auth/v1`],scopes_supported:['openid'],bearer_methods_supported:['header'],resource_name:'CRM AI First'});
    }
    if(url.pathname!=='/mcp') return json({error:'Endereço não encontrado'},404);
    const match=/^Bearer ([^\s]+)$/i.exec(req.headers.get('authorization')??'');
    let access:Access;
    try { if(!match) throw new Error(); access=await authorize(match[1]); }
    catch { return json({error:'Conecte sua conta do CRM com empresa ativa.'},401,{'WWW-Authenticate':`Bearer resource_metadata="${metadata}"`}); }
    if(req.method!=='POST') return json({error:'Método não suportado'},405,{Allow:'POST'});
    const raw=await req.text();
    if(new TextEncoder().encode(raw).length>65536) return json({error:'Pedido muito grande'},413);
    let body:unknown;
    try { body=JSON.parse(raw); } catch { return json({error:'JSON inválido'},400); }
    const server=createServer(access.context,access.rpc);
    const transport=new WebStandardStreamableHTTPServerTransport({sessionIdGenerator:undefined,enableJsonResponse:true});
    try {
      await server.connect(transport);
      const response=await transport.handleRequest(new Request(req.url,{method:'POST',headers:req.headers,body:JSON.stringify(body)}));
      const bytes=await response.arrayBuffer();
      const headers=new Headers(response.headers); headers.set('Cache-Control','no-store');
      return new Response(bytes.byteLength?bytes:null,{status:response.status,headers});
    } catch { return json({error:'Falha no protocolo MCP'},500); }
    finally { await transport.close(); await server.close(); }
  };
}

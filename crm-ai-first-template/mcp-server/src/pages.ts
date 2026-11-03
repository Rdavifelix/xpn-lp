import {z} from 'zod';
import type {McpServer} from '@modelcontextprotocol/sdk/server/mcp.js';
import type {TenantContext,rpcClient} from './auth.js';
export function registerPages(server:McpServer,ctx:TenantContext,rpc:ReturnType<typeof rpcClient>){
 const run=async(action:string,id?:string,data:unknown={},days=30)=>{try{return {content:[{type:'text' as const,text:JSON.stringify(await rpc('web_pages_admin',{p_action:action,p_id:id??null,p_data:data,p_days:days}))}]};}catch(e){return {isError:true,content:[{type:'text' as const,text:(e as Error).message}]};}};
 server.registerTool('listar_paginas_marketing',{description:'Lista landing pages da empresa e situação do rastreamento. Cadastrar URL não instala o código na página.',annotations:{readOnlyHint:true}},async()=>run('list'));
 server.registerTool('consultar_relatorio_pagina',{description:'Visualizações, visitantes estimados, cliques, origens, cadastros confirmados e oportunidades ganhas das sessões. Conversão é cadastro confirmado/sessões. Dados públicos de navegação podem ser afetados por bloqueadores e preferências do navegador.',inputSchema:{id:z.string().uuid(),days:z.number().int().min(1).max(366).default(30)},annotations:{readOnlyHint:true}},async({id,days})=>run('report',id,{},days));
 if(!ctx.can_write)return;
 server.registerTool('cadastrar_pagina_marketing',{description:'Cadastra landing page HTTPS e retorna identificação pública de rastreamento. Instale o script conforme Marketing → Páginas. Para formulário externo use await CRMTracking.ready e CRMTracking.attach(payload) antes de enviar para receive-channel; formulário/iframe do CRM recebe atribuição automaticamente pelo tracker.',inputSchema:{name:z.string().min(1).max(100),url:z.string().url()},annotations:{readOnlyHint:false,idempotentHint:true}},async data=>run('create',undefined,data));
 server.registerTool('alterar_rastreamento_pagina',{description:'Pausa ou retoma a coleta da landing page, preservando o histórico.',inputSchema:{id:z.string().uuid(),active:z.boolean()},annotations:{readOnlyHint:false,idempotentHint:true}},async({id,active})=>run('status',id,{active}));
}

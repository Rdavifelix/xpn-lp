import {z} from 'zod';
import type {McpServer} from '@modelcontextprotocol/sdk/server/mcp.js';
import type {TenantContext,rpcClient} from './auth.js';
const uuid=z.string().uuid();
export function registerWhatsApp(server:McpServer,ctx:TenantContext,rpc:ReturnType<typeof rpcClient>){
 if(!ctx.can_write)return;
 const run=async(args:Record<string,unknown>)=>{
  try{
   const result=await rpc('mcp-whatsapp',args) as Record<string,unknown>;
   const {qr_code,...data}=result;
   const content:Array<{type:'text';text:string}|{type:'image';data:string;mimeType:string}>=[{type:'text',text:JSON.stringify(data)}];
   if(typeof qr_code==='string'&&qr_code.startsWith('data:image/png;base64,'))content.push({type:'image',data:qr_code.slice('data:image/png;base64,'.length).replace(/\s/g,''),mimeType:'image/png'});
   return {content,isError:!!result.error};
  }catch(e){return {isError:true,content:[{type:'text' as const,text:JSON.stringify({error:e instanceof Error?e.message:'Operação recusada'})}]};}
 };
 server.registerTool('listar_instancias_whatsapp',{description:'Lista instâncias Uazapi, canais vinculados e se a integração está configurada. Não retorna chaves. Configure URL/Admin Token pela tela de integrações; nunca peça tokens no chat. Lista contém estado local; consulte conexão para obter estado atual.',annotations:{readOnlyHint:true}},async()=>run({action:'list'}));
 server.registerTool('criar_instancia_whatsapp',{description:'Cria instância Uazapi da empresa autenticada, usando credenciais já cadastradas. Reutilize o mesmo request_id em tentativas; criação incerta é reconciliada e nunca repetida cegamente. Depois use gerar_qrcode_whatsapp. Não envia mensagens.',inputSchema:{request_id:uuid,name:z.string().trim().min(1).max(100)},annotations:{readOnlyHint:false,idempotentHint:true}},async args=>run({action:'create',...args}));
 server.registerTool('gerar_qrcode_whatsapp',{description:'Configura o webhook do CRM nesta instância e inicia conexão ao WhatsApp. Retorna QR Code como imagem MCP para o dono escanear. Pode substituir configuração anterior de webhook; use uma instância destinada a este CRM. Se já conectada, preserva conexão. QR é temporário; não salve em conhecimento/prompts. Não envia mensagens.',inputSchema:{instance_id:uuid},annotations:{readOnlyHint:false}},async args=>run({action:'connect',...args}));
 server.registerTool('consultar_conexao_whatsapp',{description:'Consulta a Uazapi, atualiza o estado local e verifica webhook; retorna QR atual enquanto aguarda leitura. Conectado não significa atendimento testado. Aguarde alguns segundos entre consultas.',inputSchema:{instance_id:uuid},annotations:{readOnlyHint:false,idempotentHint:true}},async args=>run({action:'status',...args}));
 server.registerTool('vincular_whatsapp_agente',{description:'Vincula agente da empresa à instância. active=false prepara/pausa canal; active=true habilita atendimento automático às próximas mensagens e roteador WhatsApp V2. Requer conexão, webhook válido e agente previamente ativado/validado. Recusa conflito com outro agente. Não ativa o agente nem envia mensagem de teste. Depois valide recebimento/resposta real com o usuário.',inputSchema:{instance_id:uuid,agent_id:uuid,active:z.boolean().default(false)},annotations:{readOnlyHint:false,idempotentHint:true}},async args=>run({action:'bind',...args}));
}

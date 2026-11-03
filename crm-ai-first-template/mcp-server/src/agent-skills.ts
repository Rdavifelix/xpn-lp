import {z} from 'zod';
import type {McpServer} from '@modelcontextprotocol/sdk/server/mcp.js';
import type {TenantContext,rpcClient} from './auth.js';
const uuid=z.string().uuid();
export const skillSelection=z.array(z.string().min(1).max(120)).min(1).max(30).refine(v=>new Set(v).size===v.length,'Habilidades repetidas');
export const configuredAgentSchema=z.object({template_id:uuid.optional(),provider:z.string().min(1).max(80).optional(),model:z.string().min(1).max(200).optional(),name:z.string().trim().min(2).max(120),system_prompt:z.string().trim().min(20).max(20000),tools:skillSelection}).strict();
const text=(v:unknown)=>({content:[{type:'text' as const,text:JSON.stringify(v)}]});
export function registerAgentSkills(server:McpServer,ctx:TenantContext,rpc:ReturnType<typeof rpcClient>){
 const run=async(args:Record<string,unknown>)=>{try{return text(await rpc('mcp_agent_setup',args));}catch(e){return {...text({error:e instanceof Error?e.message:'Configuração recusada'}),isError:true};}};
 server.registerTool('listar_habilidades_agentes',{
  description:'Descobre catálogo de habilidades e sugestões dos templates. Retorna schemas, provedor, contexto exigido e installable. Consulte antes de criar qualquer agente. Se uma habilidade necessária estiver ausente/não instalável, informe a lacuna; não invente ferramentas.',
  annotations:{readOnlyHint:true,openWorldHint:false},
 },async()=>run({p_action:'catalog'}));
 server.registerTool('consultar_agente_configurado',{
  description:'Consulta ferramentas vinculadas e pendências de um agente da empresa. Instalação não prova execução. Não retorna chaves ou configuração interna de execução.',
  inputSchema:{agent_id:uuid},annotations:{readOnlyHint:true,openWorldHint:false},
 },async({agent_id})=>run({p_action:'get',p_agent_id:agent_id}));
 if(!ctx.can_write)return;
 server.registerTool('configurar_habilidade_operacional',{
  description:'Habilita ou desabilita mark_deal_lost ou notify_human no agente da empresa. Use após autorização do administrador para executar essas ações reais. A perda exige motivo e oportunidade da sessão; o encaminhamento cria tarefa interna. Não cancela reuniões nem envia mensagens. Outras habilidades com aprovação permanecem protegidas. Teste após configurar.',
  inputSchema:{request_id:uuid,agent_id:uuid,skill:z.enum(['mark_deal_lost','notify_human']),enabled:z.boolean()},
  annotations:{readOnlyHint:false,destructiveHint:false,idempotentHint:true,openWorldHint:false},
 },async({request_id,agent_id,skill,enabled})=>{try{return text(await rpc('mcp_configure_operational_skill',{p_request_id:request_id,p_agent_id:agent_id,p_skill:skill,p_enabled:enabled}));}catch(e){return {...text({error:e instanceof Error?e.message:'Configuração recusada'}),isError:true};}});

 for(const name of ['criar_agente','criar_agente_rascunho'])server.registerTool(name,{
  description:'Cria atomicamente agente INATIVO com instruções E habilidades executáveis selecionadas do catálogo, incluindo perda/cancelamento/tarefas. Pode partir de template_id ou, do zero, de provider/model consultados em listar_agentes. As habilidades selecionadas com modo always já nascem habilitadas em qualquer empresa; não precisa de ajuste no banco. Consulte listar_habilidades_agentes, proponha o conjunto adequado à função e obtenha aprovação antes. tools é obrigatório. Não copia credenciais nem ativa canais. Confira pending/validation_status; nunca anuncie agente funcional sem teste.',
  inputSchema:{request_id:uuid,...configuredAgentSchema.shape},
  annotations:{readOnlyHint:false,destructiveHint:false,idempotentHint:true,openWorldHint:false},
 },async({request_id,...config})=>run({p_action:'create',p_request_id:request_id,p_config:config}));
 server.registerTool('vincular_habilidades_agente',{
  description:'Adiciona habilidades do catálogo a agente próprio INATIVO após aprovação. Não remove ferramentas nem sobrescreve personalizações. Habilidades com aprovação obrigatória são instaladas desativadas, aguardando validação do fluxo de aprovação. Mesma tentativa deve reutilizar request_id.',
  inputSchema:{request_id:uuid,agent_id:uuid,tools:skillSelection},
  annotations:{readOnlyHint:false,destructiveHint:false,idempotentHint:true,openWorldHint:false},
 },async({request_id,agent_id,tools})=>run({p_action:'attach',p_request_id:request_id,p_agent_id:agent_id,p_config:{tools}}));
}

import {configuredAgentSchema} from './agent-skills.js';
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import type { rpcClient, TenantContext } from './auth.js';
import { pipelineSchema } from './tools.js';

const uuid = z.string().uuid();
const agentConfig = configuredAgentSchema;
export const planSchema = z.object({
  title:z.string().trim().min(2).max(120),
  process:z.string().min(10).max(20000),
  items:z.array(z.object({
    id:uuid,title:z.string().min(2).max(120),
    kind:z.enum(['pipeline','agent_draft','campaign','automation','integration','knowledge','task']),
    config:z.record(z.unknown()),depends_on:z.array(uuid).max(50),
  }).strict()).min(1).max(50),
}).strict().superRefine((plan,ctx)=>{
  const seen=new Set<string>();
  for (const [index,item] of plan.items.entries()) {
    if(seen.has(item.id)||item.depends_on.some(id=>!seen.has(id))) ctx.addIssue({code:'custom',path:['items',index],message:'IDs únicos; dependências devem aparecer antes do item.'});
    seen.add(item.id);
    const schema=item.kind==='pipeline'?pipelineSchema:item.kind==='agent_draft'?agentConfig:null;
    if(schema&&!schema.safeParse(item.config).success) ctx.addIssue({code:'custom',path:['items',index,'config'],message:'Configuração inválida para este tipo de item.'});
  }
  if(Buffer.byteLength(JSON.stringify(plan))>60000) ctx.addIssue({code:'custom',message:'Plano excede 60 KB.'});
});
const text=(value:unknown)=>({content:[{type:'text' as const,text:JSON.stringify(value)}]});

export function registerPlans(server:McpServer,context:TenantContext,rpc:ReturnType<typeof rpcClient>) {
 const run=async(args:Record<string,unknown>)=>{
  try{return text(await rpc('mcp_implementation',args));}
  catch(e){return {...text({error:e instanceof Error?e.message:'Não foi possível acessar a implantação.'}),isError:true};}
 };
 server.registerTool('diagnosticar_operacao',{
  description:'Consulte antes de desenhar a operação. Resume empresa, recursos atuais, planos salvos e capacidades executáveis. Pendências de integrações não são verificadas nesta versão.',
  annotations:{readOnlyHint:true,openWorldHint:false},
 },async()=>{
  try{const [plans,pipelines,agents]=await Promise.all([rpc('mcp_implementation',{p_action:'list'}),rpc('mcp_list_pipelines'),rpc('mcp_list_agents')]);
   return text({empresa:context,plans,pipelines,agents,executors:['pipeline','agent_draft'],planning_only:['campaign','automation','integration','knowledge','task'],available_tools_outside_plan:['listar_instancias_whatsapp','criar_instancia_whatsapp','gerar_qrcode_whatsapp','consultar_conexao_whatsapp','vincular_whatsapp_agente','criar_agente','salvar_conhecimento_agente','configurar_agente','configurar_habilidade_agente','ativar_automacao_comercial','consultar_execucoes_automacao','criar_usuario_equipe','atualizar_membro_equipe','configurar_expediente','bloquear_agenda','consultar_horarios_livres','salvar_formulario','publicar_formulario','atualizar_agente'],integration_health:'not_checked'});
  }catch(e){return {...text({error:e instanceof Error?e.message:'Diagnóstico indisponível'}),isError:true};}
 });
 server.registerTool('consultar_implantacao',{
  description:'Sem plan_id lista até 50 planos recentes da empresa; com plan_id retorna processo, versão, aprovação e resultados para continuar uma sessão anterior.',
  inputSchema:{plan_id:uuid.optional()},annotations:{readOnlyHint:true,openWorldHint:false},
 },async({plan_id})=>run({p_action:plan_id?'get':'list',p_plan_id:plan_id}));
 server.registerTool('prever_implantacao',{
  description:'Valida e apresenta o plano SEM salvar. Pipelines e agent_draft têm executor; os demais tipos ficam pendentes. Apresente a proposta completa ao usuário. Nunca inclua senhas ou tokens no plano.',
  inputSchema:{document:planSchema},annotations:{readOnlyHint:true,openWorldHint:false},
 },async({document})=>text({empresa:context.tenant_name,document,items:document.items.map(i=>({id:i.id,execution:['pipeline','agent_draft'].includes(i.kind)?'available':'pending_capability'})),saved:false}));
 if(!context.can_write)return;
 const mutation={readOnlyHint:false,destructiveHint:false,idempotentHint:true,openWorldHint:false};
 server.registerTool('salvar_implantacao',{
  description:'Salva o processo e proposta, sem executar. Use plan_id UUID estável; expected_version=0 para criar, ou versão consultada para revisar. Revisão invalida aprovação; preserve itens já aplicados. Reutilize request_id somente para a MESMA tentativa. Nunca grave segredos.',
  inputSchema:{plan_id:uuid,request_id:uuid,expected_version:z.number().int().min(0),document:planSchema},annotations:mutation,
 },async({plan_id,request_id,expected_version,document})=>run({p_action:'save',p_plan_id:plan_id,p_request_id:request_id,p_version:expected_version,p_document:document}));
 server.registerTool('aprovar_implantacao',{
  description:'Registra a confirmação EXPLÍCITA do usuário para a versão apresentada. Não chame sem essa confirmação nem invente a fala. Registrar aprovação não aplica nada; não autoriza disparos ou ativações externos.',
  inputSchema:{plan_id:uuid,request_id:uuid,expected_version:z.number().int().min(1),confirmation:z.string().trim().min(10).max(2000)},annotations:mutation,
 },async({plan_id,request_id,expected_version,confirmation})=>run({p_action:'approve',p_plan_id:plan_id,p_request_id:request_id,p_version:expected_version,p_approval:confirmation}));
 server.registerTool('aplicar_item_implantacao',{
  description:'Aplica UM item da versão aprovada, depois de suas dependências. Pipelines são criados; agentes ficam inativos. Outros tipos retornam pending_capability, nunca sucesso fictício. Resultado failed/pending não é conclusão. Consulte depois de timeout; retry da mesma chamada usa mesmo request_id. Para tentar novamente após falha confirmada use novo request_id.',
  inputSchema:{plan_id:uuid,request_id:uuid,expected_version:z.number().int().min(1),item_id:uuid},annotations:mutation,
 },async({plan_id,request_id,expected_version,item_id})=>run({p_action:'apply',p_plan_id:plan_id,p_request_id:request_id,p_version:expected_version,p_item_id:item_id}));
}

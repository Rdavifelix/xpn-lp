import {registerZernio} from './zernio.js';
import {registerPages} from './pages.js';
import {registerInbound} from './inbound.js';
import {registerWhatsApp} from './whatsapp.js';
import {registerAgentAdmin} from './agent-admin.js';
import {registerOperation} from './operation.js';
import {registerTeam} from './team.js';
import {registerForms} from './forms.js';
import {registerHistory} from './history.js';
import {registerCRM} from './crm.js';
import {registerAgentSkills} from './agent-skills.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { registerPlans } from './plans.js';
import { z } from 'zod';
import type { rpcClient, TenantContext } from './auth.js';

const stage = z.object({
  name: z.string().trim().min(1).max(80),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).default('#3b82f6'),
  is_won: z.boolean().default(false), is_lost: z.boolean().default(false),
}).strict().refine(s => !(s.is_won && s.is_lost), 'Uma etapa não pode ser ganho e perda ao mesmo tempo.');
export const pipelineSchema = z.object({
  name: z.string().trim().min(2).max(120),
  stages: z.array(stage).min(2).max(30),
}).strict().refine(p => new Set(p.stages.map(s => s.name.toLocaleLowerCase())).size === p.stages.length, 'Nomes de etapas repetidos.');
const textResult = (value: unknown) => ({ content: [{ type: 'text' as const, text: JSON.stringify(value) }] });

export function createServer(context: TenantContext, rpc: ReturnType<typeof rpcClient>) {
  const server = new McpServer({ name: 'crm-ai-first', version: '0.14.0' }, {
    instructions: 'Páginas externas: criar_canal_entrada gera URL de POST em captura; consultar_opcoes_canal lista destinos/campos, criar_campo_personalizado cria definições tipadas, salvar_mapeamento_canal configura source→target e distribuição fixa/rodízio. validar_payload_canal não grava; ativar_canal_entrada permite entradas reais; consultar_envios_canal confirma contato/deal/responsável. WhatsApp Uazapi: listar_instancias_whatsapp → criar_instancia_whatsapp → gerar_qrcode_whatsapp (imagem para o usuário escanear) → consultar_conexao_whatsapp → vincular_whatsapp_agente. Nunca peça chaves no chat. Ativar canal permite responder mensagens reais; valide o agente primeiro. Monte agentes para QUALQUER tenant pelo mesmo fluxo, sem ajustes manuais no banco: criar_agente aceita template ou provider/model para partir do zero. Habilidades always selecionadas são instaladas habilitadas, inclusive mark_deal_lost e cancel_meeting. Consulte playground_supported. Use salvar_conhecimento_agente, configurar_agente e configurar_habilidade_agente para completar e ajustar. Faça teste normal e de exceção; confira cada tool.end, não apenas resposta do modelo. Cancelamento refere-se à reunião interna; sincronização externa depende da integração. Para validar agentes use testar_conversa_agente e consultar_operacao_agente; o teste pode executar ações reais no contato/deal selecionados. Alternância de closers usa configurar_alternancia_closers e é aplicada na gravação da reunião. Credenciais existentes podem ser vinculadas pelo ID; nunca solicite segredos na conversa. Relatos por áudio chegam como texto da conversa: organize o processo e execute as ferramentas autorizadas. Para equipe consulte listar_membros e consultar_agenda_membro; crie funcionários com criar_usuario_equipe, configure SDR/closer, expediente e bloqueios. Peça nomes/emails ausentes, nunca invente pessoas. Configure horários antes de testar disponibilidade. Os links pessoais não pertencem aos planos/prompts; não envie mensagens sem autorização. Integrações externas e primeiro acesso dos funcionários exigem ação humana. Use diagnosticar_operacao primeiro e consulte planos existentes para retomar o trabalho. Desenhe o processo com o usuário; use prever_implantacao e salvar_implantacao para persistir. Só registre aprovar_implantacao após confirmação explícita sobre a versão; aplique os itens em ordem e consulte os resultados. Não anuncie operação pronta se houver itens failed ou pending_capability. Nunca inclua credenciais no plano. Mapeie o processo, responsáveis e exceções antes de propor configuração. Apresente uma prévia e peça confirmação do usuário antes de criar funis ou rascunhos de agentes. Reutilize request_id ao repetir a MESMA criação. O ambiente vem da autenticação. Antes de criar qualquer agente (SDR, atendimento ou outra função), consulte listar_habilidades_agentes. Escolha e explique as habilidades pelo processo; inclua tools na configuração do agente e no item agent_draft do plano. Criar só instruções não conclui o agente. Vincule as habilidades aprovadas; informe lacunas do catálogo. Agentes ficam inativos; credenciais, contexto real, teste e ativação continuam pendentes.',
  });
  server.registerTool('consultar_empresa', {
    description: 'Identifica a empresa e as permissões da conexão atual.',
    annotations: { readOnlyHint: true, openWorldHint: false },
  }, async () => textResult(context));
  server.registerTool('listar_pipelines', {
    description: 'Lista funis e etapas da empresa autenticada. Use antes de propor um novo funil.',
    annotations: { readOnlyHint: true, openWorldHint: false },
  }, async () => {
    try { return textResult(await rpc('mcp_list_pipelines')); }
    catch { return { ...textResult({ error: 'Não foi possível consultar os funis.' }), isError: true }; }
  });
  server.registerTool('prever_pipeline', {
    description: 'Valida a proposta de funil e mostra o que será criado, sem gravar. Apresente o resultado ao usuário antes de criar_pipeline.',
    inputSchema: { pipeline: pipelineSchema },
    annotations: { readOnlyHint: true, openWorldHint: false },
  }, async ({pipeline}) => textResult({ empresa:context.tenant_name, proposta:pipeline, gravado:false }));
  server.registerTool('listar_agentes', {
    description: 'Lista os agentes da empresa e os modelos globais disponíveis para criar rascunhos. Não retorna credenciais.',
    annotations: { readOnlyHint: true, openWorldHint: false },
  }, async () => {
    try { return textResult(await rpc('mcp_list_agents')); }
    catch { return { ...textResult({error:'Não foi possível consultar os agentes.'}), isError:true }; }
  });
  server.registerPrompt('mapear_processo', {
    description: 'Roteiro da imersão para transformar o processo comercial em configuração validada.',
  }, async () => ({ messages:[{role:'user',content:{type:'text',text:'Ajude-me a mapear meu processo comercial. Consulte a empresa e os funis atuais. Peça meu relato, organize origem dos leads, qualificação, etapas, responsáveis, critérios de avanço, ganhos/perdas e exceções. Faça perguntas sobre lacunas sem inventar regras. Apresente o mapa e valide um cenário normal e um de exceção. Só então use prever_pipeline e, com minha aprovação, crie a estrutura. Para agentes, consulte os modelos e proponha funções, limites e instruções antes de criar rascunhos inativos.'}}] }));
  if (context.can_write) server.registerTool('criar_pipeline', {
    description: 'Cria um novo funil com etapas após o usuário aprovar a proposta. Não altera funis existentes. request_id é um UUID de idempotência: reutilize apenas para repetir a mesma operação.',
    inputSchema: { request_id: z.string().uuid(), pipeline: pipelineSchema },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  }, async ({ request_id, pipeline }) => {
    try { return textResult(await rpc('mcp_create_pipeline', { p_request_id: request_id, p_pipeline: pipeline })); }
    catch { return { ...textResult({ error: 'Criação recusada ou resposta não confirmada. Confira os funis; para tentar novamente, mantenha o mesmo request_id e conteúdo.' }), isError: true }; }
  });
  registerZernio(server,context,rpc);
  registerInbound(server,context,rpc);
  registerPages(server,context,rpc);
  registerWhatsApp(server,context,rpc);
  registerAgentAdmin(server,context,rpc);
  registerOperation(server,context,rpc);
  registerTeam(server,context,rpc);
  registerForms(server,context,rpc);
  registerHistory(server,context,rpc);
  registerCRM(server,context,rpc);
  registerPlans(server,context,rpc);
  registerAgentSkills(server,context,rpc);
  return server;
}

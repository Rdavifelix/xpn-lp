/**
 * Provider dispatcher.
 * Roteia chamada do LLM pro provider correto.
 *
 * Lookup de credencial: se agent.credential_id existe, busca em agents_provider_credentials.
 * Senão, fallback pra env vars (legacy).
 */

import type {
  AgentMessage,
  AgentRegistry,
  AgentTool,
  Attachment,
  ProviderCallResult,
  ProviderCredential,
} from "../../_shared/types.ts";
import { db } from "../../_shared/supabase.ts";
import { callAnthropic } from "./anthropic.ts";
import { callOpenAI } from "./openai.ts";
import { callOpenAICodex } from "./openai-codex.ts";

export interface CallProviderParams {
  agent: AgentRegistry;
  systemPrompt: string;
  tools: AgentTool[];
  history: AgentMessage[];
  newUserMessage: string;
  /** Anexos da mensagem atual (imagens). Providers que suportam vision passam multimodal. */
  newUserAttachments?: Attachment[];
  onTextDelta: (delta: string) => void;
  credential?: ProviderCredential | null;
  /** Ferramentas nativas do provider ligadas no agente (web_search, code_interpreter, image_generation) */
  nativeTools?: string[];
  /** Multi-tenant (Onda B3-C): tenant resolvido do agente/sessão. Guarda a credencial contra uso cross-tenant. */
  tenant_id?: string | null;
  session_id?: string;
}

export async function callProvider(
  params: CallProviderParams,
): Promise<ProviderCallResult> {
  const {data: access,error} = await db.rpc('saas_ai_resolve',{p_agent_id:params.agent.id});
  if(error || !access) throw new Error(error?.message || 'Não foi possível resolver a credencial de IA.');
  const credential=access.credential as ProviderCredential;
  const effective = {...params,credential,agent:{...params.agent,model:access.model || params.agent.model,
    settings:{...params.agent.settings,...(access.source==='sponsored'?{max_tokens:access.max_output_tokens}:{})}}};
  let traceId:string|null=null;
  if(params.session_id){
    const {data,error:traceError}=await db.rpc('agent_trace_record',{p_agent_id:params.agent.id,p_session_id:params.session_id,p_request:{agent_version:params.agent.version,provider:credential.provider_type,model:effective.agent.model,system_prompt:params.systemPrompt,history:params.history.map(m=>({role:m.role,content:m.content,tool_calls:m.tool_calls,tool_call_id:m.tool_call_id})),message:params.newUserMessage,tools:params.tools.map(t=>({name:t.name,description:t.description,parameters_schema:t.parameters_schema})),native_tools:params.nativeTools??[]}});
    if(traceError)console.error('[agent-trace] Falha ao registrar execução'); else traceId=data;
  }
  try {
    const result=await dispatch(effective,credential.provider_type);
    if(traceId)await db.rpc('agent_trace_record',{p_agent_id:params.agent.id,p_session_id:params.session_id,p_trace_id:traceId,p_result:{status:'success',text:result.text,tool_calls:result.tool_calls,usage:result.usage}});
    if(access.call_id){
      const {error: usageError}=await db.rpc('saas_ai_finish',{p_call_id:access.call_id,p_success:true,p_input_tokens:result.usage.input_tokens,p_output_tokens:result.usage.output_tokens});
      if(usageError) console.error('[saas-ai] Não foi possível registrar tokens; chamada permanece contabilizada.');
    }
    return result;
  } catch(e) {
    if(traceId)await db.rpc('agent_trace_record',{p_agent_id:params.agent.id,p_session_id:params.session_id,p_trace_id:traceId,p_result:{status:'error',message:'Provedor não concluiu a chamada'}});
    if(access.call_id){
      await db.rpc('saas_ai_finish',{p_call_id:access.call_id,p_success:false});
      const message = e instanceof Error ? e.message : '';
      if (/model.*not supported|model_not_found/i.test(message)) throw new Error('O modelo da IA global não está disponível para esta credencial. Atualize o modelo em Superadmin → IA.');
      throw new Error('O provedor da IA patrocinada não concluiu a chamada. Verifique a chave e o modelo no superadmin.');
    }
    throw e;
  }
}
export async function dispatch(effective:CallProviderParams,providerType:string):Promise<ProviderCallResult>{
  switch (providerType) {
    case "anthropic":
    case "anthropic_api":
      return await callAnthropic(effective);
    case "openai":
    case "openai_api":
      return await callOpenAI(effective);
    case "openai_codex":
      return await callOpenAICodex(effective);
    case "hermes":
      throw new Error("Provider 'hermes' não implementado ainda (Fase 2)");
    case "gemini":
    case "google_gemini":
      throw new Error("Provider 'gemini' não implementado ainda (Fase 2)");
    case "groq":
    case "together":
    case "fireworks":
    case "deepseek":
      // Esses são compatíveis com OpenAI Chat Completions — reuso o adapter
      return await callOpenAI(effective);
    case "custom":
      throw new Error("Provider 'custom' não implementado ainda (Fase 2)");
    default:
      throw new Error(`Provider desconhecido: ${providerType}`);
  }
}

import {isAdsRead} from '../../../_shared/ads-read.ts';
import {execAdsRead} from './ads.ts';
/**
 * Tool executor — dispatcher por action_type.
 * + Idempotency check (toda tool que muda estado).
 * + Audit log em agents_action_log.
 */

import { db } from "../../_shared/supabase.ts";
import type { AgentTool, ToolCall } from "../../_shared/types.ts";
import { checkIdempotency, generateIdempotencyKey } from "../idempotency.ts";
import { execSqlTool } from "./sql.ts";
import { execHttpTool } from "./http.ts";
import { execAsyncHttpTool } from "./http-async.ts";
import { execWebhookTool } from "./webhook.ts";
import { execEdgeFunctionTool } from "./edge-function.ts";
import { getCachedToolResult, setCachedToolResult, isReadOnlyTool } from "../tool-cache.ts";

export interface ExecuteToolParams {
  sqlClient?: typeof db;
  tool: AgentTool;
  call: ToolCall;
  agent_id: string;
  session_id: string;
  user_id: string | null;
  /**
   * Contexto runtime injetado pelo agent-runner — NUNCA visível ao LLM.
   * Tools usam via params_map ({{lead_id}}, {{deal_id}}, etc) pra montar a
   * chamada SQL/HTTP/etc sem o LLM precisar passar UUIDs nos args.
   *
   * Best practice: LLM passa dados de negócio, sistema injeta IDs.
   */
  runtime_context?: Record<string, unknown>;
}

export interface ExecuteToolResult {
  output: unknown;
  cached: boolean; // veio de idempotency cache
  duration_ms: number;
  status: "success" | "failed";
  error?: string;
}

const STATE_CHANGING = new Set(["http", "webhook", "edge_function"]); // SQL pode ser SELECT (read-only)

export async function executeTool(params: ExecuteToolParams): Promise<ExecuteToolResult> {
  const t0 = Date.now();
  const { tool, call, agent_id, session_id, user_id, runtime_context } = params;

  // Contexto runtime sempre disponível pras tools (mesmo se runtime_context vazio).
  // Inclui: agent_id, session_id, user_id, channel (sempre) + lead_id/deal_id/etc (quando webhook injeta)
  const ctx: Record<string, unknown> = {
    agent_id,
    session_id,
    user_id,
    ...(runtime_context || {}),
  };

  if(tool.requires_approval || (tool as unknown as {usage_mode?:string}).usage_mode==='with_approval' || (tool as unknown as {usage_mode?:string}).usage_mode==='disabled'){
    return {output:{error:'Esta habilidade exige aprovação ou está desabilitada.'},cached:false,duration_ms:0,status:'failed',error:'Esta habilidade exige aprovação ou está desabilitada.'};
  }
  if(params.sqlClient && tool.action_type!=='sql' && !isAdsRead(tool)){
    return {output:{error:'O playground executa ações internas. Valide envios externos no canal conectado.'},cached:false,duration_ms:0,status:'failed',error:'O playground executa ações internas. Valide envios externos no canal conectado.'};
  }
  // ━━━ READ-ONLY CACHE (5min TTL por sessão) ━━━
  // Pattern TVCACHE — evita re-execução de SELECT/GET idênticos.
  // Economia massiva: vi 3× a mesma query no caso Netto = R$ 4 desperdiçados.
  if (!params.sqlClient && isReadOnlyTool(tool)) {
    const cached = getCachedToolResult(session_id, tool.name, call.arguments);
    if (cached !== null) {
      return {
        output: cached,
        cached: true,
        duration_ms: Date.now() - t0,
        status: "success",
      };
    }
  }

  // Idempotency: se a tool muda estado, gera key e checa
  let idempotencyKey: string | undefined;
  if (STATE_CHANGING.has(tool.action_type) && !isAdsRead(tool)) {
    idempotencyKey = generateIdempotencyKey({
      session_id,
      tool_name: tool.name,
      arguments: call.arguments,
    });

    const cached = await checkIdempotency(idempotencyKey);
    if (cached.exists && cached.status === "success") {
      return {
        output: cached.output,
        cached: true,
        duration_ms: Date.now() - t0,
        status: "success",
      };
    }
  }

  let output: unknown;
  let status: "success" | "failed" = "success";
  let error: string | undefined;

  try {
    // ━━━ ASYNC TOOL (durable execution) ━━━
    // Se action_config tem bloco `async`, dispara + cria job + retorna "processing".
    // Cron poller checa status depois e re-dispara o agente quando pronto.
    const asyncCfg = (tool.action_config as Record<string, unknown>)?.async as Record<string, unknown> | undefined;
    if (asyncCfg && tool.action_type === "http") {
      output = await execAsyncHttpTool({
        action_config: tool.action_config,
        arguments: call.arguments,
        user_id,
        provider: (tool as any).provider || null,
        agent_id,
        session_id,
        runtime_context: ctx,
        tool_name: tool.name,
      });
      // async sempre "success" — o resultado real vem no resume
      const duration_ms = Date.now() - t0;
      db.from("agents_action_log").insert({
        tenant_id:ctx.tenant_id, agent_id, session_id, user_id,
        tool_name: tool.name, input: call.arguments, output, status: "success",
        idempotency_key: null, duration_ms,
      }).then(({ error: dbErr }) => { if (dbErr) console.error("[executor] audit err", dbErr); });
      return { output, cached: false, duration_ms, status: "success" };
    }

    switch (tool.action_type) {
      case "sql":
        output = await execSqlTool({
          action_config: tool.action_config,
          arguments: call.arguments,
          runtime_context: ctx,
          sqlClient:params.sqlClient,
        });
        break;
      case "http":
        output = await execHttpTool({
          action_config: tool.action_config,
          arguments: call.arguments,
          user_id,
          tenant_id: (ctx.tenant_id as string | null) || null,
          provider: (tool as any).provider || null,
        });
        // ─── HÍBRIDO: sync poll estourou → cria job durável que continua acompanhando ───
        if (output && typeof output === "object" && (output as Record<string, unknown>).__job_handoff) {
          const h = output as Record<string, unknown>;
          const resumeContext = {
            lead_id: ctx.lead_id ?? null,
            deal_id: ctx.deal_id ?? null,
            instance_id: ctx.instance_id ?? null,
            recipient: ctx.recipient ?? ctx.telegram_chat_id ?? ctx.whatsapp_phone ?? null,
            user_id,
          };
          const { data: jobRes, error: jobErr } = await db.rpc("agent_create_job", {
            p_agent_id: agent_id,
            p_session_id: session_id,
            p_channel: (ctx.channel as string) || "chat_web",
            p_tool_name: tool.name,
            p_external_id: String(h.external_id || ""),
            p_poll_config: h.poll_config || {},
            p_provider: (tool as any).provider || null,
            p_resume_context: resumeContext,
          });
          output = jobErr
            ? { ok: false, error: `Falha criando job de acompanhamento: ${jobErr.message}` }
            : {
                ok: true,
                async: true,
                processing: true,
                job_id: (jobRes as { job_id?: string })?.job_id,
                message: h.message,
                instruction_to_agent:
                  "Avise o usuário que está gerando e que você avisa quando ficar pronto. " +
                  "NÃO mostre nenhum carrossel agora. NÃO chame mais tools.",
              };
        }
        break;
      case "webhook":
        output = await execWebhookTool({
          action_config: tool.action_config,
          arguments: call.arguments,
          user_id,
          tenant_id: (ctx.tenant_id as string | null) || null,
        });
        break;
      case "edge_function":
        output = isAdsRead(tool) ? await execAdsRead(agent_id,session_id,user_id,tool.name,call.arguments) : await execEdgeFunctionTool({
          action_config: tool.action_config,
          arguments: call.arguments,
          user_id,
          session_id,
        });
        break;
      default:
        throw new Error(`Unknown action_type: ${tool.action_type}`);
    }
    if(output && typeof output==='object' && ('error' in output || ('ok' in output && (output as {ok:unknown}).ok===false))){
      throw new Error(String((output as {error?:unknown}).error || 'A ferramenta recusou a operação.'));
    }
    if(output&&typeof output==='object'&&((output as Record<string,unknown>).ok===false||typeof (output as Record<string,unknown>).error==='string'))throw new Error(String((output as Record<string,unknown>).error??'A ferramenta não concluiu a operação'));
  } catch (e) {
    status = "failed";
    error = e instanceof Error ? e.message : String(e);
    output = { error };
  }

  const duration_ms = Date.now() - t0;

  // Salva no read-only cache (se aplicável e success)
  if (status === "success" && isReadOnlyTool(tool)) {
    setCachedToolResult(session_id, tool.name, call.arguments, output);
  }

  // Audit log (fire-and-forget)
  db.from("agents_action_log")
    .insert({
      tenant_id:ctx.tenant_id,
      agent_id,
      session_id,
      user_id,
      tool_name: tool.name,
      input: call.arguments,
      output: output,
      status,
      error: error || null,
      idempotency_key: idempotencyKey || null,
      duration_ms,
    })
    .then(({ error: dbErr }) => {
      if (dbErr) console.error("[executor] audit log err", dbErr);
    });

  return { output, cached: false, duration_ms, status, error };
}

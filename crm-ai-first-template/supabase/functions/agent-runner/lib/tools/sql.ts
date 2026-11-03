/**
 * Tool type: SQL — executa Postgres RPC function.
 *
 * action_config exemplo:
 *   {
 *     "function": "agent_qualify_lead",
 *     "params_map": {
 *       "p_lead_id":    "{{lead_id}}",      // ← injetado pelo runtime context
 *       "p_agent_id":   "{{agent_id}}",     // ← idem
 *       "p_revenue_min": "{{revenue_min}}"  // ← do args do LLM
 *     }
 *   }
 *
 * BEST PRACTICE — Padrão A (Anthropic SDK, LangChain, Letta):
 *   - LLM passa SÓ dados de negócio (revenue, authority, timeline, etc)
 *   - Sistema injeta automaticamente IDs/auth via runtime_context
 *     (lead_id, deal_id, agent_id, session_id, user_id, channel)
 *
 * Resolução de {{var}}:
 *   1º procura em runtime_context (IDs/auth) — prioridade alta
 *   2º procura nos arguments (dados do LLM)
 *
 * Validação: se {{lead_id}}/{{deal_id}}/{{activity_id}} resolverem pra string
 * que não é UUID válido → erro amigável (anti-bug de passar nome no lugar do uuid).
 */

import { db } from "../../_shared/supabase.ts";
import { interpolate } from "./template.ts";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const UUID_PARAM_NAMES = new Set([
  "lead_id", "deal_id", "activity_id", "agent_id", "session_id", "user_id",
  "p_lead_id", "p_deal_id", "p_activity_id", "p_agent_id", "p_session_id", "p_user_id",
  "p_organization_id", "p_stage_id",
]);

export async function execSqlTool(params: {
  sqlClient?: typeof db;
  action_config: Record<string, unknown>;
  arguments: Record<string, unknown>;
  runtime_context: Record<string, unknown>;
}): Promise<unknown> {
  const sqlDb=params.sqlClient??db;
  const cfg = params.action_config;
  const originalFunction = cfg.function as string;
  const playgroundFunctions:Record<string,string>={agent_mark_deal_lost:'playground_mark_deal_lost',agent_skill_notify_human:'playground_notify_human',agent_qualify_lead:'playground_qualify_lead',agent_skill_now_br:'playground_now_br',agent_check_availability:'playground_check_availability',agent_change_stage:'playground_change_stage',agent_update_lead:'playground_update_lead',agent_schedule_meeting:'playground_schedule_meeting'};
  const functionName=params.sqlClient ? (playgroundFunctions[originalFunction]??originalFunction) : originalFunction==='agent_check_availability' ? 'agent_calendar_slots' : originalFunction;
  const rawQuery = cfg.query as string | undefined;
  const queryParams = cfg.params as string[] | undefined;

  // Combina contexto: runtime_context tem PRIORIDADE sobre args do LLM.
  // Isso impede LLM de "passar lead_id inventado" e sobrescrever o real.
  const resolutionScope: Record<string, unknown> = {
    ...params.arguments,        // baseline: dados do LLM
    ...params.runtime_context,  // sobrepõe: IDs/auth do sistema
  };

  // ───────── Caso 1: RPC function (preferido) ─────────
  if (functionName) {
    const paramsMap = (cfg.params_map as Record<string, string>) || {};
    const rpcArgs: Record<string, unknown> = {};

    for (const [paramName, template] of Object.entries(paramsMap)) {
      const value = resolveTemplate(template, resolutionScope);

      // Validação UUID (anti-bug "string inventada")
      if (UUID_PARAM_NAMES.has(paramName) && value !== null && value !== undefined) {
        const s = typeof value === "string" ? value : String(value);
        if (s && !UUID_RE.test(s)) {
          throw new Error(
            `[tools/sql] Param '${paramName}' precisa ser UUID válido — recebeu "${s.slice(0, 50)}". ` +
            `Provavelmente o contexto runtime não tem essa variável (canal de teste sem lead real?). ` +
            `Tools que dependem de lead_id/deal_id só funcionam em conversas com lead real.`,
          );
        }
      }

      rpcArgs[paramName] = value;
    }

    if(['agent_change_stage','playground_change_stage'].includes(functionName)&&typeof rpcArgs.p_stage_name==='string'&&UUID_RE.test(rpcArgs.p_stage_name)){rpcArgs.p_stage_id=rpcArgs.p_stage_name;rpcArgs.p_stage_name=null;}
    if(functionName==='agent_calendar_slots') rpcArgs.p_agent_id=params.runtime_context.agent_id;
    if(originalFunction==='agent_skill_notify_human'&&params.runtime_context.responsible_user_id)rpcArgs.p_user_id=params.runtime_context.responsible_user_id;
    if(originalFunction==='agent_create_task'&&!rpcArgs.p_responsavel_id&&params.runtime_context.responsible_user_id)rpcArgs.p_responsavel_id=params.runtime_context.responsible_user_id;
    const crmActions:Record<string,string>={agent_create_lead:'lead_create',agent_create_deal:'deal_create',agent_skill_my_hot_leads:'hot_leads',agent_skill_my_deals:'my_deals',agent_skill_my_pipeline_summary:'pipeline_summary',agent_create_task:'task_create',agent_complete_task:'task_complete',agent_confirm_meeting:'meeting_confirm',agent_reschedule_meeting:'meeting_reschedule',agent_cancel_meeting:'meeting_cancel',agent_schedule_followup:'followup',agent_team_roster:'team',agent_list_notes:'notes_list',agent_read_note:'notes_read',agent_search_notes:'notes_search',agent_save_note:'notes_save'};
    if(crmActions[originalFunction]){
      const ctx=params.runtime_context;
      const {data,error}=await sqlDb.rpc(params.sqlClient?'playground_crm_action':'agent_crm_action',{p_agent_id:ctx.agent_id,p_session_id:ctx.session_id,p_lead_id:ctx.lead_id,p_deal_id:ctx.deal_id??null,p_action:crmActions[originalFunction],p_args:rpcArgs});
      if(error)throw new Error(`[tools/sql] ${originalFunction}: ${error.message}`);
      return data;
    }
    const { data, error } = await sqlDb.rpc(functionName, rpcArgs);
    if (error) throw new Error(`[tools/sql] RPC ${functionName} falhou: ${error.message}`);
    return data;
  }

  // ───────── Caso 2: query SQL bruta ─────────
  if (rawQuery && queryParams) {
    const positional = queryParams.map((name) => resolveTemplate(`{{${name}}}`, resolutionScope));
    // Usa execute_sql ou similar pra rodar query positional (mantém compat com tools antigas)
    const { data, error } = await sqlDb.rpc("execute_sql_with_params", {
      p_sql: rawQuery,
      p_params: positional,
    });
    if (error) {
      // Fallback: tenta interpolar diretamente (menos seguro mas compat)
      const finalSql = rawQuery.replace(/\$(\d+)/g, (_, idx) => {
        const v = positional[parseInt(idx, 10) - 1];
        if (v === null || v === undefined) return "NULL";
        if (typeof v === "number") return String(v);
        if (typeof v === "boolean") return v ? "true" : "false";
        return `'${String(v).replace(/'/g, "''")}'`;
      });
      throw new Error(`[tools/sql] query bruta requer execute_sql_with_params: ${error.message} (sql: ${finalSql.slice(0, 100)})`);
    }
    return data;
  }

  throw new Error("[tools/sql] action_config precisa de 'function' OU 'query+params'");
}

/**
 * Resolve {{var}} no template. Retorna RAW se template for puro `{{x}}`
 * (preserva tipo: number/boolean/object/null). Interpola string se misto.
 */
function resolveTemplate(template: string, scope: Record<string, unknown>): unknown {
  const pureMatch = template.trim().match(/^\{\{\s*([^}]+)\s*\}\}$/);
  if (pureMatch) {
    const varName = pureMatch[1].trim();
    const raw = scope[varName];
    if (raw === undefined || raw === null || raw === "") return null;
    return raw;
  }
  return interpolate(template, scope);
}

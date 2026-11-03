import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";
import { assertEntityTenant, requireTenantFromRequest, rowTenantOrSkip, tenantErrorResponse } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AutomationRule {
  id: string;
  tenant_id?: string | null;
  name: string;
  trigger_type: string;
  trigger_conditions: Record<string, any>;
  action_type: string;
  action_config: Record<string, any>;
  is_active: boolean;
  team: string;
  priority: number;
}

interface EventContext {
  trigger_type: string;
  deal_id?: string;
  lead_id?: string;
  task_id?: string;
  task_type?: string;
  has_scheduled_date?: boolean;
  stage_id?: string;
  previous_stage_id?: string;
  lead_score?: number;
  previous_lead_score?: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const event: EventContext = await req.json();

    if (!event.trigger_type) {
      return new Response(
        JSON.stringify({ error: "trigger_type é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Multi-tenant: caller com JWT de usuário → tenant do JWT (toda entidade do
    // evento precisa pertencer a ele); caller service_role (whatsapp-webhook,
    // cron) → tenant da entidade do evento (deal → lead → task). Regras são
    // SEMPRE filtradas pelo tenant do evento — regra sem tenant_id não se aplica
    // a ninguém.
    const principal = await authenticateRequest(req);
    const callerTenantId: string | null = principal.isServiceRole ? null : requireTenantFromRequest(req);

    // Modo especial: days_in_stage — buscar deals parados e executar regras
    if (event.trigger_type === "days_in_stage") {
      return await processDaysInStage(supabase, callerTenantId);
    }

    let eventTenantId: string | null = callerTenantId;
    const entityRefs: Array<[string, string | undefined]> = [
      ["deals", event.deal_id],
      ["leads", event.lead_id],
      ["company_activities", event.task_id],
    ];
    for (const [table, id] of entityRefs) {
      if (!id) continue;
      if (eventTenantId) {
        await assertEntityTenant(supabase, table, id, eventTenantId);
      } else {
        const { data: row } = await supabase.from(table).select("tenant_id").eq("id", id).maybeSingle();
        eventTenantId = (row?.tenant_id as string | undefined) || null;
        if (!eventTenantId) {
          return new Response(
            JSON.stringify({ error: `Entidade do evento não encontrada (${table})` }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }
    }
    if (!eventTenantId) {
      return new Response(
        JSON.stringify({ error: "Tenant do evento não identificado (informe deal_id, lead_id ou task_id)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Buscar regras ativas para este trigger — só do tenant do evento
    const { data: rules, error: rulesError } = await supabase
      .from("sales_automation_rules")
      .select("*")
      .eq("tenant_id", eventTenantId)
      .eq("trigger_type", event.trigger_type)
      .eq("is_active", true)
      .order("priority", { ascending: true });

    if (rulesError) {
      console.error("Error fetching rules:", rulesError);
      return new Response(
        JSON.stringify({ error: "Erro ao buscar regras" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!rules || rules.length === 0) {
      return new Response(
        JSON.stringify({ success: true, matched_rules: 0, message: "Nenhuma regra ativa para este trigger" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results: Array<{ rule_id: string; rule_name: string; action: string; success: boolean; error?: string }> = [];

    for (const rule of rules as AutomationRule[]) {
      if(rule.action_config?.executor==='mcp_sql')continue; // Executado transacionalmente no banco, não repetir pela UI.
      try {
        // 2. Verificar condições
        if (!matchesConditions(rule, event)) {
          continue;
        }

        // 3. Executar ação
        const result = await executeAction(supabase, rule, event, eventTenantId);
        results.push({ rule_id: rule.id, rule_name: rule.name, action: rule.action_type, success: true, ...result });
      } catch (err: any) {
        console.error(`Error executing rule ${rule.id}:`, err);
        results.push({ rule_id: rule.id, rule_name: rule.name, action: rule.action_type, success: false, error: String(err) });
      }
    }

    return new Response(
      JSON.stringify({ success: true, matched_rules: results.length, results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    const t = tenantErrorResponse(error, corsHeaders);
    if (t) return t;
    if (error instanceof Error && (error.message === "unauthorized" || error.message === "auth_not_configured")) {
      return authErrorResponse(error);
    }
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Erro interno", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function matchesConditions(rule: AutomationRule, event: EventContext): boolean {
  const conditions = rule.trigger_conditions || {};

  // Filtro por task_types
  if (conditions.task_types && conditions.task_types.length > 0) {
    if (!event.task_type || !conditions.task_types.includes(event.task_type)) {
      return false;
    }
  }

  // Filtro por has_scheduled_date
  if (conditions.has_scheduled_date === true && !event.has_scheduled_date) {
    return false;
  }

  // Filtro por stage_ids (stage destino deve estar na lista)
  if (conditions.stage_ids && conditions.stage_ids.length > 0) {
    if (!event.stage_id || !conditions.stage_ids.includes(event.stage_id)) {
      return false;
    }
  }

  // Filtro por exclude_stages
  if (conditions.exclude_stages && conditions.exclude_stages.length > 0) {
    if (event.stage_id && conditions.exclude_stages.includes(event.stage_id)) {
      return false;
    }
  }

  return true;
}

async function executeAction(
  supabase: any,
  rule: AutomationRule,
  event: EventContext,
  tenantId: string
): Promise<Record<string, any>> {
  const config = rule.action_config || {};
  // tenant explícito nos inserts derivados (service role não tem JWT — o
  // DEFAULT get_tenant_id() cairia no tenant default pra todo mundo)
  const tenantFields = { tenant_id: tenantId };

  switch (rule.action_type) {
    case "move_deal_stage": {
      if (!config.target_stage_id) return { skipped: "target_stage_id não configurado" };

      // Buscar pipeline_id do stage destino PRIMEIRO (pra filtrar deals do mesmo pipeline)
      const { data: targetStage } = await supabase
        .from("sales_pipeline_stages")
        .select("id, pipeline_id, name")
        .eq("id", config.target_stage_id)
        .eq("tenant_id", tenantId)
        .single();

      if (!targetStage) return { skipped: "Stage destino não encontrado" };

      // Buscar deal(s) do lead ou deal direto — APENAS do mesmo pipeline do destino
      let dealIds: string[] = [];
      if (event.deal_id) {
        dealIds = [event.deal_id];
      } else if (event.lead_id) {
        const { data: deals } = await supabase
          .from("deals")
          .select("id, pipeline_id, pipeline_stage:sales_pipeline_stages(position)")
          .eq("tenant_id", tenantId)
          .eq("lead_id", event.lead_id)
          .eq("pipeline_id", targetStage.pipeline_id)
          .not("status", "in", "(won,lost)");

        dealIds = (deals || [])
          .filter((d: any) => {
            // only_if_position_less_than: só move se a posição atual for menor
            if (config.only_if_position_less_than && d.pipeline_stage?.position >= config.only_if_position_less_than) {
              return false;
            }
            return true;
          })
          .map((d: any) => d.id);
      }

      if (dealIds.length === 0) return { skipped: "Nenhum deal no pipeline destino" };

      for (const dealId of dealIds) {
        await supabase
          .from("deals")
          .update({
            pipeline_stage_id: config.target_stage_id,
            pipeline_id: targetStage.pipeline_id,
            updated_at: new Date().toISOString(),
          })
          .eq("id", dealId)
          .eq("tenant_id", tenantId);
      }

      // Atualizar lead também (pipeline_stage_id + etapa_funil + sales_stage)
      if (event.lead_id) {
        // Mapear nome do stage para etapa_funil
        const STAGE_TO_ETAPA: Record<string, string> = {
          'Novo': 'novo',
          'Em Contato': 'em_contato',
          'Qualificado': 'qualificado',
          'Call Agendada': 'call_agendada',
          'No-show': 'no_show',
          'Call Realizada': 'call_realizada',
          'Em Fechamento': 'em_fechamento',
          'Ganho': 'ganho',
          'Perdido': 'perdido',
        };
        const etapaFunil = STAGE_TO_ETAPA[targetStage.name] || targetStage.name.toLowerCase().replace(/\s+/g, '_');

        await supabase
          .from("leads")
          .update({
            pipeline_stage_id: config.target_stage_id,
            etapa_funil: etapaFunil,
            sales_stage: etapaFunil,
            updated_at: new Date().toISOString(),
          })
          .eq("id", event.lead_id)
          .eq("tenant_id", tenantId);
      }

      return { moved_deals: dealIds.length, target_stage: targetStage.name };
    }

    case "create_task": {
      if (!config.task_template) return { skipped: "task_template não configurado" };

      const template = config.task_template;
      const scheduledAt = new Date();
      if (template.days_offset) {
        scheduledAt.setDate(scheduledAt.getDate() + template.days_offset);
      }

      // Buscar lead_id do deal se necessário
      let leadId = event.lead_id;
      if (!leadId && event.deal_id) {
        const { data: deal } = await supabase
          .from("deals")
          .select("lead_id")
          .eq("id", event.deal_id)
          .single();
        leadId = deal?.lead_id;
      }

      const { error } = await supabase
        .from("company_activities")
        .insert({
          ...tenantFields,
          name: template.name,
          task_type: template.task_type || "follow_up",
          lead_id: leadId,
          team: "sales",
          status: "pending",
          completed: false,
          scheduled_at: scheduledAt.toISOString(),
        });

      if (error) throw error;
      return { task_created: template.name };
    }

    case "send_notification": {
      if (!config.type || !config.message) return { skipped: "type ou message não configurados" };

      // Buscar dados do lead para a notificação
      let leadId = event.lead_id;
      if (!leadId && event.deal_id) {
        const { data: deal } = await supabase
          .from("deals")
          .select("lead_id")
          .eq("id", event.deal_id)
          .single();
        leadId = deal?.lead_id;
      }

      if (leadId) {
        const { data: lead } = await supabase
          .from("leads")
          .select("name, phone")
          .eq("id", leadId)
          .single();

        // Criar alerta em sales_alerts
        await supabase
          .from("sales_alerts")
          .insert({
            ...tenantFields,
            lead_id: leadId,
            alert_type: config.type,
            message: config.message.replace("{{cliente}}", lead?.name || "Lead"),
            priority: 5,
          });
      }

      return { notification_sent: config.type };
    }

    case "update_lead_field": {
      if (!event.lead_id || !config.field || config.value === undefined) {
        return { skipped: "lead_id, field ou value não configurados" };
      }

      await supabase
        .from("leads")
        .update({ [config.field]: config.value, updated_at: new Date().toISOString() })
        .eq("id", event.lead_id)
        .eq("tenant_id", tenantId);

      return { updated_field: config.field };
    }

    case "send_webhook": {
      if (!config.webhook_url) return { skipped: "webhook_url não configurado" };

      await fetch(config.webhook_url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(event),
      });

      return { webhook_sent: config.webhook_url };
    }

    case "send_whatsapp_template": {
      if (!config.template_name) return { skipped: "template_name não configurado" };

      // Resolver lead
      let leadId = event.lead_id;
      if (!leadId && event.deal_id) {
        const { data: d } = await supabase
          .from("deals")
          .select("lead_id")
          .eq("id", event.deal_id)
          .single();
        leadId = d?.lead_id;
      }
      if (!leadId) return { skipped: "lead_id não encontrado" };

      // Idempotência: checa se já enviou pra este lead com esta regra
      if (config.once_per_lead) {
        const { data: existing } = await supabase
          .from("email_automation_runs")
          .select("id")
          .eq("tenant_id", tenantId)
          .eq("rule_id", rule.id)
          .eq("lead_id", leadId)
          .eq("status", "sent")
          .maybeSingle();
        if (existing) return { skipped: "already_sent_once_per_lead" };
      }

      const { data: lead } = await supabase
        .from("leads")
        .select("id, name, phone, email")
        .eq("id", leadId)
        .eq("tenant_id", tenantId)
        .single();
      if (!lead?.phone) return { skipped: "lead sem telefone" };

      // Renderiza params com dados do lead
      const firstName = (lead.name || "").trim().split(/\s+/)[0] || "tudo bem";
      const paramTemplates: string[] = config.template_params || [];
      const renderedParams = paramTemplates.map((p: string) =>
        p.replace("{{primeiro_nome}}", firstName)
          .replace("{{nome}}", lead.name || "")
          .replace("{{email}}", lead.email || "")
          .replace("{{telefone}}", lead.phone || "")
      );

      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      const waRes = await fetch(`${supabaseUrl}/functions/v1/send-whatsapp-cloud`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          action: "send_template",
          template_name: config.template_name,
          template_params: renderedParams,
          phone: lead.phone,
          lead_id: leadId,
          tenant_id: tenantId,
          sent_by: "ai_agent",
          sent_by_name: "Automação pipeline",
        }),
      });

      const waJson: any = await waRes.json().catch(() => ({}));

      // Registrar na tabela de runs pra idempotência
      await supabase.from("email_automation_runs").insert({
        ...tenantFields,
        rule_id: rule.id,
        lead_id: leadId,
        email_to: lead.phone,
        status: waRes.ok ? "sent" : "failed",
        resend_id: waJson?.data?.messages?.[0]?.id || null,
        error_message: !waRes.ok ? JSON.stringify(waJson).slice(0, 500) : null,
      });

      if (!waRes.ok) {
        throw new Error(`send-whatsapp-cloud falhou: ${JSON.stringify(waJson)}`);
      }
      return { whatsapp_sent: true, template: config.template_name };
    }

    case "send_email": {
      if (!config.template_id) return { skipped: "template_id não configurado" };

      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      const res = await fetch(`${supabaseUrl}/functions/v1/send-automation-email`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          rule_id: rule.id,
          template_id: config.template_id,
          lead_id: event.lead_id,
          deal_id: event.deal_id,
          once_per_lead: !!config.once_per_lead,
        }),
      });

      const json: any = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(`send-automation-email falhou: ${JSON.stringify(json)}`);
      }
      return { email_dispatched: true, result: json };
    }

    default:
      return { skipped: `action_type desconhecido: ${rule.action_type}` };
  }
}

/**
 * Processa regras do tipo "days_in_stage" — busca deals parados há X dias
 * Chamado via cron (1x/dia)
 */
async function processDaysInStage(supabase: any, callerTenantId: string | null): Promise<Response> {
  // Cron (service_role) varre as regras de todos os tenants; usuário logado só
  // as do próprio tenant. Regra sem tenant_id não se aplica a ninguém.
  let rulesQuery = supabase
    .from("sales_automation_rules")
    .select("*")
    .eq("trigger_type", "days_in_stage")
    .eq("is_active", true)
    .not("tenant_id", "is", null);
  if (callerTenantId) rulesQuery = rulesQuery.eq("tenant_id", callerTenantId);
  const { data: rules } = await rulesQuery.order("priority", { ascending: true });

  if (!rules || rules.length === 0) {
    return new Response(
      JSON.stringify({ success: true, matched_rules: 0, message: "Nenhuma regra days_in_stage ativa" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const results: Array<{ rule_id: string; rule_name: string; deals_affected: number }> = [];

  for (const rule of rules as AutomationRule[]) {
    const ruleTenantId = rowTenantOrSkip(rule, `process-automation-rules:days_in_stage:${rule.id}`);
    if (!ruleTenantId) continue;
    const days = rule.trigger_conditions?.days;
    if (!days) continue;

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);

    // Buscar deals abertos que estão na mesma stage desde antes da cutoff.
    // Partição por tenant: cada regra só varre os deals do próprio tenant.
    let query = supabase
      .from("deals")
      .select("id, lead_id, pipeline_stage_id, updated_at, tenant_id")
      .eq("tenant_id", ruleTenantId)
      .not("status", "in", "(won,lost)")
      .lt("updated_at", cutoffDate.toISOString());

    // Filtrar por stages específicas se configurado
    if (rule.trigger_conditions?.stage_ids?.length > 0) {
      query = query.in("pipeline_stage_id", rule.trigger_conditions.stage_ids);
    }

    // Excluir stages
    if (rule.trigger_conditions?.exclude_stages?.length > 0) {
      for (const stageId of rule.trigger_conditions.exclude_stages) {
        query = query.neq("pipeline_stage_id", stageId);
      }
    }

    const { data: staleDeals } = await query;

    if (!staleDeals || staleDeals.length === 0) {
      results.push({ rule_id: rule.id, rule_name: rule.name, deals_affected: 0 });
      continue;
    }

    let affected = 0;
    for (const deal of staleDeals) {
      try {
        const event: EventContext = {
          trigger_type: "days_in_stage",
          deal_id: deal.id,
          lead_id: deal.lead_id,
          stage_id: deal.pipeline_stage_id,
        };

        await executeAction(supabase, rule, event, ruleTenantId);
        affected++;
      } catch (err: any) {
        console.error(`Error processing deal ${deal.id} for rule ${rule.id}:`, err);
      }
    }

    results.push({ rule_id: rule.id, rule_name: rule.name, deals_affected: affected });
  }

  return new Response(
    JSON.stringify({ success: true, results }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

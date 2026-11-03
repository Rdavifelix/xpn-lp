import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey, getPipelineRoles } from "../_shared/config.ts";
import { rowTenantOrSkip } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// Instância de notificações internas e stage "Call Agendada" são lidos da
// tabela config (keys NOTIFICATIONS_INSTANCE_ID e PIPELINE_ROLES) — sem hardcode.

interface WhatsAppInstance {
  id: string;
  name: string;
  api_key: string;
  api_url: string;
}

function formatPhone(phone: string): string {
  let cleaned = phone.replace(/\D/g, "");
  if (!cleaned.startsWith("55")) {
    cleaned = "55" + cleaned;
  }
  return cleaned;
}

async function sendWhatsApp(
  instance: WhatsAppInstance,
  phone: string,
  message: string
): Promise<boolean> {
  try {
    const response = await fetch(`${instance.api_url}/send/text`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        token: instance.api_key,
      },
      body: JSON.stringify({
        number: formatPhone(phone),
        text: message,
      }),
    });

    const result = await response.json();
    if (response.ok) {
      console.log(`✅ WhatsApp enviado para ${phone}`);
      return true;
    } else {
      console.error(`❌ Erro ao enviar WhatsApp:`, result);
      return false;
    }
  } catch (error: any) {
    console.error(`❌ Exceção ao enviar WhatsApp:`, error);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    console.log("🔔 Verificando meetings/calls pendentes...");

    // Buscar meetings/calls pendentes (varredura GLOBAL — o cron atravessa
    // vários tenants; o processamento é particionado pelo tenant da linha):
    // - task_type é call ou meeting
    // - scheduled_at passou há mais de 1 hora (mas no máximo 48h atrás — não cobrar reuniões antigas)
    // - não completada/cancelada/no_show
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const maxAge = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();

    const { data: pendingTasks, error: tasksError } = await supabase
      .from("company_activities")
      .select(
        `
        id,
        name,
        task_type,
        scheduled_at,
        responsavel_id,
        lead_id,
        tenant_id,
        metadata,
        lead:leads!company_activities_lead_id_fkey(name)
      `
      )
      .in("task_type", ["call", "meeting"])
      .eq("completed", false)
      .not("status", "in", '("completed","no_show","cancelled")')
      .not("responsavel_id", "is", null)
      .not("scheduled_at", "is", null)
      .lt("scheduled_at", oneHourAgo)
      .gt("scheduled_at", maxAge)
      .order("scheduled_at", { ascending: true })
      .limit(10);

    if (tasksError) {
      console.error("❌ Erro ao buscar tasks:", tasksError);
      return new Response(
        JSON.stringify({ error: tasksError.message }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 500,
        }
      );
    }

    console.log(
      `📋 Encontradas ${pendingTasks?.length || 0} meetings/calls pendentes`
    );

    const results = {
      processed: 0,
      notified: 0,
      skipped: 0,
      errors: [] as string[],
    };

    const SIX_HOURS_MS = 6 * 60 * 60 * 1000;

    // Particionar por tenant da linha: instância de notificações + COMPANY_NAME
    // são resolvidos POR TENANT (override → global → env). Cache local por
    // tenant pra não repetir lookup dentro do mesmo ciclo.
    interface TenantNotifCtx {
      instance: WhatsAppInstance | null;
      companyName: string;
      skipReason?: string;
    }
    const tenantCtxCache = new Map<string, TenantNotifCtx>();

    async function getTenantNotifCtx(tenantId: string): Promise<TenantNotifCtx> {
      const cached = tenantCtxCache.get(tenantId);
      if (cached) return cached;

      const ctx: TenantNotifCtx = { instance: null, companyName: "" };
      try {
        // NOTIFICATIONS_INSTANCE_ID SOMENTE do override do tenant (sem fallback
        // global: tenant sem override não envia pela instância de outro tenant).
        const { data: override } = await supabase
          .from("tenant_config_overrides")
          .select("value")
          .eq("tenant_id", tenantId)
          .eq("key", "NOTIFICATIONS_INSTANCE_ID")
          .maybeSingle();
        const notificationsInstanceId = override?.value ? String(override.value).trim() : "";
        if (!notificationsInstanceId) {
          console.warn(`[check-pending-meetings][${tenantId}] NOTIFICATIONS_INSTANCE_ID não configurado para o tenant — pulando tenant`);
          ctx.skipReason = "NOTIFICATIONS_INSTANCE_ID não configurado";
        } else {
          const { data: inst } = await supabase
            .from("whatsapp_instances")
            .select("id, name, api_key, api_url")
            .eq("id", notificationsInstanceId)
            .eq("tenant_id", tenantId)
            .eq("status", "connected")
            .maybeSingle();
          if (!inst) {
            console.warn(`[check-pending-meetings][${tenantId}] Instância de notificações não encontrada ou desconectada — pulando tenant`);
            ctx.skipReason = "Instância WhatsApp não disponível";
          } else {
            ctx.instance = inst as WhatsAppInstance;
            ctx.companyName = ((await getIntegrationKey(supabase, "COMPANY_NAME", tenantId)) || "").toLowerCase();
          }
        }
      } catch (err: any) {
        console.error(`[check-pending-meetings][${tenantId}] Erro hidratando config do tenant:`, err);
        ctx.skipReason = err instanceof Error ? err.message : String(err);
      }
      tenantCtxCache.set(tenantId, ctx);
      return ctx;
    }

    for (const task of pendingTasks || []) {
      results.processed++;

      // Contexto de notificação do tenant da linha (linha sem tenant_id é órfã → pula)
      const taskTenantId = rowTenantOrSkip(task as any, "check-pending-meetings");
      if (!taskTenantId) {
        results.skipped++;
        continue;
      }
      const tenantCtx = await getTenantNotifCtx(taskTenantId);
      if (!tenantCtx.instance) {
        results.skipped++;
        continue;
      }
      const instance = tenantCtx.instance;
      const companyName = tenantCtx.companyName;

      // Verificar se já foi notificado nas últimas 6h
      const lastNotified = task.metadata?.pending_meeting_notified_at;
      if (lastNotified) {
        const lastNotifiedTime = new Date(lastNotified).getTime();
        if (Date.now() - lastNotifiedTime < SIX_HOURS_MS) {
          console.log(
            `⏭️ Task ${task.id} já notificada há menos de 6h — pulando`
          );
          results.skipped++;
          continue;
        }
      }

      // Buscar closer (responsável)
      const { data: teamMember } = await supabase
        .from("team_members")
        .select("id, name, phone")
        .eq("id", task.responsavel_id)
        .single();

      if (!teamMember?.phone) {
        console.log(
          `⚠️ Responsável ${task.responsavel_id} sem telefone — pulando`
        );
        results.errors.push(`Task ${task.id}: responsável sem telefone`);
        continue;
      }

      // Montar mensagem — usar nome do lead, ou extrair do nome da task
      let leadName = (task as any).lead?.name;
      if (!leadName && task.name) {
        // Extrair nome da task: "Reunião | João + Fábio" → "João + Fábio"
        // "<Empresa> & Marcelo" → "Marcelo"
        const separators = [' | ', ' & ', ' + ', ' - '];
        for (const sep of separators) {
          if (task.name.includes(sep)) {
            const parts = task.name.split(sep);
            // Pegar a parte que NÃO é o nome da empresa / "Reunião"
            const candidate = parts.find((p: string) => {
              const norm = p.trim().toLowerCase();
              if (companyName && norm.includes(companyName)) return false;
              return !norm.startsWith('reunião') && !norm.startsWith('ligar');
            })?.trim();
            if (candidate) { leadName = candidate; break; }
          }
        }
      }
      if (!leadName) leadName = task.name || "lead";

      const scheduledTime = new Date(task.scheduled_at!).toLocaleTimeString(
        "pt-BR",
        {
          hour: "2-digit",
          minute: "2-digit",
          timeZone: "America/Sao_Paulo",
        }
      );

      const taskLabel = task.task_type === "call" ? "call" : "reunião";
      const message =
        `⚠️ *ATENÇÃO ${teamMember.name}!*\n\n` +
        `A ${taskLabel} com *${leadName}* das *${scheduledTime}* está sem status no CRM.\n\n` +
        `Você está travando o fluxo do pipeline! Resolve agora:\n` +
        `• *Realizada* — se a call rolou\n` +
        `• *No-show* — se o lead não apareceu\n` +
        `• *Reagendar* — se mudou a data\n\n` +
        `_Não deixa isso acumular_ 🚨`;

      const sent = await sendWhatsApp(instance, teamMember.phone, message);

      if (sent) {
        results.notified++;

        // Marcar pending_meeting_notified_at no metadata
        const updatedMetadata = {
          ...(task.metadata || {}),
          pending_meeting_notified_at: new Date().toISOString(),
        };

        await supabase
          .from("company_activities")
          .update({ metadata: updatedMetadata })
          .eq("id", task.id);
      } else {
        results.errors.push(`Task ${task.id}: falha ao enviar WhatsApp`);
      }
    }

    // --- Fix D: Alerta de anomalia ---
    // Buscar leads com meeting futura mas que NÃO estão em "Call Agendada".
    // PIPELINE_ROLES é resolvido POR TENANT da linha (cache local por ciclo).
    const callAgendadaByTenant = new Map<string, string | null>();
    async function getCallAgendadaStage(tenantId: string): Promise<string | null> {
      if (callAgendadaByTenant.has(tenantId)) return callAgendadaByTenant.get(tenantId) ?? null;
      let stageId: string | null = null;
      try {
        const roles = await getPipelineRoles(supabase, tenantId);
        stageId = roles?.stages?.call_agendada || null;
        if (!stageId) {
          console.warn(`[check-pending-meetings][${tenantId}] PIPELINE_ROLES.stages.call_agendada não configurado — pulando check de anomalias do tenant`);
        }
      } catch (err: any) {
        console.error(`[check-pending-meetings][${tenantId}] Erro lendo PIPELINE_ROLES:`, err);
      }
      callAgendadaByTenant.set(tenantId, stageId);
      return stageId;
    }

    const now = new Date().toISOString();

    const { data: futureTasks } = await supabase
      .from("company_activities")
      .select(
        `
        id,
        lead_id,
        scheduled_at,
        tenant_id,
        lead:leads!company_activities_lead_id_fkey(name, pipeline_stage_id)
      `
      )
      .in("task_type", ["call", "meeting"])
      .eq("completed", false)
      .not("status", "in", '("completed","no_show","cancelled")')
      .gt("scheduled_at", now)
      .not("lead_id", "is", null)
      .limit(50);

    let anomalies = 0;
    for (const ft of futureTasks || []) {
      const lead = (ft as any).lead;
      const ftTenantId = rowTenantOrSkip(ft as any, "check-pending-meetings:anomalies");
      if (!ftTenantId) continue;
      const callAgendadaStageId = await getCallAgendadaStage(ftTenantId);
      if (!callAgendadaStageId) continue;
      if (lead && lead.pipeline_stage_id !== callAgendadaStageId) {
        // Buscar nome do estágio atual
        const { data: stage } = await supabase
          .from("sales_pipeline_stages")
          .select("name")
          .eq("id", lead.pipeline_stage_id)
          .single();

        console.warn(
          `⚠️ Anomalia: lead "${lead.name}" tem call futura (${ft.scheduled_at}) mas está em "${stage?.name || lead.pipeline_stage_id}"`
        );
        anomalies++;
      }
    }

    console.log(`✅ Processamento concluído:`, { ...results, anomalies });

    return new Response(
      JSON.stringify({ success: true, ...results, anomalies }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error: any) {
    console.error("❌ Erro no processamento:", error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

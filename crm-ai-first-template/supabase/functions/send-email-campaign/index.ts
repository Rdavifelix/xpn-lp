import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getTenantConfig, requireActiveConfig, type TenantEmailConfig } from "../_shared/tenant-email-config.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface AudienceCriteria {
  pipeline_ids?: string[];
  stage_ids?: string[];
  lead_ids?: string[];
  source?: string;
}

interface SendBody {
  campaign_id?: string;
  test_email?: string;
  html?: string;
  subject?: string;
  tenant_id?: string;
  audience_override?: AudienceCriteria;
}

interface Recipient {
  lead_id: string | null;
  email: string;
  name: string | null;
  first_name: string | null;
  phone: string | null;
  city: string | null;
  state: string | null;
  sales_rep_name: string | null;
}

async function resolveAudienceByCriteria(
  supabase: any,
  criteria: AudienceCriteria,
  tenantId: string,
): Promise<Recipient[]> {
  if (!criteria || (!criteria.pipeline_ids?.length && !criteria.stage_ids?.length && !criteria.lead_ids?.length)) {
    return [];
  }

  let q = supabase
    .from("leads")
    .select("id, name, email, phone, city_name, state, sales_rep_id")
    .eq("tenant_id", tenantId)
    .not("email", "is", null);

  if (criteria.lead_ids?.length) {
    q = q.in("id", criteria.lead_ids);
  } else {
    if (criteria.stage_ids?.length) {
      q = q.in("pipeline_stage_id", criteria.stage_ids);
    } else if (criteria.pipeline_ids?.length) {
      const { data: stages } = await supabase
        .from("sales_pipeline_stages")
        .select("id")
        .in("pipeline_id", criteria.pipeline_ids)
        .eq("tenant_id", tenantId);
      const stageIds = (stages || []).map((s: any) => s.id);
      if (stageIds.length) q = q.in("pipeline_stage_id", stageIds);
    }
    if (criteria.source) q = q.eq("source", criteria.source);
  }

  const { data: leads, error } = await q.limit(10000);
  if (error) throw error;

  const emails = (leads || []).map((l: any) => l.email).filter(Boolean);
  if (emails.length === 0) return [];

  const { data: unsubs } = await supabase
    .from("email_subscribers")
    .select("email")
    .eq("tenant_id", tenantId)
    .in("email", emails)
    .in("status", ["unsubscribed", "bounced", "complained"]);
  const unsubSet = new Set((unsubs || []).map((u: any) => u.email));

  // Busca os nomes dos vendedores em batch (FK não está declarada, então não dá pra usar embed)
  const repIds = Array.from(
    new Set((leads || []).map((l: any) => l.sales_rep_id).filter(Boolean)),
  ) as string[];
  const repsMap = new Map<string, string>();
  if (repIds.length) {
    const { data: reps } = await supabase
      .from("team_members")
      .select("id, name")
      .in("id", repIds);
    (reps || []).forEach((r: any) => repsMap.set(r.id, r.name));
  }

  return (leads || [])
    .filter((l: any) => l.email && !unsubSet.has(l.email))
    .map((l: any) => ({
      lead_id: l.id,
      email: l.email,
      name: l.name,
      first_name: l.name ? l.name.split(" ")[0] : null,
      phone: l.phone || null,
      city: l.city_name || null,
      state: l.state || null,
      sales_rep_name: l.sales_rep_id ? (repsMap.get(l.sales_rep_id) || null) : null,
    }));
}

async function resolveAudienceFromList(supabase: any, listId: string | null, tenantId: string): Promise<Recipient[]> {
  if (!listId) return [];
  const { data: list } = await supabase
    .from("email_lists")
    .select("criteria")
    .eq("id", listId)
    .eq("tenant_id", tenantId)
    .single();
  if (!list) return [];
  return resolveAudienceByCriteria(supabase, list.criteria || {}, tenantId);
}

async function getOrCreateUnsubscribeToken(
  supabase: any,
  email: string,
  leadId: string | null,
  tenantId: string,
): Promise<string | null> {
  try {
    const { data: existing } = await supabase
      .from("email_subscribers")
      .select("unsubscribe_token, status")
      .eq("tenant_id", tenantId)
      .eq("email", email)
      .maybeSingle();

    if (existing?.unsubscribe_token) {
      return existing.status === "unsubscribed" || existing.status === "complained"
        ? null
        : existing.unsubscribe_token;
    }

    const { data: created } = await supabase
      .from("email_subscribers")
      .insert({
        tenant_id: tenantId,
        email,
        lead_id: leadId,
        status: "subscribed",
        consent_source: "campaign_send",
        consent_at: new Date().toISOString(),
      })
      .select("unsubscribe_token")
      .single();

    return created?.unsubscribe_token || null;
  } catch (e) {
    console.error("Erro ao gerar unsubscribe token:", e);
    return null;
  }
}

function injectComplianceFooter(html: string, unsubscribeUrl: string, config: TenantEmailConfig): string {
  const address = config.company_address || config.company_name || "";
  const replyEmail = config.reply_to || config.from_email || "";
  const footer = `
<table role="presentation" width="100%" style="margin-top:32px;border-top:1px solid #e5e5e5;padding:24px 0;">
  <tr>
    <td style="text-align:center;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:12px;color:#999;line-height:1.6;">
      ${address ? `<p style="margin:0 0 8px;">${address}</p>` : ""}
      <p style="margin:0;">
        <a href="${unsubscribeUrl}" style="color:#999;text-decoration:underline;">Descadastrar</a>
        ${replyEmail ? `· <a href="mailto:${replyEmail}" style="color:#999;text-decoration:underline;">Contato</a>` : ""}
      </p>
    </td>
  </tr>
</table>`;
  if (html.includes("</body>")) {
    return html.replace("</body>", `${footer}</body>`);
  }
  return html + footer;
}

function substituteVariables(text: string, vars: Record<string, string>): string {
  if (!text) return text;
  // Suporta {{nome}}, {{ nome }} e variações com espaços
  return text.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, key) => vars[key] ?? "");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const body: SendBody = await req.json();
    const { campaign_id, test_email, audience_override } = body;

    // === MODO TESTE DE TEMPLATE (sem campaign_id) ===
    // Permite testar um template antes de criar uma campanha.
    if (!campaign_id && test_email && body.html) {
      let tenantIdForTest: string | undefined;
      const auth = req.headers.get("authorization") || "";
      const userToken = auth.replace(/^bearer\s+/i, "").trim();
      if (userToken) {
        try {
          const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY") || "", {
            global: { headers: { Authorization: `Bearer ${userToken}` } },
          });
          const { data: { user } } = await userClient.auth.getUser(userToken);
          tenantIdForTest = (user?.app_metadata as any)?.tenant_id;
        } catch (_e) { /* segue sem tenant */ }
      }
      if (!tenantIdForTest) throw new Error("tenant_id é obrigatório para teste de template");

      const tCfg = await getTenantConfig(supabase, tenantIdForTest);
      const cfg = requireActiveConfig(tCfg, tenantIdForTest);
      const fEmail = (cfg.from_email || "").trim();
      const fName = (cfg.from_name || "CRM").trim();
      const rTo = cfg.reply_to || undefined;
      const appUrlT = cfg.app_url || "https://YOUR_APP_URL";

      const variables: Record<string, string> = {
        nome: "Teste",
        primeiro_nome: "Teste",
        empresa: cfg.company_name || "Empresa",
        email: test_email,
        telefone: "(11) 99999-9999",
        cidade: "São Paulo",
        estado: "SP",
        vendedor: "Vendedor de Teste",
        produto: "Produto de Teste",
        unsubscribe_url: `${appUrlT}/unsubscribe?token=teste`,
        link_descadastro: `${appUrlT}/unsubscribe?token=teste`,
      };
      const html = substituteVariables(body.html, variables);
      const subject = `[TESTE] ${substituteVariables(body.subject || "Teste de template", variables)}`;
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${cfg.resend_api_key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: `${fName} <${fEmail}>`,
          to: [test_email],
          subject,
          html,
          reply_to: rTo,
        }),
      });
      if (!res.ok) {
        const err = await res.text();
        throw new Error(`Resend: ${err}`);
      }
      return new Response(
        JSON.stringify({ success: true, test: true, sent_to: test_email }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!campaign_id) throw new Error("campaign_id é obrigatório");

    const { data: campaign, error: campaignErr } = await supabase
      .from("email_campaigns")
      .select("*")
      .eq("id", campaign_id)
      .single();
    if (campaignErr || !campaign) throw new Error("Campanha não encontrada");

    const tenantId = campaign.tenant_id;
    if (!tenantId) throw new Error("Campaign sem tenant_id — abortando");

    // Lê config Resend do tenant
    const tenantConfig = await getTenantConfig(supabase, tenantId);
    const config = requireActiveConfig(tenantConfig, tenantId);

    const fromEmail = (campaign.from_email || config.from_email || "").trim();
    const fromName = (campaign.from_name || config.from_name || "").trim() || "CRM";
    const replyTo = campaign.reply_to || config.reply_to || undefined;
    const appUrl = config.app_url || "https://YOUR_APP_URL";

    // === MODO TESTE ===
    if (test_email) {
      const variables: Record<string, string> = {
        nome: "Teste",
        primeiro_nome: "Teste",
        empresa: config.company_name || "Empresa",
        email: test_email,
        telefone: "(11) 99999-9999",
        cidade: "São Paulo",
        estado: "SP",
        vendedor: "Vendedor de Teste",
        produto: "Produto de Teste",
        unsubscribe_url: `${appUrl}/unsubscribe?token=teste`,
      };
      const baseHtml = body.html || `<p>${campaign.subject}</p>`;
      const html = substituteVariables(baseHtml, variables);
      const subject = `[TESTE] ${substituteVariables(campaign.subject, variables)}`;
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${config.resend_api_key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: `${fromName} <${fromEmail}>`,
          to: [test_email],
          subject,
          html,
          reply_to: replyTo,
        }),
      });
      if (!res.ok) {
        const err = await res.text();
        throw new Error(`Resend: ${err}`);
      }
      return new Response(
        JSON.stringify({ success: true, test: true, sent_to: test_email }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (campaign.status === "completed" || campaign.status === "cancelled") {
      return new Response(
        JSON.stringify({ error: `Campanha já está ${campaign.status}` }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    await supabase
      .from("email_campaigns")
      .update({ status: "sending", updated_at: new Date().toISOString() })
      .eq("id", campaign_id);

    // Resolve audience
    const campaignAudience = (campaign as any).settings?.audience as AudienceCriteria | undefined;
    let audience: Recipient[] = [];
    if (audience_override) {
      audience = await resolveAudienceByCriteria(supabase, audience_override, tenantId);
    } else if (campaignAudience) {
      audience = await resolveAudienceByCriteria(supabase, campaignAudience, tenantId);
    } else if ((campaign as any).list_id) {
      audience = await resolveAudienceFromList(supabase, (campaign as any).list_id, tenantId);
    } else {
      // Fallback: usa email_campaign_leads (populado por populate_email_campaign_leads via audience_filters)
      const { data: ecls } = await supabase
        .from("email_campaign_leads")
        .select("lead_id, email, name")
        .eq("campaign_id", campaign_id)
        .eq("tenant_id", tenantId)
        .eq("status", "pending");
      const leadIds = (ecls || []).map((r: any) => r.lead_id).filter(Boolean);
      if (leadIds.length) {
        audience = await resolveAudienceByCriteria(supabase, { lead_ids: leadIds }, tenantId);
      }
    }

    if (audience.length === 0) {
      await supabase
        .from("email_campaigns")
        .update({ status: "cancelled", pause_reason: "Nenhum destinatário", updated_at: new Date().toISOString() })
        .eq("id", campaign_id);
      throw new Error("Nenhum destinatário encontrado");
    }

    await supabase
      .from("email_campaigns")
      .update({ total_leads: audience.length })
      .eq("id", campaign_id);

    const from = `${fromName} <${fromEmail}>`;
    let sent = 0;
    let failed = 0;

    const bgTask = (async () => {
      for (const recipient of audience) {
        try {
          const token = await getOrCreateUnsubscribeToken(supabase, recipient.email, recipient.lead_id, tenantId);
          if (!token) {
            console.log(`Skip ${recipient.email} (unsubscribed/complained)`);
            continue;
          }

          const unsubscribeUrl = `${appUrl}/unsubscribe?token=${token}`;
          const variables: Record<string, string> = {
            nome: recipient.name || "",
            primeiro_nome: recipient.first_name || "",
            email: recipient.email,
            empresa: config.company_name || "",
            telefone: recipient.phone || "",
            cidade: recipient.city || "",
            estado: recipient.state || "",
            vendedor: recipient.sales_rep_name || "",
            produto: "",
            unsubscribe_url: unsubscribeUrl,
            link_descadastro: unsubscribeUrl,
          };

          const baseHtml = body.html || (campaign as any).html_content || `<p>${campaign.subject}</p>`;
          let html = substituteVariables(baseHtml, variables);
          html = injectComplianceFooter(html, unsubscribeUrl, config);
          const subject = substituteVariables(campaign.subject, variables);

          const { data: sendRow } = await supabase
            .from("email_sends")
            .insert({
              tenant_id: tenantId,
              campaign_id,
              lead_id: recipient.lead_id,
              email: recipient.email,
              status: "pending",
              html,
            })
            .select("id")
            .single();

          const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${config.resend_api_key}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from,
              to: [recipient.email],
              subject,
              html,
              reply_to: replyTo,
              headers: {
                "X-Campaign-ID": campaign_id,
                "X-Send-ID": sendRow?.id || "",
                "X-Tenant-ID": tenantId,
                "List-Unsubscribe": `<${unsubscribeUrl}>`,
                "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
              },
            }),
          });

          if (res.ok) {
            const data = await res.json();
            const nowIso = new Date().toISOString();
            await supabase
              .from("email_sends")
              .update({
                status: "sent",
                sent_at: nowIso,
                resend_id: data.id,
              })
              .eq("id", sendRow!.id);
            // Atualiza email_campaign_leads (que é o que a UI lê)
            await supabase
              .from("email_campaign_leads")
              .update({
                status: "sent",
                sent_at: nowIso,
                brevo_message_id: data.id,
              })
              .eq("campaign_id", campaign_id)
              .eq("email", recipient.email);
            sent++;
          } else {
            const errText = await res.text();
            await supabase
              .from("email_sends")
              .update({
                status: "failed",
                error_message: errText.slice(0, 500),
              })
              .eq("id", sendRow!.id);
            await supabase
              .from("email_campaign_leads")
              .update({
                status: "failed",
                failed_at: new Date().toISOString(),
                error_message: errText.slice(0, 500),
              })
              .eq("campaign_id", campaign_id)
              .eq("email", recipient.email);
            failed++;
          }
        } catch (err: any) {
          console.error(`Erro enviando pra ${recipient.email}:`, err);
          failed++;
        }

        await new Promise((r) => setTimeout(r, 100));
      }

      await supabase
        .from("email_campaigns")
        .update({
          status: "completed",
          completed_at: new Date().toISOString(),
          sent_count: sent,
          failed_count: failed,
          updated_at: new Date().toISOString(),
        })
        .eq("id", campaign_id);

      console.log(`Campaign ${campaign_id} done: ${sent} sent, ${failed} failed`);
    })();

    // @ts-expect-error -- EdgeRuntime is injected by the Supabase Deno runtime
    if (typeof EdgeRuntime !== "undefined") EdgeRuntime.waitUntil(bgTask);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Campanha em envio",
        recipients: audience.length,
      }),
      { status: 202, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

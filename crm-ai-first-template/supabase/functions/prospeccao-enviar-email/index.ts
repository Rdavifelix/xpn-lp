// ============================================================
// prospeccao-enviar-email
// Envia diagnóstico por email via Resend
// Body: { diagnostico_id, email_to, subject, message_text, include_link?, print_url?, user_id? }
// verify_jwt: false
// ============================================================

import "https://deno.land/x/xhr@0.3.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Input {
  diagnostico_id?: string;
  email_to: string;
  subject?: string;
  message_text: string;
  include_link?: boolean;
  print_url?: string | null;
  user_id?: string;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function textToHtmlParagraphs(text: string): string {
  return text
    .split(/\n{2,}/)
    .map((p) => p.trim())
    .filter(Boolean)
    .map(
      (p) =>
        `<p style="margin:0 0 14px;font-family:'Inter',system-ui,sans-serif;font-size:15px;color:#44403c;line-height:1.65;">${escapeHtml(
          p
        ).replace(/\n/g, "<br>")}</p>`
    )
    .join("\n");
}

function buildEmailHtml(params: {
  messageText: string;
  printUrl: string | null;
  includeLink: boolean;
  fromName: string;
}): string {
  const { messageText, printUrl, includeLink, fromName } = params;
  const paragraphs = textToHtmlParagraphs(messageText);
  const ctaBlock =
    includeLink && printUrl
      ? `
  <tr><td style="padding:24px 40px 0;" align="center">
    <table role="presentation" cellpadding="0" cellspacing="0"><tr>
      <td align="center" style="border-radius:14px;background:#0a0a0a;">
        <a href="${escapeHtml(printUrl)}" target="_blank" style="display:block;padding:16px 36px;font-family:'Inter',system-ui,sans-serif;color:#ffffff;font-size:14px;font-weight:700;text-decoration:none;letter-spacing:0.3px;">Ver diagnóstico completo &rarr;</a>
      </td>
    </tr></table>
    <p style="margin:10px 0 0;font-family:'Inter',system-ui,sans-serif;font-size:11px;color:#a8a29e;">PDF estilo consultoria com dados, scores e oportunidades</p>
  </td></tr>`
      : "";

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
</head>
<body style="margin:0;padding:0;background-color:#f5f5f4;font-family:'Inter',system-ui,sans-serif;-webkit-font-smoothing:antialiased;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f5f4;">
<tr><td align="center" style="padding:40px 16px;">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.04),0 8px 30px rgba(0,0,0,0.06);">
  <tr><td style="padding:0;height:4px;background:linear-gradient(90deg,#c8952e,#e4b964,#c8952e);"></td></tr>
  <tr><td style="padding:32px 40px 8px;">
    <p style="margin:0;font-family:'Inter',system-ui,sans-serif;font-size:11px;font-weight:700;color:#a3a3a3;letter-spacing:2px;text-transform:uppercase;">Diagnóstico de Prospecção</p>
  </td></tr>
  <tr><td style="padding:18px 40px 8px;">
    ${paragraphs}
  </td></tr>
  ${ctaBlock}
  <tr><td style="padding:32px 40px 0;"><div style="height:1px;background:#e7e5e4;"></div></td></tr>
  <tr><td style="padding:18px 40px 28px;">
    <p style="margin:0;font-family:'Inter',system-ui,sans-serif;font-size:12px;color:#a8a29e;">${escapeHtml(fromName)}</p>
  </td></tr>
</table>
</td></tr></table>
</body></html>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const t0 = Date.now();

  try {
    const input: Input = await req.json();
    const {
      diagnostico_id,
      email_to,
      subject,
      message_text,
      include_link = true,
      print_url,
      user_id,
    } = input;

    if (!email_to || !email_to.includes("@")) {
      return json({ error: "email_to inválido" }, 400);
    }
    if (!message_text || message_text.trim().length === 0) {
      return json({ error: "message_text obrigatório" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const tenantId = getTenantFromRequest(req);
    const RESEND_API_KEY = await getIntegrationKey(supabase, "RESEND_API_KEY", tenantId);
    if (!RESEND_API_KEY) {
      return json(
        { error: "RESEND_API_KEY não configurada em /configuracoes/integracoes" },
        500
      );
    }

    const fromAddress =
      (await getIntegrationKey(supabase, "prospeccao_email_from", tenantId)) ||
      "Prospecção <onboarding@resend.dev>";

    const finalSubject = subject?.trim() || "Diagnóstico de prospecção";

    const html = buildEmailHtml({
      messageText: message_text,
      printUrl: print_url || null,
      includeLink: !!include_link,
      fromName: fromAddress.replace(/\s*<.+?>$/, "").trim() || "Prospecção",
    });

    // Envia via Resend
    const resendStart = Date.now();
    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromAddress,
        to: [email_to],
        subject: finalSubject,
        html,
        text: message_text,
      }),
    });

    const resendData = await resendRes.json().catch(() => ({}));
    const resendDuration = Date.now() - resendStart;

    // Loga uso (best-effort, não bloqueia)
    try {
      await supabase.from("prospeccao_uso_api").insert({
        ...(tenantId ? { tenant_id: tenantId } : {}),
        api_provider: "resend",
        endpoint: "/emails",
        fonte: "enviar_email",
        custo: resendRes.ok ? 0.0001 : 0,
        sucesso: resendRes.ok,
        duracao_ms: resendDuration,
        erro: resendRes.ok ? null : JSON.stringify(resendData).slice(0, 500),
        metadata: { diagnostico_id: diagnostico_id || null, email_to, subject: finalSubject },
        created_by_user_id: user_id || null,
      });
    } catch (logErr) {
      console.warn("[enviar-email] log uso_api falhou:", logErr);
    }

    if (!resendRes.ok) {
      console.error("[enviar-email] Resend falhou:", resendData);
      const detalhe =
        resendData?.message ||
        resendData?.error?.message ||
        resendData?.error ||
        `HTTP ${resendRes.status}`;
      return json(
        {
          error: "Falha ao enviar email",
          detalhes: typeof detalhe === "string" ? detalhe : JSON.stringify(detalhe),
          resend_status: resendRes.status,
          dica:
            resendRes.status === 403
              ? "Resend em modo sandbox: 'onboarding@resend.dev' só envia pro email da conta Resend. Verifique um domínio próprio em resend.com/domains e configure 'prospeccao_email_from' no banco."
              : undefined,
        },
        502
      );
    }

    return json({
      ok: true,
      email_id: resendData?.id || null,
      to: email_to,
      subject: finalSubject,
      duracao_ms: Date.now() - t0,
    });
  } catch (err: any) {
    console.error("[enviar-email] Erro fatal:", err);
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

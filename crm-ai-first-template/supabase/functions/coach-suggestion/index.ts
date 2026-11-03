import "https://deno.land/x/xhr@0.3.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { getTenantFromRequest } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// Using Gemini 2.5 Flash for lowest latency
const GEMINI_MODEL = "gemini-2.5-flash";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Multi-tenant (Onda B3-C): tenant do JWT. Null = single-tenant legado (sem filtro).
    const tenantId = getTenantFromRequest(req);
    const {
      transcription,
      phase_name,
      phase_description,
      phase_checklist,
      playbook_context,
      lead_id,
    } = await req.json();

    if (!transcription) {
      return new Response(
        JSON.stringify({ error: "transcription é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
    const geminiApiKey = (await getIntegrationKey(supabase, "GEMINI_API_KEY", tenantId)) || "";
    if (!geminiApiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY não configurada" }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Buscar contexto do lead se disponível
    let leadContext = "";
    if (lead_id) {
      let leadQuery = supabase
        .from("leads")
        .select(`
          name, company_name, sales_score, sales_stage,
          ai_conversation_insights, ai_objections, ai_interests
        `)
        .eq("id", lead_id);
      if (tenantId) leadQuery = leadQuery.eq("tenant_id", tenantId);
      const { data: lead } = await leadQuery.single();

      if (lead) {
        leadContext = `
CONTEXTO DO LEAD:
- Nome: ${lead.name || "N/A"}
- Empresa: ${lead.company_name || "N/A"}
- Score: ${lead.sales_score || 0}/100
- Estágio: ${lead.sales_stage || "N/A"}
- Objeções conhecidas: ${lead.ai_objections?.join(", ") || "Nenhuma"}
- Interesses: ${lead.ai_interests?.join(", ") || "Não identificados"}
`;
      }
    }

    // Build checklist context with IDs for auto-completion
    const checklistContext = phase_checklist && phase_checklist.length > 0
      ? `\nCHECKLIST DA FASE:\n${phase_checklist.map((item: any, i: number) => `- [${item.id || `item-${i}`}] ${item.text}`).join("\n")}`
      : "";

    const systemPrompt = `Voce é um coach de vendas PROATIVO em tempo real. SEMPRE dê uma sugestão útil baseada na conversa e na fase atual.

${leadContext}
${playbook_context ? `CONTEXTO DO PLAYBOOK:\n${String(playbook_context).slice(0, 2000)}` : ""}
FASE: ${phase_name || "Geral"}
${phase_description ? `OBJETIVO: ${phase_description}` : ""}
${checklistContext}

REGRAS:
1. SEMPRE retorne has_suggestion: true com uma dica prática
2. Máximo 1-2 frases curtas e diretas
3. Se o vendedor está na fase errada (ex: falando de preço na abertura), ALERTE
4. Se o cliente apresentou objeção, sugira resposta imediata
5. Se tem item do checklist pendente, lembre o vendedor
6. Se detectar oportunidade de fechamento, avise
7. Analise a transcrição e identifique quais itens do CHECKLIST já foram cumpridos. Retorne os IDs em completed_items.

TIPOS:
- objection_handler: Objeção detectada
- question: Pergunta estratégica a fazer
- closing: Oportunidade de fechar
- tip: Dica de condução da conversa
- info: Lembrete sobre o lead/fase

JSON:
{"has_suggestion":true,"suggestion":{"type":"tip","text":"sugestão aqui","confidence":0.8},"completed_items":["item-0","item-2"]}`;

    const userMessage = `TRANSCRIÇÃO RECENTE:\n${transcription}\n\nAnalise e sugira se relevante.`;

    // Call Gemini 2.5 Flash
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${geminiApiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: `${systemPrompt}\n\n${userMessage}`,
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.5,
            maxOutputTokens: 200,
          },
        }),
      }
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini error:", errorText);
      return new Response(
        JSON.stringify({ error: "Erro ao processar com IA", details: errorText }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiResponse.json();
    const aiContent = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!aiContent) {
      return new Response(
        JSON.stringify({ has_suggestion: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse response
    let result;
    try {
      const cleanContent = aiContent
        .replace(/```json\n?/g, "")
        .replace(/```\n?/g, "")
        .trim();

      const jsonMatch = cleanContent.match(/\{[\s\S]*\}/);
      if (!jsonMatch) throw new Error("No JSON found");

      result = JSON.parse(jsonMatch[0]);
    } catch (parseError: any) {
      console.error("Parse error:", aiContent);
      return new Response(
        JSON.stringify({ has_suggestion: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error:", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(
      JSON.stringify({ error: "Erro interno", details: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

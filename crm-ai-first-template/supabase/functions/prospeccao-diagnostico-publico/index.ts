import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * prospeccao-diagnostico-publico — leitura PÚBLICA de um diagnóstico específico.
 *
 * Substitui as policies `anon read (true)` nas tabelas de prospecção (que
 * permitiam dump da tabela inteira sem login). Aqui o anon só recebe o
 * diagnóstico cujo UUID ele conhece (o link enviado ao prospect) — nunca lista.
 *
 * POST { diagnostico_id } → { diagnostico, lead }
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { diagnostico_id } = await req.json().catch(() => ({}));
    if (!diagnostico_id || !UUID_RE.test(String(diagnostico_id))) {
      return jsonRes({ error: "diagnostico_id (uuid) obrigatório" }, 400);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: diagnostico, error: dErr } = await supabase
      .from("prospeccao_diagnosticos")
      .select(`
        id, lead_descoberto_id, score_site, score_google_maps, score_instagram,
        score_facebook, score_linkedin, score_youtube, score_tiktok,
        score_doctoralia, score_reclame_aqui, score_ifood, score_meta_ads,
        score_google_ads, score_posicao_google, score_pagespeed, score_outros,
        score_geral, score_atracao, score_qualificacao, score_conversao,
        score_retencao, achados_site, achados_maps, achados_instagram,
        achados_facebook, achados_linkedin, achados_youtube, achados_tiktok,
        achados_doctoralia, achados_reclame_aqui, achados_ifood,
        achados_meta_ads, achados_google_ads, achados_posicao_google,
        achados_pagespeed, achados_contexto_negocio, achados_outros,
        oportunidades, resumo_executivo, fontes_consultadas, status,
        pdf_url, pdf_imagens_urls, created_at, updated_at
      `)
      .eq("id", diagnostico_id)
      .maybeSingle();
    if (dErr) return jsonRes({ error: dErr.message }, 500);
    if (!diagnostico) return jsonRes({ error: "Diagnóstico não encontrado" }, 404);

    let lead = null;
    if (diagnostico.lead_descoberto_id) {
      const { data } = await supabase
        .from("prospeccao_leads_descobertos")
        .select("id, nome, url_site, instagram_handle, youtube_url")
        .eq("id", diagnostico.lead_descoberto_id)
        .maybeSingle();
      lead = data || null;
    }

    return jsonRes({ diagnostico, lead });
  } catch (err: any) {
    console.error("[diagnostico-publico]", (err as Error)?.message);
    return jsonRes({ error: (err as Error)?.message || "Erro inesperado" }, 500);
  }
});

function jsonRes(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

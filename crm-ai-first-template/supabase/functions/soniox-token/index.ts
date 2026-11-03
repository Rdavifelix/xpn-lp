import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    let principal;
    try {
      principal = await authenticateRequest(req);
    } catch (error: any) {
      const response = authErrorResponse(error);
      for (const [key, value] of Object.entries(corsHeaders)) response.headers.set(key, value);
      return response;
    }
    if (!principal.user || !principal.tenantId) {
      return new Response(JSON.stringify({ error: "Authenticated tenant user required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Usa service_role pra ler config (sem depender de RLS/auth.getUser()).
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const apiKey = await getIntegrationKey(supabase, "SONIOX_API_KEY", principal.tenantId);
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "Soniox API key nao configurada. Cadastre em /configuracoes > API Keys." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const sonioxResponse = await fetch("https://api.soniox.com/v1/auth/temporary-api-key", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        usage_type: "transcribe_websocket",
        expires_in_seconds: 60,
        single_use: true,
        max_session_duration_seconds: 7200,
        client_reference_id: principal.user.id,
      }),
    });
    const responseBody = await sonioxResponse.text();
    if (!sonioxResponse.ok) {
      console.error("[soniox-token] temporary key error:", sonioxResponse.status, responseBody.slice(0, 300));
      return new Response(JSON.stringify({ error: "Unable to create temporary transcription key" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(responseBody, {
      status: 201,
      headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (err: any) {
    console.error("[soniox-token] error:", err);
    return new Response(
      JSON.stringify({ error: "Internal error", detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

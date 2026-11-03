import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getIntegrationKey } from "../_shared/config.ts";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";
import { assertEntityTenant, requireTenantFromRequest, tenantErrorResponse } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET vem da tabela `config` (com fallback
// pra env var via getIntegrationKey). Sem hardcode de credenciais.

// Refresh access token if expired
async function refreshAccessToken(supabase: any, refreshToken: string, tenantId: string | null): Promise<{ access_token: string; expires_in: number } | null> {
  try {
    // Credenciais resolvidas pro tenant do team_member alvo (override → global)
    const clientId = (await getIntegrationKey(supabase, "GOOGLE_CLIENT_ID", tenantId)) || "";
    const clientSecret = (await getIntegrationKey(supabase, "GOOGLE_CLIENT_SECRET", tenantId)) || "";
    if (!clientId || !clientSecret) {
      console.error("GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET n\u00e3o configurados na config");
      return null;
    }
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: "refresh_token",
      }),
    });

    if (!response.ok) {
      console.error("Failed to refresh token:", await response.text());
      return null;
    }

    return await response.json();
  } catch (error: any) {
    console.error("Error refreshing token:", error);
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { team_member_id, action = "setup" } = await req.json();

    if (!team_member_id) {
      return new Response(
        JSON.stringify({ success: false, error: "team_member_id is required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Multi-tenant: caller com JWT de usuário → tenant do JWT; caller service_role
    // (renew-calendar-watches) → tenant do team_member alvo (o tenant_id do body
    // NÃO é confiável). O team_member precisa pertencer ao tenant resolvido.
    const principal = await authenticateRequest(req);
    let tenantId: string;
    if (principal.isServiceRole) {
      const { data: memberRow } = await supabase
        .from("team_members")
        .select("tenant_id")
        .eq("id", team_member_id)
        .maybeSingle();
      if (!memberRow?.tenant_id) {
        return new Response(
          JSON.stringify({ success: false, error: "Team member not found" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 404 }
        );
      }
      tenantId = memberRow.tenant_id as string;
    } else {
      tenantId = requireTenantFromRequest(req);
    }
    await assertEntityTenant(supabase, "team_members", team_member_id, tenantId);

    // Get team member's Google tokens
    const { data: member, error: memberError } = await supabase
      .from("team_members")
      .select("google_access_token, google_refresh_token, google_token_expires_at, google_calendar_watch_channel_id, google_calendar_watch_resource_id, tenant_id")
      .eq("id", team_member_id)
      .eq("tenant_id", tenantId)
      .single();

    if (memberError || !member) {
      return new Response(
        JSON.stringify({ success: false, error: "Team member not found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 404 }
      );
    }

    if (!member.google_access_token || !member.google_refresh_token) {
      return new Response(
        JSON.stringify({ success: false, error: "Google Calendar not connected" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Check if token is expired and refresh if needed
    let accessToken = member.google_access_token;
    const tokenExpiry = member.google_token_expires_at ? new Date(member.google_token_expires_at) : new Date(0);
    
    if (tokenExpiry <= new Date()) {
      const newTokens = await refreshAccessToken(supabase, member.google_refresh_token, tenantId);
      
      if (!newTokens) {
        return new Response(
          JSON.stringify({ success: false, error: "Failed to refresh Google token" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
        );
      }

      accessToken = newTokens.access_token;
      const newExpiry = new Date(Date.now() + newTokens.expires_in * 1000);

      await supabase
        .from("team_members")
        .update({
          google_access_token: accessToken,
          google_token_expires_at: newExpiry.toISOString(),
        })
        .eq("id", team_member_id)
        .eq("tenant_id", tenantId);
    }

    if (action === "stop" && member.google_calendar_watch_channel_id) {
      // Stop existing watch
      console.log("Stopping existing watch...");
      
      await fetch(
        "https://www.googleapis.com/calendar/v3/channels/stop",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            id: member.google_calendar_watch_channel_id,
            resourceId: member.google_calendar_watch_resource_id,
          }),
        }
      );

      await supabase
        .from("team_members")
        .update({
          google_calendar_watch_channel_id: null,
          google_calendar_watch_resource_id: null,
          google_calendar_watch_expiration: null,
        })
        .eq("id", team_member_id)
        .eq("tenant_id", tenantId);

      return new Response(
        JSON.stringify({ success: true, message: "Watch stopped" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Setup new watch
    const channelId = crypto.randomUUID();
    const webhookUrl = `${supabaseUrl}/functions/v1/google-calendar-webhook`;
    
    // Watch expires in 7 days (Google's max is ~30 days)
    const expiration = Date.now() + 7 * 24 * 60 * 60 * 1000;

    console.log("Setting up calendar watch...", { channelId, webhookUrl });

    const watchResponse = await fetch(
      "https://www.googleapis.com/calendar/v3/calendars/primary/events/watch",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          id: channelId,
          type: "web_hook",
          address: webhookUrl,
          token: team_member_id, // Pass team_member_id as token for identification
          expiration: expiration.toString(),
        }),
      }
    );

    if (!watchResponse.ok) {
      const error = await watchResponse.text();
      console.error("Failed to setup watch:", error);
      return new Response(
        JSON.stringify({ success: false, error: `Failed to setup watch: ${error}` }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    const watchResult = await watchResponse.json();
    console.log("Watch setup result:", watchResult);

    // Save watch info
    await supabase
      .from("team_members")
      .update({
        google_calendar_watch_channel_id: watchResult.id,
        google_calendar_watch_resource_id: watchResult.resourceId,
        google_calendar_watch_expiration: new Date(parseInt(watchResult.expiration)).toISOString(),
      })
      .eq("id", team_member_id)
      .eq("tenant_id", tenantId);

    // Do initial sync
    const syncResponse = await fetch(
      `${supabaseUrl}/functions/v1/sync-google-calendar`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({
          team_member_id: team_member_id,
          full_sync: true,
        }),
      }
    );

    const syncResult = await syncResponse.json();

    return new Response(
      JSON.stringify({
        success: true,
        message: "Calendar watch setup successfully",
        watch: {
          channelId: watchResult.id,
          expiration: new Date(parseInt(watchResult.expiration)).toISOString(),
        },
        initialSync: syncResult,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    const t = tenantErrorResponse(error, corsHeaders);
    if (t) return t;
    if (error instanceof Error && (error.message === "unauthorized" || error.message === "auth_not_configured")) {
      return authErrorResponse(error);
    }
    console.error("Setup error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});

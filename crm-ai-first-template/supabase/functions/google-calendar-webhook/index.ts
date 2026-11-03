import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-goog-channel-id, x-goog-channel-token, x-goog-resource-id, x-goog-resource-state, x-goog-resource-uri, x-goog-message-number",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Google sends these headers with webhook notifications
    const channelId = req.headers.get("x-goog-channel-id");
    const resourceState = req.headers.get("x-goog-resource-state");
    const resourceId = req.headers.get("x-goog-resource-id");
    const channelToken = req.headers.get("x-goog-channel-token"); // Contains team_member_id

    console.log("📅 Google Calendar Webhook received:", {
      channelId,
      resourceState,
      resourceId,
    });

    // Ignore sync messages (initial verification)
    if (resourceState === "sync") {
      console.log("Sync verification received, acknowledging...");
      return new Response("OK", { headers: corsHeaders, status: 200 });
    }

    // For actual changes, trigger a sync
    if (resourceState === "exists" && channelToken) {
      const teamMemberId = channelToken;

      // Multi-tenant (Onda B3): tenant vem do TEAM MEMBER dono do watch
      let tenantId: string | null = null;
      try {
        const { data: member } = await supabase
          .from("team_members")
          .select("tenant_id, google_calendar_watch_channel_id, google_calendar_watch_resource_id")
          .eq("id", teamMemberId)
          .maybeSingle();
        if (!member || member.google_calendar_watch_channel_id !== channelId ||
          member.google_calendar_watch_resource_id !== resourceId) {
          return new Response("Forbidden", { headers: corsHeaders, status: 403 });
        }
        tenantId = member?.tenant_id || null;
      } catch (error: any) {
        console.error("Unable to validate calendar channel:", error);
        return new Response("Webhook validation unavailable", { headers: corsHeaders, status: 503 });
      }

      // Call the sync function
      const syncResponse = await fetch(
        `${supabaseUrl}/functions/v1/sync-google-calendar`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${supabaseServiceKey}`,
          },
          body: JSON.stringify({
            team_member_id: teamMemberId,
            full_sync: false, // Incremental sync using sync token
          }),
        }
      );

      const syncResult = await syncResponse.json();
      console.log("Sync result:", syncResult);

      // Log the webhook event
      try {
        await supabase.from("calendar_webhook_logs").insert({
          ...(tenantId ? { tenant_id: tenantId } : {}),
          channel_id: channelId,
          resource_id: resourceId,
          resource_state: resourceState,
          team_member_id: teamMemberId,
          sync_result: syncResult,
        });
      } catch { /* optional audit table */ }
    }

    return new Response("OK", { headers: corsHeaders, status: 200 });

  } catch (error: any) {
    console.error("Webhook error:", error);
    // Always return 200 to Google to prevent retries
    return new Response("OK", { headers: corsHeaders, status: 200 });
  }
});

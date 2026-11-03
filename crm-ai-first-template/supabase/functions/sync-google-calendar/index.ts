import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireIntegrationKey } from "../_shared/config.ts";
import { authenticateRequest, authErrorResponse } from "../_shared/auth.ts";
import { assertEntityTenant, requireTenantFromRequest, rowTenantOrSkip, tenantErrorResponse } from "../_shared/tenant.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// NUNCA hardcode — lidos da tabela config via getIntegrationKey (preenchidos em
// /configuracoes > Integrações). Carregados no handler e passados por parâmetro.
interface GoogleOAuthCfg {
  clientId: string;
  clientSecret: string;
}

interface GoogleEvent {
  id: string;
  summary?: string;
  description?: string;
  location?: string;
  start: { dateTime?: string; date?: string; timeZone?: string };
  end: { dateTime?: string; date?: string; timeZone?: string };
  attendees?: Array<{ email: string; responseStatus?: string }>;
  organizer?: { email: string };
  hangoutLink?: string;
  htmlLink?: string;
  status?: string;
}

// Refresh access token if expired
async function refreshAccessToken(refreshToken: string, cfg: GoogleOAuthCfg): Promise<{ access_token: string; expires_in: number } | null> {
  try {
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: cfg.clientId,
        client_secret: cfg.clientSecret,
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

// Fetch events from Google Calendar
async function fetchGoogleCalendarEvents(
  accessToken: string,
  calendarId: string = "primary",
  timeMin?: string,
  timeMax?: string,
  syncToken?: string
): Promise<{ events: GoogleEvent[]; nextSyncToken?: string }> {
  const url = new URL(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`);

  if (syncToken) {
    // Incremental sync
    url.searchParams.set("syncToken", syncToken);
  } else {
    // Full sync - get events from last 30 days to next 90 days
    const now = new Date();
    const defaultTimeMin = timeMin || new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const defaultTimeMax = timeMax || new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000).toISOString();

    url.searchParams.set("timeMin", defaultTimeMin);
    url.searchParams.set("timeMax", defaultTimeMax);
    url.searchParams.set("singleEvents", "true");
    url.searchParams.set("orderBy", "startTime");
  }

  url.searchParams.set("maxResults", "250");

  const response = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    const error = await response.text();
    console.error("Google Calendar API error:", error);

    // If sync token is invalid, do a full sync
    if (response.status === 410 && syncToken) {
      console.log("Sync token expired, doing full sync...");
      return fetchGoogleCalendarEvents(accessToken, calendarId, timeMin, timeMax);
    }

    throw new Error(`Google Calendar API error: ${response.status}`);
  }

  const data = await response.json();
  return {
    events: data.items || [],
    nextSyncToken: data.nextSyncToken,
  };
}

// Convert Google event to task format
function googleEventToTask(event: GoogleEvent, responsavelId: string | null) {
  const isAllDay = !event.start.dateTime;
  const startDateTime = event.start.dateTime || `${event.start.date}T09:00:00`;
  const endDateTime = event.end.dateTime || `${event.end.date}T18:00:00`;

  // Build description with attendees info
  const attendeesInfo = event.attendees?.map(a => a.email).join(", ");
  const description = [
    event.description,
    attendeesInfo ? `\n\nParticipantes: ${attendeesInfo}` : null
  ].filter(Boolean).join("") || null;

  // Detect birthdays/reminders — should not be imported as meetings
  const lowerName = (event.summary || '').toLowerCase();
  const isNonMeeting = lowerName.includes('aniversário') || lowerName.includes('parabéns')
    || lowerName.includes('birthday') || lowerName.includes('reminder')
    || lowerName.includes('lembrete');

  return {
    name: event.summary || "Evento sem título",
    description,
    task_type: isNonMeeting ? "internal" as const : "meeting" as const,
    team: isNonMeeting ? "internal" as const : "sales" as const,
    responsavel_id: responsavelId,
    scheduled_at: startDateTime,
    end_datetime: endDateTime,
    is_all_day: isAllDay,
    meeting_link: event.hangoutLink || null,
    google_event_id: event.id,
    google_calendar_synced: true,
  };
}

// Sync a single team member's calendar
async function syncMember(
  supabase: any,
  teamMemberId: string,
  member: {
    name: string;
    email: string;
    google_access_token: string;
    google_refresh_token: string;
    google_token_expires_at: string | null;
    google_calendar_sync_token: string | null;
    tenant_id?: string | null;
  },
  fullSync: boolean,
  cfg: GoogleOAuthCfg
): Promise<{ created: number; updated: number; deleted: number; skipped: number; total: number; error?: string }> {
  const responsavelId = teamMemberId;
  const tenantId = member.tenant_id || null;
  let created = 0, updated = 0, deleted = 0, skipped = 0;

  // Check if token is expired and refresh if needed
  let accessToken = member.google_access_token;
  const tokenExpiry = member.google_token_expires_at ? new Date(member.google_token_expires_at) : new Date(0);

  if (tokenExpiry <= new Date()) {
    console.log(`[${member.name}] Token expired, refreshing...`);
    const newTokens = await refreshAccessToken(member.google_refresh_token, cfg);

    if (!newTokens) {
      return { created: 0, updated: 0, deleted: 0, skipped: 0, total: 0, error: "Failed to refresh token" };
    }

    accessToken = newTokens.access_token;
    const newExpiry = new Date(Date.now() + newTokens.expires_in * 1000);

    await supabase
      .from("team_members")
      .update({
        google_access_token: accessToken,
        google_token_expires_at: newExpiry.toISOString(),
      })
      .eq("id", teamMemberId);
  }

  // Fetch events from Google Calendar
  const syncToken = fullSync ? undefined : member.google_calendar_sync_token || undefined;
  const { events, nextSyncToken } = await fetchGoogleCalendarEvents(accessToken, "primary", undefined, undefined, syncToken);

  console.log(`[${member.name}] Fetched ${events.length} events from Google Calendar`);

  for (const event of events) {
    // === DEDUP LAYER 1: by google_event_id (primary) ===
    let byEventIdQ = supabase
      .from("company_activities")
      .select("id, status")
      .eq("google_event_id", event.id);
    if (tenantId) byEventIdQ = byEventIdQ.eq("tenant_id", tenantId);
    const { data: existingByEventId } = await byEventIdQ.maybeSingle();

    if (event.status === "cancelled") {
      // Only delete if we have a matching task AND it's not already completed/in_progress
      if (existingByEventId) {
        // Don't delete tasks that are completed, in_progress, or have transcriptions
        if (['completed', 'in_progress'].includes(existingByEventId.status)) {
          console.log(`[${member.name}] Skipping delete of ${event.id} — task status is ${existingByEventId.status}`);
          skipped++;
        } else {
          await supabase
            .from("company_activities")
            .delete()
            .eq("id", existingByEventId.id);
          deleted++;
        }
      }
      continue;
    }

    if (existingByEventId) {
      // Update existing task — only sync safe fields (never overwrite team, status, responsavel_id)
      const taskData = googleEventToTask(event, responsavelId);
      const safeUpdate = {
        name: taskData.name,
        description: taskData.description,
        scheduled_at: taskData.scheduled_at,
        end_datetime: taskData.end_datetime,
        is_all_day: taskData.is_all_day,
        meeting_link: taskData.meeting_link,
        google_calendar_synced: true,
      };

      await supabase
        .from("company_activities")
        .update(safeUpdate)
        .eq("id", existingByEventId.id);
      updated++;
      continue;
    }

    // === DEDUP LAYER 2: by meeting_link (catch tasks created without google_event_id) ===
    if (event.hangoutLink) {
      let byMeetLinkQ = supabase
        .from("company_activities")
        .select("id")
        .eq("meeting_link", event.hangoutLink)
        .eq("responsavel_id", responsavelId);
      if (tenantId) byMeetLinkQ = byMeetLinkQ.eq("tenant_id", tenantId);
      const { data: existingByMeetLink } = await byMeetLinkQ.maybeSingle();

      if (existingByMeetLink) {
        // Link existing task to this google_event_id (so future syncs use Layer 1)
        await supabase
          .from("company_activities")
          .update({
            google_event_id: event.id,
            google_calendar_synced: true,
          })
          .eq("id", existingByMeetLink.id);
        console.log(`[${member.name}] Linked existing task ${existingByMeetLink.id} to Google event ${event.id} (matched by meeting_link)`);
        updated++;
        continue;
      }
    }

    // === DEDUP LAYER 3: by name + time window (±5 min) ===
    if (event.summary) {
      const startTime = event.start.dateTime || `${event.start.date}T09:00:00`;
      const startDate = new Date(startTime);
      const fiveMinBefore = new Date(startDate.getTime() - 5 * 60 * 1000).toISOString();
      const fiveMinAfter = new Date(startDate.getTime() + 5 * 60 * 1000).toISOString();

      let byNameTimeQ = supabase
        .from("company_activities")
        .select("id")
        .eq("responsavel_id", responsavelId)
        .eq("name", event.summary)
        .gte("scheduled_at", fiveMinBefore)
        .lte("scheduled_at", fiveMinAfter);
      if (tenantId) byNameTimeQ = byNameTimeQ.eq("tenant_id", tenantId);
      const { data: existingByNameTime } = await byNameTimeQ.maybeSingle();

      if (existingByNameTime) {
        // Link existing task to this google_event_id
        await supabase
          .from("company_activities")
          .update({
            google_event_id: event.id,
            google_calendar_synced: true,
            meeting_link: event.hangoutLink || undefined,
          })
          .eq("id", existingByNameTime.id);
        console.log(`[${member.name}] Linked existing task ${existingByNameTime.id} to Google event ${event.id} (matched by name+time)`);
        updated++;
        continue;
      }
    }

    // No match found — create new task
    // Skip past events on full sync (avoid creating stale tasks)
    if (fullSync) {
      const eventStart = event.start.dateTime || `${event.start.date}T09:00:00`;
      if (new Date(eventStart) < new Date()) {
        console.log(`[${member.name}] Skipping past event: ${event.summary} (${eventStart})`);
        skipped++;
        continue;
      }
    }

    const taskData = googleEventToTask(event, responsavelId);

    const { error: insertError } = await supabase
      .from("company_activities")
      .insert({ ...(tenantId ? { tenant_id: tenantId } : {}), ...taskData });

    if (insertError) {
      console.error(`[${member.name}] Insert error:`, insertError, "Event:", event.summary);
    } else {
      created++;
    }
  }

  // Save sync token for incremental sync next time
  if (nextSyncToken) {
    await supabase
      .from("team_members")
      .update({ google_calendar_sync_token: nextSyncToken })
      .eq("id", teamMemberId);
  }

  return { created, updated, deleted, skipped, total: events.length };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Credenciais OAuth resolvidas por TENANT do team_member alvo
    // (override do tenant → config global → env). Nada hardcoded.
    const cfgForTenant = async (tenantId: string | null): Promise<GoogleOAuthCfg> => ({
      clientId: await requireIntegrationKey(supabase, "GOOGLE_CLIENT_ID", tenantId),
      clientSecret: await requireIntegrationKey(supabase, "GOOGLE_CLIENT_SECRET", tenantId),
    });

    const body = await req.json().catch(() => ({}));
    const { team_member_id, full_sync = false, sync_all = false } = body;

    // Multi-tenant: caller com JWT de usuário → tenant do JWT (só vê/sincroniza
    // membros do próprio tenant); caller service_role (cron, setup-calendar-watch,
    // google-calendar-webhook) → tenant do team_member alvo (linha).
    const principal = await authenticateRequest(req);
    const callerTenantId: string | null = principal.isServiceRole ? null : requireTenantFromRequest(req);

    // =========================================================
    // BATCH MODE: sync all connected team members
    // =========================================================
    if (sync_all) {
      let membersQ = supabase
        .from("team_members")
        .select("id, name, email, google_access_token, google_refresh_token, google_token_expires_at, google_calendar_sync_token, tenant_id")
        .eq("is_active", true)
        .eq("google_calendar_connected", true)
        .not("google_refresh_token", "is", null);
      if (callerTenantId) membersQ = membersQ.eq("tenant_id", callerTenantId);
      const { data: members, error: membersError } = await membersQ;

      if (membersError || !members || members.length === 0) {
        console.log("No connected team members found for sync");
        return new Response(
          JSON.stringify({ success: true, message: "No connected team members", results: [] }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      console.log(`Batch sync starting for ${members.length} team members`);

      const results: Array<{ member: string; stats: any }> = [];

      for (const m of members) {
        const memberTenant = rowTenantOrSkip(m, `sync-google-calendar:team_members:${m.id}`);
        if (!memberTenant) continue;
        try {
          const stats = await syncMember(supabase, m.id, m, full_sync, await cfgForTenant(memberTenant));
          results.push({ member: m.name, stats });
          console.log(`[${m.name}] Sync done: ${stats.created} created, ${stats.updated} updated, ${stats.deleted} deleted, ${stats.skipped} skipped`);
        } catch (err: any) {
          console.error(`[${m.name}] Sync failed:`, err);
          results.push({ member: m.name, stats: { error: err instanceof Error ? err.message : "Unknown error" } });
        }
      }

      return new Response(
        JSON.stringify({ success: true, results }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // =========================================================
    // SINGLE MODE: sync specific team member
    // =========================================================
    if (!team_member_id) {
      return new Response(
        JSON.stringify({ success: false, error: "team_member_id or sync_all is required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    let tenantId: string;
    if (callerTenantId) {
      tenantId = callerTenantId;
    } else {
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
    }
    await assertEntityTenant(supabase, "team_members", team_member_id, tenantId);

    const { data: member, error: memberError } = await supabase
      .from("team_members")
      .select("name, email, google_access_token, google_refresh_token, google_token_expires_at, google_calendar_sync_token, tenant_id")
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
        JSON.stringify({ success: false, error: "Google Calendar not connected. Please connect in Settings." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const stats = await syncMember(supabase, team_member_id, member, full_sync, await cfgForTenant(tenantId));

    return new Response(
      JSON.stringify({
        success: true,
        message: `Sync completed: ${stats.created} created, ${stats.updated} updated, ${stats.deleted} deleted`,
        stats,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    const t = tenantErrorResponse(error, corsHeaders);
    if (t) return t;
    if (error instanceof Error && (error.message === "unauthorized" || error.message === "auth_not_configured")) {
      return authErrorResponse(error);
    }
    const message = error instanceof Error ? error.message : String(error);
    console.error("Sync error:", error);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});

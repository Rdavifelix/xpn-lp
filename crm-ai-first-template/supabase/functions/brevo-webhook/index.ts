import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { timingSafeEqual } from "../_shared/webhook-security.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const expectedSecret = Deno.env.get('BREVO_WEBHOOK_SECRET') || '';
    const url = new URL(req.url);
    const suppliedSecret = req.headers.get('x-webhook-secret') || url.searchParams.get('token') || '';
    if (!expectedSecret || !timingSafeEqual(suppliedSecret, expectedSecret)) {
      return new Response(JSON.stringify({ error: 'invalid webhook secret' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const body = await req.json();
    const events = Array.isArray(body) ? body : [body];

    let processed = 0;

    for (const event of events) {
      try {
        await processEvent(supabase, event);
        processed++;
      } catch (err: any) {
        console.error('[brevo-webhook] Error processing event:', err, event);
      }
    }

    return new Response(JSON.stringify({ success: true, processed }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : 'Unknown error';
    console.error('[brevo-webhook] Error:', msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

async function processEvent(supabase: any, event: any) {
  const eventType = event.event; // delivered, soft_bounce, hard_bounce, complaint, unsubscribed, opened, click
  const messageId = event['message-id'] || event.messageId;
  const email = event.email;

  if (!messageId && !email) {
    console.log('[brevo-webhook] No message ID or email, skipping');
    return;
  }

  // Try to find in campaign leads
  let campaignLead = null;
  if (messageId) {
    const { data } = await supabase
      .from('email_campaign_leads')
      .select('id, campaign_id, lead_id, tenant_id, status')
      .eq('brevo_message_id', messageId)
      .maybeSingle();
    campaignLead = data;
  }

  // Try to find in sequence logs
  let sequenceLog = null;
  if (messageId) {
    const { data } = await supabase
      .from('email_sequence_logs')
      .select('id, enrollment_id, sequence_id, lead_id, tenant_id')
      .eq('brevo_message_id', messageId)
      .maybeSingle();
    sequenceLog = data;
  }

  const now = new Date().toISOString();

  switch (eventType) {
    case 'delivered': {
      if (campaignLead) {
        await supabase.from('email_campaign_leads').update({
          status: 'delivered', delivered_at: now, updated_at: now,
        }).eq('id', campaignLead.id);

        try {
          await supabase.rpc('increment_email_campaign_counter', {
            p_campaign_id: campaignLead.campaign_id,
            p_field: 'delivered_count',
          });
        } catch {}
      }
      if (sequenceLog) {
        await supabase.from('email_sequence_logs').update({
          status: 'delivered', delivered_at: now, updated_at: now,
        }).eq('id', sequenceLog.id);
      }
      break;
    }

    case 'soft_bounce':
    case 'hard_bounce': {
      if (campaignLead) {
        await supabase.from('email_campaign_leads').update({
          status: 'bounced', bounced_at: now, error_message: event.reason || eventType, updated_at: now,
        }).eq('id', campaignLead.id);

        try {
          await supabase.rpc('increment_email_campaign_counter', {
            p_campaign_id: campaignLead.campaign_id,
            p_field: 'bounced_count',
          });
        } catch {}
      }
      if (sequenceLog) {
        await supabase.from('email_sequence_logs').update({
          status: 'bounced', bounced_at: now, error_message: event.reason || eventType, updated_at: now,
        }).eq('id', sequenceLog.id);
      }
      break;
    }

    case 'complaint':
    case 'spam': {
      if (campaignLead) {
        await supabase.from('email_campaign_leads').update({
          status: 'complained', complained_at: now, updated_at: now,
        }).eq('id', campaignLead.id);

        try {
          await supabase.rpc('increment_email_campaign_counter', {
            p_campaign_id: campaignLead.campaign_id,
            p_field: 'complained_count',
          });
        } catch {}
      }

      // Auto-unsubscribe on complaint
      if (email) {
        const tenantId = campaignLead?.tenant_id || sequenceLog?.tenant_id;
        if (tenantId) {
          await supabase.from('email_unsubscribes').upsert({
            tenant_id: tenantId,
            email,
            source: 'complaint',
            reason: 'Marcou como spam',
          }, { onConflict: 'tenant_id,email' });

          await supabase.from('leads').update({
            email_opted_out: true,
            updated_at: now,
          }).eq('email', email).eq('tenant_id', tenantId);
        }
      }
      break;
    }

    case 'unsubscribed': {
      if (campaignLead) {
        await supabase.from('email_campaign_leads').update({
          status: 'unsubscribed', unsubscribed_at: now, updated_at: now,
        }).eq('id', campaignLead.id);

        try {
          await supabase.rpc('increment_email_campaign_counter', {
            p_campaign_id: campaignLead.campaign_id,
            p_field: 'unsubscribed_count',
          });
        } catch {}
      }

      if (email) {
        const tenantId = campaignLead?.tenant_id || sequenceLog?.tenant_id;
        if (tenantId) {
          await supabase.from('email_unsubscribes').upsert({
            tenant_id: tenantId,
            email,
            source: 'brevo_webhook',
          }, { onConflict: 'tenant_id,email' });

          await supabase.from('leads').update({
            email_opted_out: true,
            updated_at: now,
          }).eq('email', email).eq('tenant_id', tenantId);
        }
      }
      break;
    }

    // Note: opened and click events are handled by email-track (our pixel/redirect)
    // But Brevo also sends these — we can use as backup
    case 'opened': {
      if (campaignLead && !campaignLead.opened_at) {
        await supabase.from('email_campaign_leads').update({
          status: 'opened', opened_at: now, updated_at: now,
        }).eq('id', campaignLead.id).is('opened_at', null);
      }
      break;
    }

    case 'click': {
      if (campaignLead && !campaignLead.clicked_at) {
        await supabase.from('email_campaign_leads').update({
          status: 'clicked', clicked_at: now, updated_at: now,
        }).eq('id', campaignLead.id).is('clicked_at', null);
      }
      break;
    }
  }
}

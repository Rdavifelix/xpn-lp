import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { timingSafeEqual } from "../_shared/webhook-security.ts";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * google-ads-webhook — receptor de dados do Google Apps Script
 *
 * Payload esperado:
 *   {
 *     tenantId:       'uuid',     // OBRIGATÓRIO — qual tenant é dono dos dados
 *                                 // (também aceito como ?tenant=<uuid> na query string)
 *     // Autenticação: x-webhook-secret (ou ?token=) deve bater com o
 *     // GOOGLE_ADS_WEBHOOK_SECRET configurado em tenant_config_overrides DESSE
 *     // tenant. Não há segredo global — tenant sem segredo próprio é recusado.
 *     accountId:      'xxx-xxx-xxxx',
 *     organizationId: 'uuid',
 *     dailyData:      [...],
 *     campaignData:   [...]
 *   }
 *
 * Trava multi-tenant: se accountId já existe cadastrado em outro tenant,
 * recusa o request com 409 (evita um script de tenant A sobrescrever dados do tenant B).
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const body = await req.json();
    const { accountId, organizationId, dailyData, campaignData } = body;
    const url = new URL(req.url);
    const tenantId: string = String(body.tenantId || body.tenant || url.searchParams.get('tenant') || '').trim();

    console.log(`📊 Tenant: ${tenantId?.slice(0,8)} | Account: ${accountId} | Org: ${organizationId?.slice(0,8)}`);
    console.log(`📅 Daily: ${dailyData?.length || 0} | Campaign: ${campaignData?.length || 0}`);

    // Validações
    if (!tenantId || !UUID_RE.test(tenantId)) {
      return new Response(
        JSON.stringify({ success: false, error: 'tenantId (uuid) é obrigatório no payload ou como ?tenant=' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    if (!accountId || !organizationId) {
      return new Response(
        JSON.stringify({ success: false, error: 'accountId e organizationId são obrigatórios' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Segredo SOMENTE do override do tenant (sem fallback global/env).
    const { data: secretRow } = await supabase
      .from('tenant_config_overrides')
      .select('value')
      .eq('tenant_id', tenantId)
      .eq('key', 'GOOGLE_ADS_WEBHOOK_SECRET')
      .maybeSingle();
    const expectedSecret = secretRow?.value ? String(secretRow.value).trim() : '';
    if (!expectedSecret) {
      console.warn(`[google-ads-webhook] Tenant ${tenantId.slice(0,8)} sem GOOGLE_ADS_WEBHOOK_SECRET próprio — recusado`);
      return new Response(
        JSON.stringify({ success: false, error: 'Webhook não configurado para este tenant' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    const suppliedSecret = req.headers.get('x-webhook-secret') || url.searchParams.get('token') || '';
    if (!timingSafeEqual(suppliedSecret, expectedSecret)) {
      return new Response(
        JSON.stringify({ success: false, error: 'Assinatura do webhook inválida' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Trava multi-tenant: se accountId já existir em outro tenant, recusa
    const { data: existing } = await supabase
      .from('google_ads_accounts')
      .select('tenant_id, account_id')
      .eq('account_id', accountId)
      .maybeSingle();

    if (existing && existing.tenant_id !== tenantId) {
      console.error(`❌ Conflito tenant: account ${accountId} já cadastrado em outro tenant`);
      return new Response(
        JSON.stringify({
          success: false,
          error: `account_id ${accountId} já está cadastrado em outro tenant. Cadastro multi-tenant não permitido.`,
        }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 1) Upsert conta — com tenant_id explícito
    const { error: accountError } = await supabase
      .from('google_ads_accounts')
      .upsert({
        tenant_id: tenantId,
        account_id: accountId,
        organization_id: organizationId,
        is_active: true,
        last_synced_date: new Date().toISOString().split('T')[0],
      }, {
        onConflict: 'account_id',
      });

    if (accountError) {
      console.error('❌ Erro ao salvar conta:', accountError);
      throw accountError;
    }

    let dailyInserted = 0;
    let campaignInserted = 0;

    // 2) Upsert daily_data
    if (dailyData && dailyData.length > 0) {
      const { error: dailyError } = await supabase
        .from('google_ads_daily_data')
        .upsert(
          dailyData.map((d: any) => ({
            tenant_id: tenantId,
            account_id: accountId,
            organization_id: organizationId,
            date: d.date,
            impressions: d.impressions || 0,
            clicks: d.clicks || 0,
            cost_micros: d.cost_micros || 0,
            conversions: d.conversions || 0,
            ctr: d.ctr || 0,
            average_cpc_micros: d.average_cpc_micros || 0,
          })),
          { onConflict: 'account_id,organization_id,date' }
        );

      if (dailyError) {
        console.error('❌ Erro ao salvar daily_data:', dailyError);
        throw dailyError;
      }
      dailyInserted = dailyData.length;
    }

    // 3) Upsert campaign_data
    if (campaignData && campaignData.length > 0) {
      const { error: campaignError } = await supabase
        .from('google_ads_campaign_data')
        .upsert(
          campaignData.map((c: any) => ({
            tenant_id: tenantId,
            account_id: accountId,
            organization_id: organizationId,
            campaign_id: c.campaign_id,
            campaign_name: c.campaign_name,
            campaign_status: c.campaign_status,
            date: c.date,
            impressions: c.impressions || 0,
            clicks: c.clicks || 0,
            cost_micros: c.cost_micros || 0,
            conversions: c.conversions || 0,
            ctr: c.ctr || 0,
            average_cpc_micros: c.average_cpc_micros || 0,
          })),
          { onConflict: 'account_id,organization_id,campaign_id,date' }
        );

      if (campaignError) {
        console.error('❌ Erro ao salvar campaign_data:', campaignError);
        throw campaignError;
      }
      campaignInserted = campaignData.length;
    }

    console.log(`✅ Salvos: ${dailyInserted} daily, ${campaignInserted} campaigns (tenant ${tenantId.slice(0,8)})`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Dados do Google Ads salvos com sucesso',
        recordsProcessed: {
          daily: dailyInserted,
          campaigns: campaignInserted,
        },
        tenantId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ Erro fatal:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useTenantId } from '@/hooks/useTenantId';
import { useCallback, useEffect, useState } from 'react';
import type {
  Campaign,
  CampaignTemplate,
  CampaignLead,
  CampaignStatus,
  CampaignLeadStatus,
  AudienceFilters,
  CampaignMetrics,
} from '@/types/campaign.types';

// ────────────────────────────────────────────
// TEMPLATES
// ────────────────────────────────────────────

export const useCampaignTemplates = () => {
  

  return useQuery({
    queryKey: ['campaign-templates'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('campaign_templates' as any)
        .select('*')
        .eq('is_active', true)
        .order('name');
      if (error) throw error;
      return (data || []) as CampaignTemplate[];
    },
  });
};

export const useCreateCampaignTemplate = () => {
  const queryClient = useQueryClient();
  const tenantId = useTenantId();
  const { teamMember } = useAuth();
  return useMutation({
    mutationFn: async (template: { name: string; content: string; variables?: string[]; category?: string }) => {
      const { data, error } = await supabase
        .from('campaign_templates' as any)
        .insert({
          ...template,
          tenant_id: tenantId,
          created_by: teamMember?.id,
        })
        .select()
        .single();
      if (error) throw error;
      return data as CampaignTemplate;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaign-templates'] });
    },
  });
};

export const useUpdateCampaignTemplate = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string; name?: string; content?: string; variables?: string[]; is_active?: boolean }) => {
      const { data, error } = await supabase
        .from('campaign_templates' as any)
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;
      return data as CampaignTemplate;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaign-templates'] });
    },
  });
};

export const useDeleteCampaignTemplate = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from('campaign_templates' as any)
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaign-templates'] });
    },
  });
};

// ────────────────────────────────────────────
// CAMPAIGNS
// ────────────────────────────────────────────

export const useCampaigns = (statusFilter?: CampaignStatus) => {
  

  return useQuery({
    queryKey: ['campaigns', statusFilter],
    
    queryFn: async () => {
      let query = supabase
        .from('campaigns' as any)
        .select('*, created_by_member:team_members!campaigns_created_by_fkey(id, name)')
        .order('created_at', { ascending: false });

      if (statusFilter) {
        query = query.eq('status', statusFilter);
      }

      const { data, error } = await query;
      if (error) throw error;
      return (data || []) as Campaign[];
    },
  });
};

export const useCampaign = (id: string | undefined) => {
  

  return useQuery({
    queryKey: ['campaign', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('campaigns' as any)
        .select('*, created_by_member:team_members!campaigns_created_by_fkey(id, name), template:campaign_templates(id, name, content, variables)')
        .eq('id', id)
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    enabled: !!id,
    refetchInterval: (query) => {
      const campaign = query.state.data as Campaign | undefined;
      // Realtime polling while sending
      if (campaign?.status === 'sending') return 5000;
      return false;
    },
  });
};

export const useCreateCampaign = () => {
  const queryClient = useQueryClient();
  const tenantId = useTenantId();
  const { teamMember } = useAuth();
  return useMutation({
    mutationFn: async (campaign: Partial<Campaign>) => {
      const { data, error } = await supabase
        .from('campaigns' as any)
        .insert({
          ...campaign,
          tenant_id: tenantId,
          created_by: teamMember?.id,
        })
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
    },
  });
};

export const useUpdateCampaign = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Campaign> & { id: string }) => {
      const { data, error } = await supabase
        .from('campaigns' as any)
        .update({ ...updates, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['campaign', data.id] });
    },
  });
};

export const useStartCampaign = () => {
  const tenantId = useTenantId();
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: async (campaignId: string) => {
      // 1. Populate leads
      const { data: rawCount, error: popError } = await supabase
        .rpc('populate_campaign_leads', {
          p_campaign_id: campaignId,
          // tenant do usuário autenticado (useTenantId) — nunca de props/URL; o banco revalida
          p_tenant_id: tenantId,
        });
      if (popError) throw popError;
      let count = rawCount;

      // 1b. Remove excluded leads
      const { data: camp } = await supabase
        .from('campaigns' as any)
        .select('audience_filters')
        .eq('id', campaignId)
        .single();
      const excludeIds = (camp?.audience_filters as AudienceFilters)?.exclude_lead_ids;
      if (excludeIds?.length) {
        await supabase
          .from('campaign_leads' as any)
          .delete()
          .eq('campaign_id', campaignId)
          .in('lead_id', excludeIds);
        // Adjust count
        count = (count || 0) - excludeIds.length;
        if (count < 0) count = 0;
      }

      // 2. Update status to sending
      const { data, error } = await supabase
        .from('campaigns' as any)
        .update({
          status: 'sending',
          started_at: new Date().toISOString(),
          total_leads: count,
          updated_at: new Date().toISOString(),
        })
        .eq('id', campaignId)
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['campaign', data.id] });
    },
  });
};

export const useScheduleCampaign = () => {
  const queryClient = useQueryClient();
  const tenantId = useTenantId();
  return useMutation({
    mutationFn: async ({ campaignId, scheduledAt }: { campaignId: string; scheduledAt: string }) => {
      // Populate leads first
      const { error: popError } = await supabase
        .rpc('populate_campaign_leads', {
          p_campaign_id: campaignId,
          // tenant do usuário autenticado (useTenantId) — nunca de props/URL; o banco revalida
          p_tenant_id: tenantId,
        });
      if (popError) throw popError;

      // Remove excluded leads
      const { data: scheduleCamp } = await supabase
        .from('campaigns' as any)
        .select('audience_filters')
        .eq('id', campaignId)
        .single();
      const schedExcludeIds = (scheduleCamp?.audience_filters as AudienceFilters)?.exclude_lead_ids;
      if (schedExcludeIds?.length) {
        await supabase
          .from('campaign_leads' as any)
          .delete()
          .eq('campaign_id', campaignId)
          .in('lead_id', schedExcludeIds);
      }

      const { data, error } = await supabase
        .from('campaigns' as any)
        .update({
          status: 'scheduled',
          scheduled_at: scheduledAt,
          updated_at: new Date().toISOString(),
        })
        .eq('id', campaignId)
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['campaign', data.id] });
    },
  });
};

export const usePauseCampaign = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ campaignId, reason }: { campaignId: string; reason?: string }) => {
      const { data, error } = await supabase
        .from('campaigns' as any)
        .update({
          status: 'paused',
          paused_at: new Date().toISOString(),
          pause_reason: reason || 'Pausada manualmente',
          updated_at: new Date().toISOString(),
        })
        .eq('id', campaignId)
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['campaign', data.id] });
    },
  });
};

export const useResumeCampaign = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (campaignId: string) => {
      const { data, error } = await supabase
        .from('campaigns' as any)
        .update({
          status: 'sending',
          paused_at: null,
          pause_reason: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', campaignId)
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['campaign', data.id] });
    },
  });
};

export const useCancelCampaign = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (campaignId: string) => {
      // Cancel pending leads
      await supabase
        .from('campaign_leads' as any)
        .update({ status: 'skipped', updated_at: new Date().toISOString() })
        .eq('campaign_id', campaignId)
        .eq('status', 'pending');

      const { data, error } = await supabase
        .from('campaigns' as any)
        .update({
          status: 'cancelled',
          completed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', campaignId)
        .select()
        .single();
      if (error) throw error;
      return data as Campaign;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      queryClient.invalidateQueries({ queryKey: ['campaign', data.id] });
    },
  });
};

// ────────────────────────────────────────────
// AUDIENCE
// ────────────────────────────────────────────

export const useAudienceCount = (filters: AudienceFilters) => {
  const tenantId = useTenantId();
  const [debouncedFilters, setDebouncedFilters] = useState(filters);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedFilters(filters), 500);
    return () => clearTimeout(timer);
  }, [filters]);

  return useQuery({
    queryKey: ['audience-count', debouncedFilters],
    queryFn: async () => {
      // Modo "leads específicos": a contagem é o tamanho do array selecionado.
      // A RPC get_campaign_audience_count NÃO conhece lead_ids — sem este short-circuit
      // ela ignora e retorna a contagem total do tenant.
      const explicitIds = (debouncedFilters as any).lead_ids as string[] | undefined;
      if (explicitIds && explicitIds.length > 0) {
        return explicitIds.length;
      }

      const { data, error } = await supabase
        .rpc('get_campaign_audience_count', {
          // tenant do usuário autenticado (useTenantId) — nunca de props/URL; o banco revalida
          p_tenant_id: tenantId,
          p_filters: debouncedFilters,
        });
      if (error) throw error;
      return (data as number) || 0;
    },
    enabled: !!tenantId,
  });
};

// Fetch sample leads for template preview
export const useAudienceSample = (filters: AudienceFilters, limit = 3) => {
  const tenantId = useTenantId();
  return useQuery({
    queryKey: ['audience-sample', filters, limit],
    queryFn: async () => {
      // Modo "leads específicos": amostra são os próprios IDs selecionados (até o limit).
      const explicitIds = (filters as any).lead_ids as string[] | undefined;
      if (explicitIds && explicitIds.length > 0) {
        const { data, error } = await supabase
          .from('leads' as any)
          .select('id, name, phone, email, city_name, state, company_name, sales_rep_id')
          .in('id', explicitIds.slice(0, limit));
        if (error) throw error;
        return data || [];
      }

      let query = supabase
        .from('leads' as any)
        .select('id, name, phone, email, city_name, state, company_name, sales_rep_id')
        .not('phone', 'is', null)
        .limit(limit);

      if (filters.pipeline_stage_ids?.length) {
        query = query.in('pipeline_stage_id', filters.pipeline_stage_ids);
      }
      if (filters.states?.length) {
        query = query.in('state', filters.states);
      }
      if (filters.cities?.length) {
        query = query.in('city_name', filters.cities);
      }

      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    },
    enabled: !!tenantId,
  });
};

// ────────────────────────────────────────────
// CAMPAIGN LEADS (drill-down)
// ────────────────────────────────────────────

export const useCampaignLeads = (campaignId: string | undefined, statusFilter?: CampaignLeadStatus, page = 0, pageSize = 50, campaignStatus?: string) => {
  const tenantId = useTenantId();
  

  return useQuery({
    queryKey: ['campaign-leads', campaignId, statusFilter, page],
    queryFn: async () => {
      let query = supabase
        .from('campaign_leads' as any)
        .select('*, lead:leads(id, name, phone, email, city_name, state, sales_rep_id), assigned_member:team_members!campaign_leads_assigned_to_fkey(id, name)', { count: 'exact' })
        .eq('campaign_id', campaignId)
        .order('created_at', { ascending: true })
        .range(page * pageSize, (page + 1) * pageSize - 1);

      if (statusFilter) {
        query = query.eq('status', statusFilter);
      }

      const { data, error, count } = await query;
      if (error) throw error;
      return { leads: (data || []) as CampaignLead[], total: count || 0 };
    },
    enabled: !!campaignId && !!tenantId,
    refetchInterval: campaignStatus === 'sending' ? 5000 : false,
  });
};

// ────────────────────────────────────────────
// CAMPAIGN METRICS (global)
// ────────────────────────────────────────────

export const useCampaignMetrics = () => {
  

  return useQuery({
    queryKey: ['campaign-metrics'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('campaigns' as any)
        .select('status, total_leads, sent_count, responded_count, blocked_count');
      if (error) throw error;

      const campaigns = data || [];
      const metrics: CampaignMetrics = {
        total_campaigns: campaigns.length,
        active_campaigns: campaigns.filter((c: any) => c.status === 'sending').length,
        total_leads_contacted: campaigns.reduce((sum: number, c: any) => sum + (c.sent_count || 0), 0),
        total_responded: campaigns.reduce((sum: number, c: any) => sum + (c.responded_count || 0), 0),
        avg_response_rate: 0,
        total_blocked: campaigns.reduce((sum: number, c: any) => sum + (c.blocked_count || 0), 0),
      };

      if (metrics.total_leads_contacted > 0) {
        metrics.avg_response_rate = Math.round((metrics.total_responded / metrics.total_leads_contacted) * 100);
      }

      return metrics;
    },
  });
};

// ────────────────────────────────────────────
// FILTER OPTIONS (for AudienceBuilder)
// ────────────────────────────────────────────

export const usePipelineStages = () => {
  

  return useQuery({
    queryKey: ['pipeline-stages-for-campaigns'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('sales_pipeline_stages' as any)
        .select('id, name, pipeline_id, position, sales_pipelines(id, name)')
        .order('position');
      if (error) throw error;
      return data || [];
    },
  });
};

export const useDistinctCities = () => {
  

  return useQuery({
    queryKey: ['distinct-cities'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('leads' as any)
        .select('city_name')
        .not('city_name', 'is', null)
        .not('city_name', 'eq', '')
        .limit(500);
      if (error) throw error;
      const unique = [...new Set((data || []).map((d: any) => d.city_name as string))].sort();
      return unique;
    },
  });
};

export const useDistinctStates = () => {
  

  return useQuery({
    queryKey: ['distinct-states'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('leads' as any)
        .select('state')
        .not('state', 'is', null)
        .not('state', 'eq', '')
        .limit(500);
      if (error) throw error;
      const unique = [...new Set((data || []).map((d: any) => d.state as string))].sort();
      return unique;
    },
  });
};

export const useDistinctUtmSources = () => {
  

  return useQuery({
    queryKey: ['distinct-utm-sources'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('leads' as any)
        .select('utm_source')
        .not('utm_source', 'is', null)
        .not('utm_source', 'eq', '')
        .limit(500);
      if (error) throw error;
      const unique = [...new Set((data || []).map((d: any) => d.utm_source as string))].sort();
      return unique;
    },
  });
};

export const useDistinctUtmCampaigns = () => {
  

  return useQuery({
    queryKey: ['distinct-utm-campaigns'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('leads' as any)
        .select('utm_campaign')
        .not('utm_campaign', 'is', null)
        .not('utm_campaign', 'eq', '')
        .limit(500);
      if (error) throw error;
      const unique = [...new Set((data || []).map((d: any) => d.utm_campaign as string))].sort();
      return unique;
    },
  });
};

/**
 * Lista instâncias WhatsApp disponíveis pra campanha.
 *
 * @param provider 'uazapi' | 'cloud_api' | undefined (default: todas)
 *
 * UAZAPI: só com purpose='campaign' (instâncias dedicadas, não a do inbox).
 * Cloud API: todas as instâncias provider='meta_cloud' do tenant (uma conta = todas as campanhas).
 */
export const useWhatsAppInstances = (provider?: 'uazapi' | 'cloud_api') => {
  const tenantId = useTenantId();
  

  return useQuery({
    queryKey: ['whatsapp-instances-campaigns', tenantId, provider || 'all'],
    
    queryFn: async () => {
      if (!tenantId) return [];
      let q = supabase
        .from('whatsapp_instances' as any)
        .select('id, name, status, provider, phone_number_id')
        
        .order('name');

      if (provider === 'uazapi') {
        q = q.eq('provider', 'uazapi').eq('purpose', 'campaign');
      } else if (provider === 'cloud_api') {
        q = q.eq('provider', 'meta_cloud');
      }

      const { data, error } = await q;
      if (error) throw error;
      return data || [];
    },
  });
};

// ────────────────────────────────────────────
// CAMPAIGN INSTANCE STATS (health/alertas)
// ────────────────────────────────────────────

export const useCampaignInstanceStats = (instanceIds: string[]) => {
  const tenantId = useTenantId();
  
  const today = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD

  return useQuery({
    queryKey: ['campaign-instance-stats', tenantId, instanceIds, today],
    enabled: !!tenantId && instanceIds.length > 0,
    refetchInterval: 30_000, // 30s para manter atualizado durante envio
    queryFn: async () => {
      // Buscar stats de hoje + info da instância
      const { data: stats, error: statsErr } = await supabase
        .from('campaign_instance_stats' as any)
        .select('*')
        .in('instance_id', instanceIds)
        .eq('date', today);
      if (statsErr) throw statsErr;

      const { data: instances, error: instErr } = await supabase
        .from('whatsapp_instances' as any)
        .select('id, name, status, phone_number')
        .in('id', instanceIds);
      if (instErr) throw instErr;

      const now = new Date();
      return (instances || []).map((inst: any) => {
        const stat = (stats || []).find((s: any) => s.instance_id === inst.id);
        const inCooldown = stat?.cooldown_until && new Date(stat.cooldown_until) > now;
        const isDisconnected = inst.status === 'disconnected' || inst.status === 'close';
        const hasBlocks = (stat?.blocks_detected_day || 0) > 0;

        let health: 'ok' | 'cooldown' | 'disconnected' | 'blocked' = 'ok';
        if (inCooldown) health = 'cooldown';
        if (isDisconnected) health = 'disconnected';
        if (hasBlocks && inCooldown) health = 'blocked';

        return {
          instanceId: inst.id,
          name: inst.name,
          phone: inst.phone_number,
          status: inst.status,
          health,
          messagesSentDay: stat?.messages_sent_day || 0,
          messagesSentHour: stat?.messages_sent_hour || 0,
          blocksDetectedDay: stat?.blocks_detected_day || 0,
          cooldownUntil: stat?.cooldown_until,
          lastBlockAt: stat?.last_block_at,
          warmupDay: stat?.warmup_day,
        };
      });
    },
  });
};

// ────────────────────────────────────────────
// CAMPAIGN INSTANCES CRUD
// ────────────────────────────────────────────

export const useCampaignInstances = () => {
  

  return useQuery({
    queryKey: ['campaign-instances'],
    
    queryFn: async () => {
      const { data, error } = await supabase
        .from('whatsapp_instances' as any)
        .select('id, name, status, phone_number, provider, purpose, created_at')
        .eq('purpose', 'campaign')
        .order('name');
      if (error) throw error;
      return data || [];
    },
  });
};

export const useCreateCampaignInstance = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (input: { name: string }) => {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.access_token) throw new Error('Not authenticated');

      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

      const res = await fetch(
        `${supabaseUrl}/functions/v1/setup-campaign-instance`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${session.access_token}`,
            apikey: supabaseKey,
          },
          body: JSON.stringify({ name: input.name }),
        }
      );

      const result = await res.json();
      if (!res.ok || !result.success) {
        throw new Error(result.error || 'Erro ao criar instancia de campanha');
      }
      return result.instance;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaign-instances'] });
      queryClient.invalidateQueries({ queryKey: ['whatsapp-instances-campaigns'] });
    },
  });
};

export const useUpdateCampaignInstance = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: string; name?: string }) => {
      const data: any = { ...updates, updated_at: new Date().toISOString() };
      const { error } = await supabase
        .from('whatsapp_instances' as any)
        .update(data)
        .eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaign-instances'] });
      queryClient.invalidateQueries({ queryKey: ['whatsapp-instances-campaigns'] });
    },
  });
};

export const useDeleteCampaignInstance = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from('whatsapp_instances' as any)
        .delete()
        .eq('id', id)
        .eq('purpose', 'campaign');
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaign-instances'] });
      queryClient.invalidateQueries({ queryKey: ['whatsapp-instances-campaigns'] });
    },
  });
};

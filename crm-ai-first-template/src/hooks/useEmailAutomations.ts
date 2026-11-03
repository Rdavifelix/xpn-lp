import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { toast } from 'sonner';

export type TriggerEvent = 'lead_created' | 'deal_won' | 'organization_created' | 'custom';

export interface EmailAutomation {
  id: string;
  name: string;
  description: string | null;
  trigger_event: TriggerEvent;
  trigger_filter: any;
  flow_json: any;
  is_active: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export const useEmailAutomations = () => {
  return useQuery({
    queryKey: ['email-automations'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('email_automations')
        .select('*')
        .order('updated_at', { ascending: false });
      if (error) throw error;
      return (data || []) as EmailAutomation[];
    },
  });
};

export const useEmailAutomation = (id: string | undefined) => {
  return useQuery({
    queryKey: ['email-automation', id],
    queryFn: async () => {
      const { data, error } = await supabase.from('email_automations').select('*').eq('id', id!).single();
      if (error) throw error;
      return data as EmailAutomation;
    },
    enabled: !!id,
  });
};

export const useSaveEmailAutomation = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: Partial<EmailAutomation> & { id?: string }) => {
      const { id, ...payload } = input;
      if (id) {
        const { data, error } = await supabase.from('email_automations').update(payload).eq('id', id).select().single();
        if (error) throw error;
        return data as EmailAutomation;
      }
      const { data, error } = await supabase.from('email_automations').insert(payload).select().single();
      if (error) throw error;
      return data as EmailAutomation;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['email-automations'] });
      toast.success('Automação salva');
    },
  });
};

export const useDeleteEmailAutomation = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('email_automations').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['email-automations'] });
      toast.success('Automação removida');
    },
  });
};

export const useToggleEmailAutomation = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, isActive }: { id: string; isActive: boolean }) => {
      const { data, error } = await supabase
        .from('email_automations')
        .update({ is_active: isActive })
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['email-automations'] });
    },
  });
};

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { useTenantId } from "@/hooks/useTenantId";

export interface WhatsAppTemplate {
  id: string;
  tenant_id: string;
  meta_template_id: string | null;
  meta_waba_id: string | null;
  name: string;
  category: string;
  language: string;
  status: string;
  rejection_reason: string | null;
  components: any[];
  example_values: Record<string, any>;
  variables_count: number;
  internal_tags: string[];
  total_sent: number;
  total_delivered: number;
  total_read: number;
  total_failed: number;
  last_used_at: string | null;
  last_synced_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface WhatsAppTemplateTag {
  id: string;
  tenant_id: string;
  slug: string;
  label: string;
  color: string;
  icon: string | null;
  position: number;
}

// ===================== TEMPLATES =====================

export const useWhatsAppTemplates = () => {
  const tenantId = useTenantId();
  
  return useQuery({
    queryKey: ["whatsapp-templates"],
    queryFn: async (): Promise<WhatsAppTemplate[]> => {
      if (!tenantId) return [];
      const { data, error } = await supabase
        .from("whatsapp_cloud_templates")
        .select("*")
        .eq("tenant_id", tenantId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data || []) as WhatsAppTemplate[];
    },
    
  });
};

export const useSyncWhatsAppTemplates = () => {
  const tenantId = useTenantId();
  
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async () => {
      if (!tenantId) throw new Error("Tenant não autenticado");
      const { data, error } = await supabase.functions.invoke("sync-whatsapp-templates", {
        body: { tenant_id: tenantId },
      });
      if (error) throw error;
      if (data?.error) throw new Error(data.error);
      return data as { success: boolean; total: number; upserted: number };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["whatsapp-templates"] });
    },
  });
};

export const useUpdateTemplateTags = () => {
  const tenantId = useTenantId();
  
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, internal_tags }: { id: string; internal_tags: string[] }) => {
      if (!tenantId) throw new Error("Tenant não autenticado");
      const { error } = await supabase
        .from("whatsapp_cloud_templates")
        .update({ internal_tags })
        .eq("id", id)
        .eq("tenant_id", tenantId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["whatsapp-templates"] });
    },
  });
};

export const useDeleteTemplate = () => {
  const tenantId = useTenantId();
  
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      if (!tenantId) throw new Error("Tenant não autenticado");
      const { error } = await supabase
        .from("whatsapp_cloud_templates")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["whatsapp-templates"] });
    },
  });
};

// ===================== TAGS =====================

export const useWhatsAppTemplateTags = () => {
  const tenantId = useTenantId();
  
  return useQuery({
    queryKey: ["whatsapp-template-tags"],
    queryFn: async (): Promise<WhatsAppTemplateTag[]> => {
      if (!tenantId) return [];
      const { data, error } = await supabase
        .from("whatsapp_template_tags")
        .select("*")
        .eq("tenant_id", tenantId)
        .order("position", { ascending: true });
      if (error) throw error;
      return (data || []) as WhatsAppTemplateTag[];
    },
    
  });
};

export const useUpsertTemplateTag = () => {
  const tenantId = useTenantId();
  
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (tag: Partial<WhatsAppTemplateTag> & { slug: string; label: string }) => {
      if (!tenantId) throw new Error("Tenant não autenticado");
      const payload = { ...tag, tenant_id: tenantId };
      if (tag.id) {
        const { error } = await supabase
          .from("whatsapp_template_tags")
          .update(payload)
          .eq("id", tag.id)
          .eq("tenant_id", tenantId);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from("whatsapp_template_tags")
          .insert(payload);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["whatsapp-template-tags"] });
    },
  });
};

export const useDeleteTemplateTag = () => {
  const tenantId = useTenantId();
  
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      if (!tenantId) throw new Error("Tenant não autenticado");
      const { error } = await supabase
        .from("whatsapp_template_tags")
        .delete()
        .eq("id", id)
        .eq("tenant_id", tenantId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["whatsapp-template-tags"] });
    },
  });
};

// ────────────────────────────────────────────
// CRIAR TEMPLATE META (envia pra aprovação)
// ────────────────────────────────────────────

export type CloudTemplateCategory = 'MARKETING' | 'UTILITY' | 'AUTHENTICATION';

export interface CloudTemplateButton {
  type: 'QUICK_REPLY' | 'URL' | 'PHONE_NUMBER';
  text: string;
  url?: string;
  phone_number?: string;
}

export interface CloudTemplateComponent {
  type: 'HEADER' | 'BODY' | 'FOOTER' | 'BUTTONS';
  format?: 'TEXT' | 'IMAGE' | 'VIDEO' | 'DOCUMENT' | 'LOCATION';
  text?: string;
  example?: {
    header_text?: string[];
    body_text?: string[][];
    header_handle?: string[];
  };
  buttons?: CloudTemplateButton[];
}

export interface CreateCloudTemplateInput {
  name: string;
  category: CloudTemplateCategory;
  language: string;
  components: CloudTemplateComponent[];
}

export const useCreateCloudTemplate = () => {
  const tenantId = useTenantId();
  
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (input: CreateCloudTemplateInput) => {
      if (!tenantId) throw new Error("Tenant não autenticado");
      const { data, error } = await supabase.functions.invoke('create-whatsapp-template', {
        body: { ...input, tenant_id: tenantId },
      });
      if (error) throw error;
      if ((data as any)?.error) throw new Error((data as any).error);
      return data as { success: boolean; template?: any; status?: string; message?: string };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['whatsapp-templates'] });
    },
  });
};

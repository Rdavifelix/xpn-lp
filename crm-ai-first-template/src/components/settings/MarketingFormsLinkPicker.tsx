import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Popover, PopoverTrigger, PopoverContent } from '@/components/ui/popover';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { FileText, Plus, Search, X } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';

interface WebForm {
  id: string;
  name: string;
  is_active: boolean;
  submissions_count: number | null;
  distribution_config_id: string | null;
}

interface Props {
  configId: string;
  configName?: string;
}

/**
 * Multi-select de formulários WEB do Form Builder próprio do CRM.
 * marketing_forms tem FK distribution_config_id (1 form -> 1 distribuição).
 * Marcar = move o form pra esta distribuição (rouba de outra se já vinculado).
 */
export default function MarketingFormsLinkPicker({ configId, configName }: Props) {
  const { tenantId } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');

  // Todos os forms web do tenant
  const { data: allForms = [], isLoading } = useQuery({
    queryKey: ['marketing-forms-link-picker', tenantId],
    enabled: !!tenantId,
    queryFn: async () => {
      const { data } = await supabase
        .from('marketing_forms')
        .select('id, name, is_active, submissions_count, distribution_config_id')
        .order('name');
      return (data || []) as WebForm[];
    },
  });

  // Forms vinculados a esta distribuição
  const linkedForms = allForms.filter(f => f.distribution_config_id === configId);

  // Lookup de distribuições pra mostrar conflito
  const { data: configsMap = {} } = useQuery({
    queryKey: ['distribution-configs-name-map', tenantId],
    enabled: !!tenantId && open,
    queryFn: async () => {
      const { data } = await supabase
        .from('lead_distribution_config')
        .select('id, name')
        .eq('tenant_id', tenantId!);
      const map: Record<string, string> = {};
      (data || []).forEach((c: any) => { map[c.id] = c.name; });
      return map;
    },
  });

  const toggleForm = useMutation({
    mutationFn: async (args: { formId: string; checked: boolean }) => {
      const { formId, checked } = args;
      const { error } = await supabase
        .from('marketing_forms')
        .update({ distribution_config_id: checked ? configId : null })
        .eq('id', formId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['marketing-forms-link-picker'] });
      queryClient.invalidateQueries({ queryKey: ['forms-for-config'] });
    },
    onError: (e: any) => {
      toast({ title: 'Erro ao vincular', description: e?.message || 'Tente novamente', variant: 'destructive' });
    },
  });

  const filteredForms = allForms.filter(f => {
    if (!search.trim()) return true;
    return f.name.toLowerCase().includes(search.toLowerCase());
  });

  return (
    <div className="space-y-2">
      {/* Forms vinculados */}
      {linkedForms.map(form => (
        <div
          key={form.id}
          className={cn(
            'flex items-center gap-3 rounded-lg border border-border/40 bg-gradient-to-r from-blue-500/[0.04] via-background to-background px-3 py-2.5 transition-colors hover:border-border/80',
            !form.is_active && 'opacity-50',
          )}
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-blue-500/10 text-blue-600">
            <FileText className="h-3.5 w-3.5" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-xs text-muted-foreground">Formulário web</div>
            <div className="text-sm text-foreground/90 truncate mt-0.5">{form.name}</div>
          </div>
          {!form.is_active && (
            <Badge variant="outline" className="text-[9px] font-mono uppercase tracking-wider">pausado</Badge>
          )}
          {typeof form.submissions_count === 'number' && form.submissions_count > 0 && (
            <Badge variant="secondary" className="text-[10px]">{form.submissions_count}</Badge>
          )}
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7 text-muted-foreground hover:text-destructive"
            onClick={() => toggleForm.mutate({ formId: form.id, checked: false })}
            disabled={toggleForm.isPending}
            title="Desvincular"
          >
            <X className="h-3.5 w-3.5" />
          </Button>
        </div>
      ))}

      {/* Popover de seleção */}
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            className="w-full h-9 justify-start text-xs gap-2 border-dashed text-muted-foreground hover:text-foreground"
          >
            <Plus className="h-3.5 w-3.5" />
            {linkedForms.length === 0
              ? 'Vincular formulário web...'
              : `Vincular mais formulário web (${linkedForms.length} vinculado${linkedForms.length > 1 ? 's' : ''})`}
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-[420px] p-0" align="start">
          <div className="p-3 border-b">
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
              <Input
                placeholder="Buscar formulário..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="h-8 pl-8 text-sm"
              />
            </div>
          </div>
          <div className="max-h-[360px] overflow-y-auto p-2 space-y-0.5">
            {isLoading && <div className="text-xs text-muted-foreground py-4 text-center">Carregando...</div>}
            {!isLoading && allForms.length === 0 && (
              <div className="text-xs text-muted-foreground py-4 text-center px-3">
                Nenhum formulário web criado ainda. Crie em <strong>Marketing → Formulários</strong>.
              </div>
            )}
            {!isLoading && filteredForms.map(form => {
              const isLinked = form.distribution_config_id === configId;
              const otherConfigName = form.distribution_config_id && form.distribution_config_id !== configId
                ? configsMap[form.distribution_config_id]
                : null;
              return (
                <label
                  key={form.id}
                  className={cn(
                    'flex items-center gap-2.5 rounded-md px-2 py-2 cursor-pointer transition-colors',
                    isLinked ? 'bg-blue-500/[0.06]' : 'hover:bg-muted/50',
                    !form.is_active && 'opacity-60',
                  )}
                >
                  <Checkbox
                    checked={isLinked}
                    onCheckedChange={(v) => toggleForm.mutate({ formId: form.id, checked: !!v })}
                    disabled={toggleForm.isPending}
                  />
                  <FileText className="h-3.5 w-3.5 text-blue-500/70 shrink-0" />
                  <div className="flex-1 min-w-0">
                    <div className="text-sm truncate">{form.name}</div>
                    {otherConfigName && !isLinked && (
                      <div className="text-[10px] text-amber-700">
                        Já vinculado a "{otherConfigName}" — será movido pra cá
                      </div>
                    )}
                    {!form.is_active && (
                      <div className="text-[10px] text-muted-foreground">Pausado</div>
                    )}
                  </div>
                  {typeof form.submissions_count === 'number' && form.submissions_count > 0 && (
                    <Badge variant="outline" className="text-[10px] shrink-0">{form.submissions_count}</Badge>
                  )}
                </label>
              );
            })}
          </div>
        </PopoverContent>
      </Popover>
    </div>
  );
}

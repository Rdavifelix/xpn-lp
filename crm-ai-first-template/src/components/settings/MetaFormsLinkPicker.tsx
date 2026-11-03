import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Popover, PopoverTrigger, PopoverContent } from '@/components/ui/popover';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { FileText, Globe, Plus, Search, X } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';

interface MetaForm {
  form_id: string;
  form_name: string;
  page_id: string;
  page_name: string | null;
  leads_count: number | null;
  is_enabled: boolean;
}

interface OtherBinding {
  config_id: string;
  config_name: string;
}

interface Props {
  configId: string;
  linkedFormIds: string[];
  onUpdated?: () => void;
}

/**
 * Multi-select de formulários Meta Lead Ads vinculados a uma distribuição.
 * Mostra forms agrupados por página (Conta > Página > Form). Mostra alerta se
 * um form já está vinculado a outra distribuição (vai roubar dele ao marcar).
 */
export default function MetaFormsLinkPicker({ configId, linkedFormIds, onUpdated }: Props) {
  const { tenantId } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');

  // Carrega todos os forms ativos do tenant + suas páginas.
  // Precisa estar sempre habilitada (não só com popover aberto), porque os cards
  // dos forms JÁ vinculados acima do botão dependem desta lista pra renderizar.
  const { data: forms = [], isLoading } = useQuery({
    queryKey: ['meta-forms-for-link', tenantId],
    enabled: !!tenantId,
    queryFn: async () => {
      const { data: rows } = await supabase
        .from('meta_lead_ads_forms')
        .select('form_id, form_name, page_id, leads_count, is_enabled')
        .eq('tenant_id', tenantId!)
        .eq('is_enabled', true)
        .order('form_name');
      const pageIds = Array.from(new Set((rows || []).map(r => r.page_id))).filter(Boolean);
      const { data: pages } = await supabase
        .from('meta_lead_ads_pages')
        .select('page_id, page_name')
        .eq('tenant_id', tenantId!)
        .in('page_id', pageIds);
      const pageMap = new Map((pages || []).map(p => [p.page_id, p.page_name]));
      return (rows || []).map(r => ({
        ...r,
        page_name: pageMap.get(r.page_id) || null,
      })) as MetaForm[];
    },
  });

  // Carrega outras distribuições que já têm vínculo com forms (pra mostrar conflito)
  const { data: otherBindings = {} } = useQuery({
    queryKey: ['meta-forms-other-bindings', tenantId, configId],
    enabled: !!tenantId && open,
    queryFn: async () => {
      const { data } = await supabase
        .from('lead_distribution_config')
        .select('id, name, match_meta_form_ids')
        .eq('tenant_id', tenantId!)
        .neq('id', configId)
        .not('match_meta_form_ids', 'is', null);
      const map: Record<string, OtherBinding> = {};
      (data || []).forEach((d: any) => {
        (d.match_meta_form_ids || []).forEach((fid: string) => {
          map[fid] = { config_id: d.id, config_name: d.name };
        });
      });
      return map;
    },
  });

  const linkedSet = new Set(linkedFormIds);

  const toggleForm = useMutation({
    mutationFn: async (args: { formId: string; checked: boolean }) => {
      const { formId, checked } = args;

      // 1) Se checando e form está em outra distribuição, REMOVE de lá primeiro
      const otherBinding = otherBindings[formId];
      if (checked && otherBinding) {
        const { data: other } = await supabase
          .from('lead_distribution_config')
          .select('match_meta_form_ids')
          .eq('id', otherBinding.config_id)
          .single();
        const newList = ((other?.match_meta_form_ids as string[]) || []).filter(f => f !== formId);
        await supabase
          .from('lead_distribution_config')
          .update({ match_meta_form_ids: newList.length ? newList : null })
          .eq('id', otherBinding.config_id);
      }

      // 2) Atualiza ESTA distribuição
      const newList = checked
        ? Array.from(new Set([...linkedFormIds, formId]))
        : linkedFormIds.filter(f => f !== formId);
      const { error } = await supabase
        .from('lead_distribution_config')
        .update({ match_meta_form_ids: newList.length ? newList : null })
        .eq('id', configId);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['distribution-configs'] });
      queryClient.invalidateQueries({ queryKey: ['meta-forms-other-bindings'] });
      onUpdated?.();
    },
    onError: (e: any) => {
      toast({ title: 'Erro ao vincular', description: e?.message || 'Tente novamente', variant: 'destructive' });
    },
  });

  // Forms vinculados (mostra no card)
  const linkedForms = forms.filter(f => linkedSet.has(f.form_id));

  // Filtros e agrupamento pra popover
  const filteredForms = forms.filter(f => {
    if (!search.trim()) return true;
    const s = search.toLowerCase();
    return (
      f.form_name.toLowerCase().includes(s) ||
      (f.page_name || '').toLowerCase().includes(s)
    );
  });
  const byPage = new Map<string, MetaForm[]>();
  filteredForms.forEach(f => {
    const k = f.page_name || f.page_id;
    if (!byPage.has(k)) byPage.set(k, []);
    byPage.get(k)!.push(f);
  });

  return (
    <div className="space-y-2">
      {/* Lista de forms já vinculados */}
      {linkedForms.map(form => (
        <div
          key={form.form_id}
          className="flex items-center gap-3 rounded-lg border border-border/40 bg-gradient-to-r from-indigo-500/[0.04] via-background to-background px-3 py-2.5 transition-colors hover:border-border/80"
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-indigo-500/10 text-indigo-600">
            <Globe className="h-3.5 w-3.5" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-xs text-muted-foreground">
              Meta · {form.page_name || form.page_id}
            </div>
            <div className="text-sm text-foreground/90 truncate mt-0.5">{form.form_name}</div>
          </div>
          {typeof form.leads_count === 'number' && form.leads_count > 0 && (
            <Badge variant="secondary" className="text-[10px]">{form.leads_count}</Badge>
          )}
          <Button
            variant="ghost"
            size="icon"
            className="h-7 w-7 text-muted-foreground hover:text-destructive"
            onClick={() => toggleForm.mutate({ formId: form.form_id, checked: false })}
            disabled={toggleForm.isPending}
            title="Desvincular"
          >
            <X className="h-3.5 w-3.5" />
          </Button>
        </div>
      ))}

      {/* Botão pra abrir popover de seleção */}
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            className="w-full h-9 justify-start text-xs gap-2 border-dashed text-muted-foreground hover:text-foreground"
          >
            <Plus className="h-3.5 w-3.5" />
            {linkedForms.length === 0
              ? 'Vincular formulário Meta...'
              : `Vincular mais formulário Meta (${linkedForms.length} vinculado${linkedForms.length > 1 ? 's' : ''})`}
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-[420px] p-0" align="start">
          <div className="p-3 border-b">
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
              <Input
                placeholder="Buscar form ou página..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="h-8 pl-8 text-sm"
              />
            </div>
          </div>
          <div className="max-h-[360px] overflow-y-auto p-2 space-y-3">
            {isLoading && (
              <div className="text-xs text-muted-foreground py-4 text-center">Carregando formulários da Meta...</div>
            )}
            {!isLoading && forms.length === 0 && (
              <div className="text-xs text-muted-foreground py-4 text-center px-3">
                Nenhum formulário ativo da Meta. Ative em <strong>Configurações → Meta Ads → Formulários</strong>.
              </div>
            )}
            {!isLoading && Array.from(byPage.entries()).map(([pageName, formsOfPage]) => (
              <div key={pageName}>
                <div className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground px-1.5 mb-1.5">
                  {pageName}
                </div>
                <div className="space-y-0.5">
                  {formsOfPage.map(form => {
                    const isLinked = linkedSet.has(form.form_id);
                    const other = otherBindings[form.form_id];
                    return (
                      <label
                        key={form.form_id}
                        className={cn(
                          'flex items-center gap-2.5 rounded-md px-2 py-2 cursor-pointer transition-colors',
                          isLinked ? 'bg-indigo-500/[0.06]' : 'hover:bg-muted/50',
                        )}
                      >
                        <Checkbox
                          checked={isLinked}
                          onCheckedChange={(v) => toggleForm.mutate({ formId: form.form_id, checked: !!v })}
                          disabled={toggleForm.isPending}
                        />
                        <FileText className="h-3.5 w-3.5 text-indigo-500/70 shrink-0" />
                        <div className="flex-1 min-w-0">
                          <div className="text-sm truncate">{form.form_name}</div>
                          {other && !isLinked && (
                            <div className="text-[10px] text-amber-700">
                              Já vinculado a "{other.config_name}" — será movido pra cá
                            </div>
                          )}
                        </div>
                        {typeof form.leads_count === 'number' && form.leads_count > 0 && (
                          <Badge variant="outline" className="text-[10px] shrink-0">{form.leads_count}</Badge>
                        )}
                      </label>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </PopoverContent>
      </Popover>
    </div>
  );
}

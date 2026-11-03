import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  Tooltip, TooltipContent, TooltipProvider, TooltipTrigger,
} from "@/components/ui/tooltip";
import { useToast } from "@/hooks/use-toast";
import {
  Send, Loader2, AlertCircle, Sparkles, Clock, User, Building2, Megaphone,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  useAvailableWhatsAppInstances, useSendWhatsAppText, useSendWhatsAppTemplate,
} from "@/hooks/useSendWhatsAppMessage";
import { useMessageWindow, formatWindowBadge } from "@/hooks/useMessageWindow";
import { useWhatsAppTemplates } from "@/hooks/useWhatsAppTemplates";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";

interface Props {
  leadId: string;
  phone: string;
  /** Pipeline do lead, pra filtrar instâncias por funil. */
  leadPipelineId?: string | null;
  className?: string;
  onSent?: () => void;
}

/**
 * Compositor unificado WhatsApp (lógica limpa portada do CHEIRINCRM):
 *  - Badge de janela (24h CSW / 72h CTWA / fechada) via useMessageWindow
 *  - Seletor de instância SEMPRE por provider ('meta_cloud'/'uazapi') — ZERO UUID hardcoded
 *  - Dentro da janela: textarea livre (roteia uazapi/cloud automaticamente)
 *  - Fora: dropdown de templates APPROVED (whatsapp_cloud_templates) via Cloud
 */
export function WhatsAppComposer({ leadId, phone, leadPipelineId, className, onSent }: Props) {
  const { toast } = useToast();
  const { data: instances = [] } = useAvailableWhatsAppInstances(leadPipelineId ?? null);
  const { data: window } = useMessageWindow(leadId);
  const { data: templates = [] } = useWhatsAppTemplates();
  const sendText = useSendWhatsAppText();
  const sendTemplate = useSendWhatsAppTemplate();

  const [selectedInstanceId, setSelectedInstanceId] = useState<string>("");
  const [text, setText] = useState("");
  const [selectedTemplateId, setSelectedTemplateId] = useState<string>("");
  const [templateParams, setTemplateParams] = useState<string[]>([]);
  const [headerMediaFile, setHeaderMediaFile] = useState<File | null>(null);
  const [headerMediaPreview, setHeaderMediaPreview] = useState<string | null>(null);
  const [uploadingMedia, setUploadingMedia] = useState(false);

  const personalInstance = instances.find(i => i.provider === "uazapi");
  const cloudInstance = instances.find(i => i.provider === "meta_cloud");

  // Instância da ÚLTIMA mensagem dessa conversa (continuidade — responder pelo mesmo número)
  const { data: lastInstanceId } = useQuery({
    queryKey: ["last-instance-for-lead", leadId],
    queryFn: async () => {
      if (!leadId) return null;
      const { data } = await supabase
        .from("whatsapp_messages")
        .select("instance_id")
        .eq("lead_id", leadId)
        .not("instance_id", "is", null)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      return (data as any)?.instance_id || null;
    },
    enabled: !!leadId,
  });

  // Default: 1) instância da última conversa (continuidade)
  //          2) Cloud (oficial, sem risco de ban)
  //          3) UAZAPI pessoal
  useEffect(() => {
    if (selectedInstanceId) return;
    const lastAvail = lastInstanceId && instances.find(i => i.id === lastInstanceId);
    const fallback = lastAvail?.id || cloudInstance?.id || personalInstance?.id || "";
    if (fallback) setSelectedInstanceId(fallback);
  }, [lastInstanceId, instances, personalInstance, cloudInstance, selectedInstanceId]);

  const selectedInstance = instances.find(i => i.id === selectedInstanceId);
  const isWindowClosed = window?.type === "template_only";

  // Quando janela fecha, força Cloud (UAZAPI fora da janela = risco de banir)
  useEffect(() => {
    if (isWindowClosed && cloudInstance && selectedInstance?.provider === "uazapi") {
      setSelectedInstanceId(cloudInstance.id);
    }
  }, [isWindowClosed, cloudInstance, selectedInstance]);

  const approvedTemplates = useMemo(
    () => templates.filter(t => t.status === "APPROVED"),
    [templates],
  );

  const selectedTemplate = approvedTemplates.find(t => t.id === selectedTemplateId);

  // Detecta se template tem header de mídia (IMAGE/VIDEO/DOCUMENT)
  const headerMediaType = useMemo(() => {
    if (!selectedTemplate?.components) return null;
    const header = (selectedTemplate.components as any[]).find((c: any) => c.type === "HEADER");
    const fmt = header?.format?.toUpperCase();
    if (fmt === "IMAGE") return "image" as const;
    if (fmt === "VIDEO") return "video" as const;
    if (fmt === "DOCUMENT") return "document" as const;
    return null;
  }, [selectedTemplate]);

  // Reset params + media quando muda template
  useEffect(() => {
    if (headerMediaPreview) URL.revokeObjectURL(headerMediaPreview);
    setHeaderMediaFile(null);
    setHeaderMediaPreview(null);
    if (!selectedTemplate) { setTemplateParams([]); return; }
    setTemplateParams(Array(selectedTemplate.variables_count || 0).fill(""));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedTemplateId, selectedTemplate]);

  const handleMediaSelect = (f: File | null) => {
    if (headerMediaPreview) URL.revokeObjectURL(headerMediaPreview);
    if (!f) { setHeaderMediaFile(null); setHeaderMediaPreview(null); return; }
    if (f.size > 5 * 1024 * 1024) {
      toast({ title: "Arquivo grande demais", description: "Máx 5 MB", variant: "destructive" });
      return;
    }
    setHeaderMediaFile(f);
    setHeaderMediaPreview(URL.createObjectURL(f));
  };

  const uploadMediaToStorage = async (file: File): Promise<string> => {
    setUploadingMedia(true);
    try {
      const ext = file.name.split(".").pop()?.toLowerCase() || "bin";
      const path = `tpl-send/${leadId || "no-lead"}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
      // Bucket whatsapp-media (existente). Não há bucket dedicado a template media.
      const { error: upErr } = await supabase.storage
        .from("whatsapp-media")
        .upload(path, file, { contentType: file.type, upsert: false });
      if (upErr) throw upErr;
      const { data: pub } = supabase.storage.from("whatsapp-media").getPublicUrl(path);
      return pub.publicUrl;
    } finally {
      setUploadingMedia(false);
    }
  };

  const badge = formatWindowBadge(window);
  const badgeClass: Record<string, string> = {
    open: "bg-emerald-500/15 text-emerald-700 border-emerald-500/30",
    ctwa: "bg-blue-500/15 text-blue-700 border-blue-500/30",
    closed: "bg-amber-500/15 text-amber-800 border-amber-500/30",
    loading: "bg-muted text-muted-foreground",
  };

  const handleSendText = async () => {
    if (!text.trim() || !selectedInstanceId) return;
    try {
      await sendText.mutateAsync({ instanceId: selectedInstanceId, phone, text, leadId });
      setText("");
      toast({ title: "Mensagem enviada" });
      onSent?.();
    } catch (e: any) {
      toast({ title: "Erro ao enviar", description: e.message, variant: "destructive" });
    }
  };

  const handleSendTemplate = async () => {
    if (!selectedTemplate || !selectedInstanceId) return;
    if (headerMediaType && !headerMediaFile) {
      toast({ title: "Anexe a imagem do cabeçalho", description: "Esse template tem cabeçalho de mídia.", variant: "destructive" });
      return;
    }
    try {
      let headerMediaUrl: string | null = null;
      if (headerMediaType && headerMediaFile) {
        headerMediaUrl = await uploadMediaToStorage(headerMediaFile);
      }
      await sendTemplate.mutateAsync({
        instanceId: selectedInstanceId,
        phone,
        templateName: selectedTemplate.name,
        templateLanguage: selectedTemplate.language,
        templateParams,
        leadId,
        headerMediaUrl,
        headerMediaType: headerMediaType || undefined,
      });
      setSelectedTemplateId("");
      setHeaderMediaFile(null);
      if (headerMediaPreview) URL.revokeObjectURL(headerMediaPreview);
      setHeaderMediaPreview(null);
      toast({ title: "Template enviado" });
      onSent?.();
    } catch (e: any) {
      toast({ title: "Erro ao enviar", description: e.message, variant: "destructive" });
    }
  };

  if (instances.length === 0) {
    return (
      <div className={cn("p-3 border rounded-lg bg-muted/30 text-sm text-muted-foreground flex items-center gap-2", className)}>
        <AlertCircle className="h-4 w-4" />
        Nenhuma instância WhatsApp vinculada ao seu usuário.
      </div>
    );
  }

  return (
    <div className={cn("space-y-2", className)}>
      {/* Badge de janela + seletor de instância */}
      <div className="flex items-center gap-2 flex-wrap">
        <Badge variant="outline" className={cn("gap-1.5 font-normal", badgeClass[badge.tone])}>
          <Clock className="h-3 w-3" />
          {badge.label}
        </Badge>

        {window?.type === "free" && window.reason === "ctwa_72h" && window.ctwa && (
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Badge variant="outline" className="bg-blue-500/10 text-blue-700 border-blue-500/30 gap-1 font-normal cursor-help">
                  <Megaphone className="h-3 w-3" />
                  via Anúncio
                </Badge>
              </TooltipTrigger>
              <TooltipContent>
                <p className="text-xs max-w-xs">
                  Lead chegou via Click-to-WhatsApp Ad: <strong>{window.ctwa.headline || window.ctwa.source_id}</strong>
                </p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        )}

        {/* Seletor de instância — detecção por provider, nunca por UUID */}
        {instances.length > 1 && (
          <div className="ml-auto">
            <Select value={selectedInstanceId} onValueChange={setSelectedInstanceId}>
              <SelectTrigger className="h-7 text-xs w-auto min-w-[180px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {instances.map(inst => {
                  const isCloud = inst.provider === "meta_cloud";
                  const Icon = isCloud ? Building2 : User;
                  const disabledByWindow = isWindowClosed && !isCloud;
                  return (
                    <SelectItem key={inst.id} value={inst.id} disabled={disabledByWindow}>
                      <div className="flex items-center gap-2">
                        <Icon className="h-3.5 w-3.5" />
                        <span>{inst.name}</span>
                        {disabledByWindow && (
                          <span className="text-xs text-muted-foreground ml-1">(fora da janela)</span>
                        )}
                      </div>
                    </SelectItem>
                  );
                })}
              </SelectContent>
            </Select>
          </div>
        )}
        {instances.length === 1 && selectedInstance && (
          <span className="ml-auto text-xs text-muted-foreground flex items-center gap-1">
            {selectedInstance.provider === "meta_cloud" ? <Building2 className="h-3 w-3" /> : <User className="h-3 w-3" />}
            {selectedInstance.name}
          </span>
        )}
      </div>

      {/* Body: textarea livre OU dropdown de templates */}
      {!isWindowClosed ? (
        <div className="flex items-end gap-2">
          <Textarea
            value={text}
            onChange={e => setText(e.target.value)}
            placeholder="Digite a mensagem..."
            rows={2}
            className="resize-none"
            onKeyDown={e => {
              if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
                e.preventDefault();
                handleSendText();
              }
            }}
          />
          <Button
            onClick={handleSendText}
            disabled={!text.trim() || sendText.isPending}
            size="icon"
            className="shrink-0"
          >
            {sendText.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
          </Button>
        </div>
      ) : (
        <div className="space-y-2 p-3 border rounded-lg bg-muted/20">
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <Sparkles className="h-3.5 w-3.5" />
            Janela fechada — selecione um template aprovado pra reabrir conversa
          </div>

          {approvedTemplates.length === 0 ? (
            <p className="text-xs text-muted-foreground">
              Nenhum template aprovado disponível.
            </p>
          ) : (
            <>
              <Select value={selectedTemplateId} onValueChange={setSelectedTemplateId}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione um template..." />
                </SelectTrigger>
                <SelectContent>
                  {approvedTemplates.map(t => (
                    <SelectItem key={t.id} value={t.id}>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs">{t.name}</span>
                        <span className="text-xs text-muted-foreground">· {t.language} · {t.category}</span>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {selectedTemplate && (
                <>
                  <div className="text-xs whitespace-pre-line bg-background border rounded p-2 max-h-32 overflow-y-auto">
                    {((selectedTemplate.components as any[]) || []).find((c: any) => c.type === "BODY")?.text || ""}
                  </div>

                  {/* Header de mídia: vendedor anexa imagem antes de enviar */}
                  {headerMediaType && (
                    <div className="rounded border bg-amber-50/40 border-amber-200 p-2 space-y-1.5">
                      <label className="text-[11px] font-medium text-amber-800 block">
                        Anexar {headerMediaType === "image" ? "imagem" : headerMediaType === "video" ? "vídeo" : "documento"} do cabeçalho
                      </label>
                      <Input
                        type="file"
                        accept={
                          headerMediaType === "image" ? "image/jpeg,image/png" :
                          headerMediaType === "video" ? "video/mp4" :
                          "application/pdf"
                        }
                        onChange={(e) => handleMediaSelect(e.target.files?.[0] || null)}
                        className="h-8 text-xs file:mr-2 file:py-0.5 file:px-2 file:border-0 file:bg-amber-200/60 file:text-amber-900 file:rounded file:text-xs"
                      />
                      {headerMediaPreview && headerMediaType === "image" && (
                        <img src={headerMediaPreview} alt="" className="max-w-[140px] rounded border" />
                      )}
                      {headerMediaFile && headerMediaType !== "image" && (
                        <p className="text-[10px] text-muted-foreground truncate">{headerMediaFile.name}</p>
                      )}
                    </div>
                  )}

                  {(selectedTemplate.variables_count || 0) > 0 && (
                    <div className="space-y-1.5">
                      {Array.from({ length: selectedTemplate.variables_count }).map((_, i) => (
                        <Input
                          key={i}
                          placeholder={`Variável {{${i + 1}}}`}
                          value={templateParams[i] || ""}
                          onChange={e => {
                            const next = [...templateParams];
                            next[i] = e.target.value;
                            setTemplateParams(next);
                          }}
                          className="h-8 text-sm"
                        />
                      ))}
                    </div>
                  )}

                  <Button
                    onClick={handleSendTemplate}
                    disabled={
                      sendTemplate.isPending || uploadingMedia ||
                      (!!headerMediaType && !headerMediaFile) ||
                      templateParams.some((p, i) => !p && i < (selectedTemplate.variables_count || 0))
                    }
                    className="w-full"
                    size="sm"
                  >
                    {uploadingMedia ? (
                      <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Subindo arquivo...</>
                    ) : sendTemplate.isPending ? (
                      <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Enviando...</>
                    ) : (
                      <><Send className="h-4 w-4 mr-2" /> Enviar template via {cloudInstance?.name || "API Oficial"}</>
                    )}
                  </Button>
                </>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}

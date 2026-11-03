import { useMemo, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Eye, Heart, MessageCircle, Bookmark, Share2, ExternalLink, Sparkles, LayoutGrid, List } from "lucide-react";
import type { Format, Platform, SocialPost } from "@/hooks/useSocialPanel";
import { PLATFORMS } from "@/hooks/useSocialPanel";

import { PlatformIcon } from "./PlatformIcon";
import { FORMAT_LABEL, FORMAT_ORDER, PLATFORM_LABEL, audiencia, fmtData, fmtNum, fmtPct } from "./shared";

type Ordem = "views" | "reach" | "engagement" | "recentes";

const ORDENS: { valor: Ordem; rotulo: string }[] = [
  { valor: "views", rotulo: "Views" },
  { valor: "reach", rotulo: "Alcance" },
  { valor: "engagement", rotulo: "Engajamento" },
  { valor: "recentes", rotulo: "Recentes" },
];

interface Props {
  posts: SocialPost[] | undefined;
  isLoading: boolean;
  rede: Platform | null;
  onMudarRede: (p: Platform | null) => void;
}

/**
 * Lista de conteúdos com thumb, métricas e análise de DNA.
 *
 * A análise reusa a `analyze-post-dna` que já roda na tela do Instagram: ela lê os
 * slides do carrossel e os comentários reais pela Graph API. Isso depende da Graph
 * API da Meta, então vale só para o Instagram — nas outras redes o clique abre o
 * post na própria plataforma, em vez de abrir um modal que não teria o que mostrar.
 */
function temAnaliseDeDNA(p: SocialPost): boolean {
  return false;
}

/** Clique: DNA onde existe, senão abre o post na plataforma. */
function aoClicar(p: SocialPost, abrirDNA: (p: SocialPost) => void) {
  if (temAnaliseDeDNA(p)) abrirDNA(p);
  else if (p.permalink) window.open(p.permalink, "_blank", "noopener,noreferrer");
}
export function SocialContentList({ posts, isLoading, rede, onMudarRede }: Props) {
  const [formato, setFormato] = useState<Format | null>(null);
  const [ordem, setOrdem] = useState<Ordem>("views");
  const [visiveis, setVisiveis] = useState(12);
  const [modo, setModo] = useState<"grade" | "lista">("grade");
  const [selecionado, setSelecionado] = useState<SocialPost | null>(null);

  const todos = posts || [];

  // Só oferece chips de tipos que existem no recorte atual — chip que sempre
  // devolve lista vazia é ruído.
  const formatosDisponiveis = useMemo(() => {
    const presentes = new Set(todos.filter((p) => !rede || p.platform === rede).map((p) => p.format));
    return FORMAT_ORDER.filter((f) => presentes.has(f));
  }, [todos, rede]);

  const filtrados = useMemo(() => {
    let lista = todos;
    if (rede) lista = lista.filter((p) => p.platform === rede);
    if (formato) lista = lista.filter((p) => p.format === formato);
    const chave = (p: SocialPost) =>
      ordem === "views" ? Number(p.views || p.reach || 0)
      : ordem === "reach" ? audiencia(p.platform, Number(p.reach || 0), Number(p.views || 0))
      : ordem === "engagement" ? Number(p.engagement_rate || 0)
      : new Date(p.published_at || 0).getTime();
    return [...lista].sort((a, b) => chave(b) - chave(a));
  }, [todos, rede, formato, ordem]);

  const mostrando = filtrados.slice(0, visiveis);

  if (isLoading) {
    return (
      <Card>
        <CardHeader><CardTitle className="text-base">Conteúdos</CardTitle></CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-3">
            {Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-[280px]" />)}
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between gap-3 flex-wrap">
          <div>
            <CardTitle className="text-base">Conteúdos</CardTitle>
            <p className="text-xs text-muted-foreground mt-0.5">
              {filtrados.length} {filtrados.length === 1 ? "conteúdo" : "conteúdos"} no período · clique para abrir a publicação
            </p>
          </div>
          <div className="flex items-center gap-1">
            {ORDENS.map((o) => (
              <Button
                key={o.valor}
                size="sm"
                variant={ordem === o.valor ? "default" : "ghost"}
                className="h-7 text-xs"
                onClick={() => setOrdem(o.valor)}
              >
                {o.rotulo}
              </Button>
            ))}
            <div className="w-px h-5 bg-border mx-1" />
            <Button size="sm" variant="ghost" className="h-7 w-7 p-0" onClick={() => setModo(modo === "grade" ? "lista" : "grade")}>
              {modo === "grade" ? <List className="h-3.5 w-3.5" /> : <LayoutGrid className="h-3.5 w-3.5" />}
            </Button>
          </div>
        </div>

        {/* Rede */}
        <div className="flex flex-wrap gap-1.5 mt-3">
          <Button size="sm" variant={rede === null ? "default" : "outline"} className="h-7 text-xs" onClick={() => { onMudarRede(null); setFormato(null); }}>
            Todas
          </Button>
          {PLATFORMS.map((p) => {
            const ativa = rede === p;
            return (
              <Button
                key={p}
                size="sm"
                variant={ativa ? "default" : "outline"}
                className="h-7 text-xs gap-1.5"
                onClick={() => { onMudarRede(p); setFormato(null); }}
              >
                <PlatformIcon platform={p} className="h-3.5 w-3.5" emCor={!ativa} />
                {PLATFORM_LABEL[p]}
              </Button>
            );
          })}
        </div>

        {/* Tipo */}
        {formatosDisponiveis.length > 1 && (
          <div className="flex flex-wrap gap-1.5 mt-2">
            <Button size="sm" variant={formato === null ? "secondary" : "ghost"} className="h-6 text-[11px] px-2" onClick={() => setFormato(null)}>
              Todos os tipos
            </Button>
            {formatosDisponiveis.map((f) => (
              <Button key={f} size="sm" variant={formato === f ? "secondary" : "ghost"} className="h-6 text-[11px] px-2" onClick={() => setFormato(f)}>
                {FORMAT_LABEL[f]}
              </Button>
            ))}
          </div>
        )}
      </CardHeader>

      <CardContent>
        {mostrando.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-12">
            Nenhum conteúdo neste período. Sincronize suas redes ou escolha outras datas.
          </p>
        ) : modo === "grade" ? (
          <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-6 gap-3">
            {mostrando.map((p) => <CardDeConteudo key={p.id} post={p} onClick={() => aoClicar(p, setSelecionado)} />)}
          </div>
        ) : (
          <div className="divide-y">
            {mostrando.map((p, i) => <LinhaDeConteudo key={p.id} post={p} posicao={i + 1} onClick={() => aoClicar(p, setSelecionado)} />)}
          </div>
        )}

        {filtrados.length > mostrando.length && (
          <div className="flex justify-center mt-4">
            <Button variant="outline" size="sm" className="text-xs" onClick={() => setVisiveis((v) => v + 12)}>
              Carregar mais ({filtrados.length - mostrando.length} restantes)
            </Button>
          </div>
        )}
      </CardContent>


    </Card>
  );
}

/** O modal de DNA nasceu na tela do Instagram e espera o formato dela. */
function paraFormatoDoModal(p: SocialPost) {
  return {
    post_id: p.platform_post_id,
    caption: p.content,
    post_type: p.format === "carousel" ? "carousel" : p.format === "reel" ? "reels" : p.format,
    thumbnail_url: p.thumbnail_url,
    permalink: p.permalink,
    views: p.views, reach: p.reach,
    like_count: p.likes, comment_count: p.comments,
    save_count: p.saves, share_count: p.shares,
    engagement_rate: p.engagement_rate,
    taken_at: p.published_at,
  };
}

function Selo({ post }: { post: SocialPost }) {
  return (
    <Badge variant="secondary" className="text-[10px] gap-1 pl-1.5">
      <PlatformIcon platform={post.platform} className="h-3 w-3" />
      {FORMAT_LABEL[post.format]}
    </Badge>
  );
}

function CardDeConteudo({ post, onClick }: { post: SocialPost; onClick: () => void }) {
  return (
    <div
      onClick={onClick}
      className="border rounded-lg overflow-hidden bg-card hover:shadow-lg hover:border-primary/40 transition-all flex flex-col cursor-pointer"
    >
      <div className="relative aspect-square bg-muted">
        {post.thumbnail_url ? (
          <img src={post.thumbnail_url} alt="" loading="lazy" className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-xs text-muted-foreground">Sem imagem</div>
        )}
        <div className="absolute top-2 right-2"><Selo post={post} /></div>
        {temAnaliseDeDNA(post) && (
          <div className="absolute bottom-2 left-2 bg-background/85 backdrop-blur-sm rounded px-1.5 py-0.5 flex items-center gap-1">
            <Sparkles className="h-2.5 w-2.5 text-orange-500" />
            <span className="text-[9px] font-medium">DNA</span>
          </div>
        )}
      </div>

      <div className="p-2.5 flex-1 flex flex-col gap-2">
        <p className="text-[11px] text-muted-foreground line-clamp-3 leading-snug">
          {post.content || "Sem legenda"}
        </p>

        <div className="grid grid-cols-3 gap-1 mt-auto">
          {[
            { Icone: Eye, cor: "text-emerald-600", v: post.views || post.reach, r: "Views" },
            { Icone: Bookmark, cor: "text-blue-600", v: post.saves, r: "Saves" },
            { Icone: Share2, cor: "text-indigo-600", v: post.shares, r: "Shares" },
          ].map((m) => (
            <div key={m.r} className="flex flex-col items-center bg-muted/50 rounded p-1">
              <m.Icone className={`h-3 w-3 ${m.cor} mb-0.5`} />
              <span className="text-[10px] font-bold tabular-nums">{fmtNum(m.v)}</span>
              <span className="text-[8px] text-muted-foreground uppercase">{m.r}</span>
            </div>
          ))}
        </div>

        <div className="flex items-center gap-2 text-[10px] text-muted-foreground">
          <span className="flex items-center gap-0.5"><Heart className="h-3 w-3 text-rose-500" />{fmtNum(post.likes)}</span>
          <span className="flex items-center gap-0.5"><MessageCircle className="h-3 w-3 text-amber-500" />{fmtNum(post.comments)}</span>
          <span className="ml-auto tabular-nums">{fmtData(post.published_at)}</span>
        </div>
      </div>
    </div>
  );
}

function LinhaDeConteudo({ post, posicao, onClick }: { post: SocialPost; posicao: number; onClick: () => void }) {
  return (
    <div onClick={onClick} className="flex items-center gap-3 py-2.5 cursor-pointer hover:bg-muted/40 rounded-md px-2 -mx-2 transition-colors">
      <span className="text-xs font-bold text-muted-foreground tabular-nums w-6 shrink-0">
        {String(posicao).padStart(2, "0")}
      </span>
      <div className="h-11 w-11 rounded bg-muted overflow-hidden shrink-0">
        {post.thumbnail_url && <img src={post.thumbnail_url} alt="" loading="lazy" className="w-full h-full object-cover" />}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-xs font-medium truncate">{post.content || "Sem legenda"}</p>
        <div className="flex items-center gap-2 mt-0.5">
          <Selo post={post} />
          <span className="text-[10px] text-muted-foreground">{fmtData(post.published_at)}</span>
        </div>
      </div>
      <div className="hidden sm:flex items-center gap-4 shrink-0 tabular-nums">
        {[
          { v: fmtNum(post.views || post.reach), r: "views" },
          { v: fmtPct(post.engagement_rate), r: "engaj." },
          { v: fmtNum(post.comments), r: "com." },
        ].map((m) => (
          <div key={m.r} className="text-right">
            <p className="text-xs font-bold">{m.v}</p>
            <p className="text-[9px] text-muted-foreground">{m.r}</p>
          </div>
        ))}
        {post.permalink && (
          <a href={post.permalink} target="_blank" rel="noopener noreferrer" onClick={(e) => e.stopPropagation()} className="text-muted-foreground hover:text-foreground">
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        )}
      </div>
    </div>
  );
}

import { useQuery } from "@tanstack/react-query";
import {
  Instagram,
  Verified,
  Lock,
  Heart,
  MessageCircle,
  Play,
  ExternalLink,
  Sparkles,
  TrendingUp,
} from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";
import { formatDistanceToNow } from "date-fns";
import { ptBR } from "date-fns/locale";

interface IgProfile {
  id: string;
  username: string;
  full_name: string | null;
  biography: string | null;
  external_url: string | null;
  bio_links: Array<{ url: string; title?: string }> | null;
  category: string | null;
  is_business: boolean;
  is_verified: boolean;
  is_private: boolean;
  follower_count: number;
  following_count: number;
  media_count: number;
  stored_profile_picture_url: string | null;
  profile_picture_url_hd: string | null;
  last_scraped_at: string;
}

interface IgPost {
  id: string;
  code: string | null;
  media_type: number | null;
  thumbnail_url: string | null;
  stored_thumbnail_url: string | null;
  caption: string | null;
  like_count: number;
  comment_count: number;
  play_count: number;
  taken_at: string | null;
  permalink: string | null;
}

interface IgStory {
  id: string;
  story_id: string;
  media_type: number | null;
  thumbnail_url: string | null;
  taken_at: string | null;
  expires_at: string | null;
}

interface IgQualLog {
  ai_score: number;
  ai_reason: string | null;
  qualified: boolean;
  profile_data: any;
}

function fmtNum(n: number) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1).replace(/\.0$/, "") + "M";
  if (n >= 1_000) return (n / 1_000).toFixed(1).replace(/\.0$/, "") + "k";
  return n.toLocaleString("pt-BR");
}

export function InstagramProfileSection({ username, afterHeader }: { username: string; afterHeader?: React.ReactNode }) {
  const handle = username?.replace(/^@/, "").trim().toLowerCase();

  const { data: profile, isLoading: loadingProfile } = useQuery({
    queryKey: ["ig-profile", handle],
    queryFn: async () => {
      if (!handle) return null;
      const { data } = await supabase
        .from("instagram_profiles")
        .select("*")
        .eq("username", handle)
        .maybeSingle();
      return data as IgProfile | null;
    },
    enabled: !!handle,
  });

  const { data: posts = [] } = useQuery({
    queryKey: ["ig-posts", profile?.id],
    queryFn: async () => {
      if (!profile?.id) return [];
      const { data } = await supabase
        .from("instagram_feed_posts")
        .select("*")
        .eq("instagram_profile_id", profile.id)
        .order("taken_at", { ascending: false })
        .limit(12);
      return (data || []) as IgPost[];
    },
    enabled: !!profile?.id,
  });

  const { data: stories = [] } = useQuery({
    queryKey: ["ig-stories", profile?.id],
    queryFn: async () => {
      if (!profile?.id) return [];
      const { data } = await supabase
        .from("instagram_stories")
        .select("*")
        .eq("instagram_profile_id", profile.id)
        .order("taken_at", { ascending: false });
      return (data || []) as IgStory[];
    },
    enabled: !!profile?.id,
  });

  const { data: qual } = useQuery({
    queryKey: ["ig-qual", handle],
    queryFn: async () => {
      if (!handle) return null;
      const { data } = await supabase
        .from("social_selling_qualification_log")
        .select("ai_score, ai_reason, qualified, profile_data")
        .eq("instagram_username", handle)
        .maybeSingle();
      return data as IgQualLog | null;
    },
    enabled: !!handle,
  });

  if (loadingProfile) {
    return (
      <Card>
        <CardContent className="p-8 text-center text-sm text-muted-foreground">
          Carregando perfil do Instagram...
        </CardContent>
      </Card>
    );
  }

  if (!profile) {
    return null;
  }

  const avatarUrl = profile.stored_profile_picture_url || profile.profile_picture_url_hd || undefined;
  const lastSyncAt = profile.last_scraped_at
    ? formatDistanceToNow(new Date(profile.last_scraped_at), { addSuffix: true, locale: ptBR })
    : null;

  return (
    <div className="space-y-4">
      {/* Header com avatar + bio */}
      <Card className="overflow-hidden">
        <CardContent className="p-0">
          <div className="bg-gradient-to-br from-pink-500/10 via-purple-500/5 to-blue-500/10 p-5">
            <div className="flex gap-4">
              <Avatar className="h-20 w-20 ring-2 ring-pink-500/30 shrink-0">
                <AvatarImage src={avatarUrl} alt={profile.full_name || profile.username} />
                <AvatarFallback>
                  <Instagram className="h-8 w-8 text-pink-500" />
                </AvatarFallback>
              </Avatar>

              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="font-semibold text-base truncate">
                    {profile.full_name || profile.username}
                  </h3>
                  {profile.is_verified && (
                    <Verified className="h-4 w-4 text-blue-500 fill-blue-500" />
                  )}
                  {profile.is_private && (
                    <Lock className="h-3.5 w-3.5 text-amber-600" aria-label="Conta privada" />
                  )}
                  {profile.is_business && (
                    <Badge variant="secondary" className="text-[10px] h-5">
                      Business
                    </Badge>
                  )}
                </div>
                <a
                  href={`https://instagram.com/${profile.username}`}
                  target="_blank"
                  rel="noreferrer"
                  className="text-xs text-pink-600 hover:underline flex items-center gap-1"
                >
                  @{profile.username}
                  <ExternalLink className="h-3 w-3" />
                </a>
                {profile.category && (
                  <Badge variant="outline" className="text-[10px] mt-1.5 h-5">
                    {profile.category}
                  </Badge>
                )}
              </div>
            </div>

            {profile.biography && (
              <p className="text-sm mt-3 whitespace-pre-line text-foreground/90">{profile.biography}</p>
            )}

            {/* Stats */}
            <div className="flex gap-4 mt-4 text-xs">
              <div>
                <span className="font-bold text-base">{fmtNum(profile.follower_count)}</span>
                <span className="text-muted-foreground ml-1">seguidores</span>
              </div>
              <div>
                <span className="font-bold text-base">{fmtNum(profile.following_count)}</span>
                <span className="text-muted-foreground ml-1">seguindo</span>
              </div>
              <div>
                <span className="font-bold text-base">{fmtNum(profile.media_count)}</span>
                <span className="text-muted-foreground ml-1">posts</span>
              </div>
            </div>

            {/* Bio links */}
            {profile.bio_links && profile.bio_links.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-3">
                {profile.bio_links.slice(0, 4).map((l, i) => (
                  <a
                    key={i}
                    href={l.url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs px-2.5 py-1 bg-background border rounded-full hover:bg-muted flex items-center gap-1.5 max-w-[260px]"
                  >
                    <ExternalLink className="h-3 w-3 shrink-0" />
                    <span className="truncate">{l.url.replace(/^https?:\/\//, "").replace(/\/$/, "")}</span>
                  </a>
                ))}
              </div>
            )}

            {lastSyncAt && (
              <p className="text-[10px] text-muted-foreground mt-3">
                Atualizado {lastSyncAt}
              </p>
            )}
          </div>

          {/* Score IA */}
          {qual && (
            <div
              className={cn(
                "px-5 py-3 border-t flex items-start gap-3",
                qual.qualified ? "bg-emerald-500/5" : "bg-amber-500/5"
              )}
            >
              <div
                className={cn(
                  "h-10 w-10 rounded-full flex items-center justify-center shrink-0 font-bold text-sm",
                  qual.qualified
                    ? "bg-emerald-500 text-white"
                    : "bg-amber-500 text-white"
                )}
              >
                {qual.ai_score}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5 mb-0.5">
                  <Sparkles className="h-3.5 w-3.5" />
                  <p className="text-xs font-semibold">
                    {qual.qualified ? "Lead qualificado pela IA" : "Lead não atingiu score mínimo"}
                  </p>
                </div>
                {qual.ai_reason && (
                  <p className="text-xs text-muted-foreground leading-relaxed">{qual.ai_reason}</p>
                )}
                {qual.profile_data?.summary && (
                  <p className="text-xs text-muted-foreground mt-1.5 italic">
                    "{qual.profile_data.summary}"
                  </p>
                )}
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Slot pro card de cadência (Aquecimento + Histórico) — render logo após o header */}
      {afterHeader}

      {/* Stories ativos */}
      {stories.length > 0 && (
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2 mb-3">
              <div className="h-2 w-2 rounded-full bg-pink-500 animate-pulse" />
              <p className="text-xs font-semibold">Stories ativos</p>
              <Badge variant="secondary" className="text-[10px] h-5">
                {stories.length}
              </Badge>
            </div>
            <div className="flex gap-2 overflow-x-auto pb-1">
              {stories.map((s) => (
                <div
                  key={s.id}
                  className="shrink-0 w-16 h-24 rounded-lg overflow-hidden bg-muted ring-2 ring-pink-500/40 relative"
                >
                  {s.thumbnail_url && (
                    <img
                      src={s.thumbnail_url}
                      alt="story"
                      className="w-full h-full object-cover"
                      loading="lazy"
                    />
                  )}
                  {s.media_type === 2 && (
                    <Play className="absolute bottom-1 right-1 h-3 w-3 text-white drop-shadow" />
                  )}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Grid de posts */}
      {posts.length > 0 && (
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2 mb-3">
              <TrendingUp className="h-3.5 w-3.5 text-muted-foreground" />
              <p className="text-xs font-semibold">Últimos posts ({posts.length})</p>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {posts.map((p: any) => (
                <a
                  key={p.id}
                  href={p.permalink || "#"}
                  target="_blank"
                  rel="noreferrer"
                  className="group relative aspect-square rounded-lg overflow-hidden bg-muted block"
                >
                  {(p.stored_thumbnail_url || p.thumbnail_url) ? (
                    <img
                      src={p.stored_thumbnail_url || p.thumbnail_url}
                      alt={p.code || "post"}
                      className="w-full h-full object-cover"
                      loading="lazy"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-muted-foreground">
                      <Instagram className="h-6 w-6 opacity-30" />
                    </div>
                  )}
                  {p.media_type === 2 && (
                    <Play className="absolute top-1.5 right-1.5 h-3.5 w-3.5 text-white drop-shadow" />
                  )}
                  <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-end p-2 text-white text-[10px]">
                    {p.caption && (
                      <p className="line-clamp-3 mb-1.5 text-[10px] leading-tight">
                        {p.caption.substring(0, 100)}
                      </p>
                    )}
                    <div className="flex items-center gap-2 text-[10px] font-semibold">
                      <span className="flex items-center gap-0.5">
                        <Heart className="h-3 w-3 fill-current" />
                        {fmtNum(p.like_count)}
                      </span>
                      <span className="flex items-center gap-0.5">
                        <MessageCircle className="h-3 w-3" />
                        {fmtNum(p.comment_count)}
                      </span>
                      {p.play_count > 0 && (
                        <span className="flex items-center gap-0.5">
                          <Play className="h-3 w-3 fill-current" />
                          {fmtNum(p.play_count)}
                        </span>
                      )}
                    </div>
                  </div>
                </a>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

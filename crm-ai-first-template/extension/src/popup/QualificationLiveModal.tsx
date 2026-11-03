// ============================================================
// Modal "Ao Vivo" — mostra qualificação acontecendo em tempo real
// 100% funcional: lê do Supabase Realtime (social_selling_known_followers).
// ============================================================
import { useEffect, useRef, useState } from 'react';
import { subscribeQualification, fetchProfileLive, fetchRecentQualifications } from '../shared/realtime';
import { getConfig } from '../shared/storage';

type Verdict = 'analyzing' | 'qualified' | 'rejected' | 'private' | 'error' | 'cached';

type Card = {
  id: string;          // username
  username: string;
  ts: number;
  verdict: Verdict;
  score?: number | null;
  reason?: string;
  full_name?: string;
  biography?: string;
  follower_count?: number;
  is_verified?: boolean;
  is_private?: boolean;
  profile_pic?: string | null;
};

function statusFromRow(row: any): Verdict {
  if (row.qualified === true) return 'qualified';
  if (row.qualified === false) {
    const r = String(row.qualification_reason || '').toLowerCase();
    if (r.includes('privado') || r.includes('private')) return 'private';
    if (r.includes('sync_error') || r.includes('lead_error') || r.includes('erro')) return 'error';
    return 'rejected';
  }
  return 'analyzing';
}

const VERDICT_CFG: Record<Verdict, { label: string; emoji: string; color: string; bg: string }> = {
  analyzing: { label: 'Analisando', emoji: '🔍', color: 'text-amber', bg: 'bg-amber/[0.08] border-amber/30' },
  qualified: { label: 'QUALIFICADO', emoji: '✅', color: 'text-moss', bg: 'bg-moss/[0.08] border-moss/30' },
  rejected:  { label: 'Fora do ICP', emoji: '⏭', color: 'text-parchment/70', bg: 'bg-parchment/[0.05] border-parchment/15' },
  private:   { label: 'Perfil privado', emoji: '🔒', color: 'text-parchment/60', bg: 'bg-parchment/[0.03] border-parchment/10' },
  error:     { label: 'Erro', emoji: '⚠️', color: 'text-rose', bg: 'bg-rose/[0.06] border-rose/20' },
  cached:    { label: 'Já conhecido', emoji: '💾', color: 'text-parchment/55', bg: 'bg-parchment/[0.04] border-parchment/15' },
};

export function QualificationLiveModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [focused, setFocused] = useState<Card | null>(null);
  const [history, setHistory] = useState<Card[]>([]);
  const [counts, setCounts] = useState({ qualified: 0, rejected: 0, private: 0, error: 0 });
  const unsubRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;

    (async () => {
      // 1) Carrega histórico recente (últimas 20 qualificações)
      const cfg = await getConfig();
      const recent = await fetchRecentQualifications(cfg.ownerUsername, 20).catch(() => []);
      if (!cancelled && recent.length > 0) {
        const cards: Card[] = recent.map((row) => ({
          id: row.username,
          username: row.username,
          ts: new Date(row.first_seen_at).getTime(),
          verdict: statusFromRow(row),
          score: row.qualification_score,
          reason: row.qualification_reason || undefined,
          full_name: row.full_name || undefined,
          is_verified: row.is_verified,
          is_private: row.is_private,
        }));
        setHistory(cards.slice(0, 10));
        // Counts iniciais
        const c = { qualified: 0, rejected: 0, private: 0, error: 0 };
        for (const card of cards) {
          if (card.verdict === 'qualified') c.qualified++;
          else if (card.verdict === 'rejected') c.rejected++;
          else if (card.verdict === 'private') c.private++;
          else if (card.verdict === 'error') c.error++;
        }
        setCounts(c);
        // Foca o mais recente
        if (cards[0]) setFocused(cards[0]);
      }

      // 2) Subscribe realtime pra novos eventos
      const unsub = await subscribeQualification(async (row, eventType) => {
        if (cancelled) return;
        const verdict = statusFromRow(row);
        const username = String(row.username || '');

        // Busca perfil completo (foto, bio) — async, não bloqueia
        const profile = await fetchProfileLive(username).catch(() => null);
        if (cancelled) return;

        const card: Card = {
          id: username,
          username,
          ts: Date.now(),
          verdict,
          score: row.qualification_score,
          reason: row.qualification_reason || undefined,
          full_name: profile?.full_name || row.full_name || undefined,
          biography: profile?.biography || undefined,
          follower_count: profile?.follower_count,
          is_verified: profile?.is_verified ?? row.is_verified,
          is_private: profile?.is_private ?? row.is_private,
          profile_pic: profile?.stored_profile_picture_url || profile?.profile_picture_url_hd || null,
        };

        // Foca o card mais recente
        setFocused(card);

        // Atualiza counts (só pra verdicts finais)
        if (verdict !== 'analyzing') {
          setCounts((c) => ({
            qualified: c.qualified + (verdict === 'qualified' ? 1 : 0),
            rejected: c.rejected + (verdict === 'rejected' ? 1 : 0),
            private: c.private + (verdict === 'private' ? 1 : 0),
            error: c.error + (verdict === 'error' ? 1 : 0),
          }));
          // adiciona ao histórico (top 10)
          setHistory((prev) => [card, ...prev.filter((p) => p.id !== card.id)].slice(0, 10));
        }
      });
      unsubRef.current = unsub;
    })();

    return () => {
      cancelled = true;
      if (unsubRef.current) unsubRef.current();
      unsubRef.current = null;
    };
  }, [open]);

  if (!open) return null;

  const cfg = focused ? VERDICT_CFG[focused.verdict] : null;

  return (
    <div className="fixed inset-0 bg-ink/95 z-50 flex flex-col p-4 overflow-y-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-3 shrink-0">
        <div className="flex items-center gap-2">
          <div className="text-lg">🔴</div>
          <div>
            <h2 className="text-sm font-bold tracking-tight">Qualificação ao vivo</h2>
            <p className="text-[10px] text-parchment/55">tempo real · Supabase Realtime</p>
          </div>
        </div>
        <button onClick={onClose} className="text-parchment/60 hover:text-parchment text-lg px-2 py-1 rounded hover:bg-parchment/[0.04]">✕</button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-1.5 mb-3 shrink-0">
        <StatBox label="Qualif" value={counts.qualified} color="moss" />
        <StatBox label="Fora ICP" value={counts.rejected} color="parchment" />
        <StatBox label="Privado" value={counts.private} color="parchment" />
        <StatBox label="Erro" value={counts.error} color="rose" />
      </div>

      {/* Card principal — lead atual */}
      {focused && cfg ? (
        <div key={focused.id + focused.ts} className={`rounded-xl border-2 ${cfg.bg} p-4 mb-3 transition-all animate-[fadeSlide_300ms_ease-out]`}>
          <div className="flex items-start gap-3">
            <div className="shrink-0">
              {focused.profile_pic ? (
                <img src={focused.profile_pic} alt={focused.username}
                  className="w-16 h-16 rounded-full object-cover border-2 border-parchment/20" />
              ) : (
                <div className="w-16 h-16 rounded-full bg-parchment/10 border-2 border-parchment/20 flex items-center justify-center text-2xl">
                  👤
                </div>
              )}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5 flex-wrap">
                <span className="text-base font-bold truncate">{focused.full_name || focused.username}</span>
                {focused.is_verified && <span className="text-blue-400 text-sm">✓</span>}
                {focused.is_private && <span className="text-[9px] px-1.5 py-0.5 rounded bg-parchment/10 text-parchment/65">privado</span>}
              </div>
              <p className="text-xs text-parchment/65">@{focused.username}</p>
              {focused.follower_count != null && (
                <p className="text-[10px] text-parchment/45 mt-0.5">
                  {focused.follower_count.toLocaleString('pt-BR')} seguidores
                </p>
              )}
            </div>
          </div>

          {focused.biography && (
            <div className="mt-3 p-2.5 rounded-md bg-ink/40 border border-parchment/10">
              <p className="text-[9px] uppercase tracking-wider text-parchment/40 mb-1">Bio analisada</p>
              <p className="text-[11px] text-parchment/85 leading-relaxed line-clamp-3 italic">
                {focused.biography}
              </p>
            </div>
          )}

          {/* Veredito */}
          <div className="mt-3 flex items-center justify-between gap-2">
            <div className={`flex items-center gap-2 ${cfg.color}`}>
              <span className="text-2xl">{cfg.emoji}</span>
              <div>
                <p className="text-base font-bold uppercase tracking-tight leading-none">{cfg.label}</p>
                {focused.score != null && focused.verdict !== 'analyzing' && (
                  <p className="text-[10px] opacity-75 mt-0.5">Score: <span className="font-bold">{focused.score}</span> / 100</p>
                )}
              </div>
            </div>
            {focused.verdict === 'analyzing' && (
              <div className="flex gap-1">
                <span className="w-2 h-2 rounded-full bg-amber animate-pulse" />
                <span className="w-2 h-2 rounded-full bg-amber animate-pulse" style={{ animationDelay: '150ms' }} />
                <span className="w-2 h-2 rounded-full bg-amber animate-pulse" style={{ animationDelay: '300ms' }} />
              </div>
            )}
          </div>

          {focused.reason && focused.verdict !== 'analyzing' && (
            <p className="mt-2 text-[11px] text-parchment/70 italic border-l-2 border-parchment/20 pl-2">
              💡 {focused.reason}
            </p>
          )}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-12 text-center mb-3">
          <div className="text-4xl mb-2 opacity-50 animate-pulse">📡</div>
          <p className="text-sm font-medium text-parchment/70">Aguardando qualificação ao vivo</p>
          <p className="text-[11px] text-parchment/45 mt-1">Inicie uma captura em "🎯 Prospecção"</p>
        </div>
      )}

      {/* Histórico recente */}
      {history.length > 0 && (
        <div className="space-y-1.5">
          <p className="text-[10px] uppercase tracking-wider text-parchment/45 font-bold px-1">Últimos analisados — clique para ver detalhes</p>
          {history.map((c) => {
            const cc = VERDICT_CFG[c.verdict];
            const isActive = focused?.id === c.id && focused?.ts === c.ts;
            return (
              <button
                key={c.id + c.ts}
                onClick={async () => {
                  // Enriquece com perfil completo (bio, foto, follower_count) ao clicar
                  setFocused(c);
                  const profile = await fetchProfileLive(c.username).catch(() => null);
                  setFocused((prev) => prev?.id === c.id ? {
                    ...c,
                    full_name: profile?.full_name || c.full_name,
                    biography: profile?.biography || c.biography,
                    follower_count: profile?.follower_count ?? c.follower_count,
                    is_verified: profile?.is_verified ?? c.is_verified,
                    is_private: profile?.is_private ?? c.is_private,
                    profile_pic: profile?.stored_profile_picture_url || profile?.profile_picture_url_hd || null,
                  } : prev);
                  // Scroll pro topo pro user ver o card focado
                  window.scrollTo({ top: 0, behavior: 'smooth' });
                }}
                className={`w-full rounded-md border ${cc.bg} px-2.5 py-1.5 flex items-center gap-2 text-left hover:brightness-125 transition-all ${isActive ? 'ring-2 ring-amber/60' : ''}`}
              >
                <span className="text-sm">{cc.emoji}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-[11px] font-medium truncate">{c.full_name || c.username}</p>
                  <p className="text-[10px] text-parchment/50 truncate">@{c.username}</p>
                </div>
                {c.score != null && (
                  <span className={`text-[10px] font-bold ${cc.color}`}>{c.score}</span>
                )}
                <span className="text-[10px] text-parchment/30">›</span>
              </button>
            );
          })}
        </div>
      )}

      <style>{`
        @keyframes fadeSlide {
          from { opacity: 0; transform: translateY(8px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}

function StatBox({ label, value, color }: { label: string; value: number; color: 'moss' | 'rose' | 'parchment' }) {
  const map = {
    moss: 'text-moss bg-moss/[0.08] border-moss/20',
    rose: 'text-rose bg-rose/[0.06] border-rose/15',
    parchment: 'text-parchment/70 bg-parchment/[0.04] border-parchment/10',
  };
  return (
    <div className={`rounded-md border px-1 py-1.5 text-center ${map[color]}`}>
      <p className="text-base font-bold leading-none">{value}</p>
      <p className="text-[9px] uppercase tracking-wider mt-0.5 opacity-70">{label}</p>
    </div>
  );
}

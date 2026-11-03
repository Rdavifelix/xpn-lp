import { useEffect, useState } from 'react';
import type { ExtMessage, QueueItem, ActionType } from '../shared/types';
import { crmLeadUrl, setCrmBaseUrl } from '../shared/types';
import { getQueue, getHistory, getConfig, getLog, type LiveLogEntry } from '../shared/storage';
import { listActiveEnrollments, listTodayInteractions, listAutomations } from '../shared/api';
import { subscribeEnrollments } from '../shared/realtime';
import { ConfigsPanel } from './ConfigsPanel';
import { LoginScreen } from './LoginScreen';
import { QualificationLiveModal } from './QualificationLiveModal';
import { getSession, signOut, type AuthSession } from '../shared/auth';

const ACTION_LABELS: Record<ActionType, string> = {
  curtir_posts: 'Curtir post',
  comentar_post: 'Comentar post',
  reagir_story: 'Reagir story',
  responder_story: 'Responder story (DM)',
  enviar_dm: 'Enviar DM',
  followup_story: 'Follow-up story',
  verificar_resposta: 'Verificar inbox',
};

const ACTION_ICONS: Record<ActionType, string> = {
  curtir_posts: '👍',
  comentar_post: '🗣️',
  reagir_story: '❤️',
  responder_story: '💬',
  enviar_dm: '📩',
  followup_story: '🔄',
  verificar_resposta: '👀',
};

type Tab = 'prospec' | 'followup' | 'logs' | 'configs';

// Classificador: cadência com target_pipeline_id = prospecção (cria lead novo no funil)
//                cadência sem pipeline = follow-up (lead já existe, só engaja)
function classifyEnrollment(enr: any): 'prospec' | 'followup' {
  return enr?.automation?.trigger_config?.target_pipeline_id ? 'prospec' : 'followup';
}
function classifyQueueItem(it: QueueItem, enrollments: any[]): 'prospec' | 'followup' {
  const enr = enrollments.find((e) => e.id === it.enrollment_id);
  if (enr) return classifyEnrollment(enr);
  // fallback: se action é da cadência aquecimento (sem enr no map), prospec
  return 'prospec';
}

const TODAY_KEY = () => new Date().toISOString().slice(0, 10);

export function App() {
  const [session, setSession] = useState<AuthSession | null | 'loading'>('loading');

  useEffect(() => {
    getSession().then((s) => setSession(s));
  }, []);

  if (session === 'loading') {
    return <div className="flex items-center justify-center h-screen text-parchment/40 text-xs">Carregando…</div>;
  }
  if (!session) {
    return <LoginScreen onLogged={() => getSession().then((s) => setSession(s))} />;
  }
  return <MainApp session={session} onSignOut={() => setSession(null)} />;
}

function MainApp({ session, onSignOut }: { session: AuthSession; onSignOut: () => void }) {
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [todayActions, setTodayActions] = useState<any[]>([]); // do banco — fonte da verdade
  const [logs, setLogs] = useState<LiveLogEntry[]>([]);
  const [tab, setTab] = useState<Tab>('followup');
  const [editing, setEditing] = useState<QueueItem | null>(null);
  const [running, setRunning] = useState(false);
  const [bootstrapped, setBootstrapped] = useState(false);

  const [idleUntil, setIdleUntil] = useState<number>(0);
  const [idleNext, setIdleNext] = useState<string | null>(null);
  const [liveOpen, setLiveOpen] = useState(false);
  const [paused, setPaused] = useState(false);

  // Carrega o CRM base URL do config (pros links "abrir lead no CRM")
  useEffect(() => {
    getConfig().then((cfg) => setCrmBaseUrl(cfg.crmBaseUrl)).catch(() => {});
  }, []);

  // Lê estado pausado a cada 2s
  useEffect(() => {
    const refresh = async () => {
      const r = await chrome.storage.local.get('iap_ss_paused');
      setPaused(r.iap_ss_paused === true);
    };
    refresh();
    const t = setInterval(refresh, 2000);
    return () => clearInterval(t);
  }, []);

  const handlePauseToggle = async () => {
    if (paused) {
      await new Promise<void>((r) => chrome.runtime.sendMessage({ kind: 'RESUME_ALL' }, () => r()));
      setPaused(false);
    } else {
      if (!confirm('Pausar TODAS as ações? Vai fechar tabs IG em execução.')) return;
      await new Promise<void>((r) => chrome.runtime.sendMessage({ kind: 'PAUSE_ALL' }, () => r()));
      setPaused(true);
    }
  };

  const loadAll = async () => {
    setQueue(await getQueue()); // só pending_approval/auto_ready em andamento (efêmero)
    setLogs(await getLog());
    const r = await chrome.storage.local.get(['iap_ss_idle_until', 'iap_ss_idle_next']);
    setIdleUntil(r.iap_ss_idle_until || 0);
    setIdleNext(r.iap_ss_idle_next || null);
    // History de hoje vem direto do banco (sem cache local)
    try {
      const cfg = await getConfig();
      const acts = await listTodayInteractions(cfg);
      setTodayActions(acts);
    } catch {}
  };

  useEffect(() => {
    (async () => {
      await loadAll();
      const q = await getQueue();
      if (q.length === 0) {
        setRunning(true);
        await new Promise<void>((r) => chrome.runtime.sendMessage({ kind: 'RUN_NOW' }, () => r()));
        await new Promise((r) => setTimeout(r, 4000));
        setRunning(false);
        await loadAll();
      }
      setBootstrapped(true);
    })();
    const t = setInterval(loadAll, 3000);
    return () => clearInterval(t);
  }, []);

  const send = (msg: ExtMessage) =>
    new Promise<any>((resolve) => chrome.runtime.sendMessage(msg, resolve));

  const handleApprove = async (item: QueueItem, edited?: string) => {
    await send({ kind: 'APPROVE_ITEM', local_id: item.local_id, edited_message: edited });
    await loadAll();
  };
  const handleSkip = async (item: QueueItem) => {
    await send({ kind: 'SKIP_ITEM', local_id: item.local_id });
    await loadAll();
  };
  const handleRunNow = async () => {
    setRunning(true);
    await send({ kind: 'RUN_NOW' });
    setTimeout(() => {
      setRunning(false);
      loadAll();
    }, 2500);
  };

  const [enrollments, setEnrollments] = useState<any[]>([]);

  useEffect(() => {
    let cancelled = false;
    const refreshEnrollments = async () => {
      try {
        const cfg = await getConfig();
        const list = await listActiveEnrollments(cfg);
        if (!cancelled) setEnrollments(list || []);
      } catch {}
    };
    refreshEnrollments();

    // Realtime: refresh imediato quando muda enrollment/interaction
    let unsubscribe: (() => void) | null = null;
    subscribeEnrollments(() => { if (!cancelled) refreshEnrollments(); })
      .then((unsub) => { unsubscribe = unsub; })
      .catch((e) => console.warn('[IAP-SS] realtime falhou (vai usar só polling):', e));

    // Polling como fallback (intervalo maior — realtime cobre o tempo real)
    const t = setInterval(refreshEnrollments, 30000);
    return () => {
      cancelled = true;
      clearInterval(t);
      if (unsubscribe) unsubscribe();
    };
  }, [bootstrapped]);

  const pending = queue.filter((q) => q.state === 'pending_approval');
  const auto = queue.filter((q) => q.state === 'auto_ready' || q.state === 'executing');

  return (
    <div className="flex flex-col h-screen min-h-screen w-full">
      {/* Header */}
      <header className="flex items-center justify-between px-4 py-3 border-b border-parchment/10 shrink-0">
        <div className="flex items-center gap-2">
          <div className="text-xl">📷</div>
          <div>
            <h1 className="text-sm font-semibold tracking-tight">IAP Social Selling</h1>
            <p className="text-[10px] text-parchment/60">
              {pending.length > 0
                ? `${pending.length} ação${pending.length > 1 ? 'ões' : ''} pra revisar`
                : auto.length > 0
                ? 'Executando…'
                : 'Tudo em dia'}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-parchment/40 max-w-[100px] truncate" title={session.user.email}>
            {session.user.email}
          </span>
          <button
            onClick={async () => {
              await signOut();
              onSignOut();
            }}
            className="text-parchment/40 hover:text-rose transition-colors text-xs"
            title="Sair"
          >
            ↩
          </button>
          <button
            onClick={async () => {
              if (!confirm('Limpar fila + histórico local? (não toca no banco)')) return;
              await new Promise<void>((r) => chrome.runtime.sendMessage({ kind: 'CLEAR_LOCAL_HISTORY' }, () => r()));
              window.location.reload();
            }}
            className="text-parchment/40 hover:text-rose transition-colors text-xs"
            title="Limpar histórico local"
          >
            🧹
          </button>
          <button
            onClick={() => chrome.runtime.openOptionsPage()}
            className="text-parchment/50 hover:text-parchment transition-colors text-base"
            title="Configurações"
          >
            ⚙️
          </button>
        </div>
      </header>

      {/* Countdown da próxima ação */}
      {idleUntil > Date.now() && idleNext && (
        <CountdownBanner until={idleUntil} nextItem={queue.find((q) => q.local_id === idleNext)} />
      )}

      {/* Live ticker (sempre visível quando há atividade recente) — clicável pra abrir modal funcional */}
      {logs.length > 0 && (logs[0].ts > Date.now() - 60000 || queue.some(q => q.state === 'executing')) && (
        <LiveTicker entries={logs.slice(0, 4)} onExpand={() => setLiveOpen(true)} />
      )}

      <QualificationLiveModal open={liveOpen} onClose={() => setLiveOpen(false)} />

      {/* Tabs principais (Follow-up/Prospecção) + ícones secundários (Logs/Configs) */}
      <nav className="flex items-stretch border-b border-parchment/10 shrink-0">
        <BigTabBtn
          active={tab === 'followup'}
          onClick={() => setTab('followup')}
          icon="🤝"
          label="Follow-up"
          count={enrollments.filter((e) => classifyEnrollment(e) === 'followup').length}
          accent="sage"
        />
        <BigTabBtn
          active={tab === 'prospec'}
          onClick={() => setTab('prospec')}
          icon="🎯"
          label="Prospecção"
          count={enrollments.filter((e) => classifyEnrollment(e) === 'prospec').length}
          accent="amber"
        />
        <button
          onClick={() => setTab('logs')}
          className={`px-3 flex items-center justify-center text-base border-l border-parchment/10 transition-colors ${
            tab === 'logs' ? 'text-parchment bg-parchment/[0.04]' : 'text-parchment/40 hover:text-parchment/70'
          }`}
          title="Logs"
        >
          📜
        </button>
        <button
          onClick={() => setTab('configs')}
          className={`px-3 flex items-center justify-center text-base border-l border-parchment/10 transition-colors ${
            tab === 'configs' ? 'text-parchment bg-parchment/[0.04]' : 'text-parchment/40 hover:text-parchment/70'
          }`}
          title="Configs"
        >
          ⚙️
        </button>
      </nav>

      {/* Content */}
      <main className="flex-1 overflow-y-auto px-3 py-3 space-y-3">
        {tab === 'prospec' && (
          <ProspecPage
            queue={queue.filter((q) => classifyQueueItem(q, enrollments) === 'prospec')}
            history={(todayActions as any).filter((h: any) => {
              const enr = enrollments.find((e: any) => e.id === h.enrollment_id);
              return !enr || classifyEnrollment(enr) === 'prospec';
            })}
            enrollments={enrollments.filter((e) => classifyEnrollment(e) === 'prospec')}
            running={running}
            bootstrapped={bootstrapped}
            onApprove={(it) => setEditing(it)}
            onApproveQuick={(it) => handleApprove(it)}
            onSkip={handleSkip}
          />
        )}
        {tab === 'followup' && (
          <FollowupPage
            queue={queue.filter((q) => classifyQueueItem(q, enrollments) === 'followup')}
            history={(todayActions as any).filter((h: any) => {
              const enr = enrollments.find((e: any) => e.id === h.enrollment_id);
              return enr && classifyEnrollment(enr) === 'followup';
            })}
            enrollments={enrollments.filter((e) => classifyEnrollment(e) === 'followup')}
            running={running}
            bootstrapped={bootstrapped}
            onApprove={(it) => setEditing(it)}
            onApproveQuick={(it) => handleApprove(it)}
            onSkip={handleSkip}
          />
        )}
        {tab === 'logs' && <LogsTab logs={logs} />}
        {tab === 'configs' && <ConfigsPanel />}
      </main>

      {/* Banner PAUSADO */}
      {paused && (
        <div className="border-t border-rose/40 bg-rose/[0.08] px-3 py-2 flex items-center gap-2 shrink-0">
          <span className="inline-block w-2 h-2 rounded-full bg-rose animate-pulse" />
          <p className="text-[11px] text-rose font-semibold flex-1">🛑 SISTEMA PAUSADO — nenhuma ação será executada</p>
        </div>
      )}

      {/* Footer */}
      <footer className="border-t border-parchment/10 px-3 py-2.5 flex items-center justify-between gap-2 bg-parchment/[0.02]">
        <button
          onClick={handlePauseToggle}
          className={`px-2.5 py-1.5 text-xs rounded-md font-semibold transition-colors ${
            paused
              ? 'bg-moss text-parchment hover:opacity-90'
              : 'border border-rose/40 text-rose hover:bg-rose/10'
          }`}
          title={paused ? 'Retomar execução' : 'Pausar todas as ações'}
        >
          {paused ? '▶ Retomar' : '⏸ Pausar'}
        </button>
        <p className="text-[10px] text-parchment/50 flex-1 text-right">Próx: amanhã</p>
        <button
          onClick={handleRunNow}
          disabled={running || paused}
          className="px-3 py-1.5 text-xs rounded-md bg-amber text-ink font-semibold hover:bg-amber-light transition-colors disabled:opacity-40"
          title={paused ? 'Retome o sistema primeiro' : 'Executar agora'}
        >
          {running ? '...' : '▶ Executar agora'}
        </button>
      </footer>

      {editing && (
        <EditModal
          item={editing}
          onCancel={() => setEditing(null)}
          onApprove={async (text) => {
            await handleApprove(editing, text);
            setEditing(null);
          }}
          onRegenerate={async () => {
            const r = await send({ kind: 'REGENERATE_MESSAGE', local_id: editing.local_id });
            if (r?.ok && r.message) {
              setEditing({ ...editing, generated_message: r.message, edited_message: undefined });
            }
          }}
        />
      )}
    </div>
  );
}

// ------------------------------------------------------------
// Banner — mostra cadências ativas hoje agrupadas + count de leads
// ------------------------------------------------------------
function CadenciasAtivasBanner({ enrollments }: { enrollments: any[] }) {
  // Agrupa por automation_id
  const byAuto = new Map<string, { name: string; emoji: string; count: number; ready: number }>();
  const now = Date.now();
  for (const enr of enrollments) {
    const key = enr.automation?.id || 'unknown';
    const name = enr.automation?.name || 'Cadência';
    const emoji = enr.automation?.emoji || '🔄';
    const cur = byAuto.get(key) || { name, emoji, count: 0, ready: 0 };
    cur.count++;
    if (enr.next_action_at && new Date(enr.next_action_at).getTime() <= now) cur.ready++;
    byAuto.set(key, cur);
  }
  const items = Array.from(byAuto.values()).sort((a, b) => b.count - a.count);
  if (items.length === 0) return null;
  const totalReady = items.reduce((s, i) => s + i.ready, 0);

  return (
    <div className="border-b border-parchment/10 bg-parchment/[0.02] px-3 py-2.5">
      <div className="flex items-center justify-between mb-1.5">
        <p className="text-[10px] uppercase tracking-wider text-parchment/45 font-bold">
          📊 Cadências ativas
        </p>
        {totalReady > 0 && (
          <span className="text-[10px] text-amber font-medium">
            {totalReady} pronto{totalReady > 1 ? 's' : ''} agora
          </span>
        )}
      </div>
      <div className="flex flex-wrap gap-1.5">
        {items.map((c, i) => (
          <div
            key={i}
            className="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-amber/[0.06] border border-amber/15 text-[11px]"
          >
            <span>{c.emoji}</span>
            <span className="font-medium text-parchment/90 truncate max-w-[150px]" title={c.name}>
              {c.name}
            </span>
            <span className="text-amber font-bold">{c.count}</span>
            {c.ready > 0 && (
              <span className="text-[9px] text-amber/80 ml-0.5">· {c.ready} agora</span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ------------------------------------------------------------
// Status da qualificação em background — mostrado no topo de Prospecção
// ------------------------------------------------------------
function QualifyStatusInline() {
  const [qualifyState, setQualifyState] = useState<any>(null);

  useEffect(() => {
    const refresh = async () => {
      const r = await chrome.storage.local.get('iap_ss_qualify_state');
      setQualifyState(r.iap_ss_qualify_state || null);
    };
    refresh();
    const t = setInterval(refresh, 2000);
    return () => clearInterval(t);
  }, []);

  if (!qualifyState) return null;

  const totals = qualifyState.totals || { qualified: 0, icp_fail: 0, sync_errors: 0, lead_errors: 0 };
  const totalProcessed = (totals.qualified || 0) + (totals.icp_fail || 0) + (totals.sync_errors || 0) + (totals.lead_errors || 0);

  return (
    <div className="rounded-xl border border-amber/30 bg-amber/[0.05] p-3 space-y-2">
      <div className="flex items-center justify-between">
        <p className="text-xs font-semibold flex items-center gap-1.5">
          <span className="animate-pulse">⚙️</span> Qualificando seguidores...
        </p>
        <span className="text-[10px] text-parchment/50">{totalProcessed} processados</span>
      </div>
      <div className="grid grid-cols-4 gap-1.5 text-center">
        <StatBox label="Qualif" value={totals.qualified} color="moss" />
        <StatBox label="Fora ICP" value={totals.icp_fail} color="parchment" />
        <StatBox label="Erro sync" value={totals.sync_errors} color="rose" />
        <StatBox label="Erro lead" value={totals.lead_errors} color="rose" />
      </div>
      <p className="text-[10px] text-parchment/45 text-center">
        Roda em background a cada 1min. Pode fechar o popup.
      </p>
    </div>
  );
}

// ------------------------------------------------------------
// Aba 🎯 Prospecção — captura + qualify + leads novos em aquecimento
// ------------------------------------------------------------
function ProspecPage(props: {
  queue: QueueItem[];
  history: any[];
  enrollments: any[];
  running: boolean;
  bootstrapped: boolean;
  onApprove: (it: QueueItem) => void;
  onApproveQuick: (it: QueueItem) => void;
  onSkip: (it: QueueItem) => void;
}) {
  return (
    <div className="space-y-3">
      {/* Header explicativo */}
      <div className="px-1">
        <p className="text-[11px] font-medium text-amber">🎯 Prospecção (leads novos)</p>
        <p className="text-[10px] text-parchment/50 mt-0.5">
          Captura seguidores → qualifica via IA → cria lead → cadência de aquecimento (curtir/story/comentar/DM)
        </p>
      </div>

      <CaptureFollowersCard />
      <QualifyStatusInline />

      {/* Leads em aquecimento */}
      {props.enrollments.length > 0 || props.queue.length > 0 ? (
        <TodayTab {...props} />
      ) : (
        <div className="rounded-lg border border-parchment/10 bg-parchment/[0.02] p-6 text-center">
          <div className="text-2xl mb-2 opacity-50">🌱</div>
          <p className="text-xs font-medium">Nenhum lead em prospecção</p>
          <p className="text-[10px] text-parchment/50 mt-1">
            Clique em "Capturar novos seguidores" pra começar.
          </p>
        </div>
      )}
    </div>
  );
}

// ------------------------------------------------------------
// Aba 🤝 Follow-up — leads do CRM que tiveram cadência iniciada manualmente
// ------------------------------------------------------------
function FollowupPage(props: {
  queue: QueueItem[];
  history: any[];
  enrollments: any[];
  running: boolean;
  bootstrapped: boolean;
  onApprove: (it: QueueItem) => void;
  onApproveQuick: (it: QueueItem) => void;
  onSkip: (it: QueueItem) => void;
}) {
  return (
    <div className="space-y-3">
      {/* Header explicativo */}
      <div className="px-1">
        <p className="text-[11px] font-medium text-sage">🤝 Follow-up (leads do funil)</p>
        <p className="text-[10px] text-parchment/50 mt-0.5">
          Leads que já existem no CRM e estão recebendo cadência iniciada manualmente.
        </p>
      </div>

      {props.enrollments.length === 0 && props.queue.length === 0 ? (
        <div className="rounded-lg border border-sage/15 bg-sage/[0.04] p-5 text-center">
          <div className="text-2xl mb-2 opacity-60">🎯</div>
          <p className="text-xs font-medium">Sem follow-up rolando</p>
          <p className="text-[10px] text-parchment/55 mt-1.5 leading-relaxed">
            Pra iniciar follow-up via Instagram num lead que já tá no funil:
          </p>
          <ol className="text-[10px] text-parchment/65 mt-2 text-left max-w-[260px] mx-auto space-y-0.5 list-decimal pl-4">
            <li>Abra o lead no CRM</li>
            <li>Aba <span className="text-sage font-medium">Instagram</span></li>
            <li>Clique em <span className="text-sage font-medium">"Iniciar cadência"</span></li>
            <li>Escolha uma cadência (não-Aquecimento)</li>
          </ol>
          <a
            href={crmLeadUrl() || '#'}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-block mt-3 text-[11px] text-sage hover:text-sage-light underline decoration-sage/30"
          >
            Abrir CRM →
          </a>
        </div>
      ) : (
        <TodayTab {...props} />
      )}
    </div>
  );
}

function StatBox({ label, value, color }: { label: string; value: number; color: 'moss' | 'rose' | 'parchment' }) {
  const colorMap = {
    moss: 'text-moss bg-moss/[0.08] border-moss/20',
    rose: 'text-rose bg-rose/[0.06] border-rose/15',
    parchment: 'text-parchment/70 bg-parchment/[0.04] border-parchment/10',
  };
  return (
    <div className={`rounded-md border px-1 py-1.5 ${colorMap[color]}`}>
      <p className="text-base font-bold leading-none">{value || 0}</p>
      <p className="text-[9px] uppercase tracking-wider mt-0.5 opacity-70">{label}</p>
    </div>
  );
}

const LAST_TARGET_KEY = 'iap_ss_last_target';

function CaptureFollowersCard() {
  const [expanded, setExpanded] = useState(false);
  const [target, setTarget] = useState('');
  const [limit, setLimit] = useState(200);
  const [automations, setAutomations] = useState<any[]>([]);
  const [automationId, setAutomationId] = useState('');
  const [running, setRunning] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const cfg = await getConfig();
        const list = await listAutomations(cfg);
        // Captura de seguidores SÓ funciona com cadência tipo new_follower
        // (precisa de target_pipeline_id pra criar leads novos).
        // Cadências stage_change são pra leads que JÁ existem → não aparecem aqui.
        const newFollowerOnly = list.filter((a: any) => a.is_active && a.trigger_type === 'new_follower');
        setAutomations(newFollowerOnly);
        setAutomationId(newFollowerOnly[0]?.id || '');
        // Persiste o último @ alvo usado — default vem do ownerUsername se nunca digitou
        const stored = await chrome.storage.local.get(LAST_TARGET_KEY);
        const last = stored[LAST_TARGET_KEY] as string | undefined;
        setTarget(last || cfg.ownerUsername || '');
      } catch {}
    })();
  }, []);

  // Salva o target a cada mudança (debounce simples via effect)
  useEffect(() => {
    const cleaned = target.trim().replace(/^@/, '');
    if (cleaned) {
      const t = setTimeout(() => {
        chrome.storage.local.set({ [LAST_TARGET_KEY]: cleaned }).catch(() => {});
      }, 500);
      return () => clearTimeout(t);
    }
  }, [target]);

  const dispatch = async () => {
    if (!automationId) { alert('Selecione uma cadência'); return; }
    const cleaned = target.trim().replace(/^@/, '');
    // Garante persistência imediata antes do dispatch
    if (cleaned) await chrome.storage.local.set({ [LAST_TARGET_KEY]: cleaned });
    setRunning(true);
    await new Promise<void>((r) => chrome.runtime.sendMessage({
      kind: 'CAPTURE_NEW_FOLLOWERS',
      target_username: cleaned,
      limit,
      automation_id: automationId,
      for_account: cleaned,
    }, () => r()));
    // Background processa async; UI volta ao normal e log mostra progresso
    setTimeout(() => setRunning(false), 3000);
    setExpanded(false);
  };

  return (
    <div className="rounded-xl border border-amber/20 bg-gradient-to-br from-amber/[0.06] to-amber/[0.02] overflow-hidden">
      {!expanded ? (
        <button onClick={() => setExpanded(true)} className="w-full px-3 py-2.5 flex items-center gap-2 hover:bg-amber/[0.04] transition-colors text-left">
          <span className="text-base">📥</span>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-semibold">Capturar novos seguidores</p>
            <p className="text-[10px] text-parchment/55">Coleta + qualifica via IA + cria leads no pipeline</p>
          </div>
          <span className="text-[10px] text-amber">▾ abrir</span>
        </button>
      ) : (
        <div className="p-3 space-y-2.5">
          <div className="flex items-center justify-between">
            <p className="text-xs font-semibold flex items-center gap-1.5">📥 Capturar seguidores</p>
            <button onClick={() => setExpanded(false)} className="text-[10px] text-parchment/50 hover:text-parchment">▴ recolher</button>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-[10px] text-parchment/60 block mb-0.5">Perfil alvo</label>
              <input
                value={target}
                onChange={(e) => setTarget(e.target.value)}
                placeholder="seu_usuario_ig"
                className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded px-2 py-1 text-xs outline-none"
              />
              <p className="text-[9px] text-parchment/40 mt-0.5">Você ou competidor</p>
            </div>
            <div>
              <label className="text-[10px] text-parchment/60 block mb-0.5">Quantidade</label>
              <input
                type="number"
                min={50}
                max={2000}
                step={50}
                value={limit}
                onChange={(e) => setLimit(parseInt(e.target.value) || 200)}
                className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded px-2 py-1 text-xs outline-none"
              />
              <p className="text-[9px] text-parchment/40 mt-0.5">Máx 2000</p>
            </div>
          </div>

          <div>
            <label className="text-[10px] text-parchment/60 block mb-0.5">Cadência destino (qualificados)</label>
            <select
              value={automationId}
              onChange={(e) => setAutomationId(e.target.value)}
              className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded px-2 py-1 text-xs outline-none"
            >
              {automations.length === 0 && <option value="">⚠ Nenhuma cadência tipo "novo seguidor" ativa</option>}
              {automations.map((a) => (
                <option key={a.id} value={a.id}>{a.emoji} {a.name}</option>
              ))}
            </select>
            {automations.length === 0 && (
              <p className="text-[9px] text-rose/80 mt-0.5">
                Crie uma cadência tipo "novo seguidor" no CRM (/configuracoes → Social Selling) antes de capturar.
              </p>
            )}
          </div>

          <button
            onClick={dispatch}
            disabled={running || !automationId}
            className="w-full px-3 py-2 text-xs rounded-md bg-amber text-ink font-semibold hover:bg-amber-light disabled:opacity-40 transition-colors"
          >
            {running ? '⋯ Iniciando...' : '▶ Capturar e qualificar'}
          </button>

          <button
            onClick={async () => {
              if (!automationId) return;
              await new Promise<void>((r) => chrome.runtime.sendMessage({
                kind: 'CONTINUE_PENDING_QUALIFICATION',
                automation_id: automationId,
                for_account: target.trim().replace(/^@/, ''),
              }, () => r()));
            }}
            disabled={!automationId}
            className="w-full px-3 py-1.5 text-[11px] rounded-md border border-amber/30 text-amber hover:bg-amber/[0.06] transition-colors"
          >
            🔄 Continuar qualificação dos pendentes (sem capturar de novo)
          </button>

          <p className="text-[10px] text-parchment/45 text-center">
            Roda em background — acompanhe na aba Logs
          </p>
        </div>
      )}
    </div>
  );
}

function PipelineBadge({ pipeline, stage, leadId }: { pipeline: string; stage?: string; leadId?: string }) {
  // Pipeline "Prospecção Social Selling" é o pipeline interno da extensão — não polui a UI
  const isInternalProspec = /prospec.*social.*selling/i.test(pipeline);
  if (isInternalProspec) return null;
  const content = (
    <span className="inline-flex items-center gap-1 mt-1 text-[10px]">
      <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-sage/10 border border-sage/20 text-sage/90">
        <span className="opacity-70">📍</span>
        <span className="font-medium truncate max-w-[120px]" title={pipeline}>{pipeline}</span>
        {stage && <><span className="opacity-40">·</span><span className="opacity-80 truncate max-w-[100px]" title={stage}>{stage}</span></>}
      </span>
    </span>
  );
  if (leadId) {
    return (
      <a
        href={crmLeadUrl(leadId)}
        target="_blank"
        rel="noopener noreferrer"
        onClick={(e) => e.stopPropagation()}
        className="inline-block hover:brightness-125 transition"
        title="Abrir lead no CRM"
      >{content}</a>
    );
  }
  return content;
}

function TabBtn({ active, onClick, children, accent }: { active: boolean; onClick: () => void; children: React.ReactNode; accent?: 'amber' | 'sage' }) {
  const accentColor = accent === 'sage' ? 'text-sage border-sage' : 'text-amber border-amber';
  return (
    <button
      onClick={onClick}
      className={`flex-1 py-2.5 text-xs font-medium transition-colors flex items-center justify-center gap-1.5 ${
        active ? `${accentColor} border-b-2` : 'text-parchment/50 hover:text-parchment/80'
      }`}
    >
      {children}
    </button>
  );
}

function BigTabBtn({
  active, onClick, icon, label, count, accent,
}: {
  active: boolean; onClick: () => void; icon: string; label: string; count: number; accent: 'amber' | 'sage';
}) {
  const colors = accent === 'sage'
    ? { active: 'border-sage bg-sage/[0.06] text-sage', inactive: 'text-parchment/55', countActive: 'bg-sage text-ink', countInactive: 'bg-parchment/10 text-parchment/60' }
    : { active: 'border-amber bg-amber/[0.06] text-amber', inactive: 'text-parchment/55', countActive: 'bg-amber text-ink', countInactive: 'bg-parchment/10 text-parchment/60' };
  return (
    <button
      onClick={onClick}
      className={`flex-1 py-2.5 px-2 flex items-center justify-center gap-1.5 transition-colors border-b-2 ${
        active ? colors.active : `border-transparent ${colors.inactive} hover:text-parchment/80 hover:bg-parchment/[0.02]`
      }`}
    >
      <span className="text-sm">{icon}</span>
      <span className="text-xs font-semibold tracking-tight">{label}</span>
      {count > 0 && (
        <span className={`text-[10px] font-bold rounded-full px-1.5 py-0.5 leading-none ${active ? colors.countActive : colors.countInactive}`}>
          {count}
        </span>
      )}
    </button>
  );
}

function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="ml-1 inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 text-[10px] rounded-full bg-amber text-ink font-bold">
      {children}
    </span>
  );
}

// ------------------------------------------------------------
// Pending tab
// ------------------------------------------------------------

// ------------------------------------------------------------
// Today tab — agrupa todas as ações de hoje POR LEAD
// Cada lead vê: cadência, dia, lista de ações com status (feito / executando / revisar / vai rodar)
// ------------------------------------------------------------

type LeadGroup = {
  enrollment_id: string;
  instagram_username: string;
  lead_id?: string;
  lead_name?: string;
  cadence_name?: string;
  cadence_emoji?: string;
  current_day?: number;
  total_days?: number;
  next_at?: string | null;
  pipeline_name?: string;
  stage_name?: string;
  done_today?: any[]; // interactions_today do banco — histórico do dia
  actions: QueueItem[]; // tudo de hoje pra esse lead (queue + history-de-hoje)
  upcoming_actions?: { type: ActionType; count?: number }[]; // ações planejadas pro current_day (do cadence_config) — filtrado p/ remover tentadas
};

function TodayTab({
  queue,
  history,
  enrollments,
  running,
  bootstrapped,
  onApprove,
  onApproveQuick,
  onSkip,
}: {
  queue: QueueItem[];
  history: QueueItem[];
  enrollments: any[];
  running: boolean;
  bootstrapped: boolean;
  onApprove: (it: QueueItem) => void;
  onApproveQuick: (it: QueueItem) => void;
  onSkip: (it: QueueItem) => void;
}) {
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [runningSelected, setRunningSelected] = useState(false);
  const toggleSelected = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };
  const runSelected = async () => {
    if (selectedIds.size === 0) return;
    setRunningSelected(true);
    await new Promise<void>((r) =>
      chrome.runtime.sendMessage({ kind: 'RUN_NOW', enrollment_ids: Array.from(selectedIds) }, () => r()),
    );
    setSelectedIds(new Set());
    setTimeout(() => setRunningSelected(false), 2500);
  };
  if (running) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="text-3xl mb-3 animate-pulse">⚙️</div>
        <p className="text-sm font-medium">Carregando cadência...</p>
        <p className="text-xs text-parchment/50 mt-1">Buscando plano + gerando mensagens IA</p>
      </div>
    );
  }

  // History só de hoje (00:00 BR em diante)
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const historyToday = history.filter((h) => (h.executed_at || 0) >= todayStart.getTime());

  // Agrupa queue + historyToday por enrollment_id
  const groups = new Map<string, LeadGroup>();

  for (const enr of enrollments) {
    const days = enr.automation?.cadence_config?.days || [];
    const currentDayCfg = days.find((d: any) => d.day === enr.current_day);
    // v13: filtra actions já tentadas hoje (success/skipped/failed) — não mostra como "vai fazer"
    const triedToday = enr.interactions_today || [];
    const triedByType: Record<string, number> = {};
    for (const t of triedToday) {
      if (t.day_number === enr.current_day) {
        triedByType[t.action_type] = (triedByType[t.action_type] || 0) + 1;
      }
    }
    const upcoming = (currentDayCfg?.actions || [])
      .map((a: any) => {
        const need = a.count || 1;
        const tried = triedByType[a.type] || 0;
        const remaining = Math.max(0, need - tried);
        return remaining > 0 ? { type: a.type as ActionType, count: remaining } : null;
      })
      .filter(Boolean) as { type: ActionType; count?: number }[];
    groups.set(enr.id, {
      enrollment_id: enr.id,
      instagram_username: enr.instagram_username,
      lead_id: enr.lead_id,
      lead_name: enr.lead?.name,
      cadence_name: enr.automation?.name,
      cadence_emoji: enr.automation?.emoji || '🔄',
      current_day: enr.current_day,
      total_days: enr.total_days,
      next_at: enr.next_action_at,
      pipeline_name: enr.lead?.stage?.pipeline?.name,
      stage_name: enr.lead?.stage?.name,
      done_today: triedToday,
      actions: [],
      upcoming_actions: upcoming,
    });
  }

  const addAction = (item: QueueItem) => {
    const key = item.enrollment_id || item.instagram_username;
    let g = groups.get(key);
    if (!g) {
      g = {
        enrollment_id: key,
        instagram_username: item.instagram_username,
        actions: [],
      };
      groups.set(key, g);
    }
    g.actions.push(item);
  };
  queue.forEach(addAction);
  historyToday.forEach(addAction);

  // Só mostra leads com algo planejado/feito hoje
  const leadsWithActions = Array.from(groups.values()).filter((g) => g.actions.length > 0);
  const leadsIdle = Array.from(groups.values()).filter((g) => g.actions.length === 0);

  if (leadsWithActions.length === 0 && enrollments.length === 0 && bootstrapped) {
    return (
      <div className="rounded-lg border border-parchment/10 bg-parchment/[0.02] p-6 text-center">
        <div className="text-3xl mb-2 opacity-50">📭</div>
        <p className="text-sm font-medium">Nenhum lead em cadência</p>
        <p className="text-[11px] text-parchment/50 mt-1">Inscreva leads pelo CRM (lead view → aba Social Selling) ou em /configuracoes/social-selling.</p>
      </div>
    );
  }

  // Classifica leads em 3 grupos:
  // 1. AÇÃO NECESSÁRIA — tem ação pending_approval / auto_ready / executing
  // 2. CONCLUÍDOS HOJE — todas ações são success/failed/skipped
  // 3. AGUARDANDO PRÓXIMO DIA — sem ação hoje mas enrollment ativo
  const leadsActive = leadsWithActions.filter((g) =>
    g.actions.some((a) => a.state === 'pending_approval' || a.state === 'auto_ready' || a.state === 'executing')
  );
  const leadsDoneToday = leadsWithActions.filter(
    (g) => !g.actions.some((a) => a.state === 'pending_approval' || a.state === 'auto_ready' || a.state === 'executing')
  );

  const totalPending = leadsActive.reduce((s, g) => s + g.actions.filter((a) => a.state === 'pending_approval').length, 0);

  return (
    <>
      {/* SEÇÃO 1 — AÇÃO NECESSÁRIA */}
      {leadsActive.length > 0 && (
        <div className="space-y-2">
          <SectionHeader
            color="amber"
            label={totalPending > 0 ? `Precisam de você (${totalPending})` : `Em andamento (${leadsActive.length})`}
            icon={totalPending > 0 ? '✋' : '⋯'}
          />
          {leadsActive.map((g) => (
            <LeadCard
              key={g.enrollment_id}
              group={g}
              expanded
              onApprove={onApprove}
              onApproveQuick={onApproveQuick}
              onSkip={onSkip}
            />
          ))}
        </div>
      )}

      {/* SEÇÃO 2 — JÁ FEITOS HOJE (colapsado por default) */}
      {leadsDoneToday.length > 0 && (
        <div className="space-y-1 pt-1">
          <SectionHeader color="moss" label={`Concluídos hoje (${leadsDoneToday.length})`} icon="✅" />
          <CollapsedDoneList groups={leadsDoneToday} />
        </div>
      )}

      {/* SEÇÃO 3 — VAZIO */}
      {leadsActive.length === 0 && leadsDoneToday.length === 0 && (
        <div className="rounded-lg border border-moss/20 bg-moss/[0.04] p-4 text-center">
          <div className="text-2xl mb-1">✅</div>
          <p className="text-sm font-medium">Tudo em dia</p>
          <p className="text-[11px] text-parchment/50 mt-1">
            {bootstrapped ? 'Nenhuma ação pendente. Aguardando próxima rodada.' : 'Carregando…'}
          </p>
        </div>
      )}

      {/* SEÇÃO 4 — Próximas: 3 buckets (pronto / aguardando 18h / agendado) */}
      {leadsIdle.length > 0 && (() => {
        const now = Date.now();
        // "Pronto pra rodar" = next_at <= now E tem ações pendentes (upcoming não vazio)
        const ready = leadsIdle.filter(
          (g) => g.next_at && new Date(g.next_at).getTime() <= now && (g.upcoming_actions || []).length > 0,
        );
        // "Aguardando próximo dia" = já fez tudo do dia atual mas precisa esperar 18h
        const waitingNextDay = leadsIdle.filter(
          (g) => (g.upcoming_actions || []).length === 0 && (g.done_today || []).length > 0 && (g.current_day ?? 0) < (g.total_days ?? 0),
        );
        // "Agendado pra depois" = next_at futuro
        const later = leadsIdle.filter(
          (g) => g.next_at && new Date(g.next_at).getTime() > now && !waitingNextDay.includes(g),
        );
        return (
          <>
            {ready.length > 0 && (
              <div className="space-y-1 pt-2">
                <div className="flex items-center justify-between px-1">
                  <SectionHeader color="amber" label={`Pronto pra rodar (${ready.length})`} icon="▶" />
                  {selectedIds.size > 0 && (
                    <button
                      onClick={runSelected}
                      disabled={runningSelected}
                      className="text-[10px] px-2 py-0.5 rounded bg-amber text-ink font-bold hover:bg-amber-light disabled:opacity-40"
                    >
                      {runningSelected ? '⋯' : `▶ Rodar ${selectedIds.size}`}
                    </button>
                  )}
                </div>
                {ready.map((g) => (
                  <IdleLeadRow
                    key={g.enrollment_id}
                    group={g}
                    selected={selectedIds.has(g.enrollment_id)}
                    onToggle={() => toggleSelected(g.enrollment_id)}
                  />
                ))}
              </div>
            )}
            {waitingNextDay.length > 0 && (
              <div className="space-y-1 pt-2">
                <SectionHeader color="moss" label={`Dia concluído — próximo D${waitingNextDay[0]?.current_day != null ? (waitingNextDay[0].current_day + 1) : ''} amanhã (${waitingNextDay.length})`} icon="⏳" />
                {waitingNextDay.map((g) => <IdleLeadRow key={g.enrollment_id} group={g} mode="waiting18h" />)}
              </div>
            )}
            {later.length > 0 && (
              <div className="space-y-1 pt-2">
                <SectionHeader color="parchment" label={`Agendado pra depois (${later.length})`} icon="⏰" muted />
                {later.slice(0, 12).map((g) => <IdleLeadRow key={g.enrollment_id} group={g} />)}
              </div>
            )}
          </>
        );
      })()}
    </>
  );
}

function SectionHeader({ label, icon, color, muted }: { label: string; icon: string; color: 'amber' | 'moss' | 'parchment'; muted?: boolean }) {
  const colorMap = { amber: 'text-amber', moss: 'text-moss', parchment: 'text-parchment/55' };
  return (
    <div className={`flex items-center gap-1.5 px-1 ${muted ? 'opacity-70' : ''}`}>
      <span className="text-xs">{icon}</span>
      <p className={`text-[10px] font-bold uppercase tracking-wider ${colorMap[color]}`}>{label}</p>
    </div>
  );
}

function CollapsedDoneList({ groups }: { groups: LeadGroup[] }) {
  const [expanded, setExpanded] = useState(false);
  if (!expanded) {
    // Mostra resumo: ícones de quem foi feito + botão expandir
    const total = groups.reduce((s, g) => s + g.actions.length, 0);
    return (
      <button
        onClick={() => setExpanded(true)}
        className="w-full rounded-md border border-moss/15 bg-moss/[0.04] hover:bg-moss/[0.08] transition-colors p-2 flex items-center gap-2 text-left"
      >
        <div className="flex -space-x-1 shrink-0">
          {groups.slice(0, 4).map((g, i) => (
            <div key={i} className="w-6 h-6 rounded-full bg-ink border border-parchment/15 flex items-center justify-center text-xs">
              {g.cadence_emoji || '🔄'}
            </div>
          ))}
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-[11px] font-medium truncate">
            {groups.slice(0, 2).map((g) => g.lead_name || `@${g.instagram_username}`).join(', ')}
            {groups.length > 2 && ` +${groups.length - 2}`}
          </p>
          <p className="text-[10px] text-parchment/50">{total} {total === 1 ? 'ação' : 'ações'} concluídas</p>
        </div>
        <span className="text-[10px] text-parchment/40">expandir ▾</span>
      </button>
    );
  }
  return (
    <div className="space-y-1">
      <button onClick={() => setExpanded(false)} className="text-[10px] text-parchment/50 hover:text-parchment px-1">
        ◂ recolher
      </button>
      {groups.map((g) => (
        <CompactLeadRow key={g.enrollment_id} group={g} />
      ))}
    </div>
  );
}

function CompactLeadRow({ group }: { group: LeadGroup }) {
  const [expanded, setExpanded] = useState(false);
  return (
    <div className="rounded-md bg-parchment/[0.02] border border-parchment/5 overflow-hidden">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full px-2.5 py-2 flex items-center gap-2 hover:bg-parchment/[0.04] transition-colors"
      >
        <span className="text-base shrink-0">{group.cadence_emoji || '🔄'}</span>
        <div className="flex-1 min-w-0 text-left">
          <p className="text-[11px] font-medium truncate">{group.lead_name || `@${group.instagram_username}`}</p>
          <p className="text-[10px] text-parchment/50">@{group.instagram_username} · D{group.current_day}</p>
        </div>
        <div className="flex gap-0.5 shrink-0">
          {group.actions.map((a, i) => (
            <span
              key={i}
              title={`${ACTION_LABELS[a.action_type]}: ${a.state}`}
              className={`text-[10px] ${a.state === 'success' ? 'opacity-100' : a.state === 'failed' ? 'opacity-40 grayscale' : 'opacity-30'}`}
            >
              {ACTION_ICONS[a.action_type]}
            </span>
          ))}
        </div>
        <span className="text-[9px] text-parchment/30">{expanded ? '▴' : '▾'}</span>
      </button>

      {expanded && (
        <div className="border-t border-parchment/5 bg-ink/30 px-2.5 py-2 space-y-1.5">
          {group.actions.map((a, i) => (
            <ActionDetailRow key={i} action={a} />
          ))}
        </div>
      )}
    </div>
  );
}

function ActionDetailRow({ action }: { action: any }) {
  const url = action.instagram_target || (action as QueueItem).target_url;
  const msg = action.content || (action as QueueItem).edited_message || (action as QueueItem).generated_message;
  const isPost = action.action_type === 'curtir_posts' || action.action_type === 'comentar_post';
  const linkLabel = isPost ? 'Ver post' : action.action_type === 'enviar_dm' ? 'Ver perfil' : 'Ver';
  const stateColor =
    action.state === 'success' || action.status === 'success' ? 'text-moss' :
    action.state === 'failed' || action.status === 'failed' ? 'text-rose' :
    'text-parchment/50';
  return (
    <div className="text-[11px] flex items-start gap-2">
      <span className="shrink-0 text-sm leading-tight">{ACTION_ICONS[action.action_type as ActionType]}</span>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="font-medium">{ACTION_LABELS[action.action_type as ActionType]}</span>
          <span className={`text-[9px] uppercase ${stateColor}`}>
            {action.state || action.status}
          </span>
        </div>
        {msg && (
          <p className="text-[10px] text-parchment/65 italic mt-0.5">"{msg}"</p>
        )}
        {url && url.startsWith('http') && (
          <a
            href={url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-[10px] text-amber hover:text-amber-light inline-flex items-center gap-0.5 mt-0.5"
          >
            🔗 {linkLabel} ↗
          </a>
        )}
        {action.error_message && (
          <p className="text-[9px] text-rose/70 mt-0.5">erro: {action.error_message}</p>
        )}
      </div>
    </div>
  );
}

function LeadCard({
  group,
  expanded,
  onApprove,
  onApproveQuick,
  onSkip,
}: {
  group: LeadGroup;
  expanded?: boolean;
  onApprove: (it: QueueItem) => void;
  onApproveQuick: (it: QueueItem) => void;
  onSkip: (it: QueueItem) => void;
}) {
  // Quando há ações ativas, foca nelas. Mostra resumo das já feitas.
  const active = group.actions.filter((a) => a.state === 'pending_approval' || a.state === 'auto_ready' || a.state === 'executing');
  const done = group.actions.filter((a) => a.state === 'success' || a.state === 'failed' || a.state === 'skipped');
  const showActions = expanded ? active : group.actions;

  return (
    <div className="rounded-lg border border-amber/20 bg-amber/[0.03] p-3 space-y-2">
      <div className="flex items-start gap-2">
        <div className="text-lg shrink-0 leading-none mt-0.5">{group.cadence_emoji || '🔄'}</div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold truncate">
            {group.lead_name || `@${group.instagram_username}`}
          </p>
          <p className="text-[11px] text-parchment/55">
            @{group.instagram_username}
            {group.cadence_name && <> · {group.cadence_name}</>}
            {group.current_day && <> · D{group.current_day}/{group.total_days}</>}
          </p>
          {group.pipeline_name && (
            <PipelineBadge pipeline={group.pipeline_name} stage={group.stage_name} leadId={group.lead_id} />
          )}
        </div>
        {expanded && done.length > 0 && (
          <div className="flex gap-0.5 shrink-0 mt-0.5" title={`${done.length} já feitas hoje`}>
            {done.map((a, i) => (
              <span
                key={i}
                className={`text-[11px] ${a.state === 'success' ? 'opacity-100' : 'opacity-40 grayscale'}`}
                title={`${ACTION_LABELS[a.action_type]}: ${a.state}`}
              >
                {ACTION_ICONS[a.action_type]}
              </span>
            ))}
          </div>
        )}
      </div>

      <div className="space-y-1.5 pt-1">
        {showActions.map((it) => (
          <ActionLine
            key={it.local_id}
            item={it}
            onApprove={onApprove}
            onApproveQuick={onApproveQuick}
            onSkip={onSkip}
          />
        ))}
      </div>
    </div>
  );
}

function ActionLine({
  item,
  onApprove,
  onApproveQuick,
  onSkip,
}: {
  item: QueueItem;
  onApprove: (it: QueueItem) => void;
  onApproveQuick: (it: QueueItem) => void;
  onSkip: (it: QueueItem) => void;
}) {
  const needsMessage = ['comentar_post', 'enviar_dm', 'responder_story', 'followup_story'].includes(item.action_type);
  const message = item.edited_message || item.generated_message;

  // Mapeia state → ícone visual
  const stateIcon =
    item.state === 'success' ? '✅' :
    item.state === 'failed' ? '❌' :
    item.state === 'skipped' ? '⏭' :
    item.state === 'executing' ? '⋯' :
    item.state === 'auto_ready' ? '⏳' :
    '✋'; // pending_approval

  const stateText =
    item.state === 'success' ? 'feito' :
    item.state === 'failed' ? `erro: ${item.error_message || ''}` :
    item.state === 'skipped' ? 'pulou' :
    item.state === 'executing' ? 'executando…' :
    item.state === 'auto_ready' ? 'na fila — vai rodar' :
    'precisa aprovação';

  const stateColor =
    item.state === 'success' ? 'text-moss' :
    item.state === 'failed' ? 'text-rose' :
    item.state === 'executing' ? 'text-amber animate-pulse' :
    item.state === 'auto_ready' ? 'text-amber' :
    item.state === 'pending_approval' ? 'text-parchment/85' :
    'text-parchment/45';

  return (
    <div className="rounded-md border border-parchment/5 bg-ink/30 px-2.5 py-2">
      <div className="flex items-center gap-2">
        <span className="text-sm">{ACTION_ICONS[item.action_type]}</span>
        <span className="text-xs flex-1 min-w-0 truncate">{ACTION_LABELS[item.action_type]}</span>
        <span className={`text-[10px] uppercase tracking-wider ${stateColor}`}>
          {stateIcon} {stateText}
        </span>
      </div>

      {item.state === 'pending_approval' && (
        <>
          {/* Links pro contexto: post/perfil IG + CRM (pra ver interações anteriores) */}
          <div className="flex items-center flex-wrap gap-x-3 gap-y-1 mt-1.5">
            {item.target_url && item.target_url.startsWith('http') && (
              <a
                href={item.target_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-[11px] text-amber hover:text-amber-light underline decoration-amber/30"
                title="Abre em nova aba pra conferir antes de aprovar"
              >
                🔗 {item.action_type === 'enviar_dm' ? 'Ver perfil IG' : 'Ver o post'} ↗
              </a>
            )}
            {item.lead_id && (
              <a
                href={crmLeadUrl(item.lead_id)}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-[11px] text-sage hover:text-sage-light underline decoration-sage/30"
                title="Ver lead no CRM (histórico, conversas, interações)"
              >
                💼 Lead no CRM ↗
              </a>
            )}
          </div>
          {needsMessage && (
            <div className="mt-2 rounded-md border border-parchment/10 bg-ink/40 p-2">
              {message ? (
                <p className="text-xs text-parchment/85 italic">"{message}"</p>
              ) : (
                <p className="text-xs text-parchment/40 italic">Gerando mensagem...</p>
              )}
            </div>
          )}
          <div className="flex items-center gap-1.5 mt-2">
            <button
              onClick={() => onApproveQuick(item)}
              disabled={needsMessage && !message}
              className="flex-1 px-2 py-1.5 text-xs rounded-md bg-moss text-parchment font-medium hover:opacity-90 transition-opacity disabled:opacity-40"
            >
              ✓ Aprovar
            </button>
            {needsMessage && (
              <button
                onClick={() => onApprove(item)}
                className="px-2 py-1.5 text-xs rounded-md border border-parchment/20 text-parchment/80 hover:bg-parchment/10 transition-colors"
                title="Editar mensagem antes de aprovar"
              >
                ✏️
              </button>
            )}
            {(item.action_type === 'comentar_post' || item.action_type === 'curtir_posts') && (
              <button
                onClick={async () => {
                  await new Promise<void>((r) =>
                    chrome.runtime.sendMessage(
                      { kind: 'REJECT_TARGET_AND_RETRY', local_id: item.local_id },
                      () => r(),
                    ),
                  );
                }}
                className="px-2 py-1.5 text-xs rounded-md border border-amber/30 text-amber hover:bg-amber/10 transition-colors"
                title="Pular esse post e pegar outro"
              >
                🔄
              </button>
            )}
            <button
              onClick={() => onSkip(item)}
              className="px-2 py-1.5 text-xs rounded-md border border-parchment/10 text-parchment/50 hover:text-rose hover:border-rose/40 transition-colors"
              title="Pular ação completamente"
            >
              ⏭
            </button>
          </div>
        </>
      )}

      {(item.state === 'success' || item.state === 'failed') && message && (
        <p className="mt-1.5 text-[11px] text-parchment/55 italic truncate">"{message}"</p>
      )}
    </div>
  );
}

function IdleLeadRow({
  group,
  selected,
  onToggle,
  mode,
}: {
  group: LeadGroup;
  selected?: boolean;
  onToggle?: () => void;
  mode?: 'waiting18h';
}) {
  const nextAt = group.next_at ? new Date(group.next_at) : null;
  const isReady = nextAt && nextAt.getTime() <= Date.now();
  // mode=waiting18h: cadência avança no DIA SEGUINTE BR (não 18h relativas)
  let nextLabel: string;
  if (mode === 'waiting18h') {
    nextLabel = 'amanhã';
  } else {
    nextLabel = nextAt
      ? isReady
        ? 'agora'
        : nextAt.toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
      : '—';
  }

  const upcoming = group.upcoming_actions || [];

  return (
    <div
      className={`rounded-md border transition-colors px-2.5 py-2 ${
        selected
          ? 'border-amber/50 bg-amber/[0.06]'
          : 'border-parchment/5 bg-parchment/[0.02] hover:bg-parchment/[0.04]'
      }`}
    >
      <div className="flex items-center gap-2">
        {onToggle && (
          <button
            onClick={onToggle}
            className={`w-4 h-4 rounded border shrink-0 flex items-center justify-center transition-colors ${
              selected ? 'bg-amber border-amber' : 'border-parchment/30 hover:border-amber'
            }`}
            title={selected ? 'Desmarcar' : 'Selecionar'}
          >
            {selected && <span className="text-[10px] text-ink leading-none">✓</span>}
          </button>
        )}
        <div className="text-base shrink-0">{group.cadence_emoji || '🔄'}</div>
        <div className="flex-1 min-w-0">
          <p className="text-xs font-medium truncate">
            {group.lead_name || `@${group.instagram_username}`}
          </p>
          <p className="text-[10px] text-parchment/55">
            @{group.instagram_username}
            {group.current_day && <> · D{group.current_day}/{group.total_days}</>}
          </p>
          {group.pipeline_name && (
            <PipelineBadge pipeline={group.pipeline_name} stage={group.stage_name} leadId={group.lead_id} />
          )}
        </div>
        <span className="text-[10px] text-parchment/40 shrink-0">{nextLabel}</span>
      </div>

      <div className="flex items-center gap-3 mt-1.5 pl-6 flex-wrap">
        {/* JÁ FEITO HOJE */}
        {group.done_today && group.done_today.length > 0 && (
          <div className="flex items-center gap-1">
            <span className="text-[9px] uppercase tracking-wider text-moss/70 shrink-0">já feito:</span>
            {group.done_today.map((d: any, i: number) => {
              const ico = ACTION_ICONS[d.action_type as ActionType] || '•';
              const stateIco = d.status === 'success' ? '✅' : d.status === 'skipped' ? '⏭' : '❌';
              const tip = `${ACTION_LABELS[d.action_type as ActionType] || d.action_type} · ${d.status}${d.error_message ? ` · ${d.error_message}` : ''}`;
              return (
                <span
                  key={i}
                  className="inline-flex items-center gap-0.5 text-[10px] bg-moss/[0.04] border border-moss/15 rounded px-1.5 py-0.5"
                  title={tip}
                >
                  <span>{ico}</span>
                  <span className="text-[8px]">{stateIco}</span>
                </span>
              );
            })}
          </div>
        )}
        {/* VAI FAZER (só o que falta) */}
        {upcoming.length > 0 && (
          <div className="flex items-center gap-1">
            <span className="text-[9px] uppercase tracking-wider text-parchment/40 shrink-0">vai fazer:</span>
            {upcoming.map((a, i) => (
              <span
                key={i}
                className="inline-flex items-center gap-0.5 text-[10px] bg-ink/40 border border-parchment/10 rounded px-1.5 py-0.5"
                title={ACTION_LABELS[a.type]}
              >
                <span>{ACTION_ICONS[a.type] || '•'}</span>
                {a.count && a.count > 1 && <span className="text-parchment/55">×{a.count}</span>}
              </span>
            ))}
          </div>
        )}
        {group.lead_id && (
          <a
            href={crmLeadUrl(group.lead_id)}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="text-[10px] text-sage hover:text-sage-light underline decoration-sage/30"
            title="Ver lead no CRM (histórico, conversas, interações)"
          >
            💼 CRM ↗
          </a>
        )}
      </div>
    </div>
  );
}

// ------------------------------------------------------------
// History tab
// ------------------------------------------------------------

function HistoryTab({ items }: { items: any[] }) {
  if (items.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="text-3xl mb-3 opacity-40">📜</div>
        <p className="text-sm text-parchment/70">Sem histórico hoje</p>
      </div>
    );
  }
  return (
    <>
      {items.slice(0, 100).map((item, i) => {
        const url = item.instagram_target || item.target_url;
        const msg = item.content || item.edited_message || item.generated_message;
        const status = item.status || item.state;
        const isPost = item.action_type === 'curtir_posts' || item.action_type === 'comentar_post';
        const at = item.executed_at;
        return (
          <div key={item.id || item.local_id || i} className="rounded-md border border-parchment/5 bg-parchment/[0.02] px-2.5 py-2">
            <div className="flex items-start gap-2">
              <div className="text-sm shrink-0 mt-0.5">{ACTION_ICONS[item.action_type as ActionType]}</div>
              <div className="flex-1 min-w-0">
                <p className="text-[11px] truncate">
                  {ACTION_LABELS[item.action_type as ActionType]}
                </p>
                {msg && <p className="text-[10px] text-parchment/65 italic mt-0.5">"{msg}"</p>}
                <div className="flex items-center gap-2 mt-0.5">
                  <p className="text-[10px] text-parchment/40">
                    {at ? new Date(at).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : ''}
                  </p>
                  {url && url.startsWith('http') && (
                    <a
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[10px] text-amber hover:text-amber-light"
                    >
                      🔗 {isPost ? 'Ver post' : 'Ver'} ↗
                    </a>
                  )}
                </div>
                {item.error_message && (
                  <p className="text-[9px] text-rose/70 mt-0.5 truncate" title={item.error_message}>erro: {item.error_message}</p>
                )}
              </div>
              <span className={`text-[9px] px-1.5 py-0.5 rounded-full font-bold uppercase shrink-0 ${
                status === 'success' ? 'bg-moss/20 text-moss' :
                status === 'failed' ? 'bg-rose/20 text-rose' :
                'bg-parchment/10 text-parchment/50'
              }`}>
                {status === 'success' ? 'OK' : status === 'failed' ? 'erro' : status === 'skipped' ? 'pulou' : status}
              </span>
            </div>
          </div>
        );
      })}
    </>
  );
}

// ------------------------------------------------------------
// Edit modal
// ------------------------------------------------------------

// ------------------------------------------------------------
// Live ticker (mostrar últimas linhas de log no topo)
// ------------------------------------------------------------

function CountdownBanner({ until, nextItem }: { until: number; nextItem?: QueueItem }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const remainSec = Math.max(0, Math.ceil((until - now) / 1000));
  const mm = Math.floor(remainSec / 60);
  const ss = remainSec % 60;
  const label = mm > 0 ? `${mm}m ${ss}s` : `${ss}s`;
  return (
    <div className="border-b border-amber/30 bg-amber/[0.06] px-3 py-2 flex items-center gap-2">
      <div className="text-base">⏳</div>
      <div className="flex-1 min-w-0">
        <p className="text-[11px] font-medium text-amber">Próxima ação em {label}</p>
        {nextItem && (
          <p className="text-[10px] text-parchment/60 truncate">
            {ACTION_ICONS[nextItem.action_type]} {ACTION_LABELS[nextItem.action_type]} · @{nextItem.instagram_username}
          </p>
        )}
      </div>
    </div>
  );
}

function LiveTicker({ entries, onExpand }: { entries: LiveLogEntry[]; onExpand: () => void }) {
  return (
    <button
      onClick={onExpand}
      className="w-full text-left border-b border-parchment/10 bg-parchment/[0.02] hover:bg-parchment/[0.05] transition-colors px-3 py-2 group"
      title="Abrir qualificação ao vivo"
    >
      <div className="flex items-center justify-between mb-1">
        <p className="text-[10px] text-parchment/40 uppercase tracking-wider flex items-center gap-1.5">
          <span className="inline-block w-1.5 h-1.5 rounded-full bg-rose animate-pulse" />
          Atividade ao vivo
        </p>
        <span className="text-[10px] text-amber/70 group-hover:text-amber transition-colors">expandir ↗</span>
      </div>
      <div className="space-y-0.5 max-h-20 overflow-hidden">
        {entries.map((e, i) => (
          <div key={i} className={`text-[11px] truncate ${
            e.level === 'error' ? 'text-rose' :
            e.level === 'success' ? 'text-moss' :
            e.level === 'step' ? 'text-amber' :
            'text-parchment/65'
          }`}>{e.message}</div>
        ))}
      </div>
    </button>
  );
}

// ------------------------------------------------------------
// Logs tab
// ------------------------------------------------------------

function LogsTab({ logs }: { logs: LiveLogEntry[] }) {
  if (logs.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="text-3xl mb-3 opacity-40">📜</div>
        <p className="text-sm text-parchment/70">Sem logs ainda</p>
      </div>
    );
  }
  return (
    <div className="space-y-1 font-mono">
      {logs.map((e, i) => (
        <div key={i} className="text-[10px] flex gap-2 leading-tight">
          <span className="text-parchment/30 shrink-0">{new Date(e.ts).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
          <span className={
            e.level === 'error' ? 'text-rose' :
            e.level === 'success' ? 'text-moss' :
            e.level === 'step' ? 'text-amber' :
            'text-parchment/65'
          }>{e.message}</span>
        </div>
      ))}
    </div>
  );
}

function EditModal({
  item,
  onCancel,
  onApprove,
  onRegenerate,
}: {
  item: QueueItem;
  onCancel: () => void;
  onApprove: (text: string) => void;
  onRegenerate: () => Promise<void>;
}) {
  const [text, setText] = useState(item.edited_message || item.generated_message || '');
  const [regenerating, setRegenerating] = useState(false);

  useEffect(() => {
    setText(item.edited_message || item.generated_message || '');
  }, [item.generated_message, item.edited_message]);

  const handleRegen = async () => {
    setRegenerating(true);
    await onRegenerate();
    setRegenerating(false);
  };

  return (
    <div className="fixed inset-0 bg-ink/90 z-50 flex items-center justify-center p-4">
      <div className="w-full max-w-sm rounded-xl border border-parchment/15 bg-ink shadow-2xl">
        <div className="p-4 border-b border-parchment/10 flex items-center justify-between">
          <h2 className="text-sm font-semibold flex items-center gap-2">
            ✏️ Editar mensagem
          </h2>
          <button onClick={onCancel} className="text-parchment/50 hover:text-parchment text-base">✕</button>
        </div>
        <div className="p-4 space-y-3">
          <div>
            <p className="text-[11px] text-parchment/60 mb-1">@{item.instagram_username} · {ACTION_LABELS[item.action_type]} · D{item.day}</p>
          </div>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={4}
            className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded-lg p-3 text-sm leading-relaxed outline-none resize-none"
          />
          <p className="text-[10px] text-parchment/40">{text.length}/280 caracteres</p>
          <div className="flex gap-2">
            <button
              onClick={handleRegen}
              disabled={regenerating}
              className="flex-1 px-3 py-2 text-xs rounded-md border border-parchment/20 text-parchment/80 hover:bg-parchment/10 transition-colors disabled:opacity-50"
            >
              {regenerating ? '⋯ Gerando' : '🔄 Regenerar IA'}
            </button>
            <button
              onClick={() => onApprove(text)}
              disabled={text.trim().length === 0}
              className="flex-1 px-3 py-2 text-xs rounded-md bg-amber text-ink font-semibold hover:bg-amber-light transition-colors disabled:opacity-40"
            >
              ✓ Aprovar
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

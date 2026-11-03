// ============================================================
// Options page MÍNIMA — toda configuração de comportamento mora no CRM.
// Aqui só: preferências do device (notificação push + atalho pro CRM).
// ============================================================
import { useEffect, useState } from 'react';
import type { ExtensionConfig, ExtMessage } from '../shared/types';
import { DEFAULT_CONFIG } from '../shared/types';
import { CRM_BASE_URL } from '../shared/env';

export function App() {
  const [cfg, setCfg] = useState<ExtensionConfig>(DEFAULT_CONFIG);
  const [loading, setLoading] = useState(true);
  const [savedAt, setSavedAt] = useState<number | null>(null);

  const send = (msg: ExtMessage) =>
    new Promise<any>((resolve) => chrome.runtime.sendMessage(msg, resolve));

  useEffect(() => {
    (async () => {
      const r = await send({ kind: 'GET_CONFIG' });
      if (r?.config) setCfg(r.config);
      setLoading(false);
    })();
  }, []);

  const save = async () => {
    await send({ kind: 'SAVE_CONFIG', config: cfg });
    setSavedAt(Date.now());
  };

  const openCrm = (path: string) => {
    const url = (cfg.crmBaseUrl || CRM_BASE_URL).replace(/\/+$/, '') + path;
    chrome.tabs.create({ url });
  };

  if (loading) return <div className="p-8 text-parchment/60">Carregando...</div>;

  return (
    <div className="min-h-screen bg-ink text-parchment">
      <div className="max-w-xl mx-auto px-6 py-10">
        <header className="mb-8">
          <h1 className="text-2xl font-serif italic flex items-center gap-3">
            📷 <span>IAP Social Selling</span>
          </h1>
          <p className="text-sm text-parchment/60 mt-1">Preferências deste navegador</p>
        </header>

        {/* Aviso: toda configuração mora no CRM */}
        <div className="rounded-xl border border-amber/30 bg-amber/[0.05] p-4 mb-6">
          <p className="text-sm font-bold text-amber mb-2">⚙️ Configurações ficam no CRM</p>
          <p className="text-xs text-parchment/75 mb-3">
            Toda configuração de cadência, ICP, tom de voz, limites e aprovação de ações é editada no CRM.
            Esta extensão só executa.
          </p>
          <button
            onClick={() => openCrm('/configuracoes/social-selling')}
            className="px-3 py-1.5 rounded bg-amber text-ink text-xs font-semibold hover:bg-amber-light"
          >
            📅 Abrir configurações no CRM →
          </button>
        </div>

        {/* APENAS notificação push (preferência do device) */}
        <section className="rounded-xl border border-parchment/10 bg-parchment/[0.02] p-4 space-y-3">
          <h2 className="text-xs font-bold uppercase tracking-wider text-parchment/70">
            🔔 Notificações do navegador
          </h2>
          <Toggle
            label="Avisar quando tiver ação pra aprovar"
            description="Notificação push do Chrome quando a IA gerar uma DM/comentário esperando sua revisão"
            value={cfg.notifyOnApprovalNeeded}
            onChange={(v) => setCfg({ ...cfg, notifyOnApprovalNeeded: v })}
          />
        </section>

        {/* SAVE */}
        <div className="mt-8 flex items-center justify-between">
          <p className="text-xs text-parchment/40">
            {savedAt ? `Salvo às ${new Date(savedAt).toLocaleTimeString('pt-BR')}` : ' '}
          </p>
          <button
            onClick={save}
            className="px-4 py-2 rounded bg-amber text-ink text-sm font-semibold hover:bg-amber-light"
          >
            💾 Salvar preferências
          </button>
        </div>
      </div>
    </div>
  );
}

function Toggle({ label, description, value, onChange }: { label: string; description?: string; value: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex items-start justify-between gap-3 py-2 cursor-pointer">
      <div className="flex-1 min-w-0">
        <p className="text-sm">{label}</p>
        {description && <p className="text-[11px] text-parchment/50 mt-0.5">{description}</p>}
      </div>
      <button
        onClick={() => onChange(!value)}
        className={`relative w-11 h-6 rounded-full transition-colors shrink-0 ${value ? 'bg-amber' : 'bg-parchment/20'}`}
      >
        <span
          className={`absolute top-0.5 w-5 h-5 rounded-full bg-ink transition-transform ${value ? 'translate-x-5' : 'translate-x-0.5'}`}
        />
      </button>
    </label>
  );
}

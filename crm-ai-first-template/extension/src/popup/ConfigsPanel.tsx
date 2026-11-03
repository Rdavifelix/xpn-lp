// ============================================================
// Painel minimalista — extensão é "burra", configuração mora no CRM
// Aqui só: atalhos pro CRM + @ Instagram do dono + preferências locais
// ============================================================
import { useEffect, useState } from 'react';
import { getConfig, setConfig } from '../shared/storage';
import { CRM_BASE_URL } from '../shared/env';
import { signOut, getSession } from '../shared/auth';

export function ConfigsPanel() {
  const [ownerUsername, setOwnerUsername] = useState('');
  const [crmUrl, setCrmUrl] = useState('');
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [userEmail, setUserEmail] = useState<string | undefined>();

  useEffect(() => {
    (async () => {
      const cfg = await getConfig();
      setOwnerUsername(cfg.ownerUsername || '');
      setCrmUrl(cfg.crmBaseUrl || CRM_BASE_URL);
      const session = await getSession();
      setUserEmail(session?.user?.email);
    })();
  }, []);

  const saveLocal = async () => {
    const cfg = await getConfig();
    await setConfig({ ...cfg, ownerUsername: ownerUsername.trim().replace(/^@/, ''), crmBaseUrl: crmUrl.trim() });
    setSavedAt(Date.now());
  };

  const openCrm = (path: string) => {
    const url = (crmUrl || CRM_BASE_URL).replace(/\/+$/, '') + path;
    chrome.tabs.create({ url });
  };

  return (
    <div className="space-y-4 p-2">
      {/* Conta logada */}
      <div className="rounded-xl border border-moss/20 bg-moss/[0.05] p-3">
        <p className="text-[10px] uppercase tracking-wider text-moss font-bold mb-1">✅ Conectado ao CRM</p>
        <p className="text-xs text-parchment/85 truncate">{userEmail || '—'}</p>
        <button onClick={signOut} className="text-[10px] text-parchment/50 hover:text-rose mt-1">Sair</button>
      </div>

      {/* Aviso: configuração mora no CRM */}
      <div className="rounded-xl border border-amber/25 bg-amber/[0.05] p-3 space-y-2">
        <p className="text-[11px] font-bold uppercase tracking-wider text-amber">⚙️ Configurações</p>
        <p className="text-[11px] text-parchment/75 leading-relaxed">
          A extensão só <strong>executa</strong> as ações. Toda configuração (cadências, ICP, pipeline, tom de voz, limites) mora no CRM.
        </p>

        <div className="space-y-1.5 pt-1">
          <ShortcutBtn onClick={() => openCrm('/configuracoes/social-selling')} emoji="📅" label="Editar cadências" hint="dias × ações, pipeline destino, mapeamento de etapas" />
          <ShortcutBtn onClick={() => openCrm('/configuracoes/social-selling')} emoji="🎯" label="ICP / qualificação IA" hint="quem deve virar lead" />
          <ShortcutBtn onClick={() => openCrm('/configuracoes/social-selling')} emoji="💬" label="Tom de voz da IA" hint="como ela escreve DMs e comentários" />
          <ShortcutBtn onClick={() => openCrm('/configuracoes/social-selling')} emoji="⚡" label="Limites e horários" hint="volume diário, working hours, delays" />
          <ShortcutBtn onClick={() => openCrm('/comercial/pipeline')} emoji="🧱" label="Pipeline + etapas" hint="seu funil de prospecção" />
        </div>
      </div>

      {/* Local: APENAS @ Instagram (por device/browser, não tenant) */}
      <div className="rounded-xl border border-parchment/10 bg-parchment/[0.02] p-3 space-y-3">
        <p className="text-[11px] font-bold uppercase tracking-wider text-parchment/70">📷 Esta extensão</p>

        <Field
          label="@ do seu Instagram"
          hint="A conta que essa extensão vai usar pra prospectar (sem o @)"
        >
          <input
            value={ownerUsername}
            onChange={(e) => setOwnerUsername(e.target.value.replace(/^@/, ''))}
            placeholder="seu_usuario_ig"
            className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded px-2 py-1.5 text-xs outline-none"
          />
        </Field>

        <Field
          label="URL do CRM (web)"
          hint="Usado pros atalhos acima e links 'abrir lead'"
        >
          <input
            type="url"
            value={crmUrl}
            onChange={(e) => setCrmUrl(e.target.value)}
            placeholder={CRM_BASE_URL}
            className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded px-2 py-1.5 text-xs outline-none"
          />
        </Field>

        <div className="flex items-center justify-between pt-1">
          <p className="text-[10px] text-parchment/40">
            {savedAt ? `Salvo ${new Date(savedAt).toLocaleTimeString('pt-BR')}` : ' '}
          </p>
          <button
            onClick={saveLocal}
            className="px-3 py-1.5 rounded bg-amber text-ink text-[11px] font-semibold hover:bg-amber-light"
          >
            💾 Salvar
          </button>
        </div>
      </div>

      {/* Avançadas (preferências auto/aprovar) na options page */}
      <div className="text-center pt-1">
        <button
          onClick={() => chrome.runtime.openOptionsPage()}
          className="text-[10px] text-parchment/50 hover:text-parchment underline"
        >
          Preferências avançadas (auto / aprovar) →
        </button>
      </div>
    </div>
  );
}

function ShortcutBtn({ onClick, emoji, label, hint }: { onClick: () => void; emoji: string; label: string; hint: string }) {
  return (
    <button
      onClick={onClick}
      className="w-full flex items-center gap-2.5 px-2.5 py-2 rounded-md bg-parchment/[0.03] hover:bg-parchment/[0.06] border border-parchment/10 hover:border-amber/30 transition-all text-left group"
    >
      <span className="text-base shrink-0">{emoji}</span>
      <div className="flex-1 min-w-0">
        <p className="text-[11px] font-medium text-parchment/90 group-hover:text-amber transition-colors">{label}</p>
        <p className="text-[10px] text-parchment/45 truncate">{hint}</p>
      </div>
      <span className="text-[10px] text-parchment/40 group-hover:text-amber shrink-0">↗</span>
    </button>
  );
}

function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-[10px] font-medium text-parchment/75 block mb-1">{label}</label>
      {children}
      {hint && <p className="text-[9px] text-parchment/40 mt-1">{hint}</p>}
    </div>
  );
}

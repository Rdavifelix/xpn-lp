import { useState } from 'react';
import { signIn } from '../shared/auth';

export function LoginScreen({ onLogged }: { onLogged: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr(null);
    setLoading(true);
    try {
      await signIn(email.trim(), password);
      onLogged();
    } catch (e: any) {
      setErr(e.message || 'Falha no login');
    }
    setLoading(false);
  };

  return (
    <div className="flex flex-col h-screen w-full">
      <div className="flex-1 flex flex-col items-center justify-center px-6">
        <div className="text-3xl mb-3">📷</div>
        <h1 className="text-base font-serif italic mb-1">IAP Social Selling</h1>
        <p className="text-[11px] text-parchment/60 mb-6">Login com sua conta do CRM</p>

        <form onSubmit={submit} className="w-full max-w-xs space-y-3">
          <input
            type="email"
            required
            placeholder="email@empresa.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded-md px-3 py-2 text-sm outline-none"
            autoComplete="email"
          />
          <input
            type="password"
            required
            placeholder="senha"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full bg-parchment/[0.04] border border-parchment/15 focus:border-amber rounded-md px-3 py-2 text-sm outline-none"
            autoComplete="current-password"
          />
          {err && (
            <div className="text-[11px] text-rose bg-rose/10 border border-rose/20 rounded p-2">
              {err}
            </div>
          )}
          <button
            type="submit"
            disabled={loading || !email || !password}
            className="w-full px-3 py-2 text-sm rounded-md bg-amber text-ink font-semibold hover:bg-amber-light disabled:opacity-40"
          >
            {loading ? 'Entrando…' : 'Entrar'}
          </button>
        </form>

        <p className="text-[10px] text-parchment/40 mt-4 text-center max-w-xs">
          Use a mesma conta do seu CRM. A sessão fica salva neste navegador.
        </p>
      </div>
    </div>
  );
}

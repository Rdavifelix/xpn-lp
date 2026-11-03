import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import ConnectionShell, { flowButton } from '@/components/mcp/ConnectionShell';

export default function McpConnect() {
  const [copied, setCopied] = useState(false);
  const rawUrl = import.meta.env.VITE_MCP_PUBLIC_URL as string | undefined;
  let url: string | null = null;
  try {
    const parsed = new URL(rawUrl ?? '');
    if (parsed.protocol === 'https:' && parsed.pathname === '/mcp' && !parsed.search && !parsed.hash && !parsed.username && !parsed.password) url = parsed.href;
  } catch { /* URL ainda não publicada */ }
  return <ConnectionShell step={3} title="Sua IA, dentro da operação" description="Conecte Claude ou ChatGPT e transforme sua próxima conversa em um processo pronto no CRM.">
      <Link to="/configuracoes" className="text-sm underline">Voltar às configurações</Link>

      {!url ? <p role="status">A conexão do CRM com Claude e ChatGPT está em preparação. O endereço aparecerá aqui depois da publicação.</p> : <>
        <p>Adicione este endereço como conector personalizado na sua IA. Depois, entre com sua conta do CRM e autorize o acesso à sua empresa.</p>
        <div className="rounded-2xl border border-amber-400/20 bg-amber-400/5 p-4 space-y-3">
          <p className="break-all font-mono text-sm">{url}</p>
          <Button className={flowButton} onClick={async () => {
            try { await navigator.clipboard.writeText(url!); setCopied(true); }
            catch { toast.error('Não foi possível copiar. Selecione o endereço acima.'); }
          }}>{copied ? 'Endereço copiado' : 'Copiar endereço'}</Button>
        </div>
        <ol className="list-decimal pl-5 space-y-3 text-sm leading-6 text-slate-400">
          <li>No Claude, abra Conectores e adicione um conector personalizado com esse endereço. Use a configuração automática de OAuth.</li>
          <li>No ChatGPT, habilite o modo desenvolvedor e cadastre um aplicativo com esse endereço e OAuth automático. A disponibilidade depende do plano e das permissões da sua organização.</li>
          <li>Entre na página do CRM que abrir e confira a empresa antes de autorizar.</li>
          <li>Na conversa, selecione o conector e peça: “Consulte minha empresa e liste meus funis”.</li>
        </ol>
        {(import.meta.env.VITE_MCP_CLAUDE_CLIENT_ID || import.meta.env.VITE_MCP_CHATGPT_CLIENT_ID) && <details className="rounded-xl border border-white/10 p-4 space-y-2 text-sm text-slate-400">
          <summary className="cursor-pointer">Configuração manual, se solicitada pela IA</summary>
          <p>Use estes identificadores apenas se a conexão automática não funcionar. Estes são clientes públicos; deixe a senha do cliente em branco.</p>
          {import.meta.env.VITE_MCP_CLAUDE_CLIENT_ID && <p className="break-all">Claude — Client ID: <code>{import.meta.env.VITE_MCP_CLAUDE_CLIENT_ID}</code></p>}
          {import.meta.env.VITE_MCP_CHATGPT_CLIENT_ID && <p className="break-all">ChatGPT — Client ID: <code>{import.meta.env.VITE_MCP_CHATGPT_CLIENT_ID}</code></p>}
        </details>}
        <p className="text-xs leading-5 text-slate-500">Você pode desconectar o conector nas configurações da sua IA. Não envie sua senha na conversa.</p>
      </>}
  </ConnectionShell>;
}

import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { z } from 'zod';

export interface Config {
  publicUrl: string; supabaseUrl: string; publishableKey: string;
  clientIds: string[]; allowDynamicClients?: boolean; host: string; port: number;
}

export function readConfig(env: NodeJS.ProcessEnv): Config {
  const publicUrl = new URL(env.MCP_PUBLIC_URL ?? 'http://127.0.0.1:8081/mcp');
  const supabaseUrl = new URL(env.SUPABASE_URL ?? '');
  const local = (u: URL) => ['127.0.0.1', 'localhost'].includes(u.hostname);
  for (const url of [publicUrl, supabaseUrl]) {
    if (url.protocol !== 'https:' && !(url.protocol === 'http:' && local(url))) throw new Error('HTTPS obrigatório fora do localhost.');
    if (url.username || url.password || url.search || url.hash) throw new Error('URL não pode conter credenciais, query ou fragmento.');
  }
  if (publicUrl.pathname !== '/mcp') throw new Error('MCP_PUBLIC_URL deve terminar em /mcp.');
  const publishableKey = env.SUPABASE_PUBLISHABLE_KEY?.trim();
  if (!publishableKey || publishableKey.startsWith('sb_secret_')) throw new Error('Configure uma chave publicável, nunca uma chave secreta.');
  if (publishableKey.split('.').length === 3) {
    const payload = JSON.parse(Buffer.from(publishableKey.split('.')[1], 'base64url').toString());
    if (payload.role !== 'anon') throw new Error('Somente a chave anon/publicável é aceita.');
  }
  const clientIds = (env.MCP_OAUTH_CLIENT_IDS ?? '').split(',').map(x => x.trim()).filter(Boolean);
  const allowDynamicClients = env.MCP_DYNAMIC_CLIENTS === 'true';
  if (!clientIds.length && !allowDynamicClients) throw new Error('Cadastre ao menos um cliente OAuth aprovado em MCP_OAUTH_CLIENT_IDS.');
  const port = z.coerce.number().int().min(1).max(65535).parse(env.PORT ?? 8081);
  return { publicUrl: publicUrl.href, supabaseUrl: supabaseUrl.origin, publishableKey, clientIds, allowDynamicClients, port, host: env.MCP_HOST ?? '127.0.0.1' };
}

export function tokenVerifier(config: Config, keys?: JWTVerifyGetKey) {
  const issuer = `${config.supabaseUrl}/auth/v1`;
  const jwks = keys ?? createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`));
  return async (token: string) => {
    const { payload } = await jwtVerify(token, jwks, {
      issuer, audience: config.publicUrl, algorithms: ['ES256', 'RS256'],
      requiredClaims: ['sub', 'exp', 'iat', 'client_id', 'session_id'],
    });
    if (!z.string().uuid().safeParse(payload.sub).success || !z.string().uuid().safeParse(payload.session_id).success || payload.role !== 'authenticated' ||
        typeof payload.client_id !== 'string' || (!config.clientIds.includes(payload.client_id) && !(config.allowDynamicClients && z.string().uuid().safeParse(payload.client_id).success))) {
      throw new Error('Cliente OAuth ou usuário inválido.');
    }
    return payload;
  };
}

export const contextSchema = z.object({
  user_id: z.string().uuid(), tenant_id: z.string().uuid(), tenant_name: z.string(),
  member_id: z.string().uuid(), role: z.string(), can_write: z.boolean(),
});
export type TenantContext = z.infer<typeof contextSchema>;

// Somente RPCs fixas; sem service_role, SQL livre ou nome de tabela vindo do LLM.
export function rpcClient(config: Config, token: string) {
  return async (name: 'web_pages_admin' | 'social-api' | 'zernio-api' | 'inbound_admin' | 'mcp-whatsapp' | 'mcp_automation' | 'mcp_agent_admin' | 'mcp_configure_operational_skill' | 'mcp-playground-test' | 'mcp_playground_job' | 'agent-runner' | 'mcp_agent_operation' | 'mcp-provision-member' | 'mcp_team' | 'playground_check_availability' | 'forms_admin' | 'mcp_history' | 'mcp_agent_edit' | 'mcp_crm' | 'mcp_agent_setup' | 'mcp_implementation' | 'mcp_context' | 'mcp_list_pipelines' | 'mcp_create_pipeline' | 'mcp_list_agents' | 'mcp_create_agent_draft', args: Record<string, unknown> = {}) => {
    const response = await fetch(`${config.supabaseUrl}/${['social-api','zernio-api','mcp-whatsapp','mcp-provision-member','agent-runner','mcp-playground-test'].includes(name) ? `functions/v1/${name}` : `rest/v1/rpc/${name}`}`, {
      method: 'POST', headers: { apikey: config.publishableKey, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args), signal: AbortSignal.timeout(name==='agent-runner'?90_000:(name==='mcp-whatsapp'||name==='zernio-api'||name==='social-api')?55_000:15_000),
    });
    if (!response.ok) {
      const error=await response.json().catch(()=>null) as {code?:string;message?:string}|null;
      if(name === 'social-api' || name === 'zernio-api' || name === 'mcp-provision-member' || name === 'mcp-whatsapp') throw new Error((error as {error?:string})?.error || 'Provisionamento recusado');
      if(error?.code && ['22023','40001','42501','P0002'].includes(error.code) && error.message && error.message.length<500) throw new Error(error.message);
      throw new Error('CRM recusou a operação. Verifique o vínculo ativo, as permissões e a instalação do MCP.');
    }
    if(name==='agent-runner'){
      const body=await response.text();
      const events=body.split('\n').filter(line=>line.startsWith('data: ')).map(line=>{try{return JSON.parse(line.slice(6));}catch{return null;}}).filter(Boolean);
      return {events,completed:events.some(e=>e.type==='done'),text:events.filter(e=>e.type==='text.delta').map(e=>e.delta??e.text??'').join('')};
    }
    const result=await response.json();
    if(name==='web_pages_admin' && result && typeof result==='object' && !Array.isArray(result) && result.key){const origin=new URL(config.publicUrl).origin;return {...result,tracking_code:`<script defer src="${origin}/crm-tracker.js" data-page="${result.id}" data-key="${result.key}" data-endpoint="${config.supabaseUrl}/functions/v1/web-track"></script>`};}
    if(name==='inbound_admin' && result && typeof result==='object' && !Array.isArray(result) && result.token) return {...result,receive_url:`${config.supabaseUrl}/functions/v1/receive-channel?key=${result.token}`,submission_method:'POST',required_headers:{'Content-Type':'application/json','X-Request-Id':'UUID estável por envio'}};
    return result;
  };
}

// Helper para ler chaves de integração da tabela `config` (preenchidas pelo
// admin em /configuracoes > Integrações > API Keys). Cai em Deno.env como
// fallback (útil pra dev local). NUNCA hardcode valores.
//
// Multi-tenant (Onda B2): a tabela `config` guarda os valores GLOBAIS/default
// da instalação; overrides por tenant vivem em `tenant_config_overrides`.
// Passe `tenantId` pra resolver override do tenant primeiro, com fallback na
// linha global. Sem `tenantId`, comportamento single-tenant idêntico ao antigo.
//
// Uso:
//   import { getIntegrationKey } from "../_shared/config.ts";
//   const anthropicKey = await getIntegrationKey(supabase, "ANTHROPIC_API_KEY");
//   // ou, escopado por tenant:
//   const key = await getIntegrationKey(supabase, "ANTHROPIC_API_KEY", tenantId);

// Keep this helper compatible with both the JSR and ESM builds used by legacy
// Edge Functions. Their SupabaseClient classes are structurally compatible at
// runtime but nominally incompatible in TypeScript because of protected fields.
interface SupabaseQueryClient {
  from(table: string): any;
}

// Cache em memória (por processo) pra evitar query a cada chamada da função.
// TTL curto pra refletir mudanças do admin sem reiniciar a função.
// Chave do cache = `${tenantId || "global"}:${key}`.
const TTL_MS = 60_000; // 60 segundos
const cache = new Map<string, { value: string | null; expiresAt: number }>();

function cacheKey(key: string, tenantId?: string | null): string {
  return `${tenantId || "global"}:${key}`;
}

export async function getIntegrationKey(
  supabase: SupabaseQueryClient,
  key: string,
  tenantId?: string | null
): Promise<string | null> {
  const ck = cacheKey(key, tenantId);

  // 1. Cache
  const cached = cache.get(ck);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.value;
  }

  // 2. Override do tenant (se tenantId informado)
  if (tenantId) {
    try {
      const { data } = await supabase
        .from("tenant_config_overrides")
        .select("value")
        .eq("tenant_id", tenantId)
        .eq("key", key)
        .maybeSingle();

      if (data?.value && String(data.value).trim().length > 0) {
        const value = String(data.value).trim();
        cache.set(ck, { value, expiresAt: Date.now() + TTL_MS });
        return value;
      }
    } catch (err: any) {
      console.warn(
        `[getIntegrationKey] Erro lendo override ${tenantId}/${key}:`,
        err
      );
    }
  }

  // 3. Tabela config global (fonte primária — admin preenche pela UI)
  try {
    const { data } = await supabase
      .from("config")
      .select("value")
      .eq("key", key)
      .maybeSingle();

    if (data?.value && String(data.value).trim().length > 0) {
      const value = String(data.value).trim();
      cache.set(ck, { value, expiresAt: Date.now() + TTL_MS });
      return value;
    }
  } catch (err: any) {
    console.warn(`[getIntegrationKey] Erro lendo config.${key}:`, err);
  }

  // 4. Env var (fallback pra dev/deploy manual)
  const envValue = Deno.env.get(key);
  if (envValue && envValue.trim().length > 0) {
    const value = envValue.trim();
    cache.set(ck, { value, expiresAt: Date.now() + TTL_MS });
    return value;
  }

  // Não encontrado
  cache.set(ck, { value: null, expiresAt: Date.now() + TTL_MS });
  return null;
}

// Invalida o cache para uma chave específica (em todos os tenants) ou tudo.
// Útil quando o admin atualiza a chave e não quer esperar o TTL.
export function invalidateIntegrationKeyCache(key?: string) {
  if (key) {
    const suffix = `:${key}`;
    for (const ck of cache.keys()) {
      if (ck.endsWith(suffix)) cache.delete(ck);
    }
  } else {
    cache.clear();
  }
}

// ─── PIPELINE_ROLES ─────────────────────────────────────────────────────────
// Key JSON na tabela config que mapeia papéis de pipeline/estágio para UUIDs
// do tenant. Formato:
//   {
//     "pre_vendas": "<uuid do pipeline de pré-vendas>",
//     "closer": "<uuid do pipeline de closers>",
//     "webinario": "<uuid do pipeline de webinário>",
//     "stages": { "call_agendada": "<uuid>", "no_show": "<uuid>", ... }
//   }
// Nunca hardcode UUIDs de pipeline/estágio nas functions — leia daqui.
export interface PipelineRoles {
  pre_vendas?: string;
  closer?: string;
  webinario?: string;
  stages?: Record<string, string>;
}

export async function getPipelineRoles(
  supabase: SupabaseQueryClient,
  tenantId?: string | null
): Promise<PipelineRoles | null> {
  const raw = await getIntegrationKey(supabase, "PIPELINE_ROLES", tenantId);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object") return parsed as PipelineRoles;
    return null;
  } catch (err: any) {
    console.warn("[getPipelineRoles] config.PIPELINE_ROLES não é JSON válido:", err);
    return null;
  }
}

// Helper que exige a chave (lança erro se não tiver) — usar quando a função
// não consegue operar sem ela.
export async function requireIntegrationKey(
  supabase: SupabaseQueryClient,
  key: string,
  tenantId?: string | null
): Promise<string> {
  const value = await getIntegrationKey(supabase, key, tenantId);
  if (!value) {
    throw new Error(
      `Integração "${key}" não configurada. Peça ao administrador ` +
      `preencher em /configuracoes > Integrações > API Keys.`
    );
  }
  return value;
}

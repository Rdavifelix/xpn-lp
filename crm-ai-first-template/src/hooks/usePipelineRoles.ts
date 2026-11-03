import { useMemo } from 'react';
import {
  getSessionTenantId,
  readTenantConfigValue,
  useTenantConfigValue,
} from '@/lib/tenant-config';

/**
 * Papéis de pipeline lidos da configuração do tenant (key `PIPELINE_ROLES`):
 * `tenant_config_overrides` do tenant sobrepõe o valor global em `config`.
 *
 * value = JSON:
 * {
 *   "pre_vendas": "<uuid do pipeline de pré-vendas>",
 *   "closer": "<uuid do pipeline de closer>",
 *   "webinario": "<uuid do pipeline de webinário>",
 *   "stages": {
 *     "closer_call_agendada": "<uuid>",
 *     "closer_noshow": "<uuid>",
 *     "closer_call_realizada": "<uuid>",
 *     "refund_closer": "<uuid>",
 *     "refund_webinario": "<uuid>"
 *   }
 * }
 *
 * Tudo opcional: quando a key não existe (ou está incompleta), as features
 * que dependem dela degradam graciosamente (ficam escondidas/inativas).
 */
export interface PipelineRoles {
  preVendas?: string;
  closer?: string;
  webinario?: string;
  stages: Record<string, string>;
}

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 min

export function parsePipelineRoles(raw: string | null | undefined): PipelineRoles {
  if (!raw) return { stages: {} };
  try {
    const parsed = JSON.parse(raw);
    const stages: Record<string, string> = {};
    if (parsed?.stages && typeof parsed.stages === 'object') {
      for (const [k, v] of Object.entries(parsed.stages)) {
        if (typeof v === 'string' && v) stages[k] = v;
      }
    }
    return {
      preVendas: typeof parsed?.pre_vendas === 'string' && parsed.pre_vendas ? parsed.pre_vendas : undefined,
      closer: typeof parsed?.closer === 'string' && parsed.closer ? parsed.closer : undefined,
      webinario: typeof parsed?.webinario === 'string' && parsed.webinario ? parsed.webinario : undefined,
      stages,
    };
  } catch {
    return { stages: {} };
  }
}

// Cache module-level pra uso fora de componentes React (funções async soltas).
// Chaveado por tenant: um tenant nunca lê o valor cacheado de outro.
const configCache = new Map<string, { value: string | null; at: number }>();

/**
 * Lê 1 key da configuração fora de componentes React (com cache de 5min).
 * O tenant vem do JWT da sessão atual (`app_metadata.tenant_id`), a menos que
 * seja passado explicitamente.
 */
export async function fetchConfigValue(key: string, tenantId?: string | null): Promise<string | null> {
  const tid = tenantId === undefined ? await getSessionTenantId() : tenantId;
  const cacheKey = `${tid ?? 'anon'}:${key}`;
  const hit = configCache.get(cacheKey);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.value;
  let value: string | null = null;
  try {
    value = await readTenantConfigValue(key, tid);
  } catch {
    value = null;
  }
  configCache.set(cacheKey, { value, at: Date.now() });
  return value;
}

/** Versão não-hook de usePipelineRoles, pra funções async fora de componentes. */
export async function fetchPipelineRoles(tenantId?: string | null): Promise<PipelineRoles> {
  return parsePipelineRoles(await fetchConfigValue('PIPELINE_ROLES', tenantId));
}

/** Hook genérico: lê 1 key da configuração do tenant atual. Retorna null se não existir. */
export function useConfigValue(key: string) {
  return useTenantConfigValue(key);
}

/** Hook: papéis de pipeline (pré-vendas / closer / webinário + stages nomeados). */
export function usePipelineRoles(): PipelineRoles {
  const { data } = useConfigValue('PIPELINE_ROLES');
  return useMemo(() => parsePipelineRoles(data), [data]);
}

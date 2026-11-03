import { useMemo } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

/**
 * Configuração por tenant.
 *
 * - `config(key, value)` guarda valores GLOBAIS da instalação e só é gravável pelo
 *   admin do tenant padrão. Para tenants secundários a maioria das keys nem é legível.
 * - `tenant_config_overrides(tenant_id, key, value)` guarda o valor do tenant.
 *
 * Leitura: override do tenant sobrepõe o global (instalações single-tenant continuam
 * funcionando com o que já está em `config`). Escrita: SEMPRE em overrides — nunca
 * em `config` a partir daqui.
 */
export type TenantConfigMap = Record<string, string | null>;

export const TENANT_CONFIG_QUERY_KEY = 'tenant-config';
export const TENANT_CONFIG_STALE_MS = 5 * 60 * 1000;

function normalizeKeys(keys: string[]): string[] {
  return Array.from(new Set(keys.filter((k) => typeof k === 'string' && k.length > 0))).sort();
}

type KeyValueRow = { key: string; value: string | null };

export async function readTenantConfig(keys: string[], tenantId: string | null): Promise<TenantConfigMap> {
  const unique = normalizeKeys(keys);
  const result: TenantConfigMap = {};
  if (unique.length === 0) return result;

  // Global: erros de RLS (tenant secundário / usuário não-admin) são esperados — engolir.
  const globalPromise: Promise<KeyValueRow[]> = (async () => {
    try {
      const { data, error } = await supabase.from('config').select('key, value').in('key', unique);
      if (error || !data) return [];
      return data as KeyValueRow[];
    } catch {
      return [];
    }
  })();

  // Override do tenant: erro real deve subir (chamador decide o fallback).
  const overridePromise: Promise<KeyValueRow[]> = tenantId
    ? (async () => {
        const { data, error } = await supabase
          .from('tenant_config_overrides')
          .select('key, value')
          .eq('tenant_id', tenantId)
          .in('key', unique);
        if (error) throw error;
        return (data ?? []) as KeyValueRow[];
      })()
    : Promise.resolve([]);

  const [globalRows, overrideRows] = await Promise.all([globalPromise, overridePromise]);
  for (const row of globalRows) result[row.key] = row.value ?? null;
  for (const row of overrideRows) result[row.key] = row.value ?? null;
  return result;
}

/** Atalho para uma única key. */
export async function readTenantConfigValue(key: string, tenantId: string | null): Promise<string | null> {
  const map = await readTenantConfig([key], tenantId);
  return map[key] ?? null;
}

export async function writeTenantConfig(entries: Record<string, string>, tenantId: string): Promise<void> {
  if (!tenantId) throw new Error('tenant_id obrigatório para salvar configurações do tenant');
  const updated_at = new Date().toISOString();
  const rows = Object.entries(entries).map(([key, value]) => ({ tenant_id: tenantId, key, value, updated_at }));
  if (rows.length === 0) return;
  const { error } = await supabase
    .from('tenant_config_overrides')
    .upsert(rows, { onConflict: 'tenant_id,key' });
  if (error) throw error;
}

/**
 * tenant_id da sessão atual (claim `app_metadata.tenant_id` do JWT) — para código
 * fora de componentes React. Dentro de componentes, use `useAuth().tenantId`.
 */
export async function getSessionTenantId(): Promise<string | null> {
  try {
    const { data } = await supabase.auth.getSession();
    const tid = (data?.session?.user?.app_metadata as Record<string, unknown> | undefined)?.tenant_id;
    return typeof tid === 'string' && tid ? tid : null;
  } catch {
    return null;
  }
}

export function tenantConfigQueryKey(tenantId: string | null, keys: string[]) {
  return [TENANT_CONFIG_QUERY_KEY, tenantId ?? 'anon', normalizeKeys(keys)] as const;
}

/** Hook: lê um conjunto de keys (override do tenant sobre global). */
export function useTenantConfig(keys: string[], options?: { enabled?: boolean }) {
  const { tenantId } = useAuth();
  const keySignature = normalizeKeys(keys).join('\u0000');
  const sortedKeys = useMemo(() => (keySignature ? keySignature.split('\u0000') : []), [keySignature]);
  return useQuery({
    queryKey: tenantConfigQueryKey(tenantId, sortedKeys),
    queryFn: () => readTenantConfig(sortedKeys, tenantId),
    staleTime: TENANT_CONFIG_STALE_MS,
    enabled: (options?.enabled ?? true) && sortedKeys.length > 0,
  });
}

/** Hook: lê uma única key. `data` é string | null. */
export function useTenantConfigValue(key: string, options?: { enabled?: boolean }) {
  const { tenantId } = useAuth();
  return useQuery({
    queryKey: tenantConfigQueryKey(tenantId, [key]),
    queryFn: () => readTenantConfigValue(key, tenantId),
    staleTime: TENANT_CONFIG_STALE_MS,
    enabled: (options?.enabled ?? true) && !!key,
  });
}

/** Mutation: grava overrides do tenant atual e invalida todas as leituras de config do tenant. */
export function useSaveTenantConfig() {
  const { tenantId } = useAuth();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (entries: Record<string, string>) => writeTenantConfig(entries, tenantId as string),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: [TENANT_CONFIG_QUERY_KEY, tenantId ?? 'anon'] }),
  });
}

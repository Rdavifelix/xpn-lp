import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock mínimo e encadeável do PostgREST builder: registra from()/eq()/in()/upsert()
// e resolve com o resultado configurado por tabela.
type Result = { data: any; error: any };
const state = vi.hoisted(() => ({
  results: {} as Record<string, Result>,
  calls: [] as Array<{ table: string; op: string; args: any[] }>,
}));

vi.mock('@/lib/supabase', () => {
  const makeBuilder = (table: string) => {
    const result = () => state.results[table] ?? { data: [], error: null };
    const builder: any = {
      select: (...args: any[]) => { state.calls.push({ table, op: 'select', args }); return builder; },
      eq: (...args: any[]) => { state.calls.push({ table, op: 'eq', args }); return builder; },
      in: (...args: any[]) => { state.calls.push({ table, op: 'in', args }); return builder; },
      upsert: (...args: any[]) => { state.calls.push({ table, op: 'upsert', args }); return Promise.resolve(result()); },
      then: (resolve: any, reject: any) => Promise.resolve(result()).then(resolve, reject),
    };
    return builder;
  };
  return {
    supabase: {
      from: (table: string) => { state.calls.push({ table, op: 'from', args: [] }); return makeBuilder(table); },
      auth: { getSession: async () => ({ data: { session: null }, error: null }) },
    },
  };
});
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ tenantId: 'tenant-a' }) }));

import { readTenantConfig, writeTenantConfig } from '@/lib/tenant-config';

const TENANT = '11111111-1111-1111-1111-111111111111';

beforeEach(() => {
  state.results = {};
  state.calls = [];
});

describe('readTenantConfig', () => {
  it('sobrepõe o override do tenant ao valor global e mantém o global onde não há override', async () => {
    state.results['config'] = {
      data: [{ key: 'PIPELINE_ROLES', value: 'global-roles' }, { key: 'COMPANY_NAME', value: 'Global Co' }],
      error: null,
    };
    state.results['tenant_config_overrides'] = {
      data: [{ key: 'PIPELINE_ROLES', value: 'tenant-roles' }],
      error: null,
    };

    const map = await readTenantConfig(['PIPELINE_ROLES', 'COMPANY_NAME', 'MISSING'], TENANT);

    expect(map).toEqual({ PIPELINE_ROLES: 'tenant-roles', COMPANY_NAME: 'Global Co' });
    const overrideEq = state.calls.find((c) => c.table === 'tenant_config_overrides' && c.op === 'eq');
    expect(overrideEq?.args).toEqual(['tenant_id', TENANT]);
  });

  it('engole erro de RLS da tabela config e ainda devolve os overrides do tenant', async () => {
    state.results['config'] = { data: null, error: { code: '42501', message: 'permission denied' } };
    state.results['tenant_config_overrides'] = { data: [{ key: 'enabled_modules', value: '{"comercial":true}' }], error: null };

    await expect(readTenantConfig(['enabled_modules'], TENANT)).resolves.toEqual({
      enabled_modules: '{"comercial":true}',
    });
  });

  it('sem tenantId lê apenas a config global (instalação single-tenant / anon)', async () => {
    state.results['config'] = { data: [{ key: 'COMPANY_NAME', value: 'Global Co' }], error: null };

    const map = await readTenantConfig(['COMPANY_NAME'], null);

    expect(map).toEqual({ COMPANY_NAME: 'Global Co' });
    expect(state.calls.some((c) => c.table === 'tenant_config_overrides')).toBe(false);
  });

  it('com lista vazia não consulta o banco', async () => {
    await expect(readTenantConfig([], TENANT)).resolves.toEqual({});
    expect(state.calls).toHaveLength(0);
  });
});

describe('writeTenantConfig', () => {
  it('faz upsert em tenant_config_overrides com onConflict tenant_id,key e nunca toca em config', async () => {
    await writeTenantConfig({ enabled_modules: '{"gestao":false}', PIPELINE_ROLES: '{}' }, TENANT);

    expect(state.calls.some((c) => c.table === 'config')).toBe(false);
    const upsert = state.calls.find((c) => c.table === 'tenant_config_overrides' && c.op === 'upsert');
    expect(upsert).toBeTruthy();
    const [rows, options] = upsert!.args;
    expect(options).toEqual({ onConflict: 'tenant_id,key' });
    expect(rows).toHaveLength(2);
    for (const row of rows) {
      expect(row.tenant_id).toBe(TENANT);
      expect(typeof row.updated_at).toBe('string');
    }
    expect(rows.find((r: any) => r.key === 'enabled_modules').value).toBe('{"gestao":false}');
  });

  it('propaga erro do banco', async () => {
    state.results['tenant_config_overrides'] = { data: null, error: new Error('rls denied') };
    await expect(writeTenantConfig({ k: 'v' }, TENANT)).rejects.toThrow('rls denied');
  });

  it('recusa salvar sem tenant_id', async () => {
    await expect(writeTenantConfig({ k: 'v' }, '' as string)).rejects.toThrow(/tenant_id/);
    expect(state.calls).toHaveLength(0);
  });
});

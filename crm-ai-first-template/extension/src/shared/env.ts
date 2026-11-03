// ============================================================
// Variáveis injetadas em BUILD-TIME pelo vite.config.ts.
// Valores vêm do .env da raiz do projeto CRM (VITE_SUPABASE_URL, etc).
// O aluno NÃO precisa configurar nada na extensão — ela sai pronta.
// ============================================================

declare const __SUPABASE_URL__: string;
declare const __SUPABASE_ANON_KEY__: string;
declare const __CRM_BASE_URL__: string;

export const SUPABASE_URL: string = __SUPABASE_URL__;
export const SUPABASE_ANON_KEY: string = __SUPABASE_ANON_KEY__;
export const CRM_BASE_URL: string = __CRM_BASE_URL__;

export function envIsConfigured(): boolean {
  return Boolean(SUPABASE_URL && SUPABASE_ANON_KEY);
}

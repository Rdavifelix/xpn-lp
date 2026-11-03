import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import { crx } from '@crxjs/vite-plugin';
import path from 'node:path';
import manifest from './manifest.json';

// Lê o .env da RAIZ do projeto (não da pasta extension).
// O aluno preenche o .env do CRM uma vez, e a extensão herda as credenciais.
export default defineConfig(({ mode }) => {
  const rootDir = path.resolve(__dirname, '..');
  const env = loadEnv(mode, rootDir, 'VITE_');
  const supabaseUrl = env.VITE_SUPABASE_URL || '';
  const supabaseAnonKey = env.VITE_SUPABASE_ANON_KEY || '';
  const crmBaseUrl = env.VITE_CRM_URL || 'http://localhost:5173';

  if (!supabaseUrl || !supabaseAnonKey) {
    console.warn('\n⚠️  AVISO: VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY não encontrados no .env da raiz do projeto.');
    console.warn('   Preencha o .env do CRM antes de buildar a extensão.\n');
  }

  return {
    plugins: [react(), crx({ manifest })],
    define: {
      // Injetadas em build-time — extensão sai pronta sem o aluno configurar nada.
      __SUPABASE_URL__: JSON.stringify(supabaseUrl),
      __SUPABASE_ANON_KEY__: JSON.stringify(supabaseAnonKey),
      __CRM_BASE_URL__: JSON.stringify(crmBaseUrl),
    },
    build: {
      outDir: 'dist',
      sourcemap: false,
      rollupOptions: { output: { chunkFileNames: 'assets/[name]-[hash].js' } },
    },
    server: { port: 5174, strictPort: true, hmr: { port: 5174 } },
  };
});

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const root = resolve(process.cwd());
const read = (path: string) => readFileSync(resolve(root, path), 'utf8');

describe('security hardening invariants', () => {
  it('limits gateway JWT exceptions to callbacks and handlers with their own authentication', () => {
    const config = read('supabase/config.toml');
    const publicFunctions = [...config.matchAll(/\[functions\.([^\]]+)\]\s+verify_jwt = false/g)]
      .map((match) => match[1]).sort();
    expect(publicFunctions).toEqual([
      'analyze-sales-call', 'book-meeting', 'brevo-webhook', 'enrich-instagram-leads', 'google-ads-webhook',
      'google-calendar-webhook', 'meta-lead-webhook', 'process-email-event',
      'prospeccao-diagnostico-publico', 'public-form', 'receive-channel', 'zernio-api', 'zernio-webhook', 'mcp-provision-member', 'mcp-playground-test', 'mcp-whatsapp', 'receive-lead', 'social-api', 'social-webhook', 'soniox-token', 'telegram-webhook',
      'unsubscribe', 'web-track', 'wavoip-webhook', 'whatsapp-cloud-webhook', 'whatsapp-webhook',
    ].sort());
  });

  it('never ships long-lived AI keys to browser hooks', () => {
    const hooks = [
      'src/hooks/useGeminiCoach.ts',
      'src/hooks/useGeminiLiveCoach.ts',
      'src/hooks/useSalesCoach.ts',
    ].map(read).join('\n');
    expect(hooks).not.toContain('gemini-token');
    expect(hooks).not.toContain('@google/genai');
    expect(read('supabase/functions/soniox-token/index.ts')).toContain('temporary-api-key');
  });

  it('contains no fallback Supabase JWT in browser source', () => {
    const publicFormFiles = [
      'src/hooks/useMarketingForms.ts',
      'src/pages/public/FormEmbed.tsx',
    ].map(read).join('\n');
    expect(publicFormFiles).not.toMatch(/eyJhbGciOiJIUzI1Ni/);
  });

  it('does not grant the extension access to every website', () => {
    expect(read('extension/manifest.json')).not.toContain('<all_urls>');
  });

  it('disables public signup during installation', () => {
    expect(read('setup.sh')).toContain('"disable_signup":true');
  });
});

// ============================================================
// keys.ts — registry de API keys carregadas via config (UI)
// Inicializado pelo index.ts no início de cada request.
// Fontes leem via getKey() em vez de Deno.env.get().
// ============================================================

type KeyName =
  | "FIRECRAWL_API_KEY"
  | "GEMINI_API_KEY"
  | "SCRAPECREATORS_API_KEY"
  | "GOOGLE_PAGESPEED_KEY";

const store: Partial<Record<KeyName, string | null>> = {};

export function setKey(name: KeyName, value: string | null | undefined) {
  store[name] = value || null;
}

export function getKey(name: KeyName): string | null {
  return store[name] ?? null;
}

export function setKeys(keys: Partial<Record<KeyName, string | null | undefined>>) {
  for (const [k, v] of Object.entries(keys)) {
    setKey(k as KeyName, v ?? null);
  }
}

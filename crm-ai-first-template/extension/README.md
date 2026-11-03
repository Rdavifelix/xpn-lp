# IAP Social Selling — Extensão Chrome

Extensão Chrome que automatiza cadência outbound no Instagram, integrada ao seu CRM. Aluno do PAIN instala, configura URL+token do CRM dele, e a extensão executa a cadência diariamente.

## Arquitetura em 30 segundos

```
[CRM Supabase] ──── plano ────▶ [Extensão Chrome]
                                      │
                ◀── log/feedback ─────┤
                                      │
                                      ▼
                            [Instagram (DOM)]
```

- **Cron interno** (`chrome.alarms`) dispara todo dia 9h BR
- **Auto vs Aprovar** por tipo de ação (curtir = auto, DM = aprovar)
- **Texto via IA** (Claude Haiku via edge function `generate-social-selling-message`)
- **Login IG** = mesmo do Chrome do aluno (zero atrito)
- **Local-first**: nada cloud, sem detecção de VPS

## Instalação (modo desenvolvedor)

### 1. Build a extensão

Pré-requisitos: Node 18+ e npm.

```bash
cd cs/social-selling-extension
npm install
npm run build
```

Isso gera a pasta `dist/` com a extensão pronta.

### 2. Carregue no Chrome

1. Abra `chrome://extensions/`
2. Ative **"Modo desenvolvedor"** (canto superior direito)
3. Clique **"Carregar sem compactação"**
4. Selecione a pasta `dist/`

A extensão aparece na barra do Chrome com ícone amber.

### 3. Configure

Clique direito no ícone → **"Opções"**:

- **URL Supabase**: `https://SEU-PROJETO.supabase.co` (Settings → API → Project URL)
- **Token**: anon key do Supabase (Settings → API → anon public)
- **URL do seu CRM (web)**: ex `https://meucrm.com` (links "abrir lead")
- **@ do seu Instagram**: conta dona, sem o @
- **Modo por ação**: ajuste auto/aprovar como preferir
- **Horário**: padrão 9h BR
- Clique **"Testar conexão"** → deve retornar ✅

### 4. Pronto

Amanhã 9h, a extensão acorda sozinha (com Chrome aberto), busca o plano, executa as auto-actions silenciosamente, e te notifica se tem ação pra revisar.

## Distribuição pros alunos PAIN

Após `npm run build:zip`:

```bash
npm run build:zip   # gera iap-social-selling-extension.zip
```

Aluno baixa o `.zip`, descompacta, segue passo 2 da instalação.

## Stack

- **Manifest V3** (futuro-proof)
- **Vite + @crxjs/vite-plugin** (build automatizado)
- **React + Tailwind** (popup + options)
- **TypeScript** (type-safe end-to-end)

## Desenvolvimento

```bash
npm run dev   # hot reload (recarrega extensão automaticamente)
```

Aí em `chrome://extensions/` clique no botão de reload da extensão pra ver mudanças.

## Estrutura

```
src/
  background/index.ts    # service worker — cron, orchestrator
  content/instagram.ts   # injetado em instagram.com — executa cliques no DOM
  popup/                 # UI da fila
  options/               # configurações
  shared/                # types + storage + api client
public/icons/            # ícones (placeholder amber — substituir)
manifest.json            # Manifest V3
```

## Endpoints Supabase consumidos

| Edge function | Quando |
|---|---|
| `social-selling-plan-day` | Cron 9h pega plano |
| `generate-social-selling-message` | Antes de cada ação que precisa texto |
| `log-social-selling-action` | Após cada ação executada |

## Limitações conhecidas

- **Chrome precisa estar aberto** pro alarm disparar (pode estar minimizado)
- **IG pode mudar selectors** — content script precisa atualizar
- **Cliques sintéticos** — IG monitora `event.isTrusted`. Solução robusta usa `chrome.debugger` (futuro)
- **Web Store rejeita automação IG** — distribuir como `.zip unpacked`, sem update automático

## Troubleshooting

| Problema | Solução |
|---|---|
| Cron não dispara | Chrome fechou completamente. Reabre e ele re-agenda. |
| "Erro ao buscar plano" | Token errado. Vai em Opções → Testar conexão. |
| IG bloqueou | Pause cadências no painel CRM. Espera 7 dias antes de reativar. |
| Ações não executam | Aluno tem que estar logado no IG no MESMO Chrome. |

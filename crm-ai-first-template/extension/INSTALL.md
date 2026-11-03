# 📷 Social Selling — Extensão Chrome (instalação e configuração)

Prospecção ativa no Instagram: capture seguidores → IA qualifica via Claude Haiku → cadência humanizada (curtir / story / comentar / DM) **direto da sua conta logada**, sem API do Meta.

> ⏱️ **Setup completo: ~10 minutos** (todo passo a passo executável pelo Claude Code).

---

## 🎯 Pré-requisitos

| Item | Como conseguir |
|---|---|
| ✅ **CRMPAIN configurado** (skill `/setup-projeto`) | Aluno já fez no setup do CRM |
| ✅ **ANTHROPIC_API_KEY** em `Configurações → Integrações → API Keys` | Aluno cadastra na UI |
| ✅ **Node 18+** | macOS: `brew install node` |
| ✅ **Google Chrome** | Qualquer versão atual |
| ✅ **Conta Instagram** (qualquer) | Onde vai prospectar |

> 🤖 **Pra Claude Code:** todos os passos abaixo são executáveis. O aluno só precisa carregar a extensão no Chrome (passo 4) e logar.

---

## 1️⃣ Banco de dados (migration)

Roda a migration consolidada:

```bash
supabase db push --project-ref <PROJECT_REF>
```

Aplica `supabase/migrations/20260526_social_selling_pack_extension.sql` — idempotente:
- Adiciona colunas faltantes (`automation_id` em enrollments, `description` em automations)
- Cria tabela `social_selling_known_followers` + RLS tenant-scoped
- Função `ss_actions_today()` pro rate-limit
- Realtime publication
- 2 cadências template seedadas (Aquecimento 3d + Follow-up 2d)
- Configs default (limits + prompt qualificação)

---

## 2️⃣ Deploy das 7 Edge Functions

```bash
supabase functions deploy social-selling-qualify-followers --no-verify-jwt
supabase functions deploy social-selling-plan-day --no-verify-jwt
supabase functions deploy log-social-selling-action --no-verify-jwt
supabase functions deploy generate-social-selling-message --no-verify-jwt
supabase functions deploy get-social-selling-enrollments --no-verify-jwt
supabase functions deploy social-selling-config-api --no-verify-jwt
supabase functions deploy social-selling-mark-reply --no-verify-jwt
```

> Functions têm `verify_jwt: false` porque validam JWT internamente via `auth.getUser()`.

---

## 3️⃣ Pipeline "Prospecção Social Selling" (5 etapas)

Crie no CRM em **Configurações → Comercial → Pipeline** com **exatamente** estas 5 etapas (a ordem importa — `log-action` move por position):

| Position | Nome sugerido |
|---|---|
| 1 | 🆕 Novo Qualificado |
| 2 | 🔥 Aquecendo |
| 3 | 📩 DM Enviada |
| 4 | ✅ Respondeu |
| 5 | ❌ Sem Resposta |

> O **nome do pipeline** ("Prospecção Social Selling") é parametrizável via secret `SS_PIPELINE_NAME` se o aluno quiser renomear.
> O **nome da stage "Respondeu"** via `SS_RESPONDED_STAGE_NAME`.

**Pode rodar via SQL também:**
```sql
WITH p AS (INSERT INTO sales_pipelines (name, position, is_active) VALUES ('Prospecção Social Selling', 99, true) RETURNING id)
INSERT INTO sales_pipeline_stages (pipeline_id, name, position) VALUES
  ((SELECT id FROM p), '🆕 Novo Qualificado', 1),
  ((SELECT id FROM p), '🔥 Aquecendo', 2),
  ((SELECT id FROM p), '📩 DM Enviada', 3),
  ((SELECT id FROM p), '✅ Respondeu', 4),
  ((SELECT id FROM p), '❌ Sem Resposta', 5);
```

---

## 4️⃣ Build da extensão

```bash
cd extension
npm install
npm run build
```

Lê `VITE_SUPABASE_URL` + `VITE_SUPABASE_ANON_KEY` + `VITE_CRM_URL` do `.env` da raiz do projeto e **injeta no bundle**. Aluno não precisa colar nada na extensão.

---

## 5️⃣ Carregar no Chrome (passo manual do aluno)

1. Abre `chrome://extensions`
2. Liga **Modo do desenvolvedor**
3. **Carregar sem compactação** → seleciona `extension/dist/`
4. Fixa o ícone 📷

---

## 6️⃣ Login + @ Instagram (aluno)

1. Clica no ícone da extensão → tela de login
2. **Email/senha do CRM** (mesma conta)
3. Abre `instagram.com` numa aba e loga normalmente
4. Em `⚙️ Configurações da extensão`, preenche **só o @ do Instagram** (ex: `frankcosta`, sem `@`)

---

## ⚙️ Personalização (tudo no CRM, sem rebuild)

### A) **ICP** (quem virar lead) — `config.social_selling_prompt_qualificacao`

Default genérico B2B. Customize por nicho:

```sql
UPDATE config SET value = $$
Você é um qualificador pra prospecção de [nicho do aluno].
Score 0-100. ICP: [perfil ideal].
Aprove se: [critérios]. Rejeite se: [red flags].
Retorne JSON: {"score": <n>, "reason": "<frase>"}.
$$ WHERE key = 'social_selling_prompt_qualificacao';
```

Exemplos por nicho:

```
Médico/Clínica: "ICP = médicos com clínica própria, 5k+ seguidores, bio menciona especialidade/CRM."
Agência: "ICP = donos de agência, posts mostram cases, bio menciona resultados ou nicho."
SaaS B2B: "ICP = founder/CEO/CTO de SaaS, bio menciona produto ou tração."
Coach/Mentor: "ICP = empreendedor com público engajado, posts mostram autoridade."
```

### B) **Tom de voz da IA** — `config.social_selling_tone`

```sql
UPDATE config SET value = $$
{
  "description": "Brasileiro, informal, direto. 1-3 frases. Sem emoji em DM frio.",
  "sample_messages": "Oi cara, vi seu post sobre X — curti a abordagem. Trabalho com Y, podemos trocar uma ideia?",
  "forbidden_words": "olá, prezado, oportunidade única"
}
$$ WHERE key = 'social_selling_tone';
```

### C) **Limites e regras anti-bloqueio** — `config.social_selling_limits`

```json
{
  "score_min": 60,                    // score mínimo pra virar lead
  "chunk_size": 10,                   // quantos qualificar por chunk
  "total_actions_per_day": 80,        // teto diário total
  "dms_per_day": 15,
  "comments_per_day": 20,
  "likes_per_day": 60,
  "working_hours_start": "09:00",
  "working_hours_end": "20:00",
  "pause_weekends": true,
  "delay_min_seconds": 45,
  "delay_max_seconds": 180,
  "min_minutes_between_actions_same_lead": 30,
  "random_skip_pct": 10               // 10% skip aleatório pra humanizar
}
```

Aluno conservador: `total_actions_per_day: 40`. Agressivo: `100+`.

### D) **Cadências** (dias × ações) — via UI da extensão

Em `Configurações → Comercial → Prospecção Social` (ou via UI da extensão, na ⚙️ → editor de cadência):

- Edita os dias da cadência (Dia 1: curtir 1 + reagir story; Dia 2: comentar; Dia 3: enviar DM)
- Define pipeline destino + stage inicial
- Pode criar várias cadências (warm/cold/reativação)

### E) **Prompts específicos por ação** (todos opcionais)

| Key | Quando IA gera |
|---|---|
| `social_selling_prompt_comentar_post` | Comentário público em post |
| `social_selling_prompt_responder_story` | DM respondendo story |
| `social_selling_prompt_enviar_dm` | DM cold/follow-up |

Todos têm defaults razoáveis. Sobrescrever só se quiser super específico.

---

## 🚀 Fluxo de uso (1ª vez)

1. Aluno abre a extensão → aba **Prospecção**
2. Em "Capturar novos seguidores": digita o @ alvo + limite (ex: 50)
3. Clica **Iniciar** → extensão abre IG, captura seguidores recentes, qualifica em background
4. Pode abrir modal **"🔴 Ao vivo"** pra ver cada lead sendo qualificado em tempo real
5. Leads aprovados aparecem no pipeline **Prospecção Social Selling** etapa "🆕 Novo Qualificado"
6. **Aba Cadência** mostra plano do dia
7. Ações com texto (DM/comentário) entram em **fila de aprovação** — aluno revisa antes de enviar
8. Lead que responder → move automaticamente pra "✅ Respondeu"

---

## 🔒 Segurança

| Componente | Como protege |
|---|---|
| Senha IG | Nunca armazenada — usa sessão do Chrome do user |
| Anon key Supabase | Pública por design; RLS protege os dados |
| Service role key | Só nas edge functions (server-side) |
| API Anthropic | Lida do `config` table (server-side) |
| Cookies IG | Ficam no browser do user — extensão usa via `chrome.scripting.executeScript` |

---

## 🆘 Troubleshooting

| Sintoma | Causa | Fix |
|---|---|---|
| Login dá "Extensão buildada sem credenciais" | `.env` da raiz sem `VITE_SUPABASE_*` | Preenche + `npm run build` de novo |
| Login dá "Invalid credentials" | Senha errada | Mesma do CRM |
| Captura para em 10 | IG mudou DOM | Já tem detecção multi-sinal — manda log se falhar |
| `0 qual / N sync_err` | Não tem IG logado OU enrich falhou | Confirma aba IG aberta + logado |
| Lead não aparece no pipeline | Pipeline com nome diferente | Renomeia ou seta secret `SS_PIPELINE_NAME` |
| Card não move de etapa | Faltam etapas no pipeline | Cria as 5 etapas |
| DM/comentário não envia | IG deslogou | Re-loga em `instagram.com` |
| "Aguardando qualificação ao vivo" sempre | Modal não pegou histórico inicial | Já corrigido — recarrega extensão |

---

## 📂 Estrutura técnica

```
extension/
├── manifest.json                  ← Chrome MV3 (perms: alarms/scripting/tabs/sidePanel)
├── vite.config.ts                 ← injeta .env da raiz em build-time
├── src/
│   ├── background/index.ts        ← service worker (cron, dispatch, qualify chain)
│   ├── content/
│   │   ├── bridge.ts              ← ISOLATED world (chrome.runtime + cookies IG)
│   │   └── instagram.ts           ← MAIN world (DOM IG, captureFollowers)
│   ├── popup/
│   │   ├── App.tsx                ← side panel principal
│   │   ├── QualificationLiveModal ← modal "Ao Vivo"
│   │   ├── ConfigsPanel.tsx       ← editor de cadências
│   │   └── LoginScreen.tsx        ← email/senha
│   ├── options/App.tsx            ← página de configurações (modos auto/aprovar)
│   └── shared/
│       ├── env.ts                 ← constantes injetadas (URL+anon)
│       ├── auth.ts                ← login + JWT refresh
│       ├── api.ts                 ← chamadas pras 7 edge functions
│       ├── realtime.ts            ← Supabase Realtime + fetchProfileLive
│       ├── storage.ts             ← chrome.storage.local helpers
│       └── types.ts               ← ExtensionConfig, QueueItem, etc
└── dist/                          ← build (carregar no Chrome)
```

---

## 🤖 Pro Claude Code do mentorado

Quando o aluno disser "instala/configura social selling":

1. **Verifica pré-req**: `.env` tem `VITE_SUPABASE_URL` + `VITE_SUPABASE_ANON_KEY`? `ANTHROPIC_API_KEY` em `config` table?
2. **Aplica migration**: `supabase db push`
3. **Deploya 7 functions**: comandos do passo 2
4. **Cria pipeline + stages**: SQL do passo 3
5. **Build extensão**: `cd extension && npm install && npm run build`
6. **Instrui o aluno** a:
   - Abrir `chrome://extensions` e carregar `extension/dist/`
   - Logar no IG numa aba
   - Logar na extensão com user do CRM
   - Configurar @ Instagram nas Options
7. **Pergunta ao aluno**: qual nicho/ICP ele quer prospectar?
8. **Customiza** `social_selling_prompt_qualificacao` e `social_selling_tone` conforme o nicho
9. **Sugere** ajustar `social_selling_limits` (conservador no início: total=40, dms=8)

Pronto.

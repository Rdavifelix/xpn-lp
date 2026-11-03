# Agents Platform Pack

Plataforma de agentes IA multi-provider, multi-canal, no-code. Instala sobre um Supabase
existente e dá ao mentorado os mesmos recursos que o CRM IAP usa em produção:

- **Multi-provider** — Anthropic, OpenAI API, OpenAI Codex (login Plus), Gemini, Groq, etc.
- **Multi-canal** — chat web, Telegram, WhatsApp (UAZAPI ou Cloud API)
- **Tools no-code** — catálogo de skills instaláveis com 1 clique
- **Memory + RAG** — notas com pgvector e busca semântica
- **Jobs duráveis** — tarefas longas viram async com auto-resume no canal
- **Lembretes proativos** — agente fala sozinho no horário marcado
- **Native tools** — web_search, web_fetch, code_interpreter, image_generation
- **Humanização** — split de mensagem, delay natural, typing indicator
- **Auditoria** — toda tool call vai pra `agents_action_log`

## Arquitetura em 1 minuto

```
                  ┌──────────────────────────────────┐
                  │  Frontend (src/agents-platform/) │
                  │  • Playground                    │
                  │  • Config (registry/tools/canais)│
                  │  • Notas + Skills + Credentials  │
                  └────────────┬─────────────────────┘
                               │ HTTPS (SSE)
                  ┌────────────▼─────────────────────┐
                  │  edge: agent-runner              │
                  │  ┌──────────┐ ┌───────────────┐  │
                  │  │ providers│ │ tools (sql/   │  │
                  │  │ (a,o,c,g)│ │  http/edge)   │  │
                  │  └──────────┘ └───────────────┘  │
                  │   lib/humanization (split, ...)   │
                  └────┬───────────────┬─────────────┘
                       │               │ async
   ┌───────────────────▼─┐   ┌─────────▼───────────┐
   │  Postgres (14 core) │   │  agent_jobs (poller)│
   │  registry/tools/    │   │  retoma resp. via   │
   │  notes (pgvector)/  │   │  resume SSE         │
   │  reminders/         │   └──────────┬──────────┘
   │  routing_log/...    │              │
   └─────────────────────┘   ┌──────────▼──────────┐
                              │  edge: agent-jobs-  │
                              │  poller (cron 1min) │
                              └─────────────────────┘
```

## Pré-requisitos

| Componente | Versão | Obrigatório | Pra quê |
|---|---|---|---|
| Supabase project (PostgreSQL 15+) | – | ✅ | banco e edge functions |
| Extension `pgvector` | 0.5+ | ✅ | RAG nas notas |
| Extension `pg_cron` | 1.6+ | ✅ | poller de jobs/reminders |
| Extension `pg_trgm` | 1.5+ | ✅ | busca substring nas notas |
| Tabela `team_members` | – | ✅ | FK em `agents_provider_credentials.owner_user_id` |
| Tabelas `config` + `tenant_config_overrides` | – | ✅ no CRM completo | flag por tenant do roteador V2 |
| Tabelas `leads`/`deals`/`pipeline_stages` | – | ❌ opcional | só pras skills de vendas |
| Node 22+ + Supabase CLI | – | ✅ | deploy de edge functions e migrations |

## O que tem no pack

```
agents-platform-pack/
├── README.md                                    ← este arquivo
├── PLAYBOOK.md                                  ← passo a passo de configuração pós-install
├── migrations/
│   ├── 0001_agents_platform.sql                 ← 14 tabelas + extensões + índices + RLS + realtime + cron
│   ├── 0002_agents_functions.sql                ← ~20 RPCs core + triggers + grants
│   ├── 0003_seed_catalog_and_providers.sql      ← 8 integration providers + 16 skills core
│   └── 0099_optional_sales_tools.sql            ← (TODO próxima onda) skills + funções de vendas (qualify_lead, schedule_meeting…)
├── functions/
│   ├── agent-runner/                            ← edge function multi-provider (lib/providers + lib/tools + lib/humanization)
│   ├── agent-jobs-poller/                       ← cron poller (jobs + reminders)
│   ├── generate-embedding/                      ← embedding pras notas (Gemini)
│   └── _whatsapp-webhook-hook.ts                ← snippet pra hookear no whatsapp-webhook do mentorado
├── frontend/
│   ├── agents-platform/                         ← cole em src/agents-platform/ no projeto Vite/React
│   └── CarouselViewer.tsx                       ← componente do BoraPostar (cole onde fizer sentido)
└── config-templates/
    ├── config.toml.snippet                      ← config.toml entries (verify_jwt)
    └── env.template                             ← env vars do mentorado
```

## Instalação (10-15 min)

### 1. Pré-flight
```bash
# Garante extensões no banco-alvo
psql $SUPABASE_DB_URL -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql $SUPABASE_DB_URL -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
psql $SUPABASE_DB_URL -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

### 2. Migrations (ordem importa!)
```bash
psql $SUPABASE_DB_URL -f migrations/0001_agents_platform.sql
psql $SUPABASE_DB_URL -f migrations/0002_agents_functions.sql
psql $SUPABASE_DB_URL -f migrations/0003_seed_catalog_and_providers.sql
# Opcional, só se você tem leads/deals/pipeline_stages no CRM:
# psql $SUPABASE_DB_URL -f migrations/0099_optional_sales_tools.sql
```

### 3. Edge functions
```bash
# Cola em supabase/functions/ do projeto
cp -r functions/agent-runner       supabase/functions/
cp -r functions/agent-jobs-poller  supabase/functions/
cp -r functions/generate-embedding supabase/functions/

# Anexa o snippet do config.toml (verify_jwt = false pras 2 abaixo)
cat config-templates/config.toml.snippet >> supabase/config.toml

# Deploy (--no-verify-jwt nas 2 abaixo já refletido no config.toml)
supabase functions deploy agent-runner --no-verify-jwt
supabase functions deploy agent-jobs-poller --no-verify-jwt
supabase functions deploy generate-embedding
```

### 4. Frontend
```bash
# No projeto React/Vite do mentorado:
cp -r frontend/agents-platform     src/
cp    frontend/CarouselViewer.tsx  src/components/

# Adicione a rota /agentes (e a página global de Habilidades) no router
# Veja src/agents-platform/README.md (interno) ou PLAYBOOK.md
```

### 5. Configurações no Supabase

a) **Secret `service_role_key`** no Vault pro trigger de embedding:
```sql
SELECT vault.create_secret('SEU_SERVICE_ROLE_KEY', 'service_role_key');
```

b) **app.settings** pra URL do projeto (usada por trigger de embedding + cron):
```sql
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://SEU-PROJECT-REF.supabase.co';
ALTER DATABASE postgres SET app.settings.service_role_key = 'SEU_SERVICE_ROLE_KEY';
```

c) **Re-rodar o bloco de cron** do 0001 (que pula se settings não existirem na primeira passada):
```sql
SELECT cron.schedule('agent-jobs-poller', '* * * * *',
  format($cron$SELECT net.http_post(url := %L, headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer %s'), body := '{}'::jsonb)$cron$,
    current_setting('app.settings.supabase_url') || '/functions/v1/agent-jobs-poller',
    current_setting('app.settings.service_role_key')
  )
);
```

### 6. Smoke test

1. Frontend: `/agentes` deve carregar (lista vazia)
2. Criar agente em `/agentes/novo` com `provider=anthropic` ou `openai_codex`
3. Adicionar credencial (`/agentes/<slug>` → aba Credenciais)
4. Chat web: enviar "oi" → deve responder
5. Instalar skill `current_time_br` → pergunta "que dia é hoje?" → deve responder com data BR
6. Instalar skill `salvar_nota` + `buscar_nota` → testa RAG
7. Verificar `agents_action_log`: deve ter as tool calls registradas
8. Verificar Realtime: abre 2 abas no mesmo agente, mensagem em uma aparece na outra

## Recursos do CRM completo que não fazem parte do pack standalone

- `0099_optional_sales_tools.sql` — qualify_lead, change_stage, schedule_meeting, etc. (depende de leads/deals/pipeline_stages do CRM IAP)
- Templates de agente prontos (Heitor de conteúdo, Vinicius SDR, CEO/Assistente Geral) como `is_template=true`
- Wizard "Instalar template" na UI
- No ZIP completo do CRM, o roteador WhatsApp V2, o envio humanizado e o
  `agent-followup` já estão integrados. O arquivo `_whatsapp-webhook-hook.ts`
  existe apenas como referência histórica para instalações standalone; não o
  copie sobre o webhook do CRM completo.

## Custos

- **Per-mentorado por padrão** — cada um pluga sua credencial Anthropic/OpenAI/Gemini/BoraPostar.
  → Custo de tokens fica com o mentorado.
- BoraPostar — mentorado cria conta em https://borapostar.com e plugar `api_key`.
- ScrapeCreators / Tavily / Jina — free tier resolve a maioria dos casos.

## Segurança

- ✅ Tudo com RLS habilitado
- ✅ `agent_execute_readonly` é SELECT-only com blacklist + statement_timeout 30s + auto-LIMIT 1000
- ✅ Credenciais ficam em `agents_provider_credentials.auth_data` (jsonb) — recomendação: usar Vault pra encrypted secrets
- ✅ `agent_get_credential_data` é SECURITY DEFINER (revogado de PUBLIC)
- ✅ `agent-runner` exige JWT válido e ainda valida usuário/tenant/admin; chamadas
  internas usam `service_role`. Webhooks públicos mantêm autenticação própria.

## Suporte

- Atualizações do pack: pull do repo CS (`cs/agents-platform-pack/`)
- Bugs específicos: abrir issue no repo
- Decisões arquiteturais: ver `cs/AGENTS-PLATFORM.md` (1200 linhas de documentação detalhada)

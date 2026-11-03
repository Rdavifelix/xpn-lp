# PLAYBOOK — Pós-instalação da Agents Platform

Guia passo a passo pra colocar a plataforma em produção depois que rodou as migrations e deployou as edge functions. Lê só o que aplica ao seu caso.

---

## ETAPA 1 — Validar instalação base (5 min)

```sql
-- Roda no SQL Editor do Supabase

-- Deve listar 14 tabelas
SELECT count(*) AS tabelas FROM pg_tables
WHERE schemaname = 'public' AND (tablename LIKE 'agents_%' OR tablename LIKE 'agent_%');
-- Esperado: 14 (ou 16 se rodou 0099 com ai_critical_decisions + ai_agent_scheduled_followups)

-- Deve listar pelo menos 20 funções
SELECT count(*) AS funcoes FROM pg_proc
WHERE pronamespace = 'public'::regnamespace AND proname LIKE 'agent_%';
-- Esperado: ~20-32 (depende se rodou 0099)

-- Deve ter o cron agendado
SELECT jobname, schedule FROM cron.job WHERE jobname = 'agent-jobs-poller';
-- Esperado: 1 linha com schedule '* * * * *'

-- agents_messages no Realtime
SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='agents_messages';
-- Esperado: 1 linha
```

Se algum check falhar, veja `README.md` seção "Instalação" e refaça o passo correspondente.

---

## ETAPA 2 — Plugar primeiro provider LLM (5 min)

A plataforma é **multi-provider** mas precisa de pelo menos 1 LLM configurado pra qualquer agente funcionar.

### Opção A — OpenAI Codex (grátis com ChatGPT Plus)
1. Abra `/agentes` no seu CRM
2. Vai em "Credenciais"
3. Clica "Nova credencial" → escolhe `openai_codex`
4. Cole o token do Codex (extraído via login no ChatGPT)
5. Salva e marca `is_active=true`

### Opção B — Anthropic API
1. Crie chave em https://console.anthropic.com/settings/keys
2. "Nova credencial" → `anthropic_api` → cola a key

### Opção C — OpenAI API
Mesma coisa com `openai_api` + key do https://platform.openai.com.

---

## ETAPA 3 — Clonar um agente template (3 min)

Você tem 3 templates instalados (`template_heitor_conteudo`, `template_assistente_geral`, `template_vinicius_sdr`).

### Pra clonar:
1. `/agentes` → ver lista
2. Clica no template que faz sentido pro seu caso
3. Botão "Clonar pra uso real"
4. UI pede valores das `template_variables` (ex: `{{owner_name}}`, `{{brand_name}}`, `{{tone_of_voice}}`)
5. Preenche → cria agente novo já com o template renderizado
6. Marca `is_active=true`

**Recomendação pra começar:**
- Se você é founder/CEO de software/SaaS → clone `template_assistente_geral` (CEO data assistant)
- Se quer agente de conteúdo IG → clone `template_heitor_conteudo`
- Se tem CRM completo com leads/deals → clone `template_vinicius_sdr` (SDR)

---

## ETAPA 4 — Plugar credenciais das tools (10 min)

Cada provider precisa de credencial separada da credencial do LLM.

### Pro Heitor (conteúdo)
| Provider | Pra quê | Onde obter |
|---|---|---|
| `borapostar` | Carrosseis IG | Conta em https://borapostar.com → API key |
| `buffer` | YouTube/LinkedIn | https://buffer.com/developers (OAuth token) |
| `scrape_creators` | Transcrição YouTube/Reels | https://scrapecreators.com |
| `gemini_image` | Gerar imagem | https://ai.google.dev (Gemini API key) |
| `uazapi` | Notificar você no WhatsApp | Sua instância UAZAPI + token |

### Pro Vinicius (SDR)
| Provider | Pra quê | Onde obter |
|---|---|---|
| `uazapi` | Enviar WhatsApp pro lead | Mesma instância acima |

### Pro Assistente Geral
Nenhuma extra — só o LLM já basta.

⚠️ **Importante pra UAZAPI**: a skill `uazapi_whatsapp_text` tem URL `https://SUA-INSTANCIA.uazapi.com/send/text`. Vá em **Habilidades** → edita a skill → troca por sua URL real.

---

## ETAPA 5 — Testar no playground (5 min)

1. `/agentes/<slug-do-agente>` → tab "Playground"
2. Manda "oi"
3. Deve responder no tom configurado
4. Testa uma tool: "que dia é hoje?" → deve usar `current_time_br` e responder
5. Pra Heitor: "gera um carrossel sobre [tema]" — deve disparar BoraPostar (job durável)
6. Pra Vinicius: simula um lead — "oi, tenho uma agência de marketing com 3 pessoas, faturo 50k" — deve usar `qualify_lead`
7. Pra Assistente Geral: "quanto vendi esse mês?" → deve rodar SQL

Validate: aba "Tool calls" deve mostrar cada chamada com input/output.

---

## ETAPA 6 — Ligar canais (Telegram / WhatsApp)

### Telegram
1. Crie um bot via @BotFather → pega o token
2. `/agentes/<slug>` → tab "Canais" → "+ Canal" → escolhe `telegram`
3. Cola o token + configura: match (autorizado pra qualquer chat ou whitelist de IDs)
4. Marca `is_active=true`
5. Configura webhook do bot pro endpoint:
   ```
   https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://SEU-PROJECT.supabase.co/functions/v1/telegram-webhook
   ```

### WhatsApp (UAZAPI)
1. Tenha instância UAZAPI conectada (número não-oficial)
2. `/agentes/<slug>` → tab "Canais" → "+ Canal" → escolhe `whatsapp`
3. Escolhe o tipo:
   - **Uso interno** (só você): cadastra whitelist de números autorizados
   - **Atende leads**: cadastra critérios de match (instância + palavra-chave opcional)
4. Salva
5. Volte para `/agentes` e ative **Roteador WhatsApp V2**. A chave é por tenant,
   exige administrador e só libera com ao menos um deployment WhatsApp ativo.
6. Para rollback imediato, desligue a mesma chave; mensagens sem match continuam
   no fluxo legado automaticamente.

O webhook agrupa mensagens curtas enviadas em sequência, evita responder por
cima de um vendedor, quebra respostas em bolhas humanizadas e envia imagens
Markdown como mídia. A automação de marketing também oferece o passo
**Follow-up do Agente**, que usa o histórico real da conversa.

### WhatsApp Cloud API (Meta)
Mesma coisa, mas escolhe canal `whatsapp_cloud` no passo 2. Precisa do `phone_number_id` + token do Meta Business.

---

## ETAPA 7 — Configurar lembretes proativos (opcional)

Lembretes funcionam out-of-the-box via cron poller. Pra testar:

1. Vai no Playground do agente
2. Manda: "me lembra de tomar água em 2 minutos"
3. Deve chamar `agendar_lembrete` (vê na aba Tool calls)
4. Espera 2 min — mensagem aparece **automaticamente** no chat (via Realtime se for web, push se Telegram/WhatsApp)

Se não chegar, verifica:
- Cron `agent-jobs-poller` rodando: `SELECT * FROM cron.job_run_details WHERE jobname = 'agent-jobs-poller' ORDER BY start_time DESC LIMIT 5;`
- Edge function `agent-jobs-poller` deployada e respondendo
- Tabela `agent_reminders` tem o lembrete com `status='pending'`

---

## ETAPA 8 — Notas (memória RAG) (opcional)

Notas funcionam pra qualquer agente que tenha as 4 skills (`salvar_nota`, `ler_nota`, `listar_notas`, `buscar_nota`). Heitor já vem com elas.

Pra criar nota manualmente:
1. `/agentes/<slug>` → tab "Notas"
2. "+ Nova nota" → preenche título + conteúdo + tags
3. Embedding é gerado em ~2-3s (trigger chama edge function `generate-embedding`)
4. Status na coluna "Embedding": ⏳ pending → ✓ ok

Daí o agente pode buscar via `buscar_nota` ("o que eu sei sobre X?") e usa o contexto na resposta.

---

## ETAPA 9 — Auditoria (Action Log)

Toda chamada de tool fica em `agents_action_log`.

Pra ver:
```sql
SELECT created_at, tool_name, status, input->>'reason' AS motivo, error
FROM agents_action_log
WHERE agent_id = (SELECT id FROM agents_registry WHERE slug = 'seu-agente')
ORDER BY created_at DESC LIMIT 50;
```

Pra ver decisões críticas (qualificação, change_stage, mark_lost):
```sql
SELECT created_at, decision_type, decision, severity, requires_review
FROM ai_critical_decisions
WHERE requires_review = true
ORDER BY created_at DESC;
```

---

## Troubleshooting comum

### "agent-runner retorna 401"
Falta `verify_jwt = false` no `config.toml`. Veja `config-templates/config.toml.snippet`.

### "Realtime não entrega mensagem proativa"
Verifica:
```sql
SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='agents_messages';
```
Se vazio, roda:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.agents_messages;
```

### "Embedding não gera"
1. Verifica se trigger ativo: `SELECT * FROM pg_trigger WHERE tgname = 'trg_agent_notes_embed';`
2. Verifica `app.settings.supabase_url` e `service_role_key` configurados
3. Edge function `generate-embedding` deployada
4. Vault tem o secret `service_role_key`

### "Cron poller não dispara"
1. `SELECT * FROM cron.job WHERE jobname = 'agent-jobs-poller';` — deve ter 1 linha
2. `SELECT * FROM cron.job_run_details WHERE jobname='agent-jobs-poller' ORDER BY start_time DESC LIMIT 3;` — vê erros
3. Se vazio, re-agenda (veja README seção 5c)

### "Sales tool falha com 'leads not found'"
0099 só roda em CRM completo. Veja preflight no início do `0099_optional_sales_tools.sql`.

---

## Próximos passos

- **Customizar o tom**: edite o `system_prompt` do agente em `/agentes/<slug>` → tab "Identidade"
- **Adicionar skill custom**: vai em `/habilidades` → "+ Nova skill" → tipo `sql`/`http`/`edge_function`
- **Monitorar custo**: filtros em `agents_messages.cost_brl`
- **Múltiplos agentes**: cada vendedor pode ter seu próprio agente clonado

Boas vendas / conteúdos / análises. 🚀

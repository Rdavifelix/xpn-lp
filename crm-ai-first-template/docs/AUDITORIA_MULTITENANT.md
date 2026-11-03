# Auditoria multi-tenant — CRM AI-First (template 2026.09.14)

Data: 2026-11-03. Escopo: 103 migrations SQL, 104 Edge Functions, frontend React (≈800 arquivos), servidor MCP, instalador e documentação.

Método: leitura estática de todo o código mais verificação dinâmica. As 103 migrations foram aplicadas, em ordem, num PostgreSQL 16 local com stubs dos esquemas do Supabase (`auth`, `storage`, `cron`, `vault`, `net`); o estado final do catálogo (`pg_policy`, `pg_constraint`, `pg_proc`, `cron.job`, `pg_publication_tables`) foi consultado e um usuário sintético da empresa B tentou ler e alterar dados da empresa A.

## Resumo executivo

O template já tem a fundação certa: `tenant_id` em 190 das 204 tabelas de `public`, RLS ligado por event trigger em todas, `get_tenant_id()` fail-closed (retorna NULL sem vínculo ativo), funções de domínio convertidas para `SECURITY INVOKER`, guarda MCP por `pre_request`, `tenant_onboard` transacional e flag `multi_tenant_enabled`.

Mesmo assim, **o sistema não podia ser operado com mais de uma empresa no mesmo banco com segurança**. Os problemas que impediam isso:

| Severidade | Achado | Evidência |
|---|---|---|
| P0 | 42 policies permissivas (`USING (true)` / `auth.role()='authenticated'`) em 18 tabelas de negócio com `tenant_id`. Policies permissivas são combinadas com OR, então uma `true` anula a policy de tenant vizinha. | Laboratório: usuário da empresa B leu **e alterou** linhas da empresa A em `email_templates`, `sales_playbook`, `lead_interactions`, `transactions`, `commission_rules`, `config_audit_log`. |
| P0 | `config_audit_log` legível por qualquer usuário autenticado e guarda old/new row de `team_members` (refresh token Google, senha SIP), `integration_settings` (chaves de API), `lead_distribution_config.api_key`. | 20260707000001:50 |
| P0 | Edge Functions: `mirror-ig-media` aceita tabela/coluna/id do cliente e grava com `service_role` (primitiva de escrita cross-tenant); `process-notification-event`, `email-automation-trigger`, `google-ads-webhook` confiam no `tenant_id` do body; 13 funções recebem IDs no body e operam com `service_role` sem conferir o tenant (IDOR). | audit-edge §4 itens 1, 6, 8, 9 |
| P0 | Crons de notificação (`daily-sales-digest`, `check-sales-alerts`, `process-task-reminders`, `check-pending-meetings`) caem na instância/grupo de WhatsApp **global** quando a empresa não tem override: alertas de uma empresa saíam pelo número da empresa default, para o grupo da empresa default. | audit-edge §4 item 3 |
| P1 | Fallback para o tenant default `…0001` em 6 Edge Functions (`DEFAULT_TENANT`) e `getTenantFromRequest` sem fallback fail-closed: JWT sem `app_metadata.tenant_id` recebia acesso sem filtro em ≈50 funções (`if (tenantId)`). | `_shared/tenant.ts`, audit-edge §3a/§4-12 |
| P1 | Storage: `call-recordings` e `agent-uploads` com policy só por bucket e caminho sem prefixo de tenant: qualquer usuário autenticado listava/baixava/apagava gravações de qualquer empresa. | 20260415000001:29-34, 20260611000200:133-150 |
| P1 | 12 constraints UNIQUE globais em colunas escolhidas pelo usuário (`products.slug`, `organizations.slug`, `agents_registry.slug`, `deal_loss_reasons.label`, `integration_settings.provider`, …): a segunda empresa não conseguia cadastrar “mentoria” e descobria, pela violação, o que a primeira cadastrou. `integration_settings.provider` único global = só uma empresa por provedor na instalação inteira. | catálogo `pg_index` |
| P1 | `public.is_superadmin()` (baseline) sem escopo de tenant: superadmin de qualquer empresa escrevia em `tenant_config` (api_key, custom_domain) e `onboarding_stages` de todas; catálogos globais (`agents_skill_catalog`, `prospeccao_prompts_config`, …) editáveis por qualquer admin de qualquer empresa. | 000:2564, 20260710000100:322-357 |
| P1 | Frontend grava configurações por natureza por-empresa (chaves de API, módulos, prompts de social selling, PIPELINE_ROLES, COMPANY_NAME) direto na tabela global `config` em ≈17 telas; nunca usa `tenant_config_overrides`. Empresas fora da default não conseguiam salvar e liam vazio. | audit-frontend §7 |
| P1 | Logout não limpa o cache do TanStack Query (93 % das queryKeys sem tenant) nem o `localStorage` (transcrições de reunião, rascunhos de WhatsApp): usuário de outra empresa no mesmo navegador via dados em cache por até 10 min. | AuthContext.tsx:190-195 |
| P1 | Módulo `cs_event_*` (8 tabelas filhas) sem `tenant_id`, leitura pública e escrita anon, 3 delas no Realtime. | 20260302000001:159-235 |
| P2 | Crons invocáveis por qualquer usuário autenticado (só `verify_jwt=true`, sem exigir `service_role`). | config.toml |
| P2 | Sem ferramentas de plataforma: nenhuma RPC/tela para listar, suspender ou limitar empresas; sem plano/quotas; link público de agendamento único por build (`VITE_BOOKING_PUBLIC_TOKEN`). | audit-mcp-infra §7/§12 |
| P2 | `ai-sales-agent` usa estado de módulo (`CURRENT_TENANT_ID`, chaves) mutado por item processado: condição de corrida entre requisições concorrentes de tenants distintos. | ai-sales-agent/index.ts:16-32 |
| P2 | `chat-manager` executa SQL gerado por LLM via `run_sql`; o isolamento é regra de prompt. | chat-manager/index.ts:1218,1377 |
| info | Migration `20260914152849_distribution_email_defaults.sql` falha em banco limpo (`email_templates.from_email` não existe). | aplicação local |

O que estava **correto** e foi preservado: servidor MCP (OAuth, tenant derivado em `crm_mcp.context()`, nenhuma tool escolhe tenant, testes PGlite com dois tenants); `tenant_onboard`; `check_tenant_references`; `mcp_request_guard`; views `security_invoker`; crons SQL por tenant (zernio, social, instagram); `manage-team-member` escopado por tenant.

## O que foi feito nesta entrega

### Banco — `supabase/migrations/20261103120000_multitenant_saas_hardening.sql`

1. As 42 policies permissivas foram removidas; as 18 tabelas receberam `tenant_isolation_all` (`tenant_id = get_tenant_id()` em USING e WITH CHECK, `TO authenticated`). RSVP público continua podendo ser criado por visitantes, mas o `tenant_id` passa a vir de um trigger que lê o evento.
2. As 8 tabelas `cs_event_*` filhas ganharam `tenant_id` (backfill pelo evento/RSVP), trigger de preenchimento e policy por tenant; leitura “para todos” ficou restrita a `anon` (app do participante). Três delas saíram do Realtime.
3. 12 constraints UNIQUE globais viraram índices únicos por `(tenant_id, coluna)` (`NULLS NOT DISTINCT`, para templates globais com `tenant_id` NULL).
4. Storage: policies de `call-recordings` e `agent-uploads` exigem a pasta `<tenant_id>/…`.
5. `tenants` ganhou `plan`, `max_users`, `trial_ends_at`, `suspended_at`, `suspended_reason`, `metadata`; trigger impede que admins da empresa mexam nesses campos; limite de usuários aplicado por trigger em `team_members`.
6. RPCs de plataforma (só superadmin): `platform_overview`, `platform_list_tenants`, `platform_update_tenant` (nome, plano, limite, suspender/reativar), `platform_set_multi_tenant`.
7. `tenant_onboard` v2: slug legível e único, `tenant_config` da empresa, `BOOKING_PUBLIC_TOKEN` e `COMPANY_NAME` por empresa, plano `trial` de 14 dias.
8. `public.is_superadmin()` passou a ser escopado por tenant; `tenant_config`, `onboarding_stages`, `tenant_sales_config` passaram para admin do próprio tenant; catálogos globais só pelo superadmin da plataforma; `config_audit_log` só para admin da própria empresa; `tenants_insert_superadmin` removida.
9. `multi_tenant_enabled = 'true'`.
10. Verificação embutida: a migration falha se restar qualquer policy permissiva sem guarda de tenant.

Validação: aplicada duas vezes (idempotente) no PostgreSQL local; `scripts/verify-multitenant-isolation.sql` passa (0 vazamentos de leitura/escrita, unicidade por tenant, suspensão bloqueia acesso, limite de usuários, RPCs recusadas para não-superadmin).

### Edge Functions

- `_shared/tenant.ts`: sem fallback para o tenant default. Novos helpers `requireTenantFromRequest`, `assertEntityTenant`, `rowTenantOrSkip`, `tenantErrorResponse`; `_shared/auth.ts`: `requireServiceRole`, `authenticateTenantRequest`.
- Removidos os 6 fallbacks `DEFAULT_TENANT`; notificações por cron só saem com instância/grupo do próprio tenant; `tenant_id` do body deixou de ser confiado; `mirror-ig-media` com allowlist e filtro de tenant; `send-whatsapp-cloud` valida a instância; `sync-member-data` por tenant; IDs recebidos no body passam por `assertEntityTenant`; processadores exclusivos de cron exigem `service_role`; regras com `tenant_id` NULL não se aplicam mais a todos. A lista exata de arquivos está no commit.

### Frontend

- Camada `src/lib/tenant-config.ts` (override por tenant → global) usada pelas telas de configuração; logout limpa cache de queries e storage da aplicação; `is_superadmin` carregado; `TOKEN_REFRESHED` atualiza `app_metadata`.
- Página `/superadmin/empresas` (visão geral, lista, editar plano/limite, suspender/reativar, liga/desliga cadastro self-service).
- Link público de agenda por empresa (`/agendar/:token`) e geração de token nas configurações; uploads de gravação e anexos de agente em pastas `<tenant_id>/…`.

### Instalador e docs

- `setup.sh`: `MULTI_TENANT=true` por padrão (cadastro self-service aberto, e-mail confirmado obrigatório); `MULTI_TENANT=false` mantém o comportamento antigo.
- `docs/MULTITENANT.md`: operação SaaS (cadastro, convite, suspensão, limites, chaves por empresa, backup/exclusão).
- `scripts/verify-multitenant-isolation.sql`: teste de isolamento executável em qualquer banco com o schema.

## Pendências e riscos residuais (não resolvidos nesta entrega)

1. **`ai-sales-agent`** (8 300 linhas): estado de módulo por tenant precisa virar contexto por requisição; `blocked_phones` e `ai_agent_logs` sem tenant. Recomendado refatorar antes de operar várias empresas com o agente ativo ao mesmo tempo.
2. **`chat-manager`** / `run_sql`: SQL de LLM. Recomendado desligar a ferramenta ou trocar por RPCs com finalidade fixa.
3. **`whatsapp-webhook` 598-640**: roteamento `ceo_bot`/`content_agent` por telefone global (aponta para funções inexistentes no pacote); remover o bloco.
4. **Realtime**: canais `postgres_changes` globais dependem de RLS (corrigida) — fazer homologação com dois tenants conectados ao mesmo tempo.
5. **Segredos globais compartilhados**: `CRM_PUBLIC_URL`, `BREVO_WEBHOOK_SECRET`, `META_WEBHOOK_VERIFY_TOKEN`, `crm_mcp.clients` são por instalação; aceitável em SaaS de domínio único, mas domínio próprio por empresa exigiria tabela de domínios.
6. **35 tabelas com `tenant_id` anulável**: não vazam (RLS esconde NULL), mas inserts via `service_role` sem tenant geram linhas órfãs. Após homologação, converter para `NOT NULL`.
7. **Página pública `/comercial/prospeccao/diagnostico/:id/print`** por UUID via função `service_role`: trocar por token assinado.
8. **12 Edge Functions referenciadas pelo frontend não existem no pacote** (`sync-ads-data`, `event-app-auth`, `generate-lead-intelligence`, …): funcionalidades quebradas, tenancy não verificável.
9. **Migration `20260914152849`** quebra em banco limpo; corrigir a origem de `from_email` antes de instalar do zero.
10. **`send-whatsapp-cloud`**: quando nenhuma instância é resolvida ainda cai nas chaves legadas `WHATSAPP_CLOUD_TOKEN`/`WHATSAPP_PHONE_NUMBER_ID` via `getIntegrationKey` (override do tenant → `config` global). Remover o fallback global assim que todas as empresas tiverem instância Cloud cadastrada.
11. Homologação em projeto Supabase real com dois tenants e OAuth/MCP ainda precisa ser feita pelo proprietário (não há Supabase nesta sessão).

Relatórios detalhados dos auditores (com `arquivo:linha`) ficam fora do pacote distribuído; os achados relevantes estão resumidos acima e refletidos no código.

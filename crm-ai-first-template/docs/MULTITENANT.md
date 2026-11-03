# Operação multi-tenant (modo SaaS)

A partir de 2026.11, o template instala em **modo SaaS**: várias empresas (tenants) compartilham o mesmo projeto Supabase, cada uma isolada por `tenant_id` + RLS. Leia junto com `docs/SEGURANCA.md` e `docs/AUDITORIA_MULTITENANT.md`.

## Conceitos

| Termo | O que é |
|---|---|
| Tenant / empresa | Linha em `public.tenants`. Todo dado de negócio tem `tenant_id`. |
| Tenant default | `00000000-0000-0000-0000-000000000001`, criado pelo instalador. É a **empresa da plataforma**: só admins dela leem/escrevem a tabela global `config`. |
| Superadmin | `team_members.is_superadmin = true` (o instalador marca o primeiro administrador). Acessa `/superadmin/empresas` e `/superadmin/ia`. Escopo por tenant: um superadmin só vale dentro da própria empresa. |
| Admin da empresa | `team_members.role = 'admin'` do tenant. Gerencia usuários, integrações e configurações da própria empresa. |
| `config` | Valores **globais** da instalação (`SUPABASE_PROJECT_URL`, `multi_tenant_enabled`, chaves de IA patrocinada). |
| `tenant_config_overrides` | Valores **por empresa** (`COMPANY_NAME`, `PIPELINE_ROLES`, `BOOKING_PUBLIC_TOKEN`, `NOTIFICATIONS_INSTANCE_ID`, chaves de integração…). Edge Functions e frontend leem override → global. |
| `tenant_config` | Identidade visual e remetente de e-mail da empresa. |

## Como o tenant é resolvido

- **Frontend / PostgREST**: JWT `app_metadata.tenant_id` → `get_tenant_id()`. Retorna NULL (bloqueia tudo) se o usuário não tiver vínculo ativo em `team_members` numa empresa ativa.
- **Edge Functions chamadas pelo navegador**: `requireTenantFromRequest(req)`; sem tenant → 401. Não há fallback para o tenant default.
- **Webhooks**: tenant vem da entidade (instância WhatsApp, conexão, token na URL) e é validado contra o banco.
- **Crons**: processam linha a linha usando o `tenant_id` da própria linha; linhas sem tenant são ignoradas e registradas. Credenciais (instância de notificação, grupo, chaves) vêm só de `tenant_config_overrides` do tenant.
- **MCP**: `crm_mcp.context()` deriva o tenant do token OAuth; nenhuma tool escolhe tenant.

## Fluxos

### Cadastro de uma nova empresa (self-service)
1. `config.multi_tenant_enabled = 'true'` (padrão; liga/desliga em `/superadmin/empresas`). O Auth do Supabase precisa aceitar cadastro (`disable_signup=false`) e exigir confirmação de e-mail — o instalador já faz isso com `MULTI_TENANT=true`.
2. Usuário acessa `/login?cadastro=1`, cria conta, confirma e-mail, informa o nome da empresa em `/criar-empresa`.
3. `tenant_onboard` cria tenant (slug legível, plano `trial` 14 dias), admin, `tenant_config`, `COMPANY_NAME`, `BOOKING_PUBLIC_TOKEN` e o funil padrão; grava `app_metadata.tenant_id`; o app faz `refreshSession()`.

### Convidar usuários para a empresa
Pelo admin da empresa em Configurações → Equipe (Edge Function `manage-team-member`, cria o usuário já com `app_metadata.tenant_id`) ou pela IA via MCP (`mcp_team('provision')`). Um e-mail só pode pertencer a uma empresa.

### Suspender / reativar / limitar
`/superadmin/empresas` → editar: plano, limite de usuários (`max_users`, aplicado por trigger), validade do trial, suspender com motivo. Tenant suspenso (`is_active=false`) faz `get_tenant_id()` retornar NULL: usuários perdem acesso imediatamente, webhooks e crons passam a ignorar a empresa.

### Chaves de integração por empresa
Cada empresa configura suas próprias chaves (WhatsApp, Meta, e-mail, IA) em Configurações; o frontend grava em `tenant_config_overrides`. Chaves globais em `config` só valem como fallback **não sensível** (URL do projeto, flags). Nunca coloque credenciais de uma empresa em `config`.

Obrigatórias por empresa para os crons de notificação: `NOTIFICATIONS_INSTANCE_ID` e `NOTIFICATIONS_GROUP_JID`. Sem elas a empresa não recebe digests/alertas (e não cai no número de outra empresa).

### Link público de agendamento
`/agendar/<BOOKING_PUBLIC_TOKEN da empresa>`. O token é criado no onboarding e pode ser regenerado em Configurações. `VITE_BOOKING_PUBLIC_TOKEN` (build) continua valendo apenas para `/agendar` da empresa default.

### Storage
Caminhos sempre `<tenant_id>/…` (`call-recordings`, `agent-uploads`). As policies recusam outros prefixos. Objetos antigos em `recordings/…` só são acessíveis via `service_role`.

## Instalação

```bash
MULTI_TENANT=true ./setup.sh      # padrão: SaaS
MULTI_TENANT=false ./setup.sh     # empresa única (cadastro fechado)
```

Atualizando uma instalação existente: aplique as migrations pendentes (inclui `20261103120000_multitenant_saas_hardening.sql`, que liga o modo SaaS). Para continuar em empresa única, rode depois `UPDATE public.config SET value='false' WHERE key='multi_tenant_enabled';` ou use o toggle em `/superadmin/empresas`. Reative o cadastro no Auth do Supabase se quiser self-service.

## Verificação

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/verify-multitenant-isolation.sql
```

Cria duas empresas sintéticas, tenta ler/alterar dados cruzados, testa unicidade por tenant, suspensão e limite de usuários, e desfaz tudo (`ROLLBACK`). Deve terminar com 6 linhas `OK`. Rode após qualquer migration nova.

Checklist de homologação com dois tenants reais: login em abas separadas, pipeline, inbox WhatsApp (instâncias distintas), agenda pública dos dois tokens, upload de gravação, agente de IA respondendo só com as credenciais da própria empresa, superadmin suspendendo e reativando uma empresa.

## Backup, exportação e exclusão (LGPD)

- Exportar uma empresa: `pg_dump --data-only` filtrado não existe no Postgres; use `COPY (SELECT … WHERE tenant_id = …) TO STDOUT` por tabela (`SELECT relname FROM pg_class … WHERE tenant_id existe`) ou a API com um usuário admin daquela empresa (RLS limita ao tenant).
- Excluir uma empresa: suspenda primeiro; depois, com `service_role`, apague as linhas das tabelas com `tenant_id` (há FKs sem `ON DELETE CASCADE`; apague filhas antes das pais), objetos de storage sob `<tenant_id>/`, usuários Auth dos `team_members` e por fim a linha em `tenants`.
- Backups do projeto são compartilhados entre empresas; a restauração parcial de um tenant exige os passos acima a partir de um restore em projeto separado.

## Limites conhecidos

- Domínio próprio por empresa não é suportado (`CRM_PUBLIC_URL` único). Branding por empresa via `tenant_config`.
- Um usuário pertence a uma empresa (sem troca de empresa na interface).
- Segredos de webhook do Brevo e verify token da Meta são por instalação.
- Ver “Pendências” em `docs/AUDITORIA_MULTITENANT.md` antes de operar o agente de IA de vendas e o chat-manager com várias empresas simultâneas.

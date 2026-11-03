# Atualização de CRM existente para 2026.11.03

Este guia é para quem já tem instalação. Não rode setup.sh: ele cria um projeto novo.

1. Faça backup do código e do banco. Confirme a possibilidade de restauração antes de alterações.
2. Preserve .env*, vínculos da hospedagem, credenciais e arquivos locais do membro.
3. Compare código, dependências e customizações. Copie as atualizações sem sobrescrever configurações pessoais; use npm ci com os lockfiles distribuídos.
4. Confira as migrations aplicadas e o schema real. Aplique apenas as pendentes em ordem; nunca reaplique 000_baseline_full.sql e nunca presuma que todos os deltas são idempotentes. Se houver drift, prepare uma correção incremental.
5. Publique as funções usando o supabase/config.toml distribuído. Não use --no-verify-jwt globalmente; funções públicas continuam exigindo validação interna adequada.
6. Configure CRM_PUBLIC_URL para o domínio próprio e conclua docs/PUBLICAR_E_CONECTAR_MCP.md. Faça build e publique frontend/MCP na hospedagem do membro.
7. Valide login, permissões, pipeline, agente, formulário, inbox e integrações em uso. Registre resultados e plano de rollback.

Os novos recursos incluem MCP, configurações de agentes por conversa, playground, formulários públicos, canais com campos, inbox unificado, recebimento social e relatórios. Credenciais e contas existentes pertencem ao membro e devem ser preservadas.

## Esta versão: hardening multi-tenant

A migration `20261103120000_multitenant_saas_hardening.sql` fecha vazamentos entre empresas (policies permissivas, storage, unicidade global, superadmin sem escopo) e **liga o modo SaaS** (`multi_tenant_enabled='true'`). Efeitos a conferir após aplicar:

- Caminhos de storage passam a exigir `<tenant_id>/…`; gravações antigas em `recordings/…` ficam acessíveis só via `service_role` (URLs assinadas já emitidas continuam válidas).
- Slugs/labels passam a ser únicos por empresa; seeds próprios que usem `ON CONFLICT (slug)` em `agents_registry` precisam mudar para `ON CONFLICT (tenant_id, slug)`.
- Configurações por empresa (chaves, módulos, prompts) passam a ser lidas/gravadas em `tenant_config_overrides`; a tabela `config` segue só para valores globais da instalação. A empresa default continua lendo `config` como fallback.
- Crons de notificação só enviam para empresas com `NOTIFICATIONS_INSTANCE_ID`/`NOTIFICATIONS_GROUP_JID` próprios.
- Para continuar em empresa única: `UPDATE public.config SET value='false' WHERE key='multi_tenant_enabled';` (ou o toggle em `/superadmin/empresas`).

Rode `scripts/verify-multitenant-isolation.sql` depois da atualização e siga `docs/MULTITENANT.md`.

## 2026.11.03 — Multi-tenant (SaaS)

- Auditoria completa de isolamento por empresa (`docs/AUDITORIA_MULTITENANT.md`).
- Migration `20261103120000_multitenant_saas_hardening.sql`: 42 policies permissivas corrigidas, `cs_event_*` com tenant, unicidade por tenant, storage por tenant, plano/suspensão/limite em `tenants`, RPCs de plataforma, `tenant_onboard` v2, `multi_tenant_enabled=true`.
- Edge Functions sem fallback para o tenant default; IDs do body validados por tenant; crons exigem `service_role`.
- Frontend: configurações por empresa (`tenant_config_overrides`), limpeza de cache no logout, `/superadmin/empresas`, `/agendar/:token`, uploads em `<tenant_id>/…`.
- `setup.sh` com `MULTI_TENANT` (padrão `true`); `scripts/verify-multitenant-isolation.sql`; `docs/MULTITENANT.md`.

# Template 2026.09.14

Inclui as melhorias desenvolvidas sobre o ZIP original: MCP OAuth e ferramentas, agentes com habilidades, playground opcional por contato, formulários e canais, campos, inbox unificado, integração social e métricas, consultas Meta Ads, correções de Realtime e isolamento.

Adaptações de distribuição: domínio por CRM_PUBLIC_URL, instalador com Node 22 e proteção contra recriação acidental, exemplos genéricos, documentação de MCP/OAuth, exclusão de arquivos privados e evidências de clientes.

A sequência histórica de migrations é preservada. Modelos e serviços externos não são patrocinados pelo pacote.

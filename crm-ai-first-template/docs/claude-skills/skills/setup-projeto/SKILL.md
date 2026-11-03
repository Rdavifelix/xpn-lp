---
name: setup-projeto
description: Instala o CRM AI-First com o instalador oficial e valida o resultado.
---

# Setup do CRM AI-First

Use somente o fluxo mantido em `setup.sh`.

1. Explique que o script cria um projeto Supabase novo e um administrador.
2. Confirme que Node.js 22+, npm, Supabase CLI, curl, jq e openssl existem.
3. Oriente `supabase login`.
4. Com autorização do usuário, execute `./setup.sh` e acompanhe até concluir.
5. Nunca aplique migrations individualmente, nunca use `--no-verify-jwt` fora das funções já declaradas no `supabase/config.toml` e nunca exponha `service_role`.
6. Valide com `npm run typecheck`, `npm test`, `npm run build`, `./scripts/check-edge-functions.sh` e `bash scripts/health-check.sh`.
7. O cadastro público permanece desativado. O usuário entra com o administrador criado pelo instalador.

Se o setup parar, diagnostique a etapa e continue apenas com ações idempotentes. Não recrie outro projeto sem confirmar com o usuário.

8. Finalize docs/PUBLICAR_E_CONECTAR_MCP.md. Não diga que MCP está pronto antes de testar OAuth autenticado. Windows usa WSL2.

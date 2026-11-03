# CRM AI-First — orientações para assistentes

Leia AGENTS.md, README.md, docs/SEGURANCA.md e docs/OPERACAO.md.
Respeite o pedido do usuário. Detecte instalação nova versus atualização antes de operar.

## Instalação nova

Sem .setup-complete e sem .env/.installation-project.json: siga .claude/skills/setup-projeto/SKILL.md. Se a pasta oculta não veio na cópia, restaure de docs/claude-skills. Instale no projeto Supabase do membro; nunca use infraestrutura da imersão.
Se existe .installation-project.json, houve instalação iniciada: recupere o mesmo projeto após conferir a etapa. Não rode setup.sh novamente para criar outro.

## Atualização

Preserve ambiente e dados; siga GUIA_UPGRADE.md. Nunca reaplique baseline em banco existente. Não altere migrations históricas aplicadas.

## Arquitetura atual

React 18/TypeScript/Vite, Tailwind/shadcn, TanStack Query; Supabase Postgres/Auth/Edge Functions/Realtime; servidor MCP Node 22 em mcp-server, integrado por netlify/functions. Configuração Netlify em netlify.toml. Sem obrigação de usar Vercel; outro host deve hospedar também o servidor MCP.

Agentes em src/agents-platform; executor agent-runner; contexto e isolamento validados no servidor. Playground pode conversar sem lead; quando o operador seleciona contato/oportunidade, as ações usam os IDs validados. Credenciais de modelo, canais e ferramentas precisam ser configurados.

MCP com OAuth acessa RPCs escopadas; o usuário não escolhe tenant arbitrariamente. Ferramentas não equivalem a autorização irrestrita. Nunca liberar SQL genérico ou remover validação de tenant para resolver um erro.

Modo SaaS (multi-tenant) é o padrão desde 2026.11: várias empresas no mesmo banco, isoladas por `tenant_id` + RLS. Regras: toda policy permissiva em tabela com `tenant_id` exige `tenant_id = get_tenant_id()`; Edge Functions usam `requireTenantFromRequest`/`assertEntityTenant` (sem fallback para o tenant default); configurações por empresa vão em `tenant_config_overrides`, nunca na `config` global; storage em `<tenant_id>/…`. Após qualquer migration, rode `scripts/verify-multitenant-isolation.sql`. Ver docs/MULTITENANT.md e docs/AUDITORIA_MULTITENANT.md.

## Configuração de ambiente

CRM_PUBLIC_URL nas funções é a origem HTTPS desta instalação. VITE_MCP_PUBLIC_URL e MCP_PUBLIC_URL apontam ao mesmo endpoint /mcp. Configure OAuth e o hook conforme docs/PUBLICAR_E_CONECTAR_MCP.md.

Nunca distribuir .env, .env.hosting, .env.local, .installation-project.json, .netlify, supabase/.temp ou tokens. Patrocínio global é opcional e começa sem credenciais. Chaves de serviço nunca vão para variáveis VITE_*.

## Encerramento

Execute os checks descritos no README e faça testes funcionais apropriados. Distingua build aprovado de integração real aprovada; registre o que depende de credenciais externas. Não envie mensagens nem publique campanhas sem autorização.

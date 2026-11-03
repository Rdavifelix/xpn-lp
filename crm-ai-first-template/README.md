# CRM AI-First — Template 2026.11.03 (multi-tenant)

Sua própria instalação de CRM **multi-tenant (SaaS)**: várias empresas isoladas por RLS no mesmo projeto Supabase, com pipeline, agentes, MCP, formulários, canais de entrada, inbox WhatsApp/Instagram, agenda e relatórios de marketing. Leia [docs/MULTITENANT.md](docs/MULTITENANT.md) e [docs/AUDITORIA_MULTITENANT.md](docs/AUDITORIA_MULTITENANT.md).

## Começar

Abra esta pasta no seu assistente de programação e diga: **“Configure meu CRM seguindo LEIA-ME-PRIMEIRO.md.”**

- macOS/Linux: Node.js 22+, npm, Supabase CLI, curl, jq e openssl.
- Windows: use WSL2 com Ubuntu para executar o instalador Bash e instale os pré-requisitos dentro do WSL.
- Uma conta Supabase com capacidade para um projeto novo; uma hospedagem e seu endereço HTTPS reservado. O projeto pode gerar custos conforme os planos escolhidos.

```bash
supabase login
./setup.sh                 # modo SaaS (padrão); MULTI_TENANT=false ./setup.sh para empresa única
npm run dev
```

O instalador cria um Supabase independente, aplica migrations, configura cofre, publica funções e cria seu administrador. Solicita um token da sua conta Supabase; nunca envie tokens ou senhas pelo chat. O cadastro público fica desativado por padrão. As credenciais dos provedores são suas; este pacote não contém créditos de IA nem contas conectadas.

Depois, finalize [publicação e MCP](docs/PUBLICAR_E_CONECTAR_MCP.md). O banco instalado não significa que OAuth e integrações externas já estejam autorizados.

## Conteúdo

- Código frontend/backend e servidor MCP remoto.
- Modelos de agentes e catálogo de habilidades definidos nas migrations.
- Captura por formulário/URL, campos e regras de distribuição.
- Inbox unificado e recebimento automático de redes após conectar o provedor.
- Playground com seleção opcional de contato/oportunidade; ações reais quando executadas.
- Consulta de anúncios por integração configurada. Não assumir que uma consulta autoriza alterar campanhas.

## Verificação

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/verify-multitenant-isolation.sql
npm run check
npm --prefix mcp-server ci
npm --prefix mcp-server run check
./scripts/check-edge-functions.sh
npm --prefix extension ci
npm --prefix extension run build
npx tsc -p extension/tsconfig.json --noEmit
```

Para atualizar um CRM existente, use [GUIA_UPGRADE.md](GUIA_UPGRADE.md). Nunca execute o instalador novo sobre uma instalação existente.

Veja [VALIDACAO_DISTRIBUICAO.md](VALIDACAO_DISTRIBUICAO.md) para os testes executados e suas limitações. O pacote não inclui um dump dos dados da imersão.

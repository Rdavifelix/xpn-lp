# WhatsApp Uazapi pelo MCP — v0.9.0

## Fluxo do cliente

1. Cadastrar URL HTTPS e Admin Token Uazapi em Configurações > Integrações > API Keys. Nunca colar chaves no chat. O resolvedor existente usa override da empresa e, quando configurado, credenciais globais da instalação.
2. `listar_instancias_whatsapp`: confirma configuração e lista apenas instâncias/canais da empresa autenticada.
3. `criar_instancia_whatsapp`: nome e request_id UUID estável. Cria desconectada via `/instance/create`. Não recebe token do cliente nem devolve segredo do provedor.
4. `gerar_qrcode_whatsapp`: configura webhook do CRM, inicia conexão e devolve QR como imagem MCP. O titular escaneia em WhatsApp > Aparelhos conectados. Esta operação substitui a configuração simples de webhook; usar instância destinada ao CRM.
5. `consultar_conexao_whatsapp`: consulta provedor, atualiza estado local e verifica webhook. Pode devolver QR atualizado enquanto aguarda leitura. Se expirar, gerar novamente.
6. Preparar agente, habilidades, conhecimento, credencial e testar no playground. Ativar agente com as ferramentas existentes quando autorizado.
7. `vincular_whatsapp_agente`: active=false prepara/pausa canal; active=true habilita atendimento e roteador V2. Exige instância conectada, webhook válido e agente ativo; conflitos com outro agente são recusados. Não troca uma instância já atribuída ao mesmo agente.
8. Titular envia uma mensagem de teste autorizada de outro número e confere conversa/ações. `delivery_tested:false` permanece explícito: conectar não comprova entrega.

## Limites

- Implementa conexão e atendimento reativo pelo roteador V2 existente. Não inicia automaticamente conversa após formulário e não inclui disparos/cadências de campanha.
- Não envia mensagens de teste para terceiros por conta própria.
- O cliente precisa escanear o QR. A geração real depende de credenciais/servidor Uazapi funcionais.
- Repetir criação mantém request_id. Se a resposta original se perder, busca apenas instância com metadados exatos da empresa e da solicitação. Em caso incerto não cria outra cegamente; retorna `creation_unconfirmed`.
- Pausar o canal não desconecta o número e não desativa canais de outros agentes.
- Uma oportunidade aberta do contato é repassada ao runner. Se houver zero ou várias, não escolhe nem inventa uma oportunidade.

## Segurança e arquitetura

- MCP não usa service_role. `mcp-whatsapp` valida JWT OAuth através de `mcp_context`, incluindo cliente, sessão revogada, membro/empresa ativos e can_write.
- O adaptador usa service role somente após essa validação, filtra todas as consultas por tenant e chama RPC fixa `mcp_whatsapp_admin`. RPC e tabela de solicitações são inacessíveis a anon/authenticated; tabela privada com RLS.
- Instâncias guardam segredo apenas no backend. Respostas são allowlist; excluem token, Admin Token, configuração secreta e URL autenticada do webhook. QR temporário é imagem e não deve ir para planos/notas/prompts.
- Requests ao provedor têm timeout, redirects proibidos e endpoints fixos. Configuração do webhook é confirmada por leitura; falha não vira prontidão fictícia.
- Roteamento deriva tenant da instância, usando plataforma de agentes existente.

## Validação em 10/09/2026

- Teste transacional `scripts/verify-mcp-whatsapp.sql`: criação/replay, vínculo inativo, ativação conectada, roteador, conflito, pausa e fronteira entre empresas. Rollback, sem instâncias reais criadas.
- Testes MCP: contrato do provedor com respostas simuladas, falhas sem vazamento, imagem nativa, catálogo admin e seleção não ambígua de oportunidade.
- Teste OAuth real no projeto: listagem, configuração ausente, recusa anônima/instância ausente/tenant no payload.
- Nenhuma credencial Uazapi configurada na conta QA ou no banco da instalação. QR real e troca de mensagens permanecem aguardando configuração e leitura pelo titular.

Fontes do contrato: https://docs.uazapi.com/openapi-bundled.json (10/09/2026), `/instance/create`, `/instance/connect`, `/instance/status` e `/webhook`.

Publicação confirmada: Netlify `6aa2aec0a4c4944984b4bf07`; MCP inicializou como v0.9.0 com 115 ferramentas. Teste após deploy via SDK MCP + OAuth real encontrou as cinco ferramentas, listou a conta QA e retornou erro explícito na criação sem credenciais. Edge Functions mcp-whatsapp, whatsapp-webhook e agent-runner publicadas. Migration 20260910130900 registrada. Verificações: app 13 testes + build/typecheck, MCP 11 testes + build, todas as Edge Functions, extensão typecheck/build e advisors sem erros. Conta QA desativada e sessões revogadas após teste; nenhuma instância criada na Uazapi.

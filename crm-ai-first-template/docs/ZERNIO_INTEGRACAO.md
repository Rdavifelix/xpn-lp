# Zernio por empresa

Cada tenant fornece sua própria chave em `/configuracoes?s=zernio`. Não há fallback global. A chave fica em `zernio_connections`, sem permissões de leitura/escrita para anon ou authenticated; somente o backend acessa. Chaves iguais não podem ser compartilhadas entre tenants e IDs de contas são exclusivos. O contexto vem de usuário/membro ativo validado no banco, incluindo OAuth MCP.

## O que foi integrado

- Catálogo das 16 redes/canais sociais, 7 conexões de anúncios e Shopify (artigos).
- Validação da chave via perfis, sincronização de contas e fluxos de conexão do provedor. Perfis existentes são escolhidos pelo administrador; não se cria assinatura Zernio pelo CRM.
- Instagram, Facebook e demais redes OAuth usam autorização hospedada pelo Zernio. Meta Ads usa Facebook Login for Business; Google Ads usa conexão própria. X Ads precisa da conta X de origem. Quando não há origem inequívoca ou a rede exige credenciais específicas (Bluesky/OpenAI Ads/Shopify), a tela orienta a conexão no painel Zernio e posterior sincronização. Telegram fornece código e instruções do bot.
- A rota `/comercial/inbox` mantém WhatsApp Uazapi/Cloud; `?channel=social` abre contas Zernio, conversa, envio, publicações e campanhas comentário→DM. Não havia rota Instagram dedicada ativa em App.tsx; havia componentes e tabelas reutilizáveis.
- Eventos Instagram são espelhados em `instagram_conversations`/`instagram_messages`; o envio do chat legado de um contato reconhece o vínculo e usa Zernio. Contas legadas mantêm seu caminho anterior.
- Ao configurar responsável, funil e etapa, novas conversas recebidas criam contato/deal. Ativar atendimento requer agente ativo e habilita o agent-runner existente com lead_id/deal_id e suas ferramentas. Mensagens de texto recebidas são atendidas; anexos ficam disponíveis no inbox, sem alegar interpretação multimodal automática neste adaptador.
- Rascunhos, publicação/agendamento para uma conta por operação; opções específicas de rede disponíveis no MCP. Anúncios: conexão e consulta da árvore existente. Esta entrega não implementa editor de campanhas pagas/orçamentos.
- Campanhas comentário→DM usam a automação nativa Zernio. O rascunho é local; ativação explícita cria a automação no provedor, pois a documentação de criação não garante isActive=false. Se a pessoa responder, o agente configurado recebe a mensagem.

## Recebimento e operação

`zernio-webhook` verifica HMAC-SHA256 do corpo bruto com segredo próprio da conexão. Eventos são persistidos e deduplicados pelo ID antes do processamento. A conta do evento deve existir no tenant. O job `zernio-pending` drena eventos pendentes a cada minuto; `SUPABASE_PROJECT_URL` em config define a URL do projeto. Mensagens na mesma conversa aguardam atendimento em andamento.

Envios possuem registro durável por request_id e hash do pedido. O backend envia Idempotency-Key para mensagens e x-request-id para posts. Em timeout/falha incerta não repete automaticamente: registra unconfirmed/needs_attention para inspeção do histórico. O recebimento de mensagem em standby (Meta Business Agent) não dispara nosso agente.

OAuth de retorno nunca vincula conta por parâmetros da URL: a sincronização consulta a API autenticada. Trocar a chave pausa as contas e renova o segredo/endereço do webhook; configure recebimento novamente. Desconectar conta pausa o atendimento local.

## MCP

Versão 0.11.0: 21 novas ferramentas de status, perfis, contas, eventos, conexões, webhook, atendimento, conversas, mensagens, posts, anúncios e campanhas de comentário. A chave é cadastrada pela interface, não pelo chat. Escritas exigem administrador; leituras exigem membro ativo.

## Validação e limites

- Testes de contrato do adaptador: endpoints sociais/anúncios, remoção de segredos, assinatura por tenant, headers de idempotência, falhas sem retry e resposta parcial.
- `scripts/verify-zernio.sql`: transação com rollback cobre entrada→contato/deal, espelhamento Instagram, deduplicação, conta desconhecida e permissões de segredo.
- HTTP publicado: assinatura inválida 401, evento sintético válido 202, repetição 200; banco confirmou um evento concluído com contato/deal.
- UI: configuração abre na seção correta, catálogo renderiza e a navegação entre WhatsApp e social preserva a rota existente.
- Nenhuma chave Zernio real foi fornecida durante implementação. OAuth social, leitura de contas reais, envio/publicação e resposta real do agente pelo provedor permanecem dependentes da chave e autorização do titular. Não foram enviados posts nem mensagens a terceiros.

As redes não têm os mesmos recursos. Snapchat está em beta fechado; TikTok/Pinterest/Snapchat não oferecem inbox Zernio; YouTube/Threads não oferecem DMs. Custos, planos, escopos, janelas de mensagem e formatos continuam sujeitos ao provedor.

## Referências consultadas

- https://docs.zernio.com/llms.txt
- https://docs.zernio.com/accounts/list-accounts
- https://docs.zernio.com/connect/get-connect-url
- https://docs.zernio.com/connect/connect-ads
- https://docs.zernio.com/messages/get-inbox-conversation-messages
- https://docs.zernio.com/messages/send-inbox-message
- https://docs.zernio.com/webhooks/inbox
- https://docs.zernio.com/webhooks
- https://docs.zernio.com/posts/create-post
- https://docs.zernio.com/comment-automations/create-comment-automation

Verificação final em produção (10/09/2026): MCP v0.11.0 anunciou 146 ferramentas; consultas autenticadas de integração, contas, eventos e opções de atendimento passaram. A consulta de agentes usa o campo existente `display_name` com alias `name`. O tenant de QA foi desativado, suas sessões revogadas e a credencial sintética removida após o teste.

Atualização posterior: o atendimento foi unificado por canal com adaptadores Zernio/Meta; comentários agora alimentam o inbox. Consulte `SOCIAL_PROVIDERS.md` para o contrato, validação e limites atuais, que substituem a descrição anterior de comentários apenas como eventos.

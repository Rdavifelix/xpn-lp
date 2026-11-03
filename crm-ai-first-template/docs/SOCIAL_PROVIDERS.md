# Atendimento social com provedores intercambiáveis

Atualização de 10/09/2026, MCP 0.12.0.

O canal Instagram usa um único inbox, histórico e função de envio. `provider` é um atributo da conexão (`zernio` ou `meta`). As tabelas `zernio_accounts`, `zernio_conversations`, `zernio_events` e `zernio_operations` mantêm seus nomes e IDs por compatibilidade; agora também guardam conexões Meta. Não foram duplicadas por provedor. `instagram_conversations` e `instagram_messages` continuam sendo o histórico usado pelo chat e pelo contato.

- `social-api` e o endpoint antigo `zernio-api` executam o mesmo `socialApi`.
- `socialSend` é usado pela interface, MCP e resposta do agente. Resolve credencial no servidor e adapta o pedido à API conectada.
- Webhooks exigem as assinaturas próprias de cada provedor. Ambos passam pelo mesmo contrato de interação e RPC `social_record_interaction`.
- Comentários usam `post_comment`, respostas públicas usam `comment_reply`, directs usam os tipos de mensagem existentes. O post e o comentário de origem ficam registrados.
- Comentário seguido de direct do mesmo identificador de participante/conexão preserva contato, oportunidade e conversa. Não fazemos junção automática por nome ou username entre contas/provedores.
- Eco e reentrega são deduplicados por identificador nativo, escopado à conta Instagram. Credenciais Meta ficam em tabela privada ao service role; o navegador recebe apenas campos de configuração não secretos, salvo o token de verificação do callback exibido ao administrador.
- Comentário por si só não abre a janela de atendimento de DM e não aciona o agente como se fosse direct. O operador escolhe explicitamente resposta pública ou private reply. A janela e o limite de private reply continuam sujeitos à API.

## Interface

Configurações → Redes sociais (o link anterior `?s=zernio` permanece válido). A conexão Zernio e a conexão Meta direto são configuradas nessa área. Meta direto exige token válido, ID da conta, App Secret e configuração do callback/assinaturas no aplicativo Meta. Facebook Login exige também o ID da Página usada no envio.

Inbox → Redes sociais → selecionar a conta. Instagram reaproveita `InstagramChat`, com comentários e directs na mesma tela, botões “Responder comentário” e “Responder por DM”.

A importação manual de histórico anterior não dispara agentes nem cria oportunidades retroativas. Sem post importa páginas de cinco conversas, até 50 mensagens por conversa; com post importa comentários paginados. Não é uma exportação completa de todo o histórico remoto.

## MCP

As ferramentas existentes continuam válidas e usam `social-api`. Foram acrescentadas:

- `listar_contas_sociais`
- `responder_comentario_social`
- `enviar_dm_do_comentario`
- `importar_historico_social`

Nas respostas aos comentários, `comment_id` é o UUID local da mensagem `post_comment` retornada pela consulta de mensagens. O servidor resolve o identificador externo e verifica a conversa/conta antes do envio.

## Escopo e validação

O contrato comum cobre o atendimento Instagram: configuração de destino/agente, recebimento, histórico, direct textual, resposta pública e private reply. Publicações, anúncios e automações nativas de comentário → DM continuam sendo capacidades do adaptador Zernio; o adaptador Meta direto ainda não implementa essas ações nem envio de anexos. Elas não devem ser anunciadas como disponíveis por Meta direto.

Testes SQL transacionais verificam ambos os provedores, comentário → direct na mesma conversa, destino do deal, eco/reentrega, resposta própria e isolamento. Testes Deno verificam normalização e os caminhos de envio dos dois adaptadores com HTTP simulado. Testes HTTP assinados usam exclusivamente contas sintéticas, sem envio externo. A interface foi verificada com comentários/directs sintéticos nos dois provedores. O teste de ponta a ponta com contas reais depende das credenciais do titular; não foi realizado com tokens reais.

Documentação consultada:
- https://docs.zernio.com/webhooks/inbox.mdx
- https://docs.zernio.com/comments/reply-to-inbox-post.mdx
- https://docs.zernio.com/comments/send-private-reply-to-comment.mdx
- https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api

Verificação final em produção: MCP 0.12.0 anunciou 150 ferramentas. Consultas autenticadas retornaram comentário, direct e resposta pública no mesmo histórico para os dois provedores sintéticos; uma tentativa com comentário não pertencente à conversa foi rejeitada antes do envio. Deploy Netlify: `6aa319d70cb91ad0380d80ad`. As credenciais sintéticas foram removidas e o tenant de QA/sessões encerrados após o teste.

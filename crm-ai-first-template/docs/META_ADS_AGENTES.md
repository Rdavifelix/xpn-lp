# Meta Ads nos agentes

As consultas `listar_contas_meta_ads`, `consultar_campanhas_meta_ads` e `consultar_metricas_meta_ads` aceitam Meta direta e Zernio. O template Vinicius inclui as três; outros agentes podem instalá-las pelo catálogo de habilidades, inclusive via MCP. A ferramenta legada `meta_api` e suas credenciais permanecem intactas.

- Zernio: Configurações → Redes sociais → chave da empresa → conectar Meta Ads → sincronizar contas.
- Meta direta: Agentes → Credenciais → Meta Ads. Uma credencial privada só é acessível ao membro proprietário; compartilhe com a empresa para agentes executados sem esse membro.
- No playground: “Liste minhas contas Meta Ads e analise os últimos 30 dias”. Havendo várias conexões, escolha `connection_id`; escolha também `ad_account_id` quando houver várias contas. O provedor nunca é trocado após uma falha.

As chaves ficam no servidor. Tenant e membro vêm da sessão autenticada, não dos argumentos do modelo. As chamadas passam pelo log normal do agente. As consultas fixas de anúncios são permitidas no playground; isso não libera HTTP arbitrário.

As três habilidades são somente leitura. Não implementam criação, pausa ou alteração de orçamento via Zernio. A ferramenta legada direta mantém seu comportamento anterior. Permissões e aprovação dessa ferramenta não são alteradas pela migration.

Métricas usam últimos 30 dias por padrão ou intervalo explícito. Ausência/erro não equivale a zero. Resultados são paginados: Meta fornece cursores; a árvore Zernio usa `page`. Estruturas aninhadas Meta têm até 25 itens por página. Orçamentos Graph são unidades mínimas da moeda; não devem ser somados a valores monetários de métricas sem conversão.

Referências de contrato: https://zernio.com/docs (GET /v1/ads/accounts, /ads/tree, /ads/insights), https://developers.facebook.com/docs/marketing-api/insights/ e coleção oficial Meta no Postman. Testes automatizados usam respostas simuladas; validação com uma conta real depende da conexão do titular.

Validação desta entrega: 7 testes de contrato/isolamento dos adaptadores, 14 testes do app, 12 do MCP, builds do app/MCP/extensão e checagem de todas as Edge Functions aprovados. MCP publicado v0.13.0 confirmou 153 ferramentas, resposta orientativa sem conexão e recusa de conexão de outra empresa. Template e catálogo verificados no banco; Meta API legada preservada. Advisors sem erros. Conta QA desativada ao encerrar.

# Marketing → Páginas

Rota `/marketing/paginas`. Cadastra nome + URL HTTPS sem query/fragmento, fornece snippet para a landing page, indica recebimento da primeira visita, permite pausar/retomar e consultar 7/30/90 dias. Não instala o código automaticamente em sites externos.

## Instalação

Cole o snippet gerado no head da página. Use `data-crm-track="Nome do botão"` nos elementos cujo clique deseja medir. Formulários próprios: aguarde `window.CRMTracking?.ready`, depois envie `window.CRMTracking?.attach(dados) ?? dados` para o canal de entrada. O exemplo em Canais já inclui essas linhas.

Links/iframes para `/form/{id}` no mesmo CRM que hospeda o script recebem `crm_page`/`crm_session` automaticamente, após o servidor aceitar a visita. O formulário público leva esses valores para a submissão confirmada. Não marque um envio como conversão apenas por clique: a atribuição ocorre na transação do recebimento efetivo.

## Dados e limites

- Visualizações e cliques de elementos marcados; visitantes estimados por ID aleatório local ao navegador. Sessão renovada após 30 minutos entre carregamentos.
- Não coleta valores digitados, IP, query string completa nem texto dos botões. Somente path autorizado, rótulo explícito, utm_source/medium/campaign e hostname de origem. Respeita DNT/GPC sem gravar identificadores.
- O identificador do rastreador é público e permite apenas escrita. Validação de origem/path reduz eventos acidentais, não prova que o visitante é humano. Bloqueadores e preferências podem causar subcontagem.
- Coleta limitada a 20 mil eventos/página/dia e 200/sessão/hora; payload até 4KB. Reenvio com o mesmo event_id não duplica.
- Conversão = sessões iniciadas no período com cadastro confirmado / sessões iniciadas no período. Leads são contados de forma distinta. Ganhas são oportunidades vinculadas a essas sessões cujo status atual é won.
- O primeiro contato identificado vincula a sessão, preserva origem do lead e leva visita/cliques anteriores à timeline. Atividades futuras da mesma sessão também são registradas. Não permite reatribuir a sessão a outro contato. Não realiza identificação probabilística entre dispositivos.
- Página, sessão, lead e deal precisam pertencer ao mesmo tenant. Dados ficam no schema privado crm_web; leitura/administração passa por RPC autenticada e autorizada. Tracker nunca recebe contatos ou relatórios.

## MCP

`listar_paginas_marketing`, `cadastrar_pagina_marketing` (retorna código pronto), `consultar_relatorio_pagina`, `alterar_rastreamento_pagina`. Cadastro/pausa exigem admin. Não há permissão de instalação automática em sites externos.

## Validação

`scripts/verify-marketing-pages.sql`: visita, clique, idempotência, origem incorreta, formulário nativo, formulário externo, conversão real, retrospectiva na timeline, atividade posterior, isolamento e pausa. Testes unitários do tracker verificam vínculo só após aceitar visita, payload original preservado e DNT sem armazenamento/rede.

Teste visual com landing page local e tenant QA: clique no CTA → formulário → sucesso → sessão vinculada ao lead, origem instagram e campanha qa_imersao. Artefato de landing local removido antes do build de produção. Sem mensagens externas.

Publicação 10/09/2026: Netlify `6aa336e3bd04bd2f73af5a25`. Rota e tracker HTTP 200. Relatório visual confirmou 1 visualização, 1 visitante, 1 clique e 1 lead/conversão; modal da timeline confirmou página, botão, origem e campanha. 17 testes frontend e 12 MCP passaram, build e typecheck da extensão passaram; SQL de regressão e advisor de segurança sem erros. Tenant, formulário e página QA desativados após o teste.

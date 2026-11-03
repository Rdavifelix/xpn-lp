# Histórico e diagnóstico pelo MCP

Publicado em 07/09/2026, frontend/MCP Netlify `6a9f38ead984040c735a5189`. Catálogo de administrador com escrita: 83 ferramentas, confirmado por OAuth real em produção.

## Ferramentas adicionadas

- `listar_conversas`: agentes/playground, WhatsApp e Instagram. Sessões sem vínculo persistido ao contato podem ser encontradas pelo agente.
- `consultar_conversa`: mensagens cronológicas, tool_calls e resultados gravados; paginação por offset. WhatsApp reúne instâncias e identifica cada mensagem por instance_id. Anexos binários não são baixados.
- `consultar_timeline`: interações, notas, tarefas, reuniões, transcrições de ligações, WhatsApp, estado da oportunidade e auditoria das mudanças de etapa.
- `consultar_contexto_contato`: cadastro + oportunidades + tarefas + página da timeline. Percorrer a paginação das listas internas separadamente.
- `consultar_diagnostico_agente`: prompt atual, versão, modelo configurado, ferramentas e regra de etapa após reunião; somente admin.
- `listar_execucoes_agente` e `consultar_execucao_agente`: chamadas reais ao modelo, prompt efetivo com contexto, histórico enviado, schemas das ferramentas, modelo resolvido, resultado e uso; somente admin. Captura começa nesta publicação. Não há reconstrução de prompts efetivos antigos nem acesso ao raciocínio privado do modelo.
- `atualizar_agente`: prompt, nome, modelo, ativação e `meeting_stage_id`; somente admin com escrita. Controle otimista por versão e repetição idempotente por request_id. Não fornece SQL livre nem acesso a credenciais/action_config.

## Reunião → etapa

O campo `meeting_stage_id` liga uma transição transacional após a criação de reunião pelo agente (metadata.agent_id). Resolve a oportunidade da sessão do playground ou uma única oportunidade aberta no funil alvo. Ambiguidade/incompatibilidade impede salvar, sem sucesso parcial. Não regride etapa e não move ganhos/perdidos. Não sincroniza agenda externa, não envia mensagens/convites. Reuniões manuais/MCP sem agent_id não acionam esta regra específica do agente. Reuniões antigas não são recriadas.

Bella — SDR PAIN: instruções complementadas e regra configurada para Reunião Agendada no Vendas Inbound. A reunião e a oportunidade existentes do Frankjito foram consultadas; nenhuma duplicação. A conversa mostrou erros de permissão em current_time_br e check_availability, corrigidos por wrappers autenticados que validam a empresa e os responsáveis. Disponibilidade calcula sobreposição, buffer, horários locais de Brasília e exclui cancelados. Scheduler legado ajustado aos campos existentes do banco.

## Segurança e testes

- RPCs validam sessão OAuth, cliente aprovado, membro e tenant ativo. Diagnóstico global do agente só admin; outros membros leem apenas suas sessões de agente.
- Campos retornados explícitos, sem provider_state, raw, credenciais ou configuração interna de execução das ferramentas. Traces em schema privado com RLS, escrita exclusiva service_role e filtragem de campos sensíveis.
- Migration `20260907221050_mcp_conversation_history.sql`: histórico, traces, edição e regra transacional; `20260907222214_playground_read_tools.sql`: relógio/disponibilidade do playground.
- `scripts/verify-mcp-history.sql`: rollback cobre mensagens, catálogo de sessões, prompts, traces, redação, paginação, edições concorrentes/replay, autorização, agenda salva + etapa e conflito sem movimentação.
- Teste HTTP OAuth real: 83 tools, edição/replay de agente QA, nova resposta pelo runner patrocinado, leitura das mensagens e trace pelo MCP, contexto e timeline.
- Frontend 13 testes/build, MCP 7 testes/build, Edge Functions e extensão typecheck/build aprovados. Advisor de segurança sem erros.

A cobertura não significa paridade com todos os módulos do CRM. Disparo de campanhas, ativação genérica de automações, credenciais e configuração de canais não foram adicionados nesta entrega. Para revisar atendimento, consultar diagnóstico atual, listar conversas, percorrer mensagens e consultar execuções capturadas; propor alteração com base nos resultados e executar a edição solicitada.

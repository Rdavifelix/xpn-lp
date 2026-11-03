# Operação pelo MCP: agentes do zero (v0.8.0, 110 ferramentas)

O mesmo fluxo atende todos os tenants, sem IDs de Bella/Frank ou modificações manuais no banco.

## Fluxo executável
1. Consultar empresa, pipelines, agentes/modelos e listar_habilidades_agentes.
2. Criar agente a partir de template ou com provider/model disponíveis e instruções próprias. tools é obrigatório: habilidades always já são habilitadas atomicamente, incluindo perda e cancelamento. A criação é idempotente e deixa o agente inativo para testar.
3. Salvar conhecimento, configurar responsável/ICP/parâmetros/horário, vincular credencial existente e configurar rodízio. Credenciais nunca são devolvidas à IA.
4. Criar equipe e expediente, pipeline, formulário e destino com as ferramentas existentes. Publicar formulário e obter contato/deal da submissão.
5. Testar conversa pelo MCP e consultar o job. Conferir tool.end e estado dos registros, além da resposta do modelo. Ajustar prompt, conhecimento e habilidades pelo MCP.
6. Ativar agente pelo atualizar_agente quando as dependências do canal estiverem prontas. Playground pode executar com agente inativo.

## Habilidades internas
Contexto/qualificação/etapas/perda; criação de contato/oportunidade; tarefas e conclusão; disponibilidade/agendamento/confirmação/remarcação/cancelamento interno; encaminhamento humano; conhecimento; equipe e consultas comerciais. Catálogo informa playground_supported e schemas reais. Retomada agenda tarefa interna, não disparo automático. Habilidades HTTP/externas não disparam pelo playground. Aprovação obrigatória não é ignorada.

Cancelar uma reunião interna não cancela automaticamente evento externo do Google; encerrar deal não equivale a opt-out em todos os canais. Encaminhamento cria tarefa para responsável da empresa, sem mensagem externa.

## Automações comerciais internas
ativar_automacao_comercial permite eventos deal_created, deal_stage_changed, task_created, task_completed, meeting_scheduled, meeting_cancelled, meeting_rescheduled. Ações: tarefa interna ou avanço para etapa intermediária posterior. Valida tenant/referências/configuração e executa por triggers mesmo quando a origem é MCP/formulário. Pausa imediata para novos eventos. Não reaplica ao histórico nem encadeia recursivamente. consultar_execucoes_automacao retorna sucesso/erro. Regras externas/temporizadas não são ativadas por esse executor.

## Cobertura e limites
O MCP já cobre contatos, deals, tarefas, pipeline/etapas, produtos, equipe/agenda, formulários/publicação, agentes/habilidades/conhecimento, conversas/timeline/diagnóstico, credenciais existentes e criação/edição de campanhas e templates. Não representa paridade com todos os módulos do produto: disparo de campanhas, roteamento de canais externos, OAuth do Google, credenciais novas, exclusão física geral e automações externas/temporizadas têm fluxos próprios ainda não inteiramente expostos. Não afirmar que essas funções estão disponíveis ou testadas.

## Verificação
- scripts/verify-mcp-new-agent.sql: empresa nova em transação rollback, criação sem template, ferramentas habilitadas, conhecimento/configuração, tarefas, leitura e perda; isolamento e leitor.
- scripts/verify-mcp-automations.sql: ativação, evento real, auditoria, prevenção de duplicação em atualização sem evento e pausa.
- OAuth MCP real: agente novo sem template; pipeline e formulário novos; submissão pública; leitura de conhecimento, qualificação, tarefa, agenda, confirmação, remarcação, cancelamento e perda. Nenhum envio externo.
- Builds/typechecks/testes de aplicativo, MCP, extensão e Edge Functions; advisors de segurança.

Validação adicional pelo MCP publicado: criação/ativação de automação → criação de deal → tarefa automática → consulta de execução → pausa. Responsável padrão aplicado na tarefa sem prazo inventado. Sessões QA revogadas, formulários retirados do ar e tenant QA desativado após validação. Deploy Netlify: 6a9f702d4256beb23f8161ad; Edge Functions atualizadas separadamente.

## Atualização WhatsApp v0.9.0 — 10/09/2026

Conexão Uazapi agora é exposta por cinco ferramentas: listar instâncias, criar, gerar QR como imagem, consultar conexão e vincular/pausar canal do agente. Veja [MCP_WHATSAPP.md](MCP_WHATSAPP.md). A pendência anterior de expor conexão e roteamento pelo MCP foi implementada; continuam dependentes da conta do cliente a configuração Uazapi, leitura do QR e teste real de entrega. Não inclui início automático após formulário nem disparos/cadências.

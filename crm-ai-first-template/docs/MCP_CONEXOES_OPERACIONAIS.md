# Conexões operacionais de agentes — v0.7.0

Deploy: `6a9f54521d87def00142ecf4`. Migração: `20260908001252_agent_operational_connections.sql`. Catálogo administrativo: 101 ferramentas.

## Implementado

- `configurar_alternancia_closers`: lista ordenada de closers ativos do tenant, cursor persistente por agente. Na gravação da reunião, lock na rotação e nos candidatos; escolhe próximo disponível e avança somente após sucesso. Repetição da mesma reunião não avança. Agenda considera expediente/bloqueios e reservas existentes. Mesma execução no playground e nos agentes. Configuração efetiva na Bella do PAIN: Robina Jubilesia e Julio Cesar. Prompt atualizado para usar closer retornado pelo servidor como fonte de verdade. Agente permanece inativo.
- `listar_credenciais_agentes` e `vincular_credencial_agente`: rótulos/IDs/provedores do tenant, sem segredos; null usa a resolução padrão existente da empresa/benefício patrocinado.
- `testar_conversa_agente`: encaminha execução autenticada ao playground do runner, com contato/deal reais. Pode executar ações reais; não repita automaticamente após timeout. Retorna eventos SSE (texto, início/fim das ferramentas, conclusão/erro). Não envia mensagens externas.
- `consultar_operacao_agente`: rotação e evidência da execução mais recente com versão. Distingue not_tested, configuration_changed, model_responded e execution_failed. `ready_for_playground` não comprova canal/formulário nem todas as habilidades.
- `consultar_agente_configurado` deixou de retornar teste ausente de forma fixa: evidência após a atualização do agente resulta em model_responded e readiness_scope=playground_model_only. Não equivale à operação comercial toda testada.

## Pendente desta solicitação

Conectar envio do formulário → atendimento da Bella, incluindo escolha entre atendimento no próprio navegador e WhatsApp. Pergunta enviada ao usuário; sem resposta até esta publicação. Não foi criado vínculo fictício, disparo automático nem declarada prontidão de ponta a ponta. A credencial existente pode ser vinculada por MCP; configuração/seleção de canal de entrada ainda não foi exposta nesta entrega.

## Validação

- `scripts/verify-agent-rotation.sql`: A → B → A, replay sem avançar, indisponibilidade de ambos, rejeição de membros/credenciais de outra empresa, paridade do playground. Transação com rollback.
- Chamada real pelo MCP publicado: agente QA inativo, contato/deal QA, habilidade current_time_br; retornou texto e tool.start/tool.end/done. Diagnóstico confirmou model_responded.
- Runner autenticado com OAuth MCP também testado diretamente.
- Frontend check (13 testes + typecheck/build), MCP (7 testes + build), Edge Functions e extensão passaram. Advisors de segurança sem erros.
- Dados de teste em tenant separado, acesso desativado e sessões do administrador QA revogadas ao final.

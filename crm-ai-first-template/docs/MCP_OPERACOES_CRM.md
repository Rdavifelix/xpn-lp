# MCP operacional — 07/09/2026

Publicado e consultado por OAuth no endpoint de produção: **83 ferramentas** para administrador com escrita. Conexões somente leitura recebem apenas operações de consulta.

## Cobertura

- Contatos: listar/buscar, consultar, criar, atualizar dados e qualificação.
- Oportunidades: listar, consultar, criar, atualizar, transferir de funil informando funil/etapa juntos e mover etapa; status de ganho/perda acompanha a etapa.
- Tarefas: listar, consultar, criar, atualizar, concluir, reabrir e cancelar. Reuniões usam as atividades do CRM com conflito de responsável/horário.
- Notas vinculadas ao contato/deal, funis, etapas e produtos: listar, consultar, criar e atualizar.
- Campanhas de email/WhatsApp: consultar, criar e editar rascunhos. Templates de email e listas: consultar, criar e atualizar.
- Automações de email/comercial: consultar e salvar configurações INATIVAS.
- Equipe: consultar membros sem chaves, tokens ou senhas.
- Catálogo `consultar_capacidades_crm`, além das ferramentas anteriores de implantação e configuração de agentes/habilidades.

## Limites explícitos

A cobertura ainda não equivale a todos os módulos e botões do produto. Estas ferramentas não disparam campanhas, ativam automações, enviam convites de equipe, configuram segredos/canais nem executam exclusão de registros. As ferramentas de criação de campanhas retornam rascunhos; criação não prova configuração de audiência nem entrega. A agenda interna não implica sincronização com Google Calendar. As rotinas de notificação/automação chamadas apenas pelos hooks da interface não são reproduzidas automaticamente por este adaptador SQL. Não anunciar paridade total com a interface.

## Verificação

- Protocolo MCP HTTP em produção com sessão OAuth de QA: tools/list retornou 75; criação/retry/atualização/busca de contato, criação/movimentação/consulta de deal, criação/conclusão de tarefa, agendamento/cancelamento de reunião e nota passaram.
- `scripts/verify-mcp-crm.sql`: transação com rollback testou todos os recursos novos, campos proibidos, isolamento entre empresas, conflito de agenda, idempotência, gate de leitura e request guard.
- `npm run check`: 13 testes e build; MCP: 7 testes incluindo catálogo e permissões; checagem Edge Functions; typecheck/build extensão passaram. Advisor de segurança sem erros.
- Migration incremental `20260907211905_mcp_crm_operations.sql` aplicada e registrada.
- Deploy `6a9f2d23ac84dcdce9e6b165`.

O adaptador usa RPC fixa, campos permitidos por recurso e identidade derivada de OAuth. Nenhum nome de tabela/SQL/tenant é aceito do modelo. Repetições da mesma ação usam o mesmo request_id. O registro privado de operações fornece auditoria e replay. Configurações já existentes e agentes reais não foram alterados durante a validação.

## Atualização de histórico e edição

Consulte `MCP_HISTORICO_DIAGNOSTICO.md`: oito ferramentas adicionais de conversas, timeline, diagnóstico/execuções e edição do agente, validadas em produção.

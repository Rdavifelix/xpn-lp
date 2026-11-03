# Perda e encaminhamento no playground — MCP 0.7.2

`configurar_habilidade_operacional` permite ao administrador habilitar/desabilitar `mark_deal_lost` e `notify_human` com request_id idempotente. A mudança é auditada e incrementa a versão do agente. Não permite SQL livre nem altera outras habilidades com aprovação. Habilidades personalizadas não são sobrescritas.

- `mark_deal_lost`: exige motivo confirmado, sessão compatível e deal do mesmo tenant/contato. Grava status lost, lost_at, lost_reason, etapa Perdido e timeline numa transação. Não altera negócios ganhos; repetir em negócio perdido não duplica a ação. Não cancela reuniões nem aplica opt-out.
- `notify_human`: cria tarefa interna para membro ativo da empresa, com registro de auditoria. Repetir o mesmo motivo na mesma sessão reutiliza o encaminhamento. Não envia mensagens externas nem pausa canais/cadências.

No playground, a única oportunidade aberta é selecionada automaticamente. O servidor faz a mesma resolução para chamadas MCP que informem apenas lead_id. Várias oportunidades exigem seleção explícita; nenhuma oportunidade exige selecionar/criar uma antes de executar ferramentas de deal. Sessões antigas sem deal podem receber o vínculo validado, com auditoria e atualização condicional; vínculos já existentes não são trocados. Ao continuar uma sessão já vinculada, o servidor reutiliza aquele deal.

Validação: scripts/verify-playground-loss.sql (transação com rollback), teste da seleção no componente, testes/typechecks/builds do aplicativo, MCP, extensão e Edge Functions. Teste OAuth MCP em tenant QA: contato sem deal no pedido → resolução → chamadas reais mark_deal_lost e notify_human → status, motivo, etapa e tarefa confirmados. Sem envios externos.

Bella configurada com as duas habilidades. Prompt diferencia desistência explícita de desqualificação por faturamento; solicita encaminhamento interno para cancelamento/opt-out quando necessário e só confirma ações após sucesso. A publicação não ativa o canal WhatsApp.

Também validados via OAuth MCP: bloqueio de seleção ambígua sem chamar ferramentas; reparo auditado de sessão antiga sem deal e execução de perda nessa mesma sessão.

# Playground com contexto real

Publicado em 07/09/2026 no CRM e na Edge Function agent-runner.

Em Agentes → Playground, o chat abre diretamente. Use **Selecionar contato** no cabeçalho do chat e escolha a oportunidade opcional. A seleção vale imediatamente, sem botão de iniciar nem tela intermediária. Trocar a seleção começa uma conversa nova. O contexto real continua validado pelo servidor. O painel Ferramentas pode ser ocultado. Agentes inativos podem ser testados sem ativar o atendimento automático.

Ferramentas habilitadas executam ações reais. O painel Tool Calls mostra argumentos, resultado, duração e falhas. Cada chamada tem um identificador próprio, inclusive quando a mesma ferramenta é chamada mais de uma vez. O contexto é validado no servidor e SQL usa a identidade autenticada do administrador, respeitando a empresa atual.

As ferramentas de mudança de etapa, atualização de contato e agendamento são encaminhadas para RPCs compatíveis com o banco atual. O agendamento cria uma atividade no CRM; não implica sincronização com calendário externo. Outras ferramentas e integrações mantêm suas configurações e requisitos existentes; não foram todas homologadas nesta entrega.

Validação: npm run check, checagem das Edge Functions, typecheck/build da extensão, teste Deno dos parâmetros/contexto, teste React de seleção/troca e scripts/verify-playground-real.sql no banco remoto com rollback. O teste SQL verificou contexto, vínculo contato/deal, isolamento entre empresas e persistência das três ações. Nenhum erro no advisor de segurança consultado. Fluxo visual conferido com registros sintéticos.

Limite da validação: a conversa completa com o provedor de IA não foi executada por falta de uma credencial configurada no agente de QA. Para usar, configure a credencial do modelo e as habilidades do agente. WhatsApp não é necessário para conversar no playground.

Deploy frontend: 6a9f2d23ac84dcdce9e6b165. As cinco migrations incrementais 20260907202910 a 20260907204215 estão aplicadas e registradas.

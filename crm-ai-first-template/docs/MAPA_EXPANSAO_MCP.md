# CRM pela IA: mapa de expansão do MCP

Data: 07/09/2026. Escopo: levantamento do código e proposta de implementação, sem ativar agentes ou integrações. Existência de tela/tabela não comprova execução em produção.

## Resultado esperado para um cliente começando do zero

Conectar IA → criar conta/empresa → explicar negócio → aprovar mapa → configurar estrutura → preparar agentes → conectar serviços → simular → ativar → acompanhar e ajustar.

O usuário não deve conhecer nomes de tabelas, IDs, provedores internos ou a distinção entre motores de agentes. A IA deve identificar o ambiente, consultar o estado real, pedir somente informações faltantes e devolver links diretos para ações humanas necessárias.

## Hoje, confirmado no MCP

`consultar_empresa`, `listar_pipelines`, `prever_pipeline`, `criar_pipeline`, `listar_agentes`, `criar_agente_rascunho` e prompt `mapear_processo`.

A criação de agente exige um modelo existente e configura nome/instruções; o agente fica inativo, sem credenciais, canais ou ferramentas. Pipeline cria nome e etapas; não cobre edição, transições completas, responsáveis ou automações. Escrita depende de administrador. Criações usam request_id para não duplicar tentativas. Isolamento é definido pela autenticação, nunca por tenant enviado pela IA.

## Capacidades propostas

| Bloco | Base encontrada | Ferramentas MCP propostas | Resultado |
|---|---|---|---|
| Diagnóstico e implantação | Contexto da empresa e configurações distribuídas | `diagnosticar_operacao`, `consultar_implantacao`, `salvar_mapa_operacao`, `prever_implantacao`, `aplicar_implantacao` | Lista de lacunas, plano persistido, execução retomável e situação por item |
| Empresa e oferta | Configurações, produtos, equipe e materiais | `consultar_negocio`, `atualizar_negocio`, `listar_produtos`, `salvar_produto`, `listar_equipe` | Oferta, público, horários, fuso, responsabilidades e catálogo |
| Processo comercial | sales_pipelines, etapas, transições, papéis e playbook | `obter_pipeline`, `atualizar_pipeline`, `configurar_transicoes`, `configurar_responsaveis`, `salvar_playbook` | Critérios de entrada/saída, ganho/perda e exceções além das colunas do funil |
| Agentes | agents_registry e templates | `obter_agente`, `criar_agente`, `atualizar_agente`, `configurar_limites_agente` | Missão, instruções, responsável humano, orçamento e regras; criação sem depender de template global |
| Conhecimento | agent_notes, versões de notas, memória e materiais | `listar_conhecimentos`, `salvar_conhecimento`, `vincular_conhecimento` | Oferta, FAQ, objeções e políticas utilizáveis pelo agente; validar limites de contexto |
| Habilidades | agents_skill_catalog, agents_tools e executor | `listar_habilidades`, `vincular_habilidade`, `configurar_permissao_habilidade` | Agente consulta lead, atualiza etapa, cria tarefa ou agenda dentro das permissões |
| Serviços e canais | Credenciais, deployments, WhatsApp e integrações | `listar_integracoes`, `iniciar_conexao_integracao`, `verificar_integracao`, `vincular_canal` | Login/QR/formulário seguro, associação ao agente e diagnóstico do canal |
| Automações | sales_automation_rules, workflow_rules e sequências | `listar_automacoes`, `prever_automacao`, `salvar_automacao`, `pausar_automacao` | Gatilhos, condições, ações, limites, horários e prevenção de duplicação |
| Operação do CRM | Leads, negócios, tarefas, notas, agenda | `buscar_leads`, `salvar_lead`, `mover_lead`, `registrar_nota`, `criar_tarefa`, `consultar_agenda` | Usar a estrutura criada e acompanhar o trabalho diário |
| Validação e publicação | Playground, runner, versões, logs e métricas | `simular_agente`, `consultar_simulacao`, `validar_operacao`, `publicar_agente`, `ativar_agente`, `pausar_agente`, `restaurar_versao` | Teste sem contato real, publicação identificável, ativação controlada e recuperação |
| Acompanhamento | Sessões, logs de ações e métricas | `consultar_saude_operacao`, `consultar_execucoes`, `consultar_metricas` | Saber o que executou, falhou, custou e precisa de intervenção |

Nomes são propostas. Não significa que as ferramentas da tabela já estão implementadas. Catálogos e paginação devem evitar respostas enormes; expor ferramentas conforme permissões e integrações disponíveis.

## Dependências que precisam ser resolvidas

1. **Dois motores de agentes.** `src/agents-platform` trabalha com agents_registry/agent-runner; `useAISalesAgent` trabalha com ai_sales_agents/ai-sales-agent. O MCP atual cria no primeiro. Priorizar a plataforma de agentes como entrada do MCP e mapear como canais e rotinas comerciais chegam ao executor. Evitar duplicar um agente nos dois sistemas; decidir explicitamente quais comportamentos serão integrados ou migrados.
2. **Rascunho não é uma fronteira de execução comprovada.** `useAgentConfig` atualiza agents_registry ao salvar; agent-runner lê system_prompt do registry. Histórico em agents_versions não garante que uma edição num agente ativo espere publicação. Antes de expor atualização/publicação pelo MCP, separar configuração em edição da versão executada, publicar atomicamente e permitir restauração.
3. **Testar rascunho exige caminho próprio.** O runner consultado filtra agentes ativos. Criar uma simulação autorizada, sem ativar o agente de produção e com ferramentas de efeitos externos substituídas por simulação. Depois executar um teste controlado da integração real.
4. **Configuração visual não comprova automação funcionando.** Rastrear cada evento até o worker/executor, inclusive temporizadores, retries e deduplicação. Não oferecer no catálogo ações que só tenham editor ou persistência.
5. **Habilidades precisam de contrato por tenant.** Catálogo contém SQL, HTTP, webhook e Edge Functions. Expor habilidades revisadas por finalidade; não oferecer SQL livre ou endpoints arbitrários como caminho normal de configuração. Revisar também chamadas internas que usam service role.
6. **Credenciais pertencem a quem opera o CRM.** A assinatura de Claude/ChatGPT/Codex usada para conversar com o MCP não garante processamento dos agentes do CRM. Propor conexão da conta de IA do cliente ou um serviço gerenciado com cobrança e limites próprios. Nunca devolver chaves ao modelo; ferramentas retornam status e referências opacas.
7. **Implantação parcial precisa ser retomável.** Persistir plano, versão, dependências, aprovação e resultado por recurso. Mudanças de plano invalidam a aprovação anterior. Usar request_id, validação de referências e controle de versão para não duplicar ou sobrescrever trabalho manual.

## Ordem recomendada de implementação

### Entrega 1 — montar a operação em rascunho

Diagnóstico + plano persistido; consulta/edição de pipeline; criação/edição de agente; conhecimento; catálogo seguro de habilidades; prévia consolidada e aplicação retomável. Aproveitar identidade/tenant e MCP existentes.

Aceite: tenant vazio descreve negócio e recebe pipeline, playbook e agente configurado com conhecimento e habilidades; repetição não duplica; ajustes não apagam configurações existentes; todas as referências pertencem ao tenant; nenhum canal externo ativado.

### Entrega 2 — colocar um agente para trabalhar

Resolver a versão executada e o caminho de canal; conexão segura de provedor; simulação; ligação de um canal inicial; autorização de publicação/ativação e botão de pausa. Começar com um agente e um canal funcionando integralmente antes de ampliar variedade.

Aceite: cenário normal, dúvida não coberta, transferência humana, erro de ferramenta e limite de orçamento; resposta em canal de teste; execução rastreável; pausa interrompe novas ações; restauração retorna à versão validada.

### Entrega 3 — rotina comercial

Operação de leads/tarefas/agenda, eventos de funil, automações e cadências. Importações e campanhas exigem prévia de volume, deduplicação, limites de envio e cancelamento.

Aceite: lead entra, agente qualifica, etapa muda, tarefa humana surge e agendamento é refletido na agenda correta; tentativas repetidas não reenviam a mesma ação.

### Entrega 4 — escala e acompanhamento

Múltiplos agentes, roteamento, mais canais, métricas, custos, revisões e recomendações. Convites da equipe podem ser preparados pela IA; envio requer intenção explícita do usuário.

## Critério de pronto de qualquer ferramenta

Contrato de entrada/saída; autorização no backend; referências do tenant verificadas; proteção de segredos; prévia para alterações relevantes; idempotência e concorrência nas gravações; log com usuário, empresa, operação e resultado; mensagens que distinguem falta de permissão, configuração incompleta e indisponibilidade. Testes com dois tenants e usuário sem permissão. Conferência do resultado na UI existente. Para efeitos externos: teste com destino autorizado e possibilidade de pausa.

## Roteiro de demonstração da imersão

“Tenho uma consultoria, vendo diagnóstico e implementação. Recebo leads pelo WhatsApp. Quero qualificar, agendar e transferir negociações para mim.”

A IA consulta o ambiente, pergunta critérios/horários/exceções, apresenta a proposta, cria a estrutura aprovada, informa a conexão externa que falta, abre a etapa segura de conexão, simula casos com o participante e pede ativação. Ao final mostra o que está ativo, o que depende do humano e como pausar.

## Referências locais verificadas

- mcp-server/src/tools.ts — ferramentas atuais e instruções.
- src/agents-platform/hooks/useAgentConfig.ts — edição e publicação atuais.
- src/agents-platform/hooks/useAgentTools.ts — tipos e modos de habilidade.
- src/agents-platform/hooks/useAgentDeployments.ts — canais.
- src/agents-platform/hooks/useAgentNotes.ts — conhecimento.
- src/hooks/useAISalesAgent.ts — motor comercial paralelo.
- src/hooks/usePipelineConfig.ts e useSalesAutomationRules.ts — processo e automações.
- supabase/functions/agent-runner/index.ts — consulta do agente, contexto e execução.
- supabase/functions/agent-runner/lib/auto-context.ts — inclusão de notas no contexto.

## Atualização — base implementada

Plano persistido, histórico, versão, confirmação e aplicação por item implementados. Executores ligados: pipeline e agent_draft. Demais capacidades continuam propostas; detalhes em IMPLANTACAO_PELA_CONVERSA.md.

## Atualização — criação com habilidades

Catálogo e sugestões de templates expostos ao MCP. Criação agora exige habilidades; elas são instaladas atomicamente, inclusive via plano. Vinculação a agentes inativos e consulta de configuração implementadas. Playground com contato/oportunidade, execução validada de cada habilidade, publicação e canais continuam pendentes.

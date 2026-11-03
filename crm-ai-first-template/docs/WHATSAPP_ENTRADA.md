# Regra de entrada por número

Em Comercial → Canais de entrada → WhatsApp, configure a instância, o agente, o pipeline, a etapa inicial e, opcionalmente, o responsável humano. Ativar autoriza respostas automáticas a próximas mensagens individuais. A instância precisa estar conectada e o agente precisa ter IA configurada para responder. Nenhuma regra de cliente é ativada durante a publicação.

A configuração usa `agents_deployments`, também visível nos canais do agente, com `entry_rule=true`. Existe uma regra por instância. Ela tem precedência sobre o roteamento anterior daquele número; pausá-la mantém a recepção no inbox, sem cair em outro agente. O gatilho do atendimento legado não enfileira mensagens desses números.

O recebimento identifica o contato e resolve a oportunidade no pipeline configurado sob lock transacional. Reutiliza uma aberta; cria quando não existe nenhuma; não reabre encerradas. Se houver várias abertas no pipeline, falha sem escolher arbitrariamente. A etapa e responsável iniciais só são aplicados a novas oportunidades. Mensagens de grupo e mensagens próprias não iniciam o fluxo. Mídia sem texto pode criar/vincular oportunidade, mas a resposta continua dependendo dos recursos de mídia existentes no agente.

O agente recebe o deal_id resolvido, sem pesquisar oportunidades de outros pipelines. Sessões de entrada separam instância, agente e telefone. Respostas ficam no histórico WhatsApp utilizado pelo inbox. O vínculo pessoal usuário → instância não é necessário para o agente atender; responsável da oportunidade é um campo separado.

MCP: `consultar_entradas_whatsapp` e `configurar_entrada_whatsapp`, disponíveis para administradores. A credencial Uazapi continua na configuração da instância; não é passada ao modelo. As rotas derivam tenant/membro do contexto autenticado e as funções internas são exclusivas de service_role.

Validação: `scripts/verify-whatsapp-entry.sql` roda em transação com rollback e verifica configuração, destino, repetição, oportunidade encerrada, pausa, isolamento e privilégios. `entry-rule_test.ts` verifica encaminhamento ao runner, envio simulado Uazapi e registro no inbox. Nenhuma mensagem a um destinatário real é enviada nesses testes.

Publicação verificada: tela salva regra pausada e mostra os valores persistidos; MCP lê a mesma regra, salva e rejeita pipeline inválido. Instância/agente sintéticos removidos e sessões QA revogadas. Testes do app/MCP/extensão e checagem Edge aprovados, advisors sem erros. Ainda não houve teste de entrega por um número real nesta implementação.

# Formulário → playground pelo MCP (0.7.1)

Em 07/09/2026, fluxo validado com OAuth MCP real em tenant e agente de controle, com dados sintéticos. Não foi feito teste de conversa da Bella com um contato real do proprietário, nem enviado WhatsApp. A Bella pode continuar inativa para testes no playground.

## Caminho comprovado

Envio anônimo do formulário publicado → contato e deal no destino configurado → testar_conversa_agente com contato/deal → update_lead (empresa/contexto) → qualify_lead (faturamento declarado e decisão) → change_stage → check_availability → schedule_meeting de 45 minutos → etapa Reunião Agendada. Asserções conferiram os registros pelo MCP, além dos eventos das ferramentas. Rodízio entre dois closers foi validado separadamente no teste SQL da v0.7.0.

## Correções

- Qualificação antiga referenciava colunas e tabela de auditoria ausentes. Agora grava o faturamento exato em monthly_revenue quando mínimo=máximo, preserva a faixa e a decisão em qualification e audita em lead_interactions. Mantém outros atributos quando omitidos. Não calcula score/potencial de receita por padrão. Wrapper playground valida administrador, tenant, agente, contato e sessão.
- Playground aceita atualização dos campos atuais de contexto e empresa. Ajustado search_path para gatilhos existentes na mudança de etapa e atualização de contato.
- Identificador UUID recebido em stage_name é convertido para stage_id no executor, ainda validado contra o funil.
- Execução longa não cabe em uma resposta síncrona do MCP hospedado. testar_conversa_agente agora recebe request_id e retorna test_id rapidamente; consultar_teste_agente retorna progresso/eventos e estado running/completed/failed/interrupted. O worker acompanha o runner em segundo plano com limite de 150s. Resultados persistidos por tenant e ator, com checkpoint. Repetição do mesmo request_id/payload não inicia outro teste. Em interrupção consulte histórico antes de nova tentativa.

Ferramentas de configuração/execução não conferem autorização de envio externo: este fluxo é apenas a simulação de conversa com ações reais internas no CRM. Não existe vínculo automático novo formulário → WhatsApp nesta entrega. Selecionar contato/deal no playground ou passá-los à ferramenta continua sendo a entrada do teste.

## Publicação e verificações

- Deploy Netlify: 6a9f57bb8b1aa627a639c251; MCP 0.7.1, 102 ferramentas administrativas.
- Edge Functions: agent-runner e mcp-playground-test.
- Migrations: 20260908002336_playground_qualification e 20260908002901_mcp_playground_jobs.
- SQL de regressão: scripts/verify-playground-qualification.sql e scripts/verify-playground-jobs.sql; isolamento, restrição a administrador, validação e idempotência, com rollback.
- Frontend typecheck/13 testes/build, MCP build/7 testes, Edge Functions, extensão e advisors sem erros.
- Testes de produção: jobs ebf35245-f5be-45ba-9d1e-d0155294b853 e 6b43f5b0-e720-4af5-afa3-ea4d6aeb3082. Primeiro: update_lead, qualify_lead, change_stage. Segundo: check_availability, schedule_meeting.
- Reunião QA cancelada e formulários QA retirados do ar. Tenant/membros QA e benefício de IA desativados, sessões revogadas; registros de auditoria preservados.

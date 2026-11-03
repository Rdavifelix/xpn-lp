# Equipe e agenda pelo MCP

Publicado em 07/09/2026, servidor 0.6.0 (96 ferramentas para administrador), deploy Netlify `6a9f4c3cd89cff9eef89b36a`.

## Fluxo de configuração por conversa

O áudio é transcrito pelo cliente (Claude/ChatGPT/Codex); o MCP recebe chamadas de ferramentas. Organizar o relato em origens dos leads, etapas, critérios, equipe, horários, responsabilidades, agentes e habilidades. Consultar recursos existentes antes de criar. Nomes/emails ausentes devem ser perguntados, não inventados. A autorização dada na conversa permite executar as ferramentas correspondentes.

1. Consultar membros, funis, agentes e habilidades existentes.
2. Criar equipe com `criar_usuario_equipe` (nome, email, função SDR/closer/comercial/admin). Retorna membro real e link pessoal de primeiro acesso. Não solicita senha na conversa e não envia email.
3. Configurar `configurar_expediente` e `bloquear_agenda`; consultar `consultar_agenda_membro` e `consultar_horarios_livres`.
4. Criar/configurar funis, etapas, agentes com ferramentas e formulários pelas ferramentas existentes; usar IDs retornados como responsáveis e destinos.
5. Testar disponibilidade, reunião, movimentação de oportunidade e atendimento. Ativação de agentes é feita pela ferramenta existente `atualizar_agente`, conforme o processo e as integrações disponíveis.
6. Informar resultados e pendências concretas. Credenciais, conexão de WhatsApp/Google e primeiro acesso continuam dependendo do titular. Não anunciar que integrações estão conectadas apenas por criar os registros.

Ferramentas novas: `criar_usuario_equipe`, `atualizar_membro_equipe`, `consultar_agenda_membro`, `consultar_horarios_livres`, `configurar_expediente`, `bloquear_agenda`, `remover_bloqueio_agenda`.

Os executores persistidos de `aplicar_item_implantacao` continuam restritos a pipeline/agent_draft. Equipe, agenda, formulários e edições de agentes são executados pelas ferramentas específicas, indicadas no diagnóstico. Não tratar um item genérico pendente no plano como automaticamente aplicado.

## Acesso e isolamento

`mcp-provision-member` valida contexto OAuth vivo via `mcp_context`, exige admin e reserva a solicitação em `mcp_team`. O tenant não vem dos argumentos. A service_role permanece só na Edge Function. O Auth cria senha aleatória não retornada e app_metadata com tenant e request_id; `team_provision_finish` só vincula usuário criado por essa solicitação. Emails existentes não são apropriados/redefinidos. Repetir a mesma criação pode reemitir o link enquanto não foi usado; após primeiro login não retorna novo link. Nunca persistir links pessoais em planos, prompts ou notas. Se a resposta se perder, repetir o mesmo request_id/dados.

SDR/closer são role comercial com sub_role específico. Mudanças no proprietário/superadmin/próprio acesso são recusadas pela ferramenta. Desativar revoga sessões e bloqueia acesso por vínculo inativo. Acesso do último administrador é preservado.

## Agenda

Usa `team_members.working_hours`, duração padrão e `calendar_blocks` existentes, visíveis nas telas atuais. Semana completa em dias 0–6 (domingo–sábado); omitido/null significa folga. Intervalos de almoço por bloqueio recorrente. Fuso desta versão: America/Sao_Paulo. Bloqueios podem ser pontuais ou semanais. Remover desativa preservando histórico; mudanças não cancelam reuniões existentes.

Busca de slots e gravação validam expediente, bloqueios, reuniões/calls e eventos Google já sincronizados. Gatilho no banco protege também criação/remarcação fora do MCP; rejeita horário indisponível. Não sincroniza Google em tempo real nem reserva slots externos. Locks por responsável serializam agendamentos. Agente e playground usam a mesma lógica. O runner injeta agent_id para conferir closers no tenant correto. Reunião cancelada deixa de ocupar o horário também no agendamento do agente.

## Validação

- `npm run check`: typecheck, 13 testes e build passaram.
- MCP build + 7 testes, incluindo descoberta administrativa/leitura das ferramentas novas.
- Checagem Edge Functions e extensão: passaram; advisors sem erros.
- `scripts/verify-mcp-team-calendar.sql`: isolamento, permissões, horários inválidos, bloqueios pontuais/recorrentes, remoção, reuniões, cancelamento e consultas; rollback.
- Teste MCP de produção: criação real de closer, horário semanal, almoço, ausência, recusa da reunião bloqueada, liberação, agendamento/cancelamento e alteração do membro.
- Link de primeiro acesso seguido até `/reset-password`; senha definida e login Auth real validado; acesso restrito ao tenant e sub_role closer. Reemissão após uso recusada.
- Funções do agente testadas em transação com rollback: consulta, agendamento, cancelamento e nova reunião no mesmo horário.
- Conta de teste desativada via MCP. Sessões de QA revogadas e tenant desativado após validação. Nenhum convite enviado.

Migrations: `20260907233537_mcp_team_and_calendar.sql`, `20260907234316_agent_ignore_cancelled_meetings.sql`. Funções publicadas: `mcp-provision-member`, `agent-runner`.

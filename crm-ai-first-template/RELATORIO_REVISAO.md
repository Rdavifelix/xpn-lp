# Relatório de revisão e prioridades

> **Atualização 2026-11-03:** a auditoria multi-tenant (`docs/AUDITORIA_MULTITENANT.md`) encontrou e corrigiu vazamentos entre empresas que a homologação abaixo não cobriu (42 policies permissivas, storage sem prefixo de tenant, IDOR em Edge Functions). As evidências desta seção valem para o pacote 2026.09.14 em modo empresa única.

Data da revisão: 12/07/2026

## Resultado executivo

O template foi endurecido para distribuição a mentorados. A revisão priorizou riscos que poderiam expor dados, misturar empresas, vazar credenciais ou permitir chamadas privilegiadas sem autenticação. O projeto original foi preservado; esta pasta contém a versão revisada.

## P0 — concluído antes da distribuição

- Autenticação real dos usuários nas funções de servidor; não basta mais apresentar um token sem validá-lo.
- Isolamento por empresa nas operações de agentes, sessões, credenciais, WhatsApp, Instagram, Meta e rotinas agendadas.
- Credenciais e tokens deixaram de ser devolvidos ao navegador.
- Webhooks públicos passaram a validar assinatura, segredo, canal ou dispositivo, conforme o provedor.
- SQL livre do agente foi desativado e rotinas administrativas passaram a exigir administrador ou chave de serviço.
- Rotinas agendadas usam URL e chave armazenadas no Vault, sem placeholders de projeto.
- Chaves de Gemini e Soniox deixaram de ficar no cliente; o Soniox usa chave temporária e de uso único.
- Cadastro público fica desativado por padrão; o instalador cria o primeiro administrador com segurança.
- Extensão passou a usar a sessão do usuário e perdeu a permissão ampla para acessar qualquer site.
- Endereços e chaves do projeto autor foram removidos do código distribuído.
- Os 138 avisos legados do React/ESLint foram corrigidos mantendo as regras ativas.
- BlockNote foi removido: os quatro pacotes estavam sem qualquer uso no código e eram a origem das vulnerabilidades.
- Vite do CRM e da extensão foi atualizado para 6.4.3; o plugin CRX foi atualizado para 2.7.1.

## Homologação limpa — concluída

- As 46 migrations foram aplicadas sem falha em um projeto Supabase vazio.
- As 193 tabelas públicas ficaram com RLS habilitado e 588 políticas foram instaladas.
- Os 6 crons ficaram ativos e autenticados pelo Vault, sem chave literal nos comandos.
- Todas as Edge Functions foram publicadas e o health check remoto retornou `healthy`.
- Dois tenants e dois usuários temporários provaram isolamento de leitura e escrita; a coluna secreta de credenciais e a RPC bruta foram bloqueadas.
- Requisições sem segredo foram recusadas por agenda, entrada de leads, Brevo e Google Ads.
- Cadastro público foi bloqueado, sem desativar o login por e-mail.
- Login, dashboard, pipeline, credenciais, configurações e agenda pública passaram no smoke test visual.
- Pipeline, Inbox, Templates, editor Maily, Tarefas, Configurações e Agentes passaram em nova regressão local.
- Indicadores sem dados agora exibem zero em vez de `NaN`.
- Todos os usuários, tenants e dados QA foram removidos após os testes.

## Agentes + WhatsApp V2 — concluído

- A chave **Roteador WhatsApp V2** agora funciona por tenant e só pode ser alterada por administrador.
- `agent_route_lookup` resolve o tenant pela instância WhatsApp e bloqueia deployments genéricos de outros tenants.
- O webhook agrupa mensagens fragmentadas no banco e evita responder por cima de uma intervenção humana.
- Respostas são divididas em bolhas humanizadas, aceitam imagens Markdown e usam o ID real da UAZAPI para deduplicar o echo.
- O runner aceita `agent_id` tenant-safe e evita um segundo debounce quando o webhook já agrupou a entrada.
- A automação de marketing ganhou **Follow-up do Agente**, com histórico real da conversa e opção segura `[PULAR]`.
- `whatsapp-webhook`, `agent-runner`, `agent-followup` e `email-automation-tick` foram publicados e ficaram `ACTIVE` na homologação.
- Chamadas sem credenciais aos quatro endpoints foram recusadas com HTTP 401.
- Testes transacionais provaram: flag desligada por padrão, escrita sem admin bloqueada, ativação admin aprovada, instância inválida bloqueada e isolamento cross-tenant aprovado. Todos os dados sintéticos foram revertidos.

## P1 — antes do uso por cada mentorado

1. Criar o administrador definitivo do ambiente.
2. Validar as integrações realmente usadas: WhatsApp, Meta, Google, Brevo/Resend, Telegram, Soniox e calendários.
3. Configurar backup, alertas, domínio, SMTP, política de retenção e rotação periódica dos segredos.
4. Fazer um piloto acompanhado antes da distribuição em massa.

## P2 — próxima rodada de engenharia

- Dividir os três pacotes grandes do front-end (`index`, editor de e-mail e gerador de PDF) para melhorar o carregamento inicial.
- Ampliar testes automatizados para RLS/multi-tenant, webhooks e fluxos de pagamento/cancelamento.
- Adicionar CI para executar lint, tipos, testes, build, checagem de funções e auditoria de dependências em toda alteração.

## Evidências da validação

- Lint: 0 erros e 0 avisos.
- TypeScript do CRM: aprovado.
- Testes automatizados: 6 aprovados.
- Build de produção do CRM: aprovado.
- Todas as funções de servidor: aprovadas na checagem de tipos.
- TypeScript e build da extensão: aprovados.
- Auditoria completa do CRM: 0 vulnerabilidades.
- Auditoria completa da extensão: 0 vulnerabilidades.
- Varredura de segredos: nenhum token real incorporado ao pacote.
- Banco remoto limpo: 46 migrations, 193/193 tabelas públicas com RLS, 588 políticas e 6/6 crons autenticados.
- Testes remotos de isolamento, endpoints e interface: aprovados.

## Comandos de aceite

```bash
npm ci
npm run check
./scripts/check-edge-functions.sh
cd extension && npm ci && npx tsc --noEmit && npm run build
```

Em cada novo ambiente, execute `./setup.sh` e siga `docs/OPERACAO.md`.

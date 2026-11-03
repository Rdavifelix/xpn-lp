# IA patrocinada do SaaS

Publicado em 07/09/2026. Painel: `/superadmin/ia`; acesso por Agentes → Credenciais → Superadmin · IA. O proprietário configura seu próprio superadmin durante a instalação. A flag real `team_members.is_superadmin` é validada no servidor; ser admin de um tenant não concede acesso global.

## Fluxo

1. Superadmin cadastra chave de API OpenAI ou Anthropic, ou sessão ChatGPT subscription / Codex (auth.json), e um modelo compatível com o respectivo adaptador. Chave global criptografada no Supabase Vault, nunca retornada para a UI, para tenants ou MCP.
2. Ativa patrocínio e, opcionalmente, inscrição automática de novos tenants. Padrões iniciais: 7 dias, 100 chamadas por dia/tenant, 2048 tokens máximos de saída por chamada. Configuração em 07/09/2026: Codex conectado, gpt-5.4-mini, inscrição automática habilitada e benefício de 7 dias/100 chamadas diárias.
3. Cada empresa pode ter liberação, validade e cota diária ajustadas separadamente. Desligar globalmente bloqueia novas chamadas patrocinadas. Requisições já iniciadas podem terminar.
4. Em Credenciais, tenant admin pode definir chave própria padrão (OpenAI/Anthropic/Codex) e modelo. Prioridade: credencial vinculada ao agente → padrão próprio do tenant → benefício patrocinado autorizado. Credencial própria inválida não retorna silenciosamente à global.

## Contagem

Uma chamada ao modelo, incluindo cada iteração com ferramentas, reserva uma unidade antes de acessar o provedor. A reserva usa lock transacional por tenant para não ultrapassar a cota por concorrência. Falhas e chamadas interrompidas contam para a cota; não há restituição automática. Tokens retornados são contabilizados com finalização idempotente. Dia UTC; esta cota não é um teto monetário. O painel mostra chamadas do dia e tokens registrados, sem estimar preços de modelos desconhecidos.

## Escopo e compatibilidade

O controle está no dispatcher do `agent-runner`, compartilhado por playground e canais que usam esse runner. Os adaptadores OpenAI/Anthropic agora usam a credencial resolvida, sem fallback direto aos secrets globais. A preferência própria aplica modelo definido pelo tenant; credencial por agente mantém o modelo do agente. Patrocínio usa o modelo global fixado pelo superadmin. OpenAI usa Chat Completions, `max_completion_tokens` e não envia temperatura fixa; selecione modelo compatível com esse endpoint. Codex aceita a sessão OAuth da assinatura; tokens globais ficam no Vault. A renovação é serializada por uma lease de 30 segundos e persistida somente pelo backend. O limite de saída por chamada é exclusivo das APIs; Codex obedece aos limites da assinatura e à cota de chamadas do SaaS.

Outras funcionalidades antigas que usam IA fora do `agent-runner` ainda têm seus próprios helpers de configuração e não estão cobertas pela cota deste painel. A integração requer credencial e modelo válidos. A sessão Codex foi validada com respostas reais de gpt-5.4-mini e gpt-6-astra; gpt-5.5 foi recusado pela conta (model_not_found).

## Validação

- `scripts/verify-saas-ai.sql` em transação com rollback: autorização superadmin, acesso negado a segredo por usuário normal, criptografia/resolução, quota, prioridade própria, chave própria inativa, expiração, desligamento, cadastro automático e finalização idempotente.
- Teste Deno com transporte substituído: adaptadores usam a chave fornecida e rejeitam credencial ausente sem usar a chave de ambiente.
- `npm run check`, checagem Edge Functions, typecheck/build extensão; advisor de segurança sem erros.
- UI de Credenciais e Superadmin verificada no navegador, incluindo salvar configuração desligada.
- Migration `20260907214006_saas_ai_sponsorship.sql` aplicada e registrada; runner publicado; frontend `6a9f30f0fdcb39db4185a9e3`.

## Assinatura ChatGPT / Codex

No superadmin, selecionar “ChatGPT subscription / Codex”, importar auth.json e salvar. Para reconectar, importar uma nova sessão. Nunca enviar o arquivo ao tenant nem registrá-lo em repositório. A sessão foi importada da conta local autenticada a pedido do proprietário; CLI e SaaS podem disputar a rotação do refresh token, exigindo reconexão. Uma sessão dedicada reduz esse conflito. O endpoint é privado e não há garantia de compatibilidade ou suporte oficial para compartilhamento SaaS.

Migration `20260907215635_saas_codex_subscription.sql` aplicada. `scripts/verify-saas-codex.sql` valida em rollback importação, não exposição, bloqueio de acesso, exclusividade da renovação e persistência; regressão `verify-saas-ai.sql` também passou.

Publicação Codex: frontend `6a9f350c1d87dede5042ed0f`, agent-runner atualizado, checks de frontend/Edge Functions/extensão aprovados e advisor de segurança sem erros. UI publicada confirmou sessão cadastrada, provedor Codex, modelo e benefício ativo.

Teste ponta a ponta em produção: login QA → playground → contato QA A → mensagem → resposta “conexão funcionando.”. Tenant sem credenciais próprias usou patrocínio Codex global. Conta QA desativada e sessões revogadas após a validação.

---
description: Setup interativo do Social Selling — guia o usuário pela primeira configuração (login no Instagram via Playwright, calibração de tom de voz, validação de permissões).
---

# Social Selling — Setup Inicial

Você guia o usuário (vendedor) na primeira configuração do social selling. SÓ precisa rodar UMA VEZ.

## Passo 1 — Saudação

Mande:

> "Opa! Vou te ajudar a configurar o Social Selling em 3 passos rápidos. Vai levar uns 5 minutos. Antes de começar — você já tem o Playwright MCP instalado no Claude Code? (responde sim/não)"

Aguarde resposta.

## Passo 2 — Verificar Playwright

Tente `mcp__playwright__browser_navigate` pra `about:blank`.

Se funcionar: confirma "Playwright tá pronto ✅" e segue.

Se der erro: instrua:
> "Você precisa instalar o Playwright MCP. Roda no terminal:
> ```
> claude mcp add playwright -- npx @playwright/mcp@latest --user-data-dir ~/Library/Caches/ms-playwright/mcp-instagram
> ```
> Reinicia o Claude Code e roda /social-selling-setup de novo."

E PARA aqui.

## Passo 3 — Login no Instagram

Mande:

> "Agora vou abrir o Instagram pra você logar. Você só precisa fazer isso 1 vez — a sessão fica salva. Vou abrir o browser, você loga normalmente, e me avisa quando estiver dentro."

Use `mcp__playwright__browser_navigate` → `https://instagram.com/`

Aguarde o usuário responder "logado" / "tá dentro" / similar.

Quando confirmar, faça `mcp__playwright__browser_snapshot` pra confirmar que tá logado (procure indicadores tipo "Mensagens", "Notificações", username dele no topo).

Se tudo OK, mande:

> "✅ Logado com sucesso! Sessão salva. Agora vou calibrar seu tom de voz."

## Passo 4 — Calibração de tom de voz

Mande:

> "Pra que as mensagens não pareçam IA, vou analisar como VOCÊ fala no Instagram. Vou abrir suas DMs e ler suas últimas mensagens enviadas (sem invadir privacidade — só pra entender padrões: gírias, emojis, tamanho de frase). Pode?"

Aguarde OK.

Use `mcp__playwright__browser_navigate` → `https://instagram.com/direct/inbox/`

Snapshot. Identifique 5-8 conversas mais recentes. Pra cada, abra e leia 3-5 mensagens enviadas POR VOCÊ (filtra `is_from_me`).

Coletar uns 20-30 exemplos de mensagens curtas que o usuário ENVIOU.

Analise:
- **Formalidade**: formal vs informal
- **Emojis**: quais usa mais (top 3)
- **Comprimento**: média de palavras
- **Gírias**: top 5 (mano, top, show, boa, kkk, etc)
- **Saudação preferida**: "Fala", "E aí", "Opa", etc

Mande pro usuário:

> "Analisei tuas últimas X mensagens. Teu tom:
>
> - Estilo: [informal/semi-formal/formal]
> - Emojis favoritos: [🔥, 🙏, 😂]
> - Tamanho médio: [X palavras]
> - Gírias que mais usa: [mano, top, show]
> - Saudação típica: [Fala!]
>
> Tá certo? Quer ajustar algo?"

Aguarde. Se ele ajustar, anote.

## Passo 5 — Salvar configuração

Salve o tom no banco (na tabela `config`):

```sql
INSERT INTO config (key, value)
VALUES ('social_selling_tone', '{"formality":"informal","emojis":["🔥","🙏"],"slang":["mano","top","show"],"avg_length":5,"greeting":"Fala!"}')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

## Passo 6 — Verificar etapa "Social Seller" no funil

```sql
SELECT id, name FROM sales_pipeline_stages WHERE name ILIKE '%social seller%';
```

Se NÃO existir:
> "Você precisa criar uma etapa chamada 'Social Seller' no seu funil. Quer que eu crie pra você? Vai ser entre 'Tentando Contato' e 'Em Qualificação'. (sim/não)"

Se sim, crie:
```sql
-- Pega o pipeline padrão
WITH pid AS (SELECT id FROM sales_pipelines LIMIT 1),
     pos AS (SELECT COALESCE(MAX(position), 0) + 1 AS p FROM sales_pipeline_stages WHERE pipeline_id = (SELECT id FROM pid))
INSERT INTO sales_pipeline_stages (pipeline_id, name, position, color)
SELECT (SELECT id FROM pid), 'Social Seller', (SELECT p FROM pos), '#ec4899';
```

## Passo 7 — Configurar agendamento

Mande:

> "Tudo configurado! 🎉
>
> Pra automatizar a rotina, rode UMA VEZ esses 2 comandos:
>
> ```
> /loop 1d /social-selling-run
> /loop 4h /social-selling-checar-respostas
> ```
>
> Pronto! Enquanto Claude Code estiver aberto, ele:
> - **Todo dia**: executa o fluxo de aquecimento (curtir, reagir, comentar, DM) pros leads na etapa 'Social Seller'
> - **De 4h em 4h**: checa se tem novo lead respondendo nas tuas DMs
>
> Pra ver o que acontecendo, abre o dashboard:
> http://localhost:8080/comercial/social-selling
>
> Quer fazer um teste agora? Posso rodar /social-selling-run pra você ver o sistema em ação."

Aguarde resposta.

## Notas

- Esse setup só precisa rodar 1x. Próximas vezes, pula direto pra `/social-selling-run`.
- Se o usuário trocar de Mac, precisa rodar de novo pra logar no IG.
- Se a sessão IG expirar, o `/social-selling-run` vai dar erro e pedir pra rodar `/social-selling-setup` de novo.

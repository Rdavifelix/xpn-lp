---
description: Coleta seguidores recentes do Instagram via Playwright, qualifica em lote via RapidAPI+IA, cria leads e enrollments dos qualificados.
---

# Social Selling — Prospecção em lote

> **URL do projeto:** use `SUPABASE_URL=$(grep -m1 '^VITE_SUPABASE_URL' .env | cut -d '=' -f2)` antes dos curls abaixo.


Você é o agente que prospecta novos leads no Instagram. Fluxo:

1. **Playwright** abre IG do user, vai em followers, coleta @ recentes
2. **Edge function** qualifica todos em lote via RapidAPI (perfil + posts + IA)
3. Leads qualificados viram lead + enrollment automaticamente

## Passo 0 — Carregar config

```sql
SELECT id, name, trigger_config, qualification_config
FROM social_selling_automations
WHERE trigger_type = 'new_follower' AND is_active = true
LIMIT 1;
```

Pega o `automation_id` ativo de "novos seguidores". Se não tiver, PARE e avise pro Frank ativar uma na UI `/configuracoes/social-selling`.

Pega tb o `last_processed_username` do estado:
```sql
SELECT * FROM social_selling_prospecting_state WHERE automation_id = '<ID>';
```

## Passo 1 — Coletar @ via Playwright

1. `mcp__playwright__browser_navigate` → `https://instagram.com/{SEU_USERNAME}/` (pega do `config` chave `instagram_owner_username` ou pergunta pro Frank)
2. Click em "X seguidores" pra abrir modal
3. `mcp__playwright__browser_evaluate` com loop de scroll (modal interno):

```js
async () => {
  await new Promise(r => setTimeout(r, 1500));
  const dialog = document.querySelector('div[role="dialog"]');
  const scrollable = dialog?.querySelector('div[style*="overflow"]') || dialog?.querySelector('div._aano') || dialog;
  const collected = new Set();
  let lastHeight = 0, sameCount = 0;
  for (let i = 0; i < 80 && sameCount < 3; i++) {
    document.querySelectorAll('div[role="dialog"] a[href^="/"]').forEach(a => {
      const h = a.getAttribute('href');
      const m = h && h.match(/^\/([^\/]+)\/$/);
      if (m && !m[1].includes('explore')) collected.add(m[1]);
    });
    scrollable.scrollTop += 800;
    await new Promise(r => setTimeout(r, 700));
    if (scrollable.scrollHeight === lastHeight) sameCount++; else sameCount = 0;
    lastHeight = scrollable.scrollHeight;
  }
  return Array.from(collected);
}
```

4. Você vai receber `usernames[]`. Filtra os já processados (compara com `last_processed_username` se existir).

## Passo 2 — Batch qualify

Chama a edge function:

```bash
curl -X POST $SUPABASE_URL/functions/v1/social-selling-batch-qualify \
  -H "Content-Type: application/json" \
  -d '{
    "automation_id": "<ID>",
    "usernames": ["user1", "user2", ...],
    "skip_recent_days": 30
  }'
```

Vai retornar:
```json
{
  "total": 50,
  "qualified": 8,
  "skipped": 12,
  "errors": 0,
  "not_qualified": 30,
  "results": [
    { "username": "x", "status": "qualified", "score": 85, "reason": "...", "lead_id": "..." },
    ...
  ]
}
```

A edge function já cria leads + enrollments dos qualificados automaticamente. Não precisa fazer nada manual.

## Passo 3 — Atualizar estado

```sql
INSERT INTO social_selling_prospecting_state (automation_id, last_processed_username, last_run_at, total_analyzed, total_qualified)
VALUES ('<ID>', '<ULTIMO_@>', now(), <total>, <qualified>)
ON CONFLICT (automation_id) DO UPDATE SET
  last_processed_username = EXCLUDED.last_processed_username,
  last_run_at = EXCLUDED.last_run_at,
  total_analyzed = social_selling_prospecting_state.total_analyzed + EXCLUDED.total_analyzed,
  total_qualified = social_selling_prospecting_state.total_qualified + EXCLUDED.total_qualified;
```

## Passo 4 — Relatório

Mostre resumo:

```
🎯 Prospecção concluída

📊 Coletados: X seguidores
⏭️ Já analisados: Y (pulados)
✅ Qualificados: Z (criados como lead + enrollment)
❌ Não qualificados: W
⚠️ Erros: E

Top 3 qualificados:
1. @user1 (95) — empresário com escritório
2. @user2 (88) — médico com clínica
3. @user3 (82) — fundador startup
```

## Notas

- **NÃO use Playwright pra qualificar** — só pra coletar lista de @. Qualificação é 100% via RapidAPI + IA na edge function (instantâneo).
- A edge function já faz dedupe (skip de @ analisados nos últimos 30 dias).
- A edge function cria lead com `instagram_username`, `pipeline_id` e `pipeline_stage_id` da automation.
- Próxima rodada: rodar com `/loop 1d /social-selling-prospect` ou agendar via cron.

---
description: Versão leve da rotina diária — só checa o inbox do Instagram pra detectar leads que responderam (e mover automático pra Em Qualificação). Roda 4x/dia.
---

# Social Selling — Checar Respostas

> **URL do projeto:** use `SUPABASE_URL=$(grep -m1 '^VITE_SUPABASE_URL' .env | cut -d '=' -f2)` antes dos curls abaixo.


Versão leve da rotina. Só detecta respostas, não executa ações. SEM PARAR pra pedir confirmação.

## Passo 1 — Listar enrolled

Use `mcp__supabase-aifirst__execute_sql`:

```sql
SELECT instagram_username FROM social_selling_enrollments
WHERE status = 'active' AND instagram_username IS NOT NULL;
```

Se vazio, retorne "Nenhum lead ativo no fluxo. Saindo." e PARE.

## Passo 2 — Abrir inbox

`mcp__playwright__browser_navigate` → `https://instagram.com/direct/inbox/`

`mcp__playwright__browser_wait_for` 2s

`mcp__playwright__browser_snapshot` da página

## Passo 3 — Detectar não-lidas

Procure no snapshot conversas que tenham:
- Bolinha azul (não lida)
- Texto em negrito
- Indicador "X conversas não lidas"

Pra CADA conversa não-lida cujo @ está na lista do passo 1:

1. Click pra abrir
2. Snapshot pra pegar a última mensagem do lead
3. Marque como reply:

```bash
curl -X POST $SUPABASE_URL/functions/v1/social-selling-mark-reply \
  -H "Content-Type: application/json" \
  -d '{
    "instagram_username": "USERNAME",
    "message_content": "TEXTO_ULTIMA_MSG",
    "message_type": "dm"
  }'
```

## Passo 4 — NÃO responda nada

Esse agente é só pra DETECTAR. Não envie nada. O agente Lia (WhatsApp) vai continuar a conversa quando o lead for movido pra Em Qualificação.

## Passo 5 — Relatório

Mostre:

```
👀 Checagem de respostas — concluída

Leads enrolled checados: X
Respostas detectadas: Y

Próxima checagem: 4h (rode /loop 4h /social-selling-checar-respostas)
```

Se Y > 0, lista cada lead que respondeu e a mensagem dele.

## Notas

- Roda em segundos (sem ações), por isso pode rodar 4x/dia sem problema de rate limit
- NÃO precisa rodar logo depois de `/social-selling-run` (esse já checa respostas no início)
- Ideal: rodar 11h, 14h, 17h, 20h pra detectar resposta rápido

---
description: Executa o fluxo diário de social selling no Instagram. Chama edge function `social-selling-plan-day` que retorna o plano humanizado do dia (com ordem random, delays variados, skip aleatório, dedupe), aí executa cada item via Playwright respeitando os delays.
---

# Social Selling — Rotina Diária (humanizada)

> **URL do projeto:** use `SUPABASE_URL=$(grep -m1 '^VITE_SUPABASE_URL' .env | cut -d '=' -f2)` antes dos curls abaixo.


## Filosofia

**Objetivo é humanizar.** Bot que repete ação no mesmo post = banido em dias.

Por isso TODA decisão de quê fazer vem da edge function `social-selling-plan-day`:
- Filtra automaticamente posts/stories já agidos (via UNIQUE constraint no DB)
- Embaralha ordem dos leads
- Delays aleatórios (45-180s)
- 10% chance de skip aleatório por ação ("humano esqueceu")
- Mín 30min entre ações no mesmo lead
- Respeita working_hours (09-20h) e pause_weekends do config
- Aplica rate limits diários (likes, comments, DMs por dia)

A skill **NÃO inventa**. Só executa o que o plan-day mandou.

---

## Passo 1 — Verificar respostas no IG inbox (antes de qualquer ação)

```
1. browser_navigate → https://instagram.com/direct/inbox/
2. browser_wait_for { time: 3 }
3. browser_snapshot
4. Pra cada conversa com indicador "não lida":
   - Se @ está na lista de enrollments active, abre, lê
   - chama edge fn social-selling-mark-reply pra mover lead pra "Respondeu"
```

## Passo 2 — Buscar plano do dia

```bash
curl -X POST '$SUPABASE_URL/functions/v1/social-selling-plan-day' \
  -H 'Content-Type: application/json' -d '{}'
```

Resposta:
```json
{
  "ok": true,
  "counts": { "total_planned": 12, "likes": 6, "comments": 2, "dms": 1 },
  "plan": [
    {
      "enrollment_id": "...", "lead_id": "...", "instagram_username": "...",
      "day": 3, "action_type": "comentar_post",
      "target_url": "https://instagram.com/p/CODE",
      "target_id": "CODE",
      "delay_after_seconds": 87
    },
    ...
  ],
  "skipped": [...]
}
```

Se `ok: false`, parar. Razões possíveis:
- `outside_working_hours` → tá fora do horário
- `weekend_pause` → fim de semana
- `daily_limit_reached` → cota do dia bateu
- `no_active_enrollments` → nada pra fazer

## Passo 3 — Executar plano item por item

Pra cada item do `plan` array, **NA ORDEM**:

### 3.1. `reagir_story`
```
1. browser_navigate → target_url (perfil)
2. browser_wait_for { time: 3 }
3. browser_evaluate → click foto perfil; check se URL virou /stories/USERNAME/
4. Se SIM: browser_snapshot → ache botão "Curtir" do story → browser_click(ref) → screenshot pra confirmar
5. Se NÃO (sem story): registrar como skipped reason=no_active_story
```

### 3.2. `curtir_posts`
```
1. browser_navigate → target_url (post específico que veio no plano, NÃO inventar outro)
2. browser_wait_for { time: 3 }
3. browser_snapshot
4. Procura botão do POST PRINCIPAL: "Curtir" perto de "Comentar"+"Repostar"+"Compartilhar"
   ⚠️ ATENÇÃO: tem 5-10 botões "Curtir" na página (dos comentários também)
5. Se for "Descurtir" (já curtido) → SKIP, registra duplicate
6. browser_click(ref do Curtir do post principal)
7. browser_take_screenshot → CONFIRMAR coração ❤️ vermelho
```

### 3.3. `comentar_post`
```
1. browser_navigate → target_url
2. browser_wait_for { time: 3 }
3. Chama edge fn preview-cadence-message → gera msg contextual no tom do config
4. browser_snapshot → acha textbox "Adicione um comentário..."
5. browser_click no textbox
6. browser_snapshot novo → pega ref do textbox [active]
7. browser_type(ref, mensagem)
8. browser_snapshot → acha botão "Postar"
9. browser_click no Postar
10. browser_evaluate → confirma que mensagem está no body do DOM
```

### 3.4. `responder_story`
```
1. browser_navigate → target_url (perfil)
2. Click foto perfil pra abrir story
3. Se URL virou /stories/USERNAME/ → tirar screenshot pra ler conteúdo
4. Chama preview-cadence-message com action=responder_story
5. Acha input "Responder a USERNAME..."
6. browser_type com submit:true
```

### 3.5. `enviar_dm`
```
1. browser_navigate → target_url (perfil)
2. browser_snapshot → ache botão "Enviar mensagem"
3. browser_click → vai pra DM
4. Chama preview-cadence-message com action=enviar_dm
5. browser_type input mensagem
6. Submit
```

### 3.6. `verificar_resposta`
```
1. browser_navigate → /direct/inbox/
2. Procura conversa com username
3. Se mensagem nova chegou → social-selling-mark-reply
4. Senão → loga como skipped
```

## Passo 4 — Após cada ação

```bash
curl -X POST '$SUPABASE_URL/functions/v1/log-social-selling-action' \
  -H 'Content-Type: application/json' \
  -d '{
    "enrollment_id": "<from plan item>",
    "lead_id": "<from plan item>",
    "action_type": "<from plan item>",
    "status": "success" | "failed" | "skipped",
    "day_number": <plan.day>,
    "content": "<msg gerada se aplicável>",
    "instagram_target": "<plan.target_url>",
    "metadata": {"verified_visually": true, "post_code": "<plan.target_id>"}
  }'
```

E aguarda `delay_after_seconds` antes da próxima:
```
browser_wait_for { time: <delay_after_seconds do plan item> }
```

## Passo 5 — Tratamento de erro

Se aparecer **CAPTCHA**, **bloqueio**, ou **modal de verificação**:
1. PARE TUDO IMEDIATAMENTE
2. Loga ação atual como `failed` com `error_message: "blocked_by_instagram"`
3. Marca remaining items do plano como `skipped`
4. Reporta pro Frank

## Passo 6 — Relatório final

Ao terminar, mostre resumo:
```
🤖 Fluxo Social Selling — concluído

✅ X ações executadas com sucesso
💬 Y leads detectados respondendo (Passo 1)
⏭️ Z ações puladas (já feitas, rate limit, ou skip humano)
❌ W erros

🔥 Próxima rodada: amanhã 9:57 (cron já agendado)
```

## REGRAS DURAS

- **NUNCA** inventar URL de post — só usar `target_url` do plano
- **NUNCA** repetir ação no mesmo target — UNIQUE constraint do DB já bloqueia, mas confere antes
- **NUNCA** pular delay — `delay_after_seconds` é OBRIGATÓRIO entre ações
- **SEMPRE** confirmar visualmente (screenshot) antes de marcar `success`
- **NUNCA** afirmar "curti X" sem screenshot mostrando coração ❤️ vermelho
- **NUNCA** usar `browser_evaluate(() => btn.click())` pra ações no IG — usar `browser_click(ref)` SEMPRE (IG bloqueia clicks via JS)

## Notas técnicas

- Tom de voz e prompts estão TODOS no `config` (chaves `social_selling_tone`, `social_selling_prompt_*`)
- Edge function `preview-cadence-message` gera mensagens contextuais no tom do Frank
- Edge function `log-social-selling-action` espelha em `instagram_messages` quando ação é DM (responder_story, enviar_dm) — comentários ficam só no timeline
- Auto-aprovado em `.claude/settings.json` — não pede confirmação a cada ação

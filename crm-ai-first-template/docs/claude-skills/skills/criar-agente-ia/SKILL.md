---
name: criar-agente-ia
description: |
  Use esta skill SEMPRE que o usuário pedir para criar/configurar/setup um agente
  de IA, agente de atendimento, agente de vendas, agente IA, bot de WhatsApp, ou
  similar no CRM. Frases-gatilho: "criar agente", "novo agente IA", "agente de
  atendimento", "agente de vendas IA", "configurar IA", "bot IA", "agente claude",
  "agente para meu negócio".

  Esta skill garante que TODAS as informações necessárias sejam coletadas ANTES
  de qualquer ação no banco — para que o agente fique customizado pro negócio do
  usuário, não genérico.
---

# Skill: Criar Agente IA Customizado

## Quando esta skill é acionada

Sempre que o usuário pedir para criar/configurar um agente de IA no CRM
(`ai_sales_agents`).

## Regra inviolável

**NUNCA** criar o agente direto. SEMPRE entrevistar o usuário primeiro com as
perguntas abaixo, montar um briefing, mostrar pra ele e pedir confirmação.

## Etapa 1: Entender o negócio

Pergunte (UMA pergunta por vez, não despeje tudo):

1. **Sobre o negócio**
   - Qual o nome do negócio?
   - Tem site? (se sim, peça o link e use WebFetch + WebSearch para enriquecer)
   - O que vocês vendem? (produto/serviço/SaaS/consultoria)
   - Quem são os clientes (perfil: B2B/B2C, tamanho, segmento)?
   - Qual ticket médio?
   - Quais são os 3 planos/produtos principais e preços?

2. **Sobre as dores do cliente**
   - Qual a principal dor que vocês resolvem?
   - Quais objeções comuns os leads têm? (pelo menos 3)
   - Qual o tom da marca (formal, descontraído, técnico, próximo, premium)?

## Etapa 2: Definir o agente

3. **Identidade**
   - Que nome dar pro agente? (ex: Sandra, Pedro, AtendAI)
   - Persona/personalidade: 3-5 traços (ex: empático, direto, consultivo)

4. **Objetivo principal**
   - O que o agente DEVE fazer? Escolha:
     - (a) Apenas qualificar e agendar reunião
     - (b) Vender direto (fechar venda no chat)
     - (c) Triagem (responder dúvidas e transferir pra humano)
     - (d) Atendimento pós-venda (SAC, dúvidas)
     - (e) Outra (descrever)

5. **Horário de funcionamento**
   - Dias da semana ativos? (ex: seg-sex, seg-sab, todo dia)
   - Horário (ex: 08:00-20:00, 24h)
   - Fuso horário (default: America/Sao_Paulo)
   - Fora do horário: agenda resposta pra próximo período válido OU avisa o lead?

6. **Comportamento humanizado**
   - Debounce: quantos segundos esperar antes de responder após msg do lead? (default 10s)
   - Delay de resposta humanizado? (default 2-5s aleatório)
   - Limite de mensagens por conversa? (default 30)

## Etapa 3: Integrações

7. **Pipeline e estágios**
   - Qual pipeline o agente atua? (mostrar lista do banco com `SELECT id, name FROM sales_pipelines WHERE is_active = true`)
   - Em quais estágios? (default: estágios iniciais, ex: "RECEBIDO", "EM ANDAMENTO" — listar do banco com `SELECT name FROM sales_pipeline_stages WHERE pipeline_id = ?`)

8. **Instância WhatsApp**
   - Qual instância usar? (mostrar lista: `SELECT id, name, status FROM whatsapp_instances WHERE status = 'connected'`)
   - Se não tiver nenhuma conectada → instruir o usuário a conectar primeiro em `/configuracoes > WhatsApp`.

## Etapa 4: Tools (ferramentas)

9. **Quais tools ativar?** Mostrar a lista padrão e pedir confirmação:
   - ☐ `qualificar_lead` (BANT — quase sempre ativar)
   - ☐ `agendar_reuniao` (se objetivo for agendar)
   - ☐ `transferir_para_humano` (quase sempre ativar)
   - ☐ `mudar_estagio` (move lead no funil)
   - ☐ `atualizar_lead` (salva dados coletados)
   - ☐ `consultar_produtos` (se vende vários produtos)
   - ☐ `enviar_whatsapp` (notifica time/vendedor)

10. **Regras de transferência pra humano** (lista; pedir pelo menos 3)
    Ex: "lead pediu humano", "negociação de preço", "caso técnico complexo",
    "faturamento > X", "reclamação".

## Etapa 5: Modelo IA e custos

11. **Qual modelo Claude usar?**
    - **Claude Sonnet 4.6** (recomendado — equilibrado custo/qualidade)
    - Claude Haiku 4.5 (mais rápido/barato — bom pra atendimento simples)
    - Claude Opus 4.6 (top — só pra negócios complexos / ticket alto)

    Antes: confirmar que tem `ANTHROPIC_API_KEY` em `config` table do Supabase.

12. **Limite de tokens** por resposta? (default 800 — cabe 4-5 parágrafos curtos)

## Etapa 6: Validação

13. **Montar o briefing completo** com todas as respostas e mostrar pro usuário em formato tabela / bullet. Perguntar:
    - "Está tudo certo? Posso criar agora?"
    - Se ele pedir ajustes, ajustar e mostrar de novo.
    - Só executar SQL quando ele autorizar explicitamente ("pode criar", "ok",
      "autoriza", "manda ver").

## Etapa 7: Execução

Depois da autorização:

1. **Verificar pré-requisitos no banco:**
   - Tabela `ai_sales_agents` existe? (se não, abortar e pedir migrations)
   - Trigger `trg_enqueue_for_ai_agent` existe?
   - Edge function `ai-sales-agent` deployada?
   - Edge function `whatsapp-webhook` deployada?
   - `config.ANTHROPIC_API_KEY` preenchido?
   - Pipeline e instância WhatsApp existem e estão ativas?

2. **Construir o `system_prompt`** baseado no briefing. Estrutura padrão:
   ```
   Você é a {NOME}, {PAPEL} da {EMPRESA}.

   # CONTEXTO DA EMPRESA
   {descrição enriquecida com WebFetch}

   **Planos/Produtos:** {lista com preços}

   # SEU PAPEL
   {objetivo principal}

   # TOM DE VOZ
   {persona em bullets}

   # REGRAS DE QUALIFICAÇÃO
   {BANT adaptado ao negócio}

   # OBJEÇÕES COMUNS
   {lista das 3+ objeções com como tratar}

   # QUANDO TRANSFERIR PRA HUMANO
   {regras de transferência}

   # COMO FECHAR
   {fluxo de fechamento por perfil de lead}

   # NUNCA
   {lista de proibições}

   # FORMATO DE RESPOSTA
   - 2-4 linhas máx
   - Português coloquial mas correto
   - 1 emoji no máximo
   - Termina com pergunta ou CTA
   - 1 informação por vez
   ```

3. **Inserir** em `ai_sales_agents` com todos os campos preenchidos.

4. **Cadastrar as tools** escolhidas em `ai_agent_tools` (uma linha por tool).

5. **Reportar** o agente criado: id, nome, modelo, instância, pipeline, tools.

6. **Instruir o usuário a testar:**
   - Pegar outro celular
   - Mandar msg pro WhatsApp do CRM
   - Aguardar `debounce_seconds`
   - Verificar resposta

## Anti-patterns (NÃO fazer)

- ❌ Criar agente com prompt genérico ("Você é um vendedor")
- ❌ Pular a entrevista quando o usuário só falou "cria um agente"
- ❌ Inventar planos/preços que não foram informados
- ❌ Ativar TODAS as tools sem perguntar
- ❌ Usar modelo padrão sem confirmar
- ❌ Salvar com `is_active = false` sem avisar
- ❌ Esquecer de checar pré-requisitos antes do INSERT
- ❌ Hardcodear instance_id ou pipeline_id "default"

## Esqueleto SQL de referência

```sql
INSERT INTO ai_sales_agents (
  name, description, system_prompt, personality_traits, target_stages,
  settings, model, temperature, max_tokens, is_active,
  instance_id, pipeline_id, scope
) VALUES (
  '{nome}', '{descrição}', $prompt$ {prompt completo} $prompt$,
  '[{traços}]'::jsonb,
  ARRAY['{estagio1}', '{estagio2}']::text[],
  $cfg${
    "working_days": [1,2,3,4,5],
    "working_hours_start": "08:00",
    "working_hours_end": "20:00",
    "timezone": "America/Sao_Paulo",
    "debounce_seconds": 10,
    "response_delay_min_ms": 2000,
    "response_delay_max_ms": 5000,
    "auto_pause_after_human_reply": true,
    "auto_pause_minutes": 60,
    "max_messages_per_conversation": 30,
    "cadence_max_messages_per_hour": 4,
    "cadence_max_messages_per_day": 12
  }$cfg$::jsonb,
  '{model}', 0.7, {max_tokens}, true,
  '{instance_uuid}', '{pipeline_uuid}', 'lead'
);

-- Tools (uma por vez):
INSERT INTO ai_agent_tools (agent_id, name, description, parameters, action_type, action_config, priority, is_active)
VALUES ('{agent_id}', '{tool_name}', '{desc}', '{params_json}'::jsonb, '{action_type}', '{}'::jsonb, {priority}, true);
```

## Tools disponíveis (action_type → comportamento)

| Tool name | action_type | O que faz |
|-----------|-------------|-----------|
| qualificar_lead | qualify_bant | Atualiza `bant_*` no lead |
| agendar_reuniao | schedule_meeting | Cria `company_activity` tipo 'meeting' |
| transferir_para_humano | notify_human | Pausa conversa + cria sales_alert |
| mudar_estagio | change_stage | Update `leads.pipeline_stage_id` |
| atualizar_lead | update_lead | Update genérico em `leads` |
| consultar_produtos | query_products | Lê `products` tabela |
| enviar_whatsapp | send_whatsapp | Envia msg via UAZAPI |

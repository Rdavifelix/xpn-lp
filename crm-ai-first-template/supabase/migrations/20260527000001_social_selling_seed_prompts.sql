-- ============================================================
-- Social Selling — seed completo dos prompts e tom de voz
-- Tudo no banco / editável pela UI em /configuracoes?s=social-selling
-- Zero fallback hardcoded em edge function (errors out se chave faltar)
-- ============================================================

-- 1) Tom de voz (JSON com description / sample_messages / forbidden_words)
INSERT INTO config (key, value)
SELECT 'social_selling_tone',
  jsonb_build_object(
    'description', 'Tom brasileiro, informal, direto. Frases curtas (3-12 palavras). Empresário falando com empresário. Sem emoji em DM ou comentário frio. Sem clichês de vendedor ("agregar valor", "potencializar", "alavancar").',
    'sample_messages', E'curti o post sobre [tema], faz sentido demais\nvocês fazem isso pra cliente externo tb ou só interno?\nmano boa, achei sua abordagem diferente do mercado',
    'forbidden_words', 'agregar valor, potencializar, alavancar, sinergia, ecossistema, mindset, disruptivo, soluções inovadoras, parceria de sucesso'
  )::text
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_tone');

-- 2) Prompt: comentar post (público)
INSERT INTO config (key, value)
SELECT 'social_selling_prompt_comentar_post',
  'Gere comentário PÚBLICO no post. 4-12 palavras. Cite UM detalhe específico do post (não genérico). Sem vender. Sem emoji. Sem aspas. Sem chamar pra DM. Empresário comentando com empresário — natural, não bajulação.'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_prompt_comentar_post');

-- 3) Prompt: responder story (DM)
INSERT INTO config (key, value)
SELECT 'social_selling_prompt_responder_story',
  'Gere mensagem curta de DM em resposta ao story atual. 1 frase de 4-12 palavras. Comenta o conteúdo do story de forma leve (precisa fazer sentido com o que ele postou). NÃO oferece nada. NÃO pede nada. Sem emoji.'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_prompt_responder_story');

-- 4) Prompt: enviar DM (frio ou follow-up)
INSERT INTO config (key, value)
SELECT 'social_selling_prompt_enviar_dm',
  'Gere DM de prospecção/reativação. 2-3 frases. Conecta com ALGO concreto do perfil (bio, post recente) OU do histórico de conversa se existir. Termina com pergunta aberta. Empresário falando com empresário — sem tom de vendedor. Sem emoji. Sem "oi, tudo bem?" genérico.'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_prompt_enviar_dm');

-- 5) Prompt: followup após story (DM)
INSERT INTO config (key, value)
SELECT 'social_selling_prompt_followup_story',
  'Gere DM de follow-up depois de já ter reagido/respondido um story. 2 frases. Referencia algo do story OU da última interação. Pergunta aberta no fim. Sem oferecer produto. Sem emoji.'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_prompt_followup_story');

-- 6) Garante que social_selling_prompt_qualificacao continua existindo
-- (já criado em 20260526_social_selling_pack_extension.sql — só reforça idempotência)
INSERT INTO config (key, value)
SELECT 'social_selling_prompt_qualificacao',
  'Você é um qualificador de prospects B2B. Score 0-100. Profissão/empresa clara na bio = 70. Empresa própria/CEO/founder = 80. Verificado + profissão = 85. Bio vazia/só hobbies = 25. Privado sem bio = 10. Retorne JSON {"score": <n>, "reason": "<frase>"}.'
WHERE NOT EXISTS (SELECT 1 FROM config WHERE key = 'social_selling_prompt_qualificacao');

-- FIM

# Páginas externas e campos personalizados

Em Marketing → Canais de Entrada → Páginas externas, crie um canal. Copie a URL de recebimento e envie POST JSON com X-Request-Id UUID. Reutilize esse identificador somente nas tentativas do mesmo envio.

O canal começa em captura: armazena amostras sem criar contatos. Escolha pipeline, etapa e responsável fixo ou rodízio; os campos da amostra aparecem automaticamente com valores legíveis, inclusive objetos aninhados. No destino, escolha um campo existente ou “+ Criar campo novo”. Campos personalizados pertencem à oportunidade e ao pipeline; tipos: texto, número, data, sim/não e lista. Os valores aparecem no detalhe da oportunidade.

Use “Salvar e ativar canal”: salva, valida o exemplo e ativa em sequência. “Salvar sem ativar” mantém a captura. Alterar o mapeamento devolve o canal à captura. Amostras antigas não são processadas automaticamente. Campos não mapeados são ignorados. Nome e email ou telefone devem ser obrigatórios. Dados inválidos registram erro sem cadastro parcial. A área Envios recebidos mostra payload, resultado e links para os registros.

O rodízio avança para cada oportunidade nova. Contatos com uma oportunidade aberta no mesmo funil preservam etapa e responsável. Reenvios idênticos com o mesmo X-Request-Id não duplicam registros. Contatos ambíguos e destinos inválidos geram erro, sem distribuição alternativa silenciosa.

A URL permite somente enviar dados para aquele canal. Não contém chave administrativa. Pode ser usada no formulário público; pause o canal para interromper recebimentos. Há limite de 50 KB por payload e 200 recebimentos novos por canal/hora. Não dispara WhatsApp por si só.

## MCP 0.10.0

Ferramentas: listar_canais_entrada, consultar_opcoes_canal, criar_campo_personalizado, criar_canal_entrada, consultar_canal_entrada, salvar_mapeamento_canal, validar_payload_canal, ativar_canal_entrada, consultar_envios_canal e consultar_campos_oportunidade. Configuração exige administrador. A leitura de valores respeita a empresa autenticada. IDs estáveis evitam duplicar campos/canais e revisões impedem sobrescrever configuração concorrente.

## Verificação

scripts/verify-inbound-channels.sql executa testes transacionais com rollback: captura, criação, deduplicação, reconversão, rodízio persistente, valores numéricos, falha sem escrita parcial, pausa e permissões. A interface e o endpoint publicado foram exercitados com dados sintéticos em tenant de QA, incluindo criação do campo na tela e visualização no deal.

Publicado em 10/09/2026 no deploy 6aa307caef7ff822d4dae3de. MCP de produção validado por OAuth: versão 0.10.0, 125 ferramentas, consulta de canais/opções e leitura do campo personalizado com valor 18000. Testes: 13 frontend, 12 MCP; typechecks e builds app/extensão, Edge Functions e advisors de segurança sem erros. Tenant de QA desativado após os testes.

## Revisão de interface

Campos recebidos são detectados automaticamente em captura a cada cinco segundos. Cada linha mostra resposta e destino; nome/email/telefone e campos comuns recebem sugestões sem substituir escolhas existentes. Criação de campo ocorre na própria linha, com tipo número ou sim/não sugerido conforme o valor. Histórico exibe respostas formatadas; código fica em detalhes técnicos da conexão. Fluxo validado visualmente em QA com criação de campo numérico, ativação e novo envio processado.

Interface revisada publicada no deploy 6aa30c3eaf109139982e0d6c; arquivo de produção conferido contra o build local.

## Timeline de formulário

Cada envio processado aparece como Formulário preenchido na timeline do contato. Clique abre modal com respostas formatadas, nome do formulário/canal e data. A migration 20260910220219 preserva os dados do envio e preenche eventos anteriores disponíveis. Envios distintos no mesmo minuto são mantidos. Capturas sem contato e falhas não geram evento de cadastro. Teste visual: abertura do evento e modal em contato QA; teste automatizado cobre clique/teclado e valores numéricos/booleanos. Publicado no deploy 6aa329acf2baae5048c29b86.

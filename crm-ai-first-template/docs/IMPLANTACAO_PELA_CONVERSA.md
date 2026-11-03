# Implantação pela conversa — primeira entrega

O plano de implantação agora persiste o processo, a proposta, sua versão, confirmação e os resultados de execução. Escopo implementado: coordenação e criação de pipelines/agentes em rascunho. Não equivale à implantação integral de campanhas, canais ou atendimento autônomo.

## Ferramentas novas

- `diagnosticar_operacao`: empresa, permissões, pipelines, agentes, planos recentes e capacidades implementadas. Não verifica saúde de integrações.
- `consultar_implantacao`: lista até 50 planos; com plan_id retorna documento, versão, aprovação, resultados e últimas 50 ações.
- `prever_implantacao`: valida o documento sem gravar e distingue executores disponíveis de capacidades pendentes.
- `salvar_implantacao`: cria com versão esperada 0, ou revisa usando a versão atual. Toda revisão invalida a aprovação anterior.
- `aprovar_implantacao`: registra a confirmação explícita recebida na conversa, o usuário autenticado, versão e data. A confirmação é transmitida pelo cliente MCP; não é assinatura independente nem prova criptográfica da fala humana.
- `aplicar_item_implantacao`: aplica um item aprovado, após suas dependências; registra resultado e permite retomada.

As ferramentas anteriores continuam disponíveis. As novas regras de aprovação persistida protegem o executor do plano; as criações diretas anteriores continuam seguindo a confirmação conversacional descrita nos seus contratos.

## Documento

Um plano contém `title`, `process` e `items`. Cada item tem UUID estável, título, tipo, configuração e IDs das dependências. Dependências aparecem antes dos seus dependentes, impedindo ciclos. Limites: 50 planos por empresa, 50 itens por plano, 60 KB por documento.

Tipos executáveis:

- `pipeline`: configuração com nome e etapas, no mesmo formato de `prever_pipeline`.
- `agent_draft`: template_id global válido, name, system_prompt e tools (slugs do catálogo). O resultado é um agente inativo com as habilidades selecionadas instaladas; sem canal/credencial. Planos antigos sem tools precisam ser revisados e aprovados novamente antes de aplicar um novo agente.

Tipos apenas planejáveis: campaign, automation, integration, knowledge e task. Sua tentativa de aplicação retorna `pending_capability`. Esse estado não desbloqueia dependências nem significa conclusão. Assim, a conversa pode desenhar a operação inteira sem anunciar que módulos ainda não implementados foram configurados.

## Sequência de uso

1. Diagnosticar; consultar o plano existente antes de criar outro.
2. Entrevistar o usuário e preencher lacunas do processo.
3. Apresentar a prévia, incluindo o que será executado e o que ficará pendente.
4. Salvar o plano e sua versão.
5. Após confirmação explícita do usuário, registrar a aprovação dessa versão.
6. Aplicar os itens na ordem das dependências; consultar resultados.
7. Relatar recursos criados, itens com falha e pendências. Não declarar operação ativa porque um rascunho foi criado.

Para continuar em outra sessão, consultar o plano; não repetir criações diretas. Após timeout, reutilizar o mesmo request_id e payload. Depois de uma falha confirmada, corrigir/reaprovar se necessário e usar novo request_id para nova tentativa. Itens já aplicados não são duplicados mesmo com novo request_id.

## Consistência e isolamento

Tenant deriva da autenticação e é validado no backend. Leitura exige vínculo/sessão/cliente válidos; escrita exige administrador. Tabelas ficam em schema privado, RLS ativo e sem acesso direto de anon/authenticated. RPC pública fixa, incluída no guard OAuth. Sem SQL livre, sem nome de tabela enviado pela IA, sem service_role no servidor MCP.

Cada mutação é serializada por tenant. Recursos e resultados são gravados na mesma transação; falha do executor é revertida e registrada como `failed`. request_id é associado ao usuário e conteúdo. expected_version impede sobrescrever uma proposta revisada. Um item aplicado não pode ser removido/alterado por salvar_implantacao: futuras edições de recursos terão executores próprios.

Histórico guarda snapshots por ação em crm_mcp.plan_events, incluindo proposta e confirmação. Nunca inserir senhas, tokens ou credenciais no documento ou confirmação. O histórico retornado ao cliente mostra metadados; snapshots completos permanecem privados.

## Validação

- PostgreSQL local/PGlite: versões, aprovação obrigatória, replay, dependências, falha atômica, histórico, agente inativo, restrição de escrita e separação de tenants.
- Adapter HTTP MCP: novas ferramentas descobertas e preview de campanha corretamente pendente.
- Banco remoto: scripts/verify-mcp-plans.sql confirma criação única e retomada, com rollback integral.
- Build/testes do MCP e CRM, checagem Edge Functions, typecheck/build da extensão.

## Próximos executores

Configuração completa de agentes e conhecimento; catálogo seguro de habilidades; campanhas/automações; conexão de serviços; simulação e publicação/ativação. Antes de ativar, resolver a versão executada do agente e o caminho de atendimento entre os dois motores existentes. Não expor somente CRUD de tabelas como prova de operação funcional.

## Habilidades dos agentes

`listar_habilidades_agentes` retorna catálogo, parâmetros, provedores, contexto runtime necessário e sugestões dos templates. `criar_agente` e o alias `criar_agente_rascunho` agora exigem tools (1–30 slugs) e instalam as habilidades na mesma transação da criação. `vincular_habilidades_agente` adiciona a um agente próprio inativo; `consultar_agente_configurado` retorna habilidades e checklist de validação. Configurações personalizadas existentes não são sobrescritas.

O MCP não recebe nem altera SQL/URLs/segredos das implementações; copia a configuração interna do catálogo global. Ferramentas administrativas amplas (SQL livre, inspeção de tabelas e Meta API genérica) não são instaláveis por esse fluxo. Modos always do catálogo são preservados; habilidades que exigem aprovação ou estão disabled são instaladas desativadas até validação do respectivo fluxo. O agente continua inativo.

Disponibilidade no catálogo e instalação não provam funcionamento do executor legado. A resposta sempre informa validation_status=not_tested, ready=false e pendências. Nenhuma credencial é copiada do template. O MCP ainda não cria novas implementações de habilidades ausentes: deve informar a lacuna.

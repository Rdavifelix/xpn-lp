# Validação do pacote 2026.09.14

## Executado na cópia independente

- Instalação das dependências com npm ci e lockfiles, frontend/MCP/extensão.
- Frontend: typecheck, 27 testes e build aprovados.
- MCP: build e 12 testes aprovados.
- Checagem de todas as Edge Functions aprovada.
- 9 testes Deno aprovados (origem pública e consulta de anúncios).
- Extensão: build e typecheck aprovados.
- Sintaxe Bash do instalador aprovada; validação de origem HTTPS exercitada.
- Migration nova de remetente validada em PostgreSQL embarcado PGlite: preserva remetentes existentes e exige remetente explícito em novos registros.
- Varredura por JWTs, chaves privadas, padrões de chaves de provedores e referências à infraestrutura da produção: sem ocorrências identificadas no conteúdo distribuído.
- Arquivos privados, vínculos de deploy, dependências e builds não entram no ZIP. SHA256SUMS identifica o conteúdo distribuído.

## Ainda não validado

A instalação completa desde um Supabase vazio não foi executada: não havia Docker para Supabase local, e nenhum projeto remoto novo foi criado para esta entrega. PGlite não substitui Supabase Auth/Storage/Realtime/Vault. Os testes anteriores da produção não certificam instalação limpa.

OAuth/MCP no domínio de um membro, recuperação de senha e integrações externas precisam de homologação com as contas do proprietário. Não foram enviados WhatsApp, directs ou campanhas durante esta preparação.

Recomendação de entrega: homologar primeiro com uma instalação piloto antes de anunciar o pacote como validado de ponta a ponta para toda a turma. O pacote está preparado para essa instalação e inclui instruções; não contém serviços patrocinados.

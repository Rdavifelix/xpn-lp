# Instruções para Codex e outros agentes

Este repositório é um template distribuído para mentorados. Antes de alterar qualquer arquivo, leia integralmente:

1. `CLAUDE.md` — arquitetura, regras do projeto e detecção de primeiro uso.
2. `README.md` — visão geral e comandos.
3. `docs/SEGURANCA.md` e `docs/OPERACAO.md` — regras de segurança e publicação.

## Escolha obrigatória do fluxo

- **Instalação nova:** se o mentorado acabou de receber este template e ainda não tem um CRM anterior, siga `.claude/skills/setup-projeto/SKILL.md` e execute o fluxo guiado de `setup.sh`. Se `.claude/` não existir, restaure-a a partir de `docs/claude-skills/` conforme `CLAUDE.md`.
- **Atualização de CRM existente:** leia e siga `GUIA_UPGRADE.md`. Preserve `.env` e dados existentes, faça backup e aplique apenas migrations ainda não executadas. Nunca trate uma atualização como instalação limpa.
- Se não for possível determinar com segurança qual dos dois casos se aplica, pergunte antes de alterar banco ou ambiente.

## Regras obrigatórias

- Nunca grave senhas, service-role keys ou tokens privados no código, documentação ou commits.
- Não execute operações destrutivas nem reaplique migrations de baseline em banco com dados sem autorização explícita.
- Respeite o isolamento multi-tenant, RLS e as verificações de administrador existentes.
- Use os lockfiles e não rode atualizações forçadas de dependências.
- Ao concluir, rode `npm run check`, a checagem das Edge Functions e o build/typecheck da extensão conforme `RELATORIO_REVISAO.md`.
- Informe claramente o que foi configurado, o que foi validado e quais integrações ainda dependem de credenciais do mentorado.

As instruções de `CLAUDE.md` também se aplicam ao Codex, exceto quando conflitarem com uma solicitação explícita do usuário ou com estas regras de segurança.

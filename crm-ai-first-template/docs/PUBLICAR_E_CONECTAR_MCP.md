# Publicar o CRM e conectar o MCP

## 1. Hospedagem

Use um site próprio. O netlify.toml inclui build do frontend/MCP e função HTTP. Instale Node 22 e use os lockfiles. Não reutilize links ou IDs de outro proprietário.

Na hospedagem, cadastre as variáveis VITE_* geradas em .env e as variáveis de servidor geradas em .env.hosting. Não envie esses arquivos ao Git. SUPABASE_PUBLISHABLE_KEY é a chave pública/anon, nunca service_role.

- VITE_APP_URL e VITE_CRM_URL: origem HTTPS do seu CRM.
- VITE_MCP_PUBLIC_URL e MCP_PUBLIC_URL: essa origem + /mcp.
- SUPABASE_URL: seu projeto.
- SUPABASE_PUBLISHABLE_KEY: chave pública desse projeto.
- MCP_DYNAMIC_CLIENTS=true.

Publique no site reservado no setup. Se mudar de domínio, atualize todas as variáveis, refaça o build, ajuste Auth e execute `supabase secrets set --project-ref SEU_PROJETO_REF CRM_PUBLIC_URL=https://seu-dominio`.

## 2. Supabase OAuth (configuração única do proprietário)

No projeto criado para você:

1. Authentication → URL Configuration: Site URL = origem HTTPS do CRM; adicione o retorno /reset-password e os retornos locais necessários.
2. Authentication → OAuth Server: habilite o servidor e registro dinâmico de clientes; Authorization Path = /oauth/consent.
3. Authentication → Hooks: configure Custom Access Token Hook para public.mcp_access_token_hook.
4. Confira assinatura assimétrica de JWT e JWKS acessível. O MCP valida assinatura, emissor e audiência.
5. No SQL Editor, execute substituindo o endereço abaixo pelo mesmo MCP_PUBLIC_URL:

```sql
INSERT INTO crm_mcp.settings(resource,dynamic_clients_enabled)
VALUES ('https://seu-dominio/mcp',true)
ON CONFLICT (singleton) DO UPDATE SET resource=EXCLUDED.resource,dynamic_clients_enabled=true;
```

O schema crm_mcp permanece fora dos schemas públicos da Data API. Não desative RLS nem conceda acesso geral para fazer a conexão funcionar. Cadastro de membros por convite continua funcionando com signup público desativado. Habilitar cadastro público/SaaS é uma decisão separada do proprietário.

## 3. Validação

Abra /oauth/consent pelo fluxo iniciado no cliente MCP, faça login com seu administrador e autorize. No Claude ou outro cliente compatível, cadastre https://seu-dominio/mcp. Consulte a empresa, liste pipelines e faça uma criação de teste autorizada. Confira que o recurso pertence ao seu tenant. Teste revogação e acesso negado por outra empresa antes de oferecer SaaS.

Uma URL acessível sem autenticação não comprova autorização MCP. Valide uma chamada autenticada de verdade.

## 4. Integrações opcionais

Configure IA, UAZAPI ou WhatsApp oficial, redes sociais, agenda e demais serviços na interface. Use contas próprias. As chaves patrocinadas da imersão não acompanham o template. Autorizar redes prepara seu webhook automaticamente; a permissão do provedor e o vínculo com agente precisam ser confirmados.

Referência oficial: https://supabase.com/docs/guides/auth/oauth-server/getting-started

# Servidor MCP do CRM

Node 22+, Streamable HTTP e autenticação Supabase OAuth. Código em src; catálogo completo definido pelos registros de ferramentas, com permissões e isolamento por tenant.

```bash
npm ci
npm run check
npm run build
npm start
```

Para desenvolvimento copie .env.example e configure o projeto próprio. Para produção, siga ../docs/PUBLICAR_E_CONECTAR_MCP.md. Endpoint = origem pública + /mcp. Não configure service_role neste servidor.

As ferramentas incluem CRM, pipelines, agentes/habilidades, formulários, equipe, agenda e integrações conforme o catálogo. Consulte as capacidades no cliente; não assuma que uma integração de leitura permite escrita.

Scripts live-smoke e live-write-smoke exigem ambiente de teste próprio e token OAuth privado. Nunca distribua o arquivo de sessão.

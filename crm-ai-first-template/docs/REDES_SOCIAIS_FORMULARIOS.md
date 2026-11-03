# Instagram no formulário e painel de redes

Implementado em 10/09/2026.

- Marketing → Formulários: tipo Instagram, mapeamento `instagram`, aceita @ ou URL de perfil. Páginas externas oferecem o mesmo destino padrão. MCP salvar_formulario aceita esse tipo; salvar_mapeamento_canal documenta o destino.
- Salva o identificador normalizado no contato. Mantém origem, idempotência e destino do formulário. Mudança do @ limpa vínculo do perfil anterior.
- Fila `instagram_enrichment_jobs` separa enriquecimento de captação. Worker a cada minuto usa segredo dedicado no Vault/Edge Secrets. Retenta falhas até três vezes; ausência de configuração aguarda uma hora. Não bloqueia cadastro por falta de provedor.
- Provedor de perfil: ScrapeCreators, chave resolvida por empresa → configuração global → ambiente. Não foi copiada credencial do projeto IAP. Sem chave, timeline mostra configuração pendente. Consulta pública real da bio ainda depende dessa chave.
- Vínculo de comentários futuros usa @ com correspondência única dentro da empresa; nunca mescla contatos nem toma conversa já atribuída a outro lead. @ informado no formulário é uma declaração, não prova de posse. Duplicidades exigem revisão humana.
- Timeline diferencia comentários de DMs e mostra modal de perfil e de comentário. Miniatura/legenda/link vêm de `social_posts`, quando sincronizados; ausência mantém comentário legível.
- `/marketing/redes`: layout adaptado de IAP/crm-comercial SocialCommand. Contas, conteúdos, filtros, KPIs e gráficos. RLS e todas as escritas de sincronização escopadas por tenant. Não foram copiadas políticas globais do IAP.
- Sincronizar consulta apenas redes já conectadas da empresa, leitura no provedor. Zernio consulta até 90 dias (máximo 10 páginas de 100 itens por conta); Meta importa até 100 mídias. Histórico salvo permanece. Stories e análise de DNA do IAP não foram portados. Métricas dependem das permissões/plano do provedor; ausentes não são apresentadas como desempenho zero nos KPIs.
- Documentação consultada: https://docs.zernio.com/analytics/get-daily-metrics e https://scrapecreators.com/ . Daily metrics aceita accountId; resposta pode usar metrics ou platformMetrics.

## Validação

`scripts/verify-instagram-forms.sql`: transação revertida, formulário nativo + entrada externa, normalização, idempotência, troca de @, perfil, comentário associado ao lead existente, origem preservada, privilégios e RLS. Formulário enviado pelo navegador no tenant QA; timeline confirmou recebimento e falta de credencial. Worker autenticado retornou 200; sem segredo retornou 403. Teste do modal protege link inválido e preserva comentário sem post.

Migrations: 20260910221834 e 20260910223210. `npm run check`, MCP checks, Edge Functions e extensão. A checagem expandida de todo tsconfig.app não terminou em tempo razoável e foi interrompida; o comando padrão do projeto e build passaram.

Deploy de produção: 6aa3309b2769ae12891ea214. Página /marketing/redes respondeu HTTP 200.

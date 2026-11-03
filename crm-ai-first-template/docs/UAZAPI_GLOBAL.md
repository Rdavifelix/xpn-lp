# Conexão WhatsApp incluída

As novas instâncias usam a conexão global do SaaS por padrão. O servidor resolve SAAS_UAZAPI_ADMIN_URL e SAAS_UAZAPI_ADMIN_TOKEN nos secrets do Supabase; o navegador recebe somente configured/source. O token global não é enviado ao cliente nem gravado no repositório.

Em Configurações → WhatsApp, o administrador pode abrir “Usar minha própria Uazapi” e salvar URL + Admin Token. Os dois valores são gravados juntos em tenant_config_overrides sob RLS. Um par próprio incompleto bloqueia a criação, sem enviar a chave global a uma URL própria. “Usar conexão incluída” remove o par próprio. Instâncias existentes mantêm api_url/api_key; a preferência afeta novas instâncias.

Interface e MCP usam o mesmo resolvedor. A instância é criada com tenant e propósito inbox, e o webhook de mensagens/conexão é configurado. O usuário precisa escanear o QR e vincular a instância ao agente/responsáveis desejados; criar instância não ativa automaticamente todos os agentes.

Validação 10/09/2026: autenticação administrativa HTTP 200; empresa QA sem override resolveu source=global; criação de instância pelo proxy autenticado; QR real gerado; webhook ativo com messages; instância temporária excluída na Uazapi e no CRM. Teste do resolvedor cobre par próprio, global e ausência de mistura de credenciais. Não houve conexão de um telefone real nem envio de mensagens.

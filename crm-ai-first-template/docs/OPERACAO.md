# Operação

Siga README.md e PUBLICAR_E_CONECTAR_MCP.md para instalar/publicar. Antes de liberar para uso, valide login, recuperação de senha, isolamento de tenants (`scripts/verify-multitenant-isolation.sql` + homologação com duas empresas reais, ver `docs/MULTITENANT.md`), webhook válido/inválido, jobs agendados, envio/recebimento autorizado, agenda e backup/restauração. Monitore falhas de funções/filas, custo da IA e limites dos provedores.

Não reutilize evidências de outra instalação como comprovação de funcionamento desta. Todas as integrações externas exigem configuração do proprietário.

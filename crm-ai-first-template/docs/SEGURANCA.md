# Segurança

## Modelo adotado

- O JWT é validado pelo gateway e, nos fluxos privilegiados, novamente pelo Auth.
- O tenant é derivado do usuário ou da integração no servidor; nunca do corpo enviado pelo navegador. Não existe fallback para o tenant default: requisição sem tenant é recusada e linha sem `tenant_id` é ignorada.
- Toda policy permissiva em tabela com `tenant_id` exige `tenant_id = get_tenant_id()`; `scripts/verify-multitenant-isolation.sql` falha se alguma escapar. Detalhes em `docs/MULTITENANT.md`.
- A `service_role` fica somente no Supabase Vault e nas Edge Functions.
- Credenciais de IA e integrações não são devolvidas ao frontend. Soniox usa chave temporária, de uso único e duração limitada.
- Webhooks públicos falham fechado quando assinatura ou segredo não está configurado.
- RPCs `SECURITY DEFINER` dos agentes ficam restritos à `service_role`, salvo operações administrativas explicitamente protegidas.
- SQL livre gerado por LLM está desativado. Agentes usam RPCs com finalidade e escopo definidos.

## Segredos obrigatórios por integração

| Integração | Configuração |
|---|---|
| Meta WhatsApp / Lead Ads | `META_APP_SECRET` e verify token |
| Resend | `RESEND_WEBHOOK_SECRET` |
| Brevo | `BREVO_WEBHOOK_SECRET`; use `?token=...` na URL do webhook |
| Google Ads Apps Script | `GOOGLE_ADS_WEBHOOK_SECRET`; envie em `x-webhook-secret` ou `?token=` |
| UAZAPI | URL do webhook gerada pelo CRM, contendo token por instância |
| WaVoIP | URL exibida no CRM, contendo token do dispositivo |
| Telegram | `webhook_secret` gerado no deployment |

## Rotação e incidentes

1. Revogue imediatamente a chave no provedor.
2. Atualize o secret/configuração no CRM.
3. Reconfigure o webhook quando a URL contiver o token rotacionado.
4. Revise logs das Edge Functions e tabelas de auditoria pelo período afetado.
5. Invalide sessões de usuários se houver suspeita de vazamento de JWT.

Não registre payloads completos de webhook nem tokens em logs. Não use projetos Supabase compartilhados entre clientes sem o tenant provisionado e testado.

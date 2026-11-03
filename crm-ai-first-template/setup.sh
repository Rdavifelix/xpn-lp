#!/usr/bin/env bash
# Instalador seguro e reproduzível do CRM AI-First em um projeto Supabase novo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
API="https://api.supabase.com/v1"
DEFAULT_TENANT="00000000-0000-0000-0000-000000000001"

say()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m  ✅ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m  ⚠️  %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m  ❌ %s\033[0m\n" "$*"; exit 1; }

management_query() {
  local query="$1" payload
  payload="$(jq -n --arg query "$query" '{query:$query}')"
  curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
    -X POST "$API/projects/$REF/database/query" -d "$payload"
}

# Existing installations must use the upgrade/recovery guide.
[[ ! -f .env && ! -f .installation-project.json ]] || fail "Esta pasta já tem uma instalação iniciada. Consulte GUIA_UPGRADE.md; não crie outro projeto."
say "Verificando pré-requisitos"
for bin in node npm supabase curl jq openssl base64; do
  command -v "$bin" >/dev/null || fail "'$bin' não está instalado."
done
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
[[ "$NODE_MAJOR" -ge 22 ]] || fail "Node.js 22 ou superior é obrigatório."
ok "Node $(node -v) | Supabase CLI $(supabase --version 2>/dev/null | head -1)"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  printf "\nGere um token em https://supabase.com/dashboard/account/tokens\n"
  read -r -s -p "Supabase Access Token: " SUPABASE_ACCESS_TOKEN
  printf "\n"
  export SUPABASE_ACCESS_TOKEN
fi
AUTH=(-H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN")

if [[ -z "${CRM_PUBLIC_URL:-}" ]]; then read -r -p "URL pública reservada para seu CRM (https://...): " CRM_PUBLIC_URL; fi
CRM_PUBLIC_URL="$(node scripts/validate-public-url.mjs "$CRM_PUBLIC_URL")" || fail "Informe uma origem HTTPS válida."
export CRM_PUBLIC_URL
say "Selecionando organização"
ORGS="$(curl -fsS "${AUTH[@]}" "$API/organizations")" || fail "Token inválido ou sem acesso."
N_ORGS="$(jq 'length' <<<"$ORGS")"
if [[ -n "${ORG_ID:-}" ]]; then
  ok "Organização definida por ORG_ID"
elif [[ "$N_ORGS" -eq 1 ]]; then
  ORG_ID="$(jq -r '.[0].id' <<<"$ORGS")"
  ok "Organização: $(jq -r '.[0].name' <<<"$ORGS")"
else
  jq -r 'to_entries[] | "  [\(.key)] \(.value.name)"' <<<"$ORGS"
  read -r -p "Número da organização: " IDX
  ORG_ID="$(jq -r ".[$IDX].id // empty" <<<"$ORGS")"
  [[ -n "$ORG_ID" ]] || fail "Organização inválida."
fi

PROJECT_NAME="${PROJECT_NAME:-crm-ai-first}"
DB_PASS="${SUPABASE_DB_PASSWORD:-$(openssl rand -hex 16)}"
say "Criando projeto '$PROJECT_NAME' em São Paulo"
CREATE_PAYLOAD="$(jq -n \
  --arg organization_id "$ORG_ID" --arg name "$PROJECT_NAME" --arg db_pass "$DB_PASS" \
  '{organization_id:$organization_id,name:$name,region:"sa-east-1",db_pass:$db_pass}')"
CREATE="$(curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
  -X POST "$API/projects" -d "$CREATE_PAYLOAD")" || fail "Não foi possível criar o projeto. Confira os limites do plano."
REF="$(jq -r '.id // empty' <<<"$CREATE")"
[[ -n "$REF" ]] || fail "A API não retornou o identificador do projeto."
umask 077
jq -n --arg project_ref "$REF" --arg database_password "$DB_PASS" '{project_ref:$project_ref,database_password:$database_password}' > .installation-project.json
ok "Projeto criado: $REF"

say "Aguardando o projeto ficar pronto"
STATUS=""
for _ in $(seq 1 60); do
  STATUS="$(curl -fsS "${AUTH[@]}" "$API/projects/$REF" | jq -r '.status')"
  [[ "$STATUS" == "ACTIVE_HEALTHY" ]] && break
  sleep 10
done
[[ "$STATUS" == "ACTIVE_HEALTHY" ]] || fail "Projeto não ficou pronto a tempo (status: $STATUS)."
ok "Projeto ativo"

say "Aplicando o banco completo"
supabase link --project-ref "$REF" -p "$DB_PASS" >/dev/null 2>&1 || fail "Falha ao vincular o projeto."
supabase db push -p "$DB_PASS" --include-all || fail "Falha ao aplicar as migrations."
ok "Banco e políticas aplicados"

say "Obtendo as chaves geradas pelo Supabase"
KEYS="$(curl -fsS "${AUTH[@]}" "$API/projects/$REF/api-keys")" || fail "Falha ao obter as chaves do projeto."
ANON="$(jq -r '.[] | select(.name=="anon") | .api_key' <<<"$KEYS" | head -1)"
SERVICE="$(jq -r '.[] | select(.name=="service_role") | .api_key' <<<"$KEYS" | head -1)"
[[ -n "$ANON" && "$ANON" != "null" ]] || fail "Chave anon não encontrada."
[[ -n "$SERVICE" && "$SERVICE" != "null" ]] || fail "Chave service_role não encontrada."

BOOKING_TOKEN="$(openssl rand -hex 32)"
GOOGLE_ADS_WEBHOOK_SECRET="$(openssl rand -hex 32)"
BREVO_WEBHOOK_SECRET="$(openssl rand -hex 32)"
META_VERIFY_TOKEN="$(openssl rand -hex 24)"

say "Configurando cofre, workers e links públicos"
# Modo SaaS (várias empresas no mesmo banco) é o padrão. MULTI_TENANT=false
# instala em modo empresa única (cadastro público fechado).
MULTI_TENANT="${MULTI_TENANT:-true}"
case "$MULTI_TENANT" in true|false) ;; *) fail "MULTI_TENANT deve ser true ou false." ;; esac
BOOTSTRAP_SQL="
INSERT INTO public.config (key,value) VALUES
  ('SUPABASE_PROJECT_URL','https://$REF.supabase.co'),
  ('multi_tenant_enabled','$MULTI_TENANT')
ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value;
INSERT INTO public.tenant_config_overrides (tenant_id,key,value) VALUES
  ('$DEFAULT_TENANT','BOOKING_PUBLIC_TOKEN','$BOOKING_TOKEN'),
  ('$DEFAULT_TENANT','GOOGLE_ADS_WEBHOOK_SECRET','$GOOGLE_ADS_WEBHOOK_SECRET')
ON CONFLICT (tenant_id,key) DO UPDATE SET value=EXCLUDED.value, updated_at=now();
SELECT vault.create_secret('https://$REF.supabase.co','supabase_url');
SELECT vault.create_secret('$SERVICE','service_role_key');"
management_query "$BOOTSTRAP_SQL" >/dev/null || fail "Falha ao configurar o cofre do projeto."

supabase secrets set --project-ref "$REF" \
  CRM_PUBLIC_URL="$CRM_PUBLIC_URL" \
  BREVO_WEBHOOK_SECRET="$BREVO_WEBHOOK_SECRET" \
  META_WEBHOOK_VERIFY_TOKEN="$META_VERIFY_TOKEN" >/dev/null \
  || fail "Falha ao configurar secrets das Edge Functions."
ok "Cofre e tokens configurados"

say "Deployando Edge Functions"
supabase functions deploy --project-ref "$REF" || fail "Falha no deploy das Edge Functions."
ok "Edge Functions publicadas"

if [[ "$MULTI_TENANT" == "true" ]]; then
  say "Habilitando cadastro self-service de empresas (modo SaaS) e criando o administrador"
  # Cadastro aberto: cada conta nova cria a própria empresa isolada via tenant_onboard
  # (exige e-mail confirmado — autoconfirm desligado).
  AUTH_PAYLOAD="$(jq -n --arg site "$CRM_PUBLIC_URL" '{"mailer_autoconfirm":false,"disable_signup":false,site_url:$site,uri_allow_list:($site+"/reset-password,"+$site+"/criar-empresa,http://localhost:8080/**") }')"
else
  say "Fechando cadastro público e criando o administrador"
  AUTH_PAYLOAD="$(jq -n --arg site "$CRM_PUBLIC_URL" '{"mailer_autoconfirm":true,"disable_signup":true,site_url:$site,uri_allow_list:($site+"/reset-password,http://localhost:8080/**") }')"
fi
curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" \
  -X PATCH "$API/projects/$REF/config/auth" -d "$AUTH_PAYLOAD" >/dev/null \
  || fail "Falha ao configurar o Auth."

if [[ -z "${ADMIN_EMAIL:-}" ]]; then read -r -p "E-mail do administrador: " ADMIN_EMAIL; fi
if [[ -z "${ADMIN_NAME:-}" ]]; then read -r -p "Nome do administrador: " ADMIN_NAME; fi
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "Senha do administrador (mínimo 12 caracteres): " ADMIN_PASSWORD
  printf "\n"
fi
[[ "$ADMIN_EMAIL" == *@*.* ]] || fail "E-mail do administrador inválido."
[[ "${#ADMIN_PASSWORD}" -ge 12 ]] || fail "A senha precisa ter pelo menos 12 caracteres."
[[ -n "$ADMIN_NAME" ]] || fail "Informe o nome do administrador."

ADMIN_PAYLOAD="$(jq -n --arg email "$ADMIN_EMAIL" --arg password "$ADMIN_PASSWORD" \
  --arg name "$ADMIN_NAME" --arg tenant "$DEFAULT_TENANT" \
  '{email:$email,password:$password,email_confirm:true,user_metadata:{name:$name},app_metadata:{tenant_id:$tenant}}')"
ADMIN_RESULT="$(curl -fsS "https://$REF.supabase.co/auth/v1/admin/users" \
  -H "Authorization: Bearer $SERVICE" -H "apikey: $SERVICE" \
  -H "Content-Type: application/json" -d "$ADMIN_PAYLOAD")" \
  || fail "Falha ao criar o usuário administrador."
ADMIN_ID="$(jq -r '.id // empty' <<<"$ADMIN_RESULT")"
[[ -n "$ADMIN_ID" ]] || fail "O Auth não retornou o ID do administrador."

ADMIN_EMAIL_B64="$(printf '%s' "$ADMIN_EMAIL" | base64 | tr -d '\n')"
ADMIN_NAME_B64="$(printf '%s' "$ADMIN_NAME" | base64 | tr -d '\n')"
ADMIN_SQL="
UPDATE public.tenants SET name=convert_from(decode('$ADMIN_NAME_B64','base64'),'UTF8'), updated_at=now()
 WHERE id='$DEFAULT_TENANT';
INSERT INTO public.team_members (tenant_id,email,name,role,is_active,auth_user_id,is_superadmin)
VALUES ('$DEFAULT_TENANT',convert_from(decode('$ADMIN_EMAIL_B64','base64'),'UTF8'),
  convert_from(decode('$ADMIN_NAME_B64','base64'),'UTF8'),'admin',true,'$ADMIN_ID',true)
ON CONFLICT (email,tenant_id) DO UPDATE SET auth_user_id=EXCLUDED.auth_user_id, role='admin',
  is_active=true, tenant_id=EXCLUDED.tenant_id, is_superadmin=true;"
management_query "$ADMIN_SQL" >/dev/null || fail "Falha ao vincular o administrador ao CRM."
if [[ "$MULTI_TENANT" == "true" ]]; then
  ok "Administrador da plataforma criado (superadmin); cadastro self-service de empresas ativo"
else
  ok "Administrador criado; cadastro público desativado"
fi

say "Gerando arquivos locais de ambiente"
umask 077
cat > .env <<EOF
VITE_SUPABASE_URL=https://$REF.supabase.co
VITE_SUPABASE_ANON_KEY=$ANON
VITE_APP_URL=$CRM_PUBLIC_URL
VITE_CRM_URL=$CRM_PUBLIC_URL
VITE_MCP_PUBLIC_URL=$CRM_PUBLIC_URL/mcp
VITE_BOOKING_PUBLIC_TOKEN=$BOOKING_TOKEN
VITE_COCKPIT_V2=true
EOF
cat > .env.local <<EOF
# Arquivo privado — não commitar
SUPABASE_PROJECT_REF=$REF
SUPABASE_DB_PASSWORD=$DB_PASS
EOF
cat > .env.hosting <<EOF
# Privado. Copie as variáveis para a hospedagem. Nunca envie este arquivo ao Git.
SUPABASE_URL=https://$REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=$ANON
MCP_PUBLIC_URL=$CRM_PUBLIC_URL/mcp
MCP_DYNAMIC_CLIENTS=true
EOF
ok "Ambiente local criado com permissão restrita"

say "Instalando dependências de forma reproduzível"
npm ci --no-audit --no-fund || fail "npm ci falhou."
npm --prefix mcp-server ci --no-audit --no-fund || fail "Dependências MCP falharam."
ok "Dependências instaladas"
touch .setup-complete
warn "Finalize a publicação e o OAuth seguindo docs/PUBLICAR_E_CONECTAR_MCP.md antes de conectar sua IA."

say "Validando a instalação"
HC="$(curl -fsS -X POST "https://$REF.supabase.co/functions/v1/health-check" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $SERVICE" \
  -H "apikey: $SERVICE" -d '{}' | jq -r '.status // empty')" || true
[[ "$HC" == "healthy" ]] && ok "Health check aprovado" || warn "Health check retornou '${HC:-indisponível}'. Revise as integrações na UI."

printf "\n\033[1;32m============================================\033[0m\n"
printf "\033[1;32m  ✅ CRM INSTALADO COM SEGURANÇA\033[0m\n"
printf "\033[1;32m============================================\033[0m\n\n"
printf "  1. Rode: npm run dev\n"
printf "  2. Entre com: %s\n" "$ADMIN_EMAIL"
printf "  3. Configure Anthropic/Gemini e demais integrações na área administrativa.\n"
printf "  4. URL pública de agenda da sua empresa: %s/agendar/%s\n" "$CRM_PUBLIC_URL" "$BOOKING_TOKEN"
if [[ "$MULTI_TENANT" == "true" ]]; then
  printf "  5. Modo SaaS ativo: novas empresas se cadastram em %s/login?cadastro=1\n" "$CRM_PUBLIC_URL"
  printf "     Gerencie empresas em %s/superadmin/empresas (leia docs/MULTITENANT.md).\n" "$CRM_PUBLIC_URL"
fi
printf "\n  Guarde o arquivo .env.local em local seguro.\n\n"

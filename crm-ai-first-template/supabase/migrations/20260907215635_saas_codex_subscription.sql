BEGIN;
ALTER TABLE saas_ai.settings DROP CONSTRAINT settings_provider_check;
ALTER TABLE saas_ai.settings ADD CONSTRAINT settings_provider_check CHECK(provider IN ('openai_api','anthropic_api','openai_codex'));
CREATE FUNCTION saas_ai.normalize_codex(p_auth jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE a jsonb;BEGIN
 IF jsonb_typeof(p_auth) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Sessão Codex inválida' USING ERRCODE='22023';END IF;
 a:=coalesce(p_auth->'tokens',p_auth);
 IF jsonb_typeof(a->'access_token') IS DISTINCT FROM 'string' OR length(a->>'access_token') NOT BETWEEN 20 AND 20000 OR jsonb_typeof(a->'account_id') IS DISTINCT FROM 'string' OR length(a->>'account_id') NOT BETWEEN 1 AND 200 OR jsonb_typeof(a->'refresh_token') IS DISTINCT FROM 'string' OR length(a->>'refresh_token') NOT BETWEEN 10 AND 10000 THEN RAISE EXCEPTION 'A sessão precisa de access_token, refresh_token e account_id' USING ERRCODE='22023';END IF;
 RETURN jsonb_strip_nulls(jsonb_build_object('access_token',a->>'access_token','refresh_token',a->>'refresh_token','account_id',a->>'account_id','expires_at',a->'expires_at'));
END $$;
REVOKE ALL ON FUNCTION saas_ai.normalize_codex(jsonb) FROM PUBLIC,anon,authenticated;
CREATE TABLE saas_ai.refresh_lease(secret_id uuid PRIMARY KEY,owner uuid NOT NULL,expires_at timestamptz NOT NULL);
ALTER TABLE saas_ai.refresh_lease ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON saas_ai.refresh_lease FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.saas_ai_own_credential(p_credential_id uuid DEFAULT NULL,p_model text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid:=public.get_tenant_id(); BEGIN
 IF tid IS NULL OR NOT public.is_admin() OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501'; END IF;
 IF p_credential_id IS NOT NULL AND (nullif(btrim(p_model),'') IS NULL OR length(p_model)>200 OR NOT EXISTS(SELECT 1 FROM public.agents_provider_credentials WHERE id=p_credential_id AND tenant_id=tid AND is_active AND provider_type IN ('openai_api','anthropic_api','openai_codex'))) THEN RAISE EXCEPTION 'Credencial própria ou modelo inválido' USING ERRCODE='22023'; END IF;
 INSERT INTO saas_ai.tenants(tenant_id,credential_id,model) VALUES(tid,p_credential_id,p_model) ON CONFLICT(tenant_id) DO UPDATE SET credential_id=excluded.credential_id,model=excluded.model,updated_at=now();
END $$;
CREATE OR REPLACE FUNCTION public.saas_ai_admin(p_action text DEFAULT 'get',p_tenant_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s saas_ai.settings%ROWTYPE; secret uuid; result jsonb; auth_data jsonb; secret_value text; next_provider text; BEGIN
 IF NOT saas_ai.is_superadmin() THEN RAISE EXCEPTION 'Somente superadmin do SaaS' USING ERRCODE='42501'; END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>50000 THEN RAISE EXCEPTION 'Dados inválidos' USING ERRCODE='22023'; END IF;
 SELECT * INTO s FROM saas_ai.settings FOR UPDATE;
 IF p_action='settings' THEN
  IF p_data-ARRAY['enabled','auto_enroll','trial_days','daily_calls','provider','model','api_key','codex_auth','max_output_tokens']<>'{}'::jsonb THEN RAISE EXCEPTION 'Campo inválido' USING ERRCODE='22023'; END IF;
  next_provider:=coalesce(p_data->>'provider',s.provider);
  IF next_provider='openai_codex' THEN
   IF p_data?'api_key' THEN RAISE EXCEPTION 'Use a sessão Codex, não api_key' USING ERRCODE='22023'; END IF;
   IF p_data?'codex_auth' THEN
    auth_data:=saas_ai.normalize_codex(p_data->'codex_auth');secret_value:=auth_data::text;
   END IF;
  ELSE
   IF p_data?'codex_auth' THEN RAISE EXCEPTION 'Sessão Codex requer provedor de assinatura' USING ERRCODE='22023'; END IF;
   secret_value:=nullif(p_data->>'api_key','');
   IF secret_value IS NOT NULL AND length(secret_value) NOT BETWEEN 20 AND 10000 THEN RAISE EXCEPTION 'Chave inválida' USING ERRCODE='22023'; END IF;
  END IF;
  IF next_provider<>s.provider AND secret_value IS NULL THEN RAISE EXCEPTION 'Informe a credencial do novo provedor' USING ERRCODE='22023'; END IF;
  IF secret_value IS NOT NULL THEN
   -- A replacement gets its own ID so an in-flight refresh cannot overwrite it.
   SELECT vault.create_secret(secret_value) INTO secret;
   IF s.secret_id IS NOT NULL THEN DELETE FROM vault.secrets WHERE id=s.secret_id; END IF;
  ELSE secret:=s.secret_id; END IF;
  UPDATE saas_ai.settings SET enabled=coalesce((p_data->>'enabled')::boolean,enabled),auto_enroll=coalesce((p_data->>'auto_enroll')::boolean,auto_enroll),trial_days=coalesce((p_data->>'trial_days')::integer,trial_days),daily_calls=coalesce((p_data->>'daily_calls')::integer,daily_calls),provider=coalesce(p_data->>'provider',provider),model=coalesce(p_data->>'model',model),max_output_tokens=coalesce((p_data->>'max_output_tokens')::integer,max_output_tokens),secret_id=secret;
  SELECT * INTO s FROM saas_ai.settings;
  IF s.enabled AND (s.secret_id IS NULL OR nullif(btrim(s.model),'') IS NULL OR length(s.model)>200) THEN RAISE EXCEPTION 'Cadastre chave e modelo antes de ativar' USING ERRCODE='22023'; END IF;
 ELSIF p_action='tenant' THEN
  IF NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=p_tenant_id) OR p_data-ARRAY['enabled','expires_at','daily_calls']<>'{}'::jsonb THEN RAISE EXCEPTION 'Empresa ou campos inválidos' USING ERRCODE='22023'; END IF;
  INSERT INTO saas_ai.tenants(tenant_id) VALUES(p_tenant_id) ON CONFLICT DO NOTHING;
  UPDATE saas_ai.tenants SET enabled=coalesce((p_data->>'enabled')::boolean,enabled),expires_at=CASE WHEN p_data?'expires_at' THEN (p_data->>'expires_at')::timestamptz ELSE expires_at END,daily_calls=coalesce((p_data->>'daily_calls')::integer,daily_calls),updated_at=now() WHERE tenant_id=p_tenant_id;
  IF EXISTS(SELECT 1 FROM saas_ai.tenants WHERE tenant_id=p_tenant_id AND enabled AND expires_at IS NULL) THEN RAISE EXCEPTION 'Defina validade do benefício' USING ERRCODE='22023'; END IF;
 ELSIF p_action<>'get' THEN RAISE EXCEPTION 'Ação inválida' USING ERRCODE='22023'; END IF;
 SELECT coalesce(jsonb_agg(x),'[]') INTO result FROM (SELECT t.id,t.name,t.is_active,coalesce(g.enabled,false) enabled,g.expires_at,coalesce(g.daily_calls,s.daily_calls) daily_calls,g.credential_id,(SELECT count(*) FROM saas_ai.calls c WHERE c.tenant_id=t.id AND c.created_at>=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC') used_today,(SELECT coalesce(sum(input_tokens+output_tokens),0) FROM saas_ai.calls c WHERE c.tenant_id=t.id) tokens_total FROM public.tenants t LEFT JOIN saas_ai.tenants g ON g.tenant_id=t.id ORDER BY t.name LIMIT 1000) x;
 RETURN jsonb_build_object('settings',to_jsonb(s)-'secret_id'||jsonb_build_object('key_configured',s.secret_id IS NOT NULL),'tenants',result);
END $$;
CREATE OR REPLACE FUNCTION public.saas_ai_resolve(p_agent_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a public.agents_registry%ROWTYPE; c public.agents_provider_credentials%ROWTYPE; s saas_ai.settings%ROWTYPE; t saas_ai.tenants%ROWTYPE; cid uuid; call_id uuid; used bigint; key text;
BEGIN
 SELECT * INTO a FROM public.agents_registry WHERE id=p_agent_id;
 IF NOT FOUND OR a.tenant_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=a.tenant_id AND is_active) THEN RAISE EXCEPTION 'Empresa inativa' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM saas_ai.tenants WHERE tenant_id=a.tenant_id;
 cid:=coalesce(a.credential_id,t.credential_id);
 IF cid IS NOT NULL THEN
  SELECT * INTO c FROM public.agents_provider_credentials WHERE id=cid AND tenant_id=a.tenant_id AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Credencial própria inativa ou inválida. Corrija em Credenciais.' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('source','own','credential',to_jsonb(c),'model',CASE WHEN a.credential_id IS NULL THEN t.model ELSE a.model END);
 END IF;
 SELECT * INTO s FROM saas_ai.settings;
 IF NOT s.enabled OR s.secret_id IS NULL OR t.tenant_id IS NULL OR NOT t.enabled OR t.expires_at IS NULL OR t.expires_at<=now() THEN RAISE EXCEPTION 'IA patrocinada indisponível. Cadastre uma chave própria em Credenciais.' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('saas-ai:'||a.tenant_id::text,0));
 SELECT count(*) INTO used FROM saas_ai.calls WHERE tenant_id=a.tenant_id AND created_at>=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
 IF used>=t.daily_calls THEN RAISE EXCEPTION 'Limite diário de IA patrocinada atingido. Use uma chave própria ou aguarde a renovação UTC.' USING ERRCODE='42501'; END IF;
 SELECT decrypted_secret INTO key FROM vault.decrypted_secrets WHERE id=s.secret_id;
 IF nullif(key,'') IS NULL THEN RAISE EXCEPTION 'Chave global indisponível' USING ERRCODE='42501'; END IF;
 INSERT INTO saas_ai.calls(tenant_id,agent_id) VALUES(a.tenant_id,a.id) RETURNING id INTO call_id;
 RETURN jsonb_build_object('source','sponsored','call_id',call_id,'model',s.model,'max_output_tokens',s.max_output_tokens,'credential',jsonb_build_object('id',s.secret_id,'provider_type',s.provider,'auth_data',CASE WHEN s.provider='openai_codex' THEN key::jsonb ELSE jsonb_build_object('api_key',key) END,'metadata',jsonb_build_object('saas_global',true)));
END $$;

CREATE FUNCTION public.saas_codex_refresh(p_secret_id uuid,p_owner uuid,p_action text,p_auth jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s saas_ai.settings%ROWTYPE; a jsonb; lease saas_ai.refresh_lease%ROWTYPE;
BEGIN
 SELECT * INTO s FROM saas_ai.settings FOR UPDATE;
 IF s.secret_id IS DISTINCT FROM p_secret_id OR s.provider<>'openai_codex' OR NOT s.enabled THEN RAISE EXCEPTION 'Sessão global substituída ou desativada' USING ERRCODE='42501';END IF;
 IF p_owner IS NULL THEN RAISE EXCEPTION 'Identificador obrigatório' USING ERRCODE='22023';END IF;
 SELECT decrypted_secret::jsonb INTO a FROM vault.decrypted_secrets WHERE id=p_secret_id;
 IF p_action='acquire' THEN
  SELECT * INTO lease FROM saas_ai.refresh_lease WHERE secret_id=p_secret_id;
  IF lease.secret_id IS NOT NULL AND lease.expires_at>now() AND lease.owner<>p_owner THEN RETURN jsonb_build_object('acquired',false);END IF;
  INSERT INTO saas_ai.refresh_lease VALUES(p_secret_id,p_owner,now()+interval '30 seconds') ON CONFLICT(secret_id) DO UPDATE SET owner=excluded.owner,expires_at=excluded.expires_at;
  RETURN jsonb_build_object('acquired',true,'auth',a);
 ELSIF p_action='save' THEN
  IF NOT EXISTS(SELECT 1 FROM saas_ai.refresh_lease WHERE secret_id=p_secret_id AND owner=p_owner AND expires_at>now()) THEN RAISE EXCEPTION 'Renovação perdeu exclusividade' USING ERRCODE='42501';END IF;
  IF a->>'account_id' IS DISTINCT FROM p_auth->>'account_id' THEN RAISE EXCEPTION 'Conta diferente' USING ERRCODE='42501';END IF;
  PERFORM vault.update_secret(p_secret_id,saas_ai.normalize_codex(p_auth)::text);
 ELSIF p_action<>'release' THEN RAISE EXCEPTION 'Ação inválida' USING ERRCODE='22023'; END IF;
 DELETE FROM saas_ai.refresh_lease WHERE secret_id=p_secret_id AND owner=p_owner;
 RETURN jsonb_build_object('ok',true);
END $$;
REVOKE ALL ON FUNCTION public.saas_codex_refresh(uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.saas_codex_refresh(uuid,uuid,text,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

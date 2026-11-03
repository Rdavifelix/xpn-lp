BEGIN;
CREATE SCHEMA saas_ai;
REVOKE ALL ON SCHEMA saas_ai FROM PUBLIC,anon,authenticated;
CREATE TABLE saas_ai.settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),enabled boolean NOT NULL DEFAULT false,auto_enroll boolean NOT NULL DEFAULT false,trial_days integer NOT NULL DEFAULT 7 CHECK(trial_days BETWEEN 1 AND 365),daily_calls integer NOT NULL DEFAULT 100 CHECK(daily_calls BETWEEN 1 AND 100000),provider text NOT NULL DEFAULT 'openai_api' CHECK(provider IN ('openai_api','anthropic_api')),model text NOT NULL DEFAULT '',secret_id uuid,max_output_tokens integer NOT NULL DEFAULT 2048 CHECK(max_output_tokens BETWEEN 128 AND 16000));
INSERT INTO saas_ai.settings DEFAULT VALUES;
CREATE TABLE saas_ai.tenants(tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id),enabled boolean NOT NULL DEFAULT false,expires_at timestamptz,daily_calls integer NOT NULL DEFAULT 100 CHECK(daily_calls BETWEEN 1 AND 100000),credential_id uuid REFERENCES public.agents_provider_credentials(id),model text,updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE saas_ai.calls(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES public.tenants(id),agent_id uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),finished_at timestamptz,input_tokens bigint NOT NULL DEFAULT 0,output_tokens bigint NOT NULL DEFAULT 0,success boolean);
CREATE INDEX ON saas_ai.calls(tenant_id,created_at);
ALTER TABLE saas_ai.settings ENABLE ROW LEVEL SECURITY; ALTER TABLE saas_ai.tenants ENABLE ROW LEVEL SECURITY; ALTER TABLE saas_ai.calls ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA saas_ai FROM PUBLIC,anon,authenticated;
CREATE FUNCTION saas_ai.is_superadmin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT auth.uid() IS NOT NULL AND public.get_tenant_id() IS NOT NULL AND nullif(auth.jwt()->>'client_id','') IS NULL AND EXISTS(SELECT 1 FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=public.get_tenant_id() AND is_active AND is_superadmin); $$;
REVOKE ALL ON FUNCTION saas_ai.is_superadmin() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION saas_ai.enroll() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE s saas_ai.settings%ROWTYPE; BEGIN SELECT * INTO s FROM saas_ai.settings; IF s.auto_enroll THEN INSERT INTO saas_ai.tenants(tenant_id,enabled,expires_at,daily_calls) VALUES(NEW.id,true,now()+make_interval(days=>s.trial_days),s.daily_calls) ON CONFLICT DO NOTHING; END IF; RETURN NEW; END $$;
REVOKE ALL ON FUNCTION saas_ai.enroll() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER saas_ai_enroll AFTER INSERT ON public.tenants FOR EACH ROW EXECUTE FUNCTION saas_ai.enroll();
CREATE FUNCTION public.saas_ai_status() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid:=public.get_tenant_id(); s saas_ai.settings%ROWTYPE; t saas_ai.tenants%ROWTYPE; used bigint;
BEGIN
 IF tid IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN RAISE EXCEPTION 'Acesso recusado' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM saas_ai.settings; SELECT * INTO t FROM saas_ai.tenants WHERE tenant_id=tid;
 SELECT count(*) INTO used FROM saas_ai.calls WHERE tenant_id=tid AND created_at>=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
 RETURN jsonb_build_object('is_superadmin',saas_ai.is_superadmin(),'enabled',coalesce(s.enabled AND s.secret_id IS NOT NULL AND t.enabled AND t.expires_at>now() AND used<t.daily_calls,false),'expires_at',t.expires_at,'daily_calls',t.daily_calls,'used_today',used,'provider',s.provider,'model',s.model,'credential_id',t.credential_id,'own_model',t.model);
END $$;
CREATE FUNCTION public.saas_ai_own_credential(p_credential_id uuid DEFAULT NULL,p_model text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid:=public.get_tenant_id(); BEGIN
 IF tid IS NULL OR NOT public.is_admin() OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501'; END IF;
 IF p_credential_id IS NOT NULL AND (nullif(btrim(p_model),'') IS NULL OR length(p_model)>200 OR NOT EXISTS(SELECT 1 FROM public.agents_provider_credentials WHERE id=p_credential_id AND tenant_id=tid AND is_active AND provider_type IN ('openai_api','anthropic_api'))) THEN RAISE EXCEPTION 'Credencial própria ou modelo inválido' USING ERRCODE='22023'; END IF;
 INSERT INTO saas_ai.tenants(tenant_id,credential_id,model) VALUES(tid,p_credential_id,p_model) ON CONFLICT(tenant_id) DO UPDATE SET credential_id=excluded.credential_id,model=excluded.model,updated_at=now();
END $$;
CREATE FUNCTION public.saas_ai_admin(p_action text DEFAULT 'get',p_tenant_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s saas_ai.settings%ROWTYPE; secret uuid; result jsonb; BEGIN
 IF NOT saas_ai.is_superadmin() THEN RAISE EXCEPTION 'Somente superadmin do SaaS' USING ERRCODE='42501'; END IF;
 IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR octet_length(p_data::text)>12000 THEN RAISE EXCEPTION 'Dados inválidos' USING ERRCODE='22023'; END IF;
 SELECT * INTO s FROM saas_ai.settings FOR UPDATE;
 IF p_action='settings' THEN
  IF p_data-ARRAY['enabled','auto_enroll','trial_days','daily_calls','provider','model','api_key','max_output_tokens']<>'{}'::jsonb THEN RAISE EXCEPTION 'Campo inválido' USING ERRCODE='22023'; END IF;
  IF nullif(p_data->>'api_key','') IS NOT NULL THEN
   IF length(p_data->>'api_key') NOT BETWEEN 20 AND 10000 THEN RAISE EXCEPTION 'Chave inválida' USING ERRCODE='22023'; END IF;
   IF s.secret_id IS NULL THEN SELECT vault.create_secret(p_data->>'api_key') INTO secret; ELSE PERFORM vault.update_secret(s.secret_id,p_data->>'api_key');secret:=s.secret_id; END IF;
  ELSE secret:=s.secret_id; END IF;
  IF p_data?'provider' AND p_data->>'provider'<>s.provider AND nullif(p_data->>'api_key','') IS NULL THEN RAISE EXCEPTION 'Informe a chave do novo provedor' USING ERRCODE='22023'; END IF;
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
CREATE FUNCTION public.saas_ai_resolve(p_agent_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
 RETURN jsonb_build_object('source','sponsored','call_id',call_id,'model',s.model,'max_output_tokens',s.max_output_tokens,'credential',jsonb_build_object('id',s.secret_id,'provider_type',s.provider,'auth_data',jsonb_build_object('api_key',key)));
END $$;
CREATE FUNCTION public.saas_ai_finish(p_call_id uuid,p_success boolean,p_input_tokens bigint DEFAULT 0,p_output_tokens bigint DEFAULT 0) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ UPDATE saas_ai.calls SET finished_at=now(),success=p_success,input_tokens=greatest(0,p_input_tokens),output_tokens=greatest(0,p_output_tokens) WHERE id=p_call_id AND finished_at IS NULL; $$;
REVOKE ALL ON FUNCTION public.saas_ai_resolve(uuid),public.saas_ai_finish(uuid,boolean,bigint,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.saas_ai_resolve(uuid),public.saas_ai_finish(uuid,boolean,bigint,bigint) TO service_role;
REVOKE ALL ON FUNCTION public.saas_ai_status(),public.saas_ai_own_credential(uuid,text),public.saas_ai_admin(text,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.saas_ai_status(),public.saas_ai_own_credential(uuid,text),public.saas_ai_admin(text,uuid,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

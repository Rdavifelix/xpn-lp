BEGIN;
ALTER TABLE saas_ai.calls ALTER COLUMN agent_id DROP NOT NULL;
ALTER TABLE saas_ai.calls ADD COLUMN purpose text NOT NULL DEFAULT 'agent';
CREATE FUNCTION public.saas_ai_resolve_analysis(p_tenant uuid,p_user uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.agents_provider_credentials%ROWTYPE; s saas_ai.settings%ROWTYPE; t saas_ai.tenants%ROWTYPE; cid uuid; call_id uuid; used bigint; key text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=p_tenant AND is_active) OR NOT EXISTS(SELECT 1 FROM public.team_members WHERE tenant_id=p_tenant AND auth_user_id=p_user AND is_active) THEN RAISE EXCEPTION 'Empresa ou usuário inativo' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM saas_ai.tenants WHERE tenant_id=p_tenant;
 cid:=t.credential_id;
 IF cid IS NOT NULL THEN
  SELECT * INTO c FROM public.agents_provider_credentials WHERE id=cid AND tenant_id=p_tenant AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Credencial própria inativa ou inválida. Corrija em Credenciais.' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('source','own','credential',to_jsonb(c),'model',t.model);
 END IF;
 SELECT * INTO s FROM saas_ai.settings;
 IF NOT s.enabled OR s.secret_id IS NULL OR t.tenant_id IS NULL OR NOT t.enabled OR t.expires_at IS NULL OR t.expires_at<=now() THEN RAISE EXCEPTION 'IA patrocinada indisponível. Cadastre uma chave própria em Credenciais.' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('saas-ai:'||p_tenant::text,0));
 SELECT count(*) INTO used FROM saas_ai.calls WHERE tenant_id=p_tenant AND created_at>=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
 IF used>=t.daily_calls THEN RAISE EXCEPTION 'Limite diário de IA patrocinada atingido. Use uma chave própria ou aguarde a renovação UTC.' USING ERRCODE='42501'; END IF;
 SELECT decrypted_secret INTO key FROM vault.decrypted_secrets WHERE id=s.secret_id;
 IF nullif(key,'') IS NULL THEN RAISE EXCEPTION 'Chave global indisponível' USING ERRCODE='42501'; END IF;
 INSERT INTO saas_ai.calls(tenant_id,agent_id,purpose) VALUES(p_tenant,NULL,'call_analysis') RETURNING id INTO call_id;
 RETURN jsonb_build_object('source','sponsored','call_id',call_id,'model',s.model,'max_output_tokens',s.max_output_tokens,'credential',jsonb_build_object('id',s.secret_id,'provider_type',s.provider,'auth_data',CASE WHEN s.provider='openai_codex' THEN key::jsonb ELSE jsonb_build_object('api_key',key) END,'metadata',jsonb_build_object('saas_global',true)));
END $$;

REVOKE ALL ON FUNCTION public.saas_ai_resolve_analysis(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.saas_ai_resolve_analysis(uuid,uuid) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

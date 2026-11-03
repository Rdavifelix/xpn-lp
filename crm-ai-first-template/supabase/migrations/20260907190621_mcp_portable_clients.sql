BEGIN;
-- Registration is not a brand endorsement. Access requires user consent,
-- a valid OAuth session, the MCP audience and an active tenant membership.
CREATE FUNCTION crm_mcp.valid_redirect(uri text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE authority text; port text;
BEGIN
 IF uri IS NULL OR uri ~ '[[:space:][:cntrl:]\\#]' THEN RETURN false; END IF;
 IF uri !~ '^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?([/?]|$)'
    AND uri !~ '^http://(127[.]0[.]0[.]1|localhost|\[::1\])(:[0-9]{1,5})?([/?]|$)' THEN RETURN false; END IF;
 authority := substring(uri FROM '^https?://([^/?]+)');
 port := substring(authority FROM ':([0-9]+)$');
 RETURN port IS NULL OR port::integer BETWEEN 1 AND 65535;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.valid_redirect(text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION crm_mcp.resolve_client(p_client_id text)
RETURNS crm_mcp.clients LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE approved crm_mcp.clients%ROWTYPE; oauth record; cfg crm_mcp.settings%ROWTYPE; uri text;
BEGIN
 SELECT * INTO approved FROM crm_mcp.clients WHERE client_id=p_client_id;
 IF FOUND THEN RETURN approved; END IF;
 SELECT * INTO cfg FROM crm_mcp.settings WHERE singleton AND dynamic_clients_enabled;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT * INTO oauth FROM auth.oauth_clients WHERE id::text=p_client_id AND deleted_at IS NULL
  AND client_type::text='public' AND registration_type::text='dynamic' AND token_endpoint_auth_method='none';
 IF NOT FOUND OR coalesce(oauth.redirect_uris,'')='' THEN RETURN NULL; END IF;
 FOREACH uri IN ARRAY string_to_array(oauth.redirect_uris,',') LOOP
  IF NOT crm_mcp.valid_redirect(uri) THEN RETURN NULL; END IF;
 END LOOP;
 RETURN (p_client_id,cfg.resource,true,true)::crm_mcp.clients;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.resolve_client(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.mcp_authorization_info(p_client_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid := public.get_tenant_id(); v_info jsonb;
BEGIN
  IF v_tenant IS NULL OR auth.uid() IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'Entre com uma conta vinculada ao CRM' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM crm_mcp.resolve_client(p_client_id) WHERE is_active) THEN
    RAISE EXCEPTION 'Este aplicativo está bloqueado ou possui um endereço de retorno inválido.' USING ERRCODE='42501'; END IF;
  SELECT jsonb_build_object('tenant_name', t.name, 'can_write', m.role = 'admin' AND c.can_write)
    INTO v_info FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id
    CROSS JOIN crm_mcp.resolve_client(p_client_id) c
    WHERE m.auth_user_id=auth.uid() AND m.tenant_id=v_tenant AND m.is_active AND t.is_active
      AND c.client_id=p_client_id AND c.is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sua conta não possui um vínculo ativo com esta empresa.' USING ERRCODE='42501'; END IF;
  RETURN v_info;
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_authorization_info(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mcp_authorization_info(text) TO authenticated;


COMMIT;

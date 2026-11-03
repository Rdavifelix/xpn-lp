BEGIN;
-- Supabase authenticates confidential clients during token exchange.
-- Preserve consent, redirect validation, revocation and tenant authorization.
CREATE OR REPLACE FUNCTION crm_mcp.resolve_client(p_client_id text)
RETURNS crm_mcp.clients LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE approved crm_mcp.clients%ROWTYPE; oauth record; cfg crm_mcp.settings%ROWTYPE; uri text;
BEGIN
 SELECT * INTO approved FROM crm_mcp.clients WHERE client_id=p_client_id;
 IF FOUND THEN RETURN approved; END IF;
 SELECT * INTO cfg FROM crm_mcp.settings WHERE singleton AND dynamic_clients_enabled;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT * INTO oauth FROM auth.oauth_clients WHERE id::text=p_client_id AND deleted_at IS NULL
  AND registration_type::text='dynamic'
  AND ((client_type::text='public' AND token_endpoint_auth_method='none')
    OR (client_type::text='confidential' AND token_endpoint_auth_method IN ('client_secret_post','client_secret_basic')));
 IF NOT FOUND OR coalesce(oauth.redirect_uris,'')='' THEN RETURN NULL; END IF;
 FOREACH uri IN ARRAY string_to_array(oauth.redirect_uris,',') LOOP
  IF NOT crm_mcp.valid_redirect(uri) THEN RETURN NULL; END IF;
 END LOOP;
 RETURN (p_client_id,cfg.resource,true,true)::crm_mcp.clients;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.resolve_client(text) FROM PUBLIC,anon,authenticated;


NOTIFY pgrst,'reload schema';
COMMIT;

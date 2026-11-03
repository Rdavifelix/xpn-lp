BEGIN;
CREATE TABLE crm_mcp.settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),resource text NOT NULL CHECK(resource ~ '^https://[^?#]+/mcp$'),dynamic_clients_enabled boolean NOT NULL DEFAULT false);
ALTER TABLE crm_mcp.settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON crm_mcp.settings FROM PUBLIC,anon,authenticated;
CREATE FUNCTION crm_mcp.resolve_client(p_client_id text)
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
  IF uri NOT IN ('https://claude.ai/api/mcp/auth_callback','https://chatgpt.com/connector_platform_oauth_redirect')
   AND uri !~ '^https://chatgpt[.]com/connector/oauth/[A-Za-z0-9_-]+$' THEN RETURN NULL; END IF;
 END LOOP;
 RETURN (p_client_id,cfg.resource,true,true)::crm_mcp.clients;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.resolve_client(text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION crm_mcp.context()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid := public.get_tenant_id(); v_member record; v_client record;
BEGIN
  IF auth.uid() IS NULL OR v_tenant IS NULL THEN RAISE EXCEPTION 'Empresa não provisionada' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.sessions WHERE id::text = auth.jwt()->>'session_id' AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Sessão revogada' USING ERRCODE = '42501'; END IF;
  SELECT * INTO v_client FROM crm_mcp.resolve_client(auth.jwt()->>'client_id')
    WHERE is_active
      AND to_jsonb(resource) = auth.jwt()->'aud';
  IF NOT FOUND THEN RAISE EXCEPTION 'Cliente MCP não autorizado' USING ERRCODE = '42501'; END IF;
  SELECT m.id, m.role, t.name INTO STRICT v_member
    FROM public.team_members m JOIN public.tenants t ON t.id = m.tenant_id
    WHERE m.auth_user_id = auth.uid() AND m.tenant_id = v_tenant AND m.is_active AND t.is_active;
  RETURN jsonb_build_object('user_id', auth.uid(), 'tenant_id', v_tenant,
    'member_id', v_member.id, 'tenant_name', v_member.name, 'role', v_member.role,
    'can_write', v_member.role = 'admin' AND v_client.can_write);
END;
$$;
CREATE OR REPLACE FUNCTION public.mcp_authorization_info(p_client_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid := public.get_tenant_id(); v_info jsonb;
BEGIN
  IF v_tenant IS NULL OR auth.uid() IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'Entre com uma conta vinculada ao CRM' USING ERRCODE = '42501'; END IF;
  SELECT jsonb_build_object('tenant_name', t.name, 'can_write', m.role = 'admin' AND c.can_write)
    INTO STRICT v_info FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id
    CROSS JOIN crm_mcp.resolve_client(p_client_id) c
    WHERE m.auth_user_id=auth.uid() AND m.tenant_id=v_tenant AND m.is_active AND t.is_active
      AND c.client_id=p_client_id AND c.is_active;
  RETURN v_info;
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_authorization_info(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mcp_authorization_info(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mcp_access_token_hook(event jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE claims jsonb := event->'claims'; v_resource text;
  v_client text := coalesce(nullif(event->>'client_id',''),nullif(event->'claims'->>'client_id','')); 
BEGIN
  IF v_client IS NOT NULL THEN
    SELECT resource INTO v_resource FROM crm_mcp.resolve_client(v_client)
      WHERE is_active;
    IF v_resource IS NOT NULL THEN
      claims := jsonb_set(claims, '{aud}', to_jsonb(v_resource));
      claims := jsonb_set(claims, '{client_id}', to_jsonb(v_client));
    END IF;
  END IF;
  RETURN jsonb_build_object('claims', claims);
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_access_token_hook(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mcp_access_token_hook(jsonb) TO supabase_auth_admin;

COMMIT;
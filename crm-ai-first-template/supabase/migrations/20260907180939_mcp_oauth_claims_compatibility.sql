BEGIN;
CREATE OR REPLACE FUNCTION public.mcp_access_token_hook(event jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE claims jsonb := event->'claims'; v_resource text;
  v_client text := coalesce(nullif(event->>'client_id',''),nullif(event->'claims'->>'client_id','')); 
BEGIN
  IF v_client IS NOT NULL THEN
    SELECT resource INTO v_resource FROM crm_mcp.clients
      WHERE client_id = v_client AND is_active;
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

BEGIN;
CREATE OR REPLACE FUNCTION public.mcp_authorization_info(p_client_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_tenant uuid := public.get_tenant_id(); v_info jsonb;
BEGIN
  IF v_tenant IS NULL OR auth.uid() IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    RAISE EXCEPTION 'Entre com uma conta vinculada ao CRM' USING ERRCODE = '42501'; END IF;
  SELECT jsonb_build_object('tenant_name', t.name, 'can_write', m.role = 'admin' AND c.can_write)
    INTO v_info FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id
    CROSS JOIN crm_mcp.resolve_client(p_client_id) c
    WHERE m.auth_user_id=auth.uid() AND m.tenant_id=v_tenant AND m.is_active AND t.is_active
      AND c.client_id=p_client_id AND c.is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Cliente OAuth não permitido para esta empresa' USING ERRCODE='42501'; END IF;
  RETURN v_info;
END;
$$;
REVOKE ALL ON FUNCTION public.mcp_authorization_info(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mcp_authorization_info(text) TO authenticated;

COMMIT;
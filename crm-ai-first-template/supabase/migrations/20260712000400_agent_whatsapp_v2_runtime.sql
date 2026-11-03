-- WhatsApp Agent Platform V2 runtime hardening.
-- - tenant-scoped router flag using the existing config override architecture
-- - admin-only toggle RPCs
-- - route lookup resolved from the WhatsApp instance tenant

CREATE OR REPLACE FUNCTION public.agent_get_router_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid := public.get_tenant_id();
  v_raw text;
  v_value jsonb;
BEGIN
  SELECT tco.value INTO v_raw
    FROM public.tenant_config_overrides tco
   WHERE tco.tenant_id = v_tenant
     AND tco.key = 'agent_platform_v2_enabled';

  IF v_raw IS NULL THEN
    SELECT c.value INTO v_raw
      FROM public.config c
     WHERE c.key = 'agent_platform_v2_enabled';
  END IF;

  BEGIN
    v_value := COALESCE(NULLIF(v_raw, '')::jsonb, '{"enabled":false}'::jsonb);
  EXCEPTION WHEN OTHERS THEN
    v_value := jsonb_build_object('enabled', lower(COALESCE(v_raw, 'false')) = 'true');
  END;

  IF jsonb_typeof(v_value) = 'boolean' THEN
    v_value := jsonb_build_object('enabled', v_value::text::boolean);
  END IF;

  RETURN jsonb_build_object(
    'enabled', COALESCE((v_value->>'enabled')::boolean, false),
    'updated_at', v_value->>'updated_at',
    'updated_by', v_value->>'updated_by'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.agent_set_router_enabled(p_enabled boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid := public.get_tenant_id();
  v_member uuid;
  v_value jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin required' USING ERRCODE = '42501';
  END IF;

  SELECT tm.id INTO v_member
    FROM public.team_members tm
   WHERE tm.auth_user_id = auth.uid()
     AND tm.tenant_id = v_tenant
     AND tm.is_active
   LIMIT 1;

  v_value := jsonb_build_object(
    'enabled', p_enabled,
    'updated_at', now(),
    'updated_by', v_member
  );

  INSERT INTO public.tenant_config_overrides (tenant_id, key, value, updated_at)
  VALUES (v_tenant, 'agent_platform_v2_enabled', v_value::text, now())
  ON CONFLICT (tenant_id, key) DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = EXCLUDED.updated_at;

  RETURN v_value;
END;
$$;

REVOKE ALL ON FUNCTION public.agent_get_router_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.agent_set_router_enabled(boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agent_get_router_status() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agent_set_router_enabled(boolean) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.agent_route_lookup(
  p_channel text,
  p_instance_id text,
  p_ctx jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(agent_slug text, agent_id uuid, deployment_id uuid, priority integer, match_used jsonb)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_clean_match jsonb;
  v_keywords jsonb;
  v_kw_mode text;
  v_text text;
  v_kw text;
  v_kw_hit boolean;
  v_tenant uuid;
BEGIN
  -- WhatsApp routing must always derive its tenant from a real instance.
  IF p_channel = 'whatsapp' THEN
    BEGIN
      SELECT wi.tenant_id INTO v_tenant
        FROM public.whatsapp_instances wi
       WHERE wi.id = p_instance_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_tenant := NULL;
    END;
  ELSE
    v_tenant := public.get_tenant_id();
  END IF;

  IF v_tenant IS NULL THEN RETURN; END IF;

  v_text := lower(COALESCE(p_ctx->>'text', ''));
  FOR v_row IN
    SELECT d.id AS dep_id, d.config, d.agent_id, r.slug,
           COALESCE((d.config->>'priority')::int, 100) AS pri
      FROM public.agents_deployments d
      JOIN public.agents_registry r
        ON r.id = d.agent_id
       AND r.tenant_id = v_tenant
     WHERE d.channel = p_channel
       AND d.is_active
       AND r.is_active
       AND d.tenant_id = v_tenant
       AND (
         p_instance_id IS NULL
         OR d.config->>'instance_id' IS NULL
         OR d.config->>'instance_id' = p_instance_id
       )
     ORDER BY COALESCE((d.config->>'priority')::int, 100), d.created_at
  LOOP
    v_keywords := v_row.config->'match'->'keywords';
    v_kw_mode := COALESCE(v_row.config->'match'->>'keywords_mode', 'any');

    SELECT COALESCE(jsonb_object_agg(je.key, je.value), '{}'::jsonb)
      INTO v_clean_match
      FROM jsonb_each(COALESCE(v_row.config->'match', '{}'::jsonb)) AS je
     WHERE je.key NOT LIKE '\_\_%' ESCAPE '\'
       AND je.key NOT IN ('keywords', 'keywords_mode')
       AND je.value IS NOT NULL
       AND je.value <> 'null'::jsonb;

    IF NOT (v_clean_match = '{}'::jsonb OR p_ctx @> v_clean_match) THEN
      CONTINUE;
    END IF;

    IF v_keywords IS NOT NULL
       AND jsonb_typeof(v_keywords) = 'array'
       AND jsonb_array_length(v_keywords) > 0 THEN
      IF v_kw_mode = 'all' THEN
        v_kw_hit := true;
        FOR v_kw IN SELECT lower(x) FROM jsonb_array_elements_text(v_keywords) AS x LOOP
          IF v_kw = '' OR position(v_kw IN v_text) = 0 THEN
            v_kw_hit := false;
            EXIT;
          END IF;
        END LOOP;
      ELSE
        v_kw_hit := false;
        FOR v_kw IN SELECT lower(x) FROM jsonb_array_elements_text(v_keywords) AS x LOOP
          IF v_kw <> '' AND position(v_kw IN v_text) > 0 THEN
            v_kw_hit := true;
            EXIT;
          END IF;
        END LOOP;
      END IF;
      IF NOT v_kw_hit THEN CONTINUE; END IF;
    END IF;

    agent_slug := v_row.slug;
    agent_id := v_row.agent_id;
    deployment_id := v_row.dep_id;
    priority := v_row.pri;
    match_used := v_clean_match || CASE
      WHEN v_keywords IS NOT NULL THEN jsonb_build_object('keywords', v_keywords)
      ELSE '{}'::jsonb
    END;
    RETURN NEXT;
    RETURN;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.agent_route_lookup(text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agent_route_lookup(text,text,jsonb) TO authenticated, service_role;

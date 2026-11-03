-- Security hardening for the distributable CRM template.
-- This migration closes privilege-escalation paths and keeps privileged agent
-- routines callable only by trusted Edge Functions.

BEGIN;

-- Team membership is invitation/admin managed. Users may not choose their own
-- role or change security-sensitive columns through a generic table update.
DROP POLICY IF EXISTS tenant_insert_team_members ON public.team_members;
CREATE POLICY tenant_insert_team_members_admin
  ON public.team_members FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.get_tenant_id() AND public.is_admin());

DROP POLICY IF EXISTS tenant_self_update_team_members ON public.team_members;

-- Linking an invited member must use the authenticated user's own email.
CREATE OR REPLACE FUNCTION public.link_auth_user_to_team_member(user_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_claim_email text;
  v_count integer;
  v_tenant uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  v_claim_email := lower(COALESCE(auth.jwt()->>'email', ''));
  IF v_claim_email = '' OR lower(trim(user_email)) <> v_claim_email THEN
    RAISE EXCEPTION 'Email does not match authenticated user';
  END IF;

  UPDATE public.team_members
     SET auth_user_id = auth.uid()
   WHERE lower(email) = v_claim_email
     AND auth_user_id IS NULL
     AND is_active = true;

  SELECT count(*)
    INTO v_count
    FROM public.team_members
   WHERE lower(email) = v_claim_email
     AND auth_user_id = auth.uid()
     AND is_active = true;

  IF v_count = 1 THEN
    SELECT tenant_id INTO v_tenant
      FROM public.team_members
     WHERE lower(email) = v_claim_email
       AND auth_user_id = auth.uid()
       AND is_active = true
     LIMIT 1;
    UPDATE auth.users
       SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
         || jsonb_build_object('tenant_id', v_tenant)
     WHERE id = auth.uid();
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.link_auth_user_to_team_member(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.link_auth_user_to_team_member(text) TO authenticated;

-- Auth directory lookup is backend-only.
REVOKE ALL ON FUNCTION public.get_user_by_email(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_by_email(text) TO service_role;

-- Raw provider credentials must never be returned to browser roles. The table
-- RLS remains useful for metadata management, but secret reads are backend-only.
REVOKE ALL ON FUNCTION public.agent_get_credential_data(text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agent_get_credential_data(text, uuid) TO service_role;

-- Authenticated clients may manage credentials but can never read auth_data
-- back from PostgREST. Edge Functions retain full access through service_role.
REVOKE SELECT ON public.agents_provider_credentials FROM authenticated;
GRANT SELECT (
  id, tenant_id, owner_user_id, provider_type, label, metadata, is_active,
  is_shared, last_used_at, last_refreshed_at, created_at, updated_at
) ON public.agents_provider_credentials TO authenticated;

REVOKE SELECT ON public.instagram_business_accounts FROM authenticated;
GRANT SELECT (
  id, tenant_id, facebook_page_id, instagram_business_id, instagram_username,
  token_expires_at, name, status, teams, profile_picture_url,
  followers_count, biography, created_at, updated_at
) ON public.instagram_business_accounts TO authenticated;

-- Agent tool RPCs execute with SECURITY DEFINER. Only the service-role runner
-- may invoke them; selected admin UX RPCs are granted back below.
DO $$
DECLARE fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname LIKE 'agent\_%' ESCAPE '\'
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', fn.signature);
  END LOOP;
END $$;

-- Admin-only metadata inspection used by the tool editor.
CREATE OR REPLACE FUNCTION public.agent_describe_function(p_fn_name text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_desc text; v_args text; v_returns text;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Admin required'; END IF;
  SELECT obj_description(p.oid, 'pg_proc'), pg_get_function_arguments(p.oid), pg_get_function_result(p.oid)
    INTO v_desc, v_args, v_returns
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname = p_fn_name LIMIT 1;
  IF v_desc IS NULL AND v_args IS NULL THEN RETURN jsonb_build_object('found', false); END IF;
  RETURN jsonb_build_object('found',true,'name',p_fn_name,'description',v_desc,'arguments',v_args,'returns',v_returns);
END;
$$;
GRANT EXECUTE ON FUNCTION public.agent_describe_function(text) TO authenticated, service_role;

-- Free-form SQL generated by an LLM cannot be made tenant-safe with string
-- matching. Keep the routine backend-only and disable the generic tool; agents
-- must use the catalog's purpose-built, tenant-aware RPCs instead.
UPDATE public.agents_skill_catalog
   SET default_usage_mode = 'disabled', is_recommended = false
 WHERE slug = 'execute_sql';
UPDATE public.agents_tools
   SET usage_mode = 'disabled', is_active = false
 WHERE name = 'execute_sql'
    OR action_config->>'function' = 'agent_execute_readonly';

-- External provider endpoints are credential configuration, not properties of
-- the template author's Supabase project.
UPDATE public.agents_skill_catalog
   SET action_config = regexp_replace(
     action_config::text,
     'https://[a-z0-9]+\.supabase\.co/functions/v1/carousel-api',
     '{{credential.base_url}}/functions/v1/carousel-api',
     'g'
   )::jsonb
 WHERE provider = 'borapostar';
UPDATE public.agents_tools
   SET action_config = regexp_replace(
     action_config::text,
     'https://[a-z0-9]+\.supabase\.co/functions/v1/carousel-api',
     '{{credential.base_url}}/functions/v1/carousel-api',
     'g'
   )::jsonb
 WHERE provider = 'borapostar';

-- Admin-only agent creation. Tenant, creator and credential ownership are
-- derived/validated server-side instead of trusted from browser parameters.
CREATE OR REPLACE FUNCTION public.agent_create_from_template(
  p_template_id uuid,
  p_name text,
  p_slug text,
  p_emoji text DEFAULT NULL,
  p_color text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_vars jsonb DEFAULT '{}'::jsonb,
  p_credential_id uuid DEFAULT NULL,
  p_created_by uuid DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  tpl record;
  new_id uuid;
  final_prompt text;
  final_provider text;
  final_model text;
  final_cred uuid;
  kv record;
  v_tenant uuid := public.get_tenant_id();
  v_creator uuid;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Admin required'; END IF;
  IF p_name IS NULL OR trim(p_name) = '' OR p_slug !~ '^[a-z0-9][a-z0-9_-]{1,79}$' THEN
    RAISE EXCEPTION 'Invalid agent name or slug';
  END IF;

  SELECT id INTO v_creator
    FROM public.team_members
   WHERE auth_user_id = auth.uid() AND tenant_id = v_tenant AND is_active
   LIMIT 1;
  IF v_creator IS NULL THEN RAISE EXCEPTION 'Active team member required'; END IF;

  SELECT * INTO tpl
    FROM public.agents_registry
   WHERE id = p_template_id AND is_template IS TRUE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Template not found'; END IF;

  final_prompt := tpl.system_prompt;
  FOR kv IN SELECT key, value FROM jsonb_each_text(COALESCE(p_vars, '{}'::jsonb)) LOOP
    final_prompt := replace(final_prompt, '{{' || kv.key || '}}', kv.value);
  END LOOP;

  final_cred := COALESCE(p_credential_id, tpl.credential_id);
  IF final_cred IS NOT NULL THEN
    SELECT provider_type INTO final_provider
      FROM public.agents_provider_credentials
     WHERE id = final_cred AND tenant_id = v_tenant AND is_active;
    IF final_provider IS NULL THEN RAISE EXCEPTION 'Credential not available in tenant'; END IF;
  END IF;

  final_provider := COALESCE(final_provider, tpl.provider);
  final_model := tpl.model;
  INSERT INTO public.agents_registry (
    tenant_id, slug, display_name, description, emoji, provider, model,
    system_prompt, settings, tier, avatar_color, is_active, is_template,
    credential_id, parent_agent_id, daily_token_limit, daily_cost_limit_brl,
    created_by
  ) VALUES (
    v_tenant, p_slug, trim(p_name), COALESCE(p_description, tpl.description),
    COALESCE(p_emoji, tpl.emoji), final_provider, final_model, final_prompt,
    tpl.settings, tpl.tier, COALESCE(p_color, tpl.avatar_color), true, false,
    final_cred, NULL, tpl.daily_token_limit, tpl.daily_cost_limit_brl, v_creator
  ) RETURNING id INTO new_id;

  INSERT INTO public.agents_tools (
    tenant_id, agent_id, name, description, parameters_schema, action_type,
    action_config, usage_mode, is_active, provider
  )
  SELECT v_tenant, new_id, name, description, parameters_schema, action_type,
         action_config, usage_mode, is_active, provider
    FROM public.agents_tools WHERE agent_id = tpl.id;

  INSERT INTO public.agents_versions (
    tenant_id, agent_id, system_prompt, settings, change_summary,
    is_published, published_at
  ) VALUES (
    v_tenant, new_id, final_prompt, tpl.settings,
    'Criado a partir do template ' || tpl.display_name, true, now()
  );

  INSERT INTO public.agents_deployments (tenant_id, agent_id, channel, config)
  VALUES (v_tenant, new_id, 'chat_web', '{}'::jsonb);
  RETURN p_slug;
END;
$$;
GRANT EXECUTE ON FUNCTION public.agent_create_from_template(uuid,text,text,text,text,text,jsonb,uuid,uuid)
  TO authenticated, service_role;

-- Credential ownership stores team_member.id, not auth.users.id.
DROP POLICY IF EXISTS apc_read_admin_or_owner ON public.agents_provider_credentials;
CREATE POLICY apc_read_admin_or_owner ON public.agents_provider_credentials
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_tenant_id()
    AND (
      public.is_admin()
      OR (
        is_shared = false
        AND owner_user_id IN (
        SELECT id FROM public.team_members
         WHERE auth_user_id = auth.uid() AND tenant_id = public.get_tenant_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS apc_write_admin_or_owner ON public.agents_provider_credentials;
CREATE POLICY apc_write_admin_or_owner ON public.agents_provider_credentials
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_tenant_id()
    AND (
      public.is_admin()
      OR owner_user_id IN (
        SELECT id FROM public.team_members
         WHERE auth_user_id = auth.uid() AND tenant_id = public.get_tenant_id()
      )
    )
  )
  WITH CHECK (
    tenant_id = public.get_tenant_id()
    AND (
      public.is_admin()
      OR (
        is_shared = false
        AND owner_user_id IN (
          SELECT id FROM public.team_members
           WHERE auth_user_id = auth.uid() AND tenant_id = public.get_tenant_id()
        )
      )
    )
  );

COMMIT;

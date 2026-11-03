BEGIN;
-- Views públicas devem aplicar as policies de quem consulta.
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT c.oid::regclass AS relation FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='v' LOOP
  EXECUTE format('ALTER VIEW %s SET (security_invoker=true)',r.relation);
 END LOOP;
END $$;

CREATE POLICY tenant_directory_scope ON public.tenants AS RESTRICTIVE FOR SELECT TO anon,authenticated
 USING (id=public.get_tenant_id());
CREATE POLICY agent_templates_scope ON public.agents_registry AS RESTRICTIVE FOR SELECT TO authenticated
 USING (tenant_id=public.get_tenant_id() OR (tenant_id IS NULL AND is_template IS TRUE));
-- Um administrador de outra empresa não pode ler segredos globais da instalação.
CREATE POLICY config_platform_scope ON public.config AS RESTRICTIVE FOR SELECT TO anon,authenticated
 USING ((public.is_admin() AND public.get_tenant_id()='00000000-0000-0000-0000-000000000001'::uuid)
 OR key IN ('multi_tenant_enabled','enabled_modules','COMPANY_NAME','COMPANY_DOMAIN','agent_platform_v2_enabled','SUPABASE_PROJECT_URL'));

-- Funções de domínio passam a respeitar o RLS, inclusive parâmetros tenant_id fornecidos pelo cliente.
-- Helpers que precisam consultar auth/associação sem recursão permanecem definers.
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT p.oid::regprocedure AS signature,p.proname,p.prorettype
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prosecdef AND has_function_privilege('authenticated',p.oid,'EXECUTE') LOOP
  IF r.prorettype IN ('trigger'::regtype,'event_trigger'::regtype)
   OR r.proname IN ('health_check','link_auth_user_to_team_member','create_impersonation_token','agent_route_lookup') THEN
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
  ELSIF r.proname NOT IN ('get_tenant_id','is_admin','is_tenant_admin','is_superadmin','is_marketing_manager',
    'select_tenant_for_user','clear_tenant_from_jwt','tenant_onboard','mcp_request_guard','mcp_authorization_info') THEN
   EXECUTE format('ALTER FUNCTION %s SECURITY INVOKER',r.signature);
  END IF;
 END LOOP;
END $$;

-- Só o backend pode conceder administração da plataforma ou alterar o vínculo Auth.
-- Onboarding SECURITY DEFINER é o único caminho autenticado que precisa inserir o próprio vínculo.
-- O teste de current_user permite esse caminho, sem confiar em dados editáveis do JWT.
CREATE OR REPLACE FUNCTION crm_mcp.protect_member_identity()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF current_user='authenticated' THEN
  IF TG_OP='INSERT' AND (NEW.is_superadmin IS TRUE OR NEW.auth_user_id IS NOT NULL) THEN
   RAISE EXCEPTION 'Vínculo de identidade reservado ao backend' USING ERRCODE='42501';
  ELSIF TG_OP='UPDATE' AND (NEW.is_superadmin IS DISTINCT FROM OLD.is_superadmin
    OR NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id) THEN
   RAISE EXCEPTION 'Vínculo de identidade reservado ao backend' USING ERRCODE='42501';
  END IF;
 END IF;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION crm_mcp.protect_member_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER protect_member_identity BEFORE INSERT OR UPDATE ON public.team_members
 FOR EACH ROW EXECUTE FUNCTION crm_mcp.protect_member_identity();

-- FKs simples entre registros de empresas também precisam conferir o tenant.
-- Isso impede que um registro próprio aponte para um lead/funil de outra empresa.
CREATE FUNCTION crm_mcp.check_tenant_references()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE r record; item jsonb:=to_jsonb(NEW); parent_tenant uuid; fk_value text;
BEGIN
 IF current_user <> 'authenticated' THEN RETURN NEW; END IF;
 FOR r IN SELECT c.confrelid::regclass AS parent,ca.attname AS child_key,pa.attname AS parent_key
 FROM pg_constraint c
 JOIN pg_attribute ca ON ca.attrelid=c.conrelid AND ca.attnum=c.conkey[1]
 JOIN pg_attribute pa ON pa.attrelid=c.confrelid AND pa.attnum=c.confkey[1]
 WHERE c.conrelid=TG_RELID AND c.contype='f' AND cardinality(c.conkey)=1 AND cardinality(c.confkey)=1
 AND EXISTS(SELECT 1 FROM pg_attribute a WHERE a.attrelid=c.confrelid AND a.attname='tenant_id' AND NOT a.attisdropped)
 LOOP
  fk_value:=item->>r.child_key;
  IF fk_value IS NOT NULL THEN
   parent_tenant:=NULL;
   EXECUTE format('SELECT tenant_id FROM %s WHERE %I::text=$1',r.parent,r.parent_key) INTO parent_tenant USING fk_value;
   -- RLS do pai torna referências a empresas alheias invisíveis.
   IF parent_tenant IS NOT NULL AND parent_tenant::text IS DISTINCT FROM item->>'tenant_id' THEN
    RAISE EXCEPTION 'Referência fora da empresa' USING ERRCODE='42501';
   END IF;
   -- SELECT dinâmico não altera FOUND: verificar existência separadamente.
   IF parent_tenant IS NULL THEN
    DECLARE visible boolean; BEGIN
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s WHERE %I::text=$1 AND tenant_id IS NULL)',r.parent,r.parent_key) INTO visible USING fk_value;
     IF NOT visible THEN RAISE EXCEPTION 'Referência indisponível na empresa' USING ERRCODE='42501'; END IF;
    END;
   END IF;
  END IF;
 END LOOP;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION crm_mcp.check_tenant_references() FROM PUBLIC,anon,authenticated;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT c.oid::regclass AS relation FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r'
 AND EXISTS(SELECT 1 FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attname='tenant_id' AND NOT a.attisdropped)
 AND EXISTS(SELECT 1 FROM pg_constraint f WHERE f.conrelid=c.oid AND f.contype='f') LOOP
  EXECUTE format('CREATE TRIGGER check_tenant_references BEFORE INSERT OR UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION crm_mcp.check_tenant_references()',r.relation);
 END LOOP;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;

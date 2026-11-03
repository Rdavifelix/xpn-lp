BEGIN;
CREATE OR REPLACE FUNCTION public.fn_config_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = ''
AS $function$
DECLARE
  v_user_id UUID;
  v_user_name TEXT;
  v_old JSONB;
  v_new JSONB;
  v_changed TEXT[];
  v_tenant UUID;
  v_record_id TEXT;
  k TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NOT NULL THEN
    SELECT name INTO v_user_name FROM public.team_members WHERE auth_user_id = v_user_id LIMIT 1;
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    v_new := NULL;
    v_record_id := OLD.id::text;
    v_tenant := OLD.tenant_id;
  ELSIF TG_OP = 'INSERT' THEN
    v_old := NULL;
    v_new := to_jsonb(NEW);
    v_record_id := NEW.id::text;
    v_tenant := NEW.tenant_id;
  ELSE
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_record_id := NEW.id::text;
    v_tenant := NEW.tenant_id;
    
    v_changed := '{}';
    FOR k IN SELECT jsonb_object_keys(v_new)
    LOOP
      -- Ignorar campos de update automático E current_activity (presença)
      IF k NOT IN ('updated_at', 'created_at', 'current_activity', 'current_activity_at', 'current_activity_meta') 
         AND (v_old->k IS DISTINCT FROM v_new->k) THEN
        v_changed := array_append(v_changed, k);
      END IF;
    END LOOP;
    
    IF array_length(v_changed, 1) IS NULL THEN
      RETURN NEW;
    END IF;
  END IF;

  INSERT INTO public.config_audit_log (table_name, record_id, action, changed_by_user_id, changed_by_name, old_data, new_data, changed_fields, tenant_id)
  VALUES (TG_TABLE_NAME, v_record_id, TG_OP, v_user_id, v_user_name, v_old, v_new, v_changed, v_tenant);

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$
;
COMMIT;
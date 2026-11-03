BEGIN;
CREATE UNIQUE INDEX whatsapp_entry_one_per_instance ON public.agents_deployments(tenant_id,(config->>'instance_id')) WHERE channel='whatsapp' AND config->>'entry_rule'='true';
CREATE FUNCTION public.whatsapp_entry_admin(p_tenant uuid,p_member uuid,p_action text,p_data jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE iid uuid; aid uuid; pid uuid; sid uuid; mid uuid; did uuid; active boolean;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM team_members m JOIN tenants t ON t.id=m.tenant_id WHERE m.id=p_member AND m.tenant_id=p_tenant AND m.is_active AND m.role='admin' AND t.is_active) THEN RAISE EXCEPTION 'Administrador ativo obrigatório';END IF;
 IF p_action='list' THEN RETURN jsonb_build_object('instances',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'status',status,'phone_number',phone_number)),'[]') FROM whatsapp_instances WHERE tenant_id=p_tenant),'rules',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'agent_id',agent_id,'active',is_active,'config',config)),'[]') FROM agents_deployments WHERE tenant_id=p_tenant AND channel='whatsapp' AND config->>'entry_rule'='true'));END IF;
 IF p_action<>'save' THEN RAISE EXCEPTION 'Ação inválida';END IF;
 iid=(p_data->>'instance_id')::uuid;aid=(p_data->>'agent_id')::uuid;pid=(p_data->>'pipeline_id')::uuid;sid=(p_data->>'stage_id')::uuid;mid=nullif(p_data->>'member_id','')::uuid;active=coalesce((p_data->>'active')::boolean,false);
 IF NOT EXISTS(SELECT 1 FROM whatsapp_instances WHERE id=iid AND tenant_id=p_tenant) OR NOT EXISTS(SELECT 1 FROM agents_registry WHERE id=aid AND tenant_id=p_tenant AND (NOT active OR is_active)) OR NOT EXISTS(SELECT 1 FROM sales_pipelines WHERE id=pid AND tenant_id=p_tenant AND is_active) OR NOT EXISTS(SELECT 1 FROM sales_pipeline_stages WHERE id=sid AND pipeline_id=pid AND tenant_id=p_tenant AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Instância, agente ativo, pipeline ou etapa inválidos nesta empresa';END IF;
 IF mid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM team_members WHERE id=mid AND tenant_id=p_tenant AND is_active) THEN RAISE EXCEPTION 'Responsável inválido';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('whatsapp-entry:'||iid,0));
 SELECT id INTO did FROM agents_deployments WHERE tenant_id=p_tenant AND channel='whatsapp' AND config->>'instance_id'=iid::text AND config->>'entry_rule'='true' FOR UPDATE;
 IF did IS NULL THEN INSERT INTO agents_deployments(tenant_id,agent_id,channel,is_active,config) VALUES(p_tenant,aid,'whatsapp',active,'{}') RETURNING id INTO did;END IF;
 UPDATE agents_deployments SET agent_id=aid,is_active=active,config=jsonb_build_object('entry_rule',true,'instance_id',iid,'pipeline_id',pid,'stage_id',sid,'member_id',mid,'access_mode','open','purpose','leads','priority',0) WHERE id=did;
 UPDATE whatsapp_instances SET teams=ARRAY(SELECT DISTINCT unnest(coalesce(teams,ARRAY[]::text[])||ARRAY['comercial'])) WHERE id=iid AND tenant_id=p_tenant;
 IF active THEN INSERT INTO tenant_config_overrides(tenant_id,key,value,updated_at) VALUES(p_tenant,'agent_platform_v2_enabled','{"enabled":true}',now()) ON CONFLICT(tenant_id,key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at;END IF;
 RETURN jsonb_build_object('id',did,'active',active);
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_entry_admin(uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.whatsapp_entry_admin(uuid,uuid,text,jsonb) TO service_role;

CREATE FUNCTION public.whatsapp_entry_resolve(p_instance uuid,p_lead uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE tid uuid; r record; pid uuid; sid uuid; mid uuid; did uuid; count_open integer;
BEGIN
 SELECT tenant_id INTO tid FROM whatsapp_instances WHERE id=p_instance;
 SELECT d.*,a.slug,a.is_active AS agent_active INTO r FROM agents_deployments d JOIN agents_registry a ON a.id=d.agent_id AND a.tenant_id=d.tenant_id WHERE d.tenant_id=tid AND d.channel='whatsapp' AND d.config->>'entry_rule'='true' AND d.config->>'instance_id'=p_instance::text;
 IF NOT FOUND THEN RETURN NULL;END IF;
 IF NOT r.is_active OR NOT r.agent_active OR NOT EXISTS(SELECT 1 FROM tenants WHERE id=tid AND is_active) THEN RETURN jsonb_build_object('handled',true,'paused',true);END IF;
 IF NOT EXISTS(SELECT 1 FROM leads WHERE id=p_lead AND tenant_id=tid) THEN RAISE EXCEPTION 'Contato inválido na entrada WhatsApp';END IF;
 pid=(r.config->>'pipeline_id')::uuid;sid=(r.config->>'stage_id')::uuid;mid=(r.config->>'member_id')::uuid;
 IF NOT EXISTS(SELECT 1 FROM sales_pipelines WHERE id=pid AND tenant_id=tid AND is_active) OR NOT EXISTS(SELECT 1 FROM sales_pipeline_stages WHERE id=sid AND pipeline_id=pid AND tenant_id=tid AND NOT is_won AND NOT is_lost) THEN RAISE EXCEPTION 'Destino WhatsApp indisponível';END IF;
 IF mid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM team_members WHERE id=mid AND tenant_id=tid AND is_active) THEN RAISE EXCEPTION 'Responsável WhatsApp inativo';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('whatsapp-lead:'||tid||':'||p_lead||':'||pid,0));
 SELECT count(*) INTO count_open FROM deals WHERE tenant_id=tid AND lead_id=p_lead AND pipeline_id=pid AND status NOT IN ('won','lost');
 IF count_open>1 THEN RAISE EXCEPTION 'Mais de uma oportunidade aberta neste pipeline; selecione ou una as oportunidades';END IF;
 SELECT id INTO did FROM deals WHERE tenant_id=tid AND lead_id=p_lead AND pipeline_id=pid ORDER BY (status NOT IN ('won','lost')) DESC,created_at DESC LIMIT 1;
 IF did IS NULL THEN INSERT INTO deals(tenant_id,lead_id,pipeline_id,pipeline_stage_id,sales_rep_id,title,metadata) SELECT tid,p_lead,pid,sid,mid,'WhatsApp · '||coalesce(name,phone,'Contato'),jsonb_build_object('source','whatsapp','instance_id',p_instance,'entry_rule_id',r.id) FROM leads WHERE id=p_lead AND tenant_id=tid RETURNING id INTO did;END IF;
 RETURN jsonb_build_object('agent_id',r.agent_id,'agent_slug',r.slug,'deployment_id',r.id,'deal_id',did,'tenant_id',tid);
END $$;
REVOKE ALL ON FUNCTION public.whatsapp_entry_resolve(uuid,uuid) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION public.whatsapp_entry_resolve(uuid,uuid) TO service_role;
-- Legacy enqueue runs on message INSERT, before the Edge router; suppress it for explicit entry rules, including paused ones.
DO $$ DECLARE def text;BEGIN
 SELECT pg_get_functiondef('public.trigger_enqueue_for_ai_agent()'::regprocedure) INTO def;
 def=regexp_replace(def,'BEGIN','BEGIN IF EXISTS(SELECT 1 FROM public.agents_deployments d WHERE d.tenant_id=NEW.tenant_id AND d.channel=''whatsapp'' AND d.config->>''entry_rule''=''true'' AND d.config->>''instance_id''=NEW.instance_id::text) THEN RETURN NEW; END IF;');
 EXECUTE def;
END $$;
COMMIT;

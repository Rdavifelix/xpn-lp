BEGIN;
CREATE SCHEMA crm_web;
REVOKE ALL ON SCHEMA crm_web FROM PUBLIC,anon,authenticated;
CREATE TABLE crm_web.pages(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL REFERENCES public.tenants(id),name text NOT NULL,url text NOT NULL,origin text NOT NULL,path text NOT NULL,key uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),active boolean NOT NULL DEFAULT true,created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(tenant_id,url));
CREATE TABLE crm_web.sessions(page_id uuid NOT NULL REFERENCES crm_web.pages(id),id uuid NOT NULL,visitor_id uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),source text,medium text,campaign text,referrer text,lead_id uuid REFERENCES public.leads(id),deal_id uuid REFERENCES public.deals(id),converted_at timestamptz,PRIMARY KEY(page_id,id));
CREATE TABLE crm_web.events(page_id uuid NOT NULL,session_id uuid NOT NULL,id uuid NOT NULL,type text NOT NULL CHECK(type IN('pageview','click')),label text,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(page_id,id),FOREIGN KEY(page_id,session_id) REFERENCES crm_web.sessions(page_id,id));
CREATE INDEX ON crm_web.events(page_id,created_at);
CREATE INDEX ON crm_web.sessions(page_id,created_at);
CREATE INDEX ON crm_web.pages(tenant_id);
ALTER TABLE crm_web.pages ENABLE ROW LEVEL SECURITY;ALTER TABLE crm_web.sessions ENABLE ROW LEVEL SECURITY;ALTER TABLE crm_web.events ENABLE ROW LEVEL SECURITY;
CREATE FUNCTION crm_web.timeline_event(p crm_web.pages,s crm_web.sessions,e crm_web.events) RETURNS void LANGUAGE sql SET search_path='' AS $$
 INSERT INTO public.lead_interactions(tenant_id,lead_id,interaction_type,content,created_at,metadata)
 SELECT p.tenant_id,s.lead_id,'page_activity',CASE WHEN e.type='pageview' THEN 'Visitou a página' ELSE 'Clicou na página' END,e.created_at,jsonb_build_object('page_id',p.id,'page_name',p.name,'page_url',p.url,'event_id',e.id,'event_type',e.type,'label',e.label,'source',s.source,'medium',s.medium,'campaign',s.campaign,'referrer',s.referrer)
 WHERE s.lead_id IS NOT NULL;
$$;
CREATE FUNCTION public.web_collect(p_key uuid,p_origin text,p_path text,p_session uuid,p_visitor uuid,p_event uuid,p_type text,p_label text DEFAULT NULL,p_source text DEFAULT NULL,p_medium text DEFAULT NULL,p_campaign text DEFAULT NULL,p_referrer text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p crm_web.pages;s crm_web.sessions;e crm_web.events;BEGIN
 SELECT * INTO p FROM crm_web.pages WHERE key=p_key AND active;
 IF p.id IS NULL OR p.origin<>p_origin OR p.path<>rtrim(p_path,'/') OR NOT EXISTS(SELECT 1 FROM public.tenants WHERE id=p.tenant_id AND is_active) THEN RAISE EXCEPTION 'Página não autorizada' USING ERRCODE='42501';END IF;
 IF p_session IS NULL OR p_visitor IS NULL OR p_event IS NULL OR p_type NOT IN('pageview','click') OR length(coalesce(p_label,''))>100 OR length(coalesce(p_source,''))>100 OR length(coalesce(p_medium,''))>100 OR length(coalesce(p_campaign,''))>150 OR length(coalesce(p_referrer,''))>250 THEN RAISE EXCEPTION 'Evento inválido' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('web-page:'||p.id,0));
 IF EXISTS(SELECT 1 FROM crm_web.events WHERE page_id=p.id AND id=p_event) THEN RETURN '{"ok":true}'::jsonb;END IF;
 IF (SELECT count(*) FROM crm_web.events WHERE page_id=p.id AND created_at>now()-interval '1 day')>=20000 OR (SELECT count(*) FROM crm_web.events WHERE page_id=p.id AND session_id=p_session AND created_at>now()-interval '1 hour')>=200 THEN RAISE EXCEPTION 'Limite atingido' USING ERRCODE='P0001';END IF;
 INSERT INTO crm_web.sessions(page_id,id,visitor_id,source,medium,campaign,referrer) VALUES(p.id,p_session,p_visitor,nullif(p_source,''),nullif(p_medium,''),nullif(p_campaign,''),nullif(p_referrer,'')) ON CONFLICT(page_id,id) DO NOTHING;
 SELECT * INTO s FROM crm_web.sessions WHERE page_id=p.id AND id=p_session;
 INSERT INTO crm_web.events(page_id,session_id,id,type,label) VALUES(p.id,p_session,p_event,p_type,nullif(p_label,'')) RETURNING * INTO e;
 PERFORM crm_web.timeline_event(p,s,e);
 RETURN '{"ok":true}'::jsonb;
END $$;
REVOKE ALL ON FUNCTION public.web_collect(uuid,text,text,uuid,uuid,uuid,text,text,text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.web_collect(uuid,text,text,uuid,uuid,uuid,text,text,text,text,text,text) TO service_role;
CREATE FUNCTION crm_web.bind(p_tenant uuid,p_lead uuid,p_deal uuid,p_tracking jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE p crm_web.pages;s crm_web.sessions;e crm_web.events;page_id uuid;session_id uuid;BEGIN
 BEGIN page_id:=(p_tracking->>'page_id')::uuid;session_id:=(p_tracking->>'session_id')::uuid;EXCEPTION WHEN invalid_text_representation THEN RETURN;END;
 SELECT * INTO p FROM crm_web.pages WHERE id=page_id AND tenant_id=p_tenant;
 IF p.id IS NULL THEN RETURN;END IF;
 SELECT * INTO s FROM crm_web.sessions WHERE crm_web.sessions.page_id=p.id AND id=session_id AND created_at>now()-interval '30 days' FOR UPDATE;
 IF s.id IS NULL OR s.lead_id IS NOT NULL THEN RETURN;END IF;
 IF NOT EXISTS(SELECT 1 FROM public.leads WHERE id=p_lead AND tenant_id=p_tenant) OR (p_deal IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.deals WHERE id=p_deal AND tenant_id=p_tenant AND lead_id=p_lead)) THEN RETURN;END IF;
 UPDATE crm_web.sessions SET lead_id=p_lead,deal_id=p_deal,converted_at=now() WHERE crm_web.sessions.page_id=p.id AND id=s.id RETURNING * INTO s;
 FOR e IN SELECT * FROM crm_web.events WHERE crm_web.events.page_id=p.id AND crm_web.events.session_id=s.id ORDER BY created_at LOOP PERFORM crm_web.timeline_event(p,s,e);END LOOP;
END $$;
CREATE FUNCTION crm_web.form_conversion() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF TG_TABLE_SCHEMA='crm_forms' THEN PERFORM crm_web.bind(new.tenant_id,new.lead_id,new.deal_id,jsonb_build_object('page_id',new.payload#>>'{tracking,crm_page}','session_id',new.payload#>>'{tracking,crm_session}'));
 ELSIF new.status='processed' AND old.status IS DISTINCT FROM 'processed' THEN
  PERFORM crm_web.bind((SELECT tenant_id FROM crm_inbound.channels WHERE id=new.channel_id),new.lead_id,new.deal_id,new.payload->'_crm_tracking');
 END IF;RETURN new;
END $$;
CREATE TRIGGER web_form_conversion AFTER INSERT ON crm_forms.submissions FOR EACH ROW EXECUTE FUNCTION crm_web.form_conversion();
CREATE TRIGGER web_channel_conversion AFTER UPDATE OF status ON crm_inbound.receipts FOR EACH ROW EXECUTE FUNCTION crm_web.form_conversion();
CREATE FUNCTION public.web_pages_admin(p_action text,p_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_days integer DEFAULT 30) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid:=public.get_tenant_id();ctx jsonb;uid uuid;w boolean;p crm_web.pages;r jsonb;u text;start_at timestamptz;BEGIN
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN ctx:=crm_mcp.context();tid:=(ctx->>'tenant_id')::uuid;uid:=(ctx->>'member_id')::uuid;w:=(ctx->>'can_write')::boolean;
 ELSE SELECT m.id,m.role='admin' INTO uid,w FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id WHERE m.auth_user_id=auth.uid() AND m.tenant_id=tid AND m.is_active AND t.is_active;END IF;
 IF uid IS NULL OR tid IS NULL THEN RAISE EXCEPTION 'Membro ativo obrigatório' USING ERRCODE='42501';END IF;
 IF p_days IS NULL OR p_days NOT BETWEEN 1 AND 366 THEN RAISE EXCEPTION 'Período inválido' USING ERRCODE='22023';END IF;start_at:=now()-make_interval(days=>p_days);
 IF p_action='list' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO r FROM(SELECT p.*, (SELECT max(created_at) FROM crm_web.events WHERE page_id=p.id) last_event FROM crm_web.pages p WHERE tenant_id=tid ORDER BY created_at DESC)x;RETURN r;END IF;
 IF p_action='create' THEN
  IF NOT coalesce(w,false) THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;
  u:=rtrim(p_data->>'url','/');
  IF length(btrim(coalesce(p_data->>'name',''))) NOT BETWEEN 1 AND 100 OR u IS NULL OR length(u)>2000 OR u!~'^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/[^?#[:space:]]*)?$' THEN RAISE EXCEPTION 'Informe nome e URL HTTPS da página, sem parâmetros' USING ERRCODE='22023';END IF;
  INSERT INTO crm_web.pages(tenant_id,name,url,origin,path) VALUES(tid,btrim(p_data->>'name'),u,substring(u from '^(https://[^/]+)'),coalesce(substring(u from '^https://[^/]+(/.*)$'),'')) ON CONFLICT(tenant_id,url) DO NOTHING;
  SELECT * INTO p FROM crm_web.pages WHERE tenant_id=tid AND url=u;RETURN to_jsonb(p);
 END IF;
 SELECT * INTO p FROM crm_web.pages WHERE id=p_id AND tenant_id=tid;
 IF p.id IS NULL THEN RAISE EXCEPTION 'Página não encontrada' USING ERRCODE='42501';END IF;
 IF p_action='status' THEN IF NOT coalesce(w,false) THEN RAISE EXCEPTION 'Administrador obrigatório' USING ERRCODE='42501';END IF;IF jsonb_typeof(p_data->'active') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Status inválido';END IF;UPDATE crm_web.pages SET active=(p_data->>'active')::boolean WHERE id=p.id RETURNING * INTO p;RETURN to_jsonb(p);END IF;
 IF p_action='get' THEN RETURN to_jsonb(p);END IF;
 IF p_action='report' THEN RETURN jsonb_build_object('page',to_jsonb(p),'days',p_days,
 'views',(SELECT count(*) FROM crm_web.events WHERE page_id=p.id AND created_at>=start_at AND type='pageview'),
 'clicks',(SELECT count(*) FROM crm_web.events WHERE page_id=p.id AND created_at>=start_at AND type='click'),
 'visitors',(SELECT count(DISTINCT visitor_id) FROM crm_web.sessions WHERE page_id=p.id AND created_at>=start_at),
 'sessions',(SELECT count(*) FROM crm_web.sessions WHERE page_id=p.id AND created_at>=start_at),
 'conversions',(SELECT count(*) FROM crm_web.sessions WHERE page_id=p.id AND created_at>=start_at AND converted_at IS NOT NULL),
 'leads',(SELECT count(DISTINCT lead_id) FROM crm_web.sessions WHERE page_id=p.id AND created_at>=start_at),
 'won',(SELECT count(DISTINCT d.id) FROM crm_web.sessions s JOIN public.deals d ON d.id=s.deal_id AND d.tenant_id=tid WHERE s.page_id=p.id AND s.created_at>=start_at AND d.status='won'),
 'daily',(SELECT coalesce(jsonb_agg(x),'[]') FROM(SELECT (created_at AT TIME ZONE 'America/Sao_Paulo')::date AS "day",count(*) FILTER(WHERE type='pageview') views,count(*) FILTER(WHERE type='click') clicks FROM crm_web.events WHERE page_id=p.id AND created_at>=start_at GROUP BY 1 ORDER BY 1)x),
 'sources',(SELECT coalesce(jsonb_agg(x),'[]') FROM(SELECT coalesce(source,referrer,'Direto') source,count(*) visits,count(*) FILTER(WHERE lead_id IS NOT NULL) conversions FROM crm_web.sessions WHERE page_id=p.id AND created_at>=start_at GROUP BY 1 ORDER BY count(*) DESC LIMIT 20)x),
 'buttons',(SELECT coalesce(jsonb_agg(x),'[]') FROM(SELECT coalesce(label,'Botão') label,count(*) clicks FROM crm_web.events WHERE page_id=p.id AND created_at>=start_at AND type='click' GROUP BY 1 ORDER BY count(*) DESC LIMIT 20)x),
 'last_event',(SELECT max(created_at) FROM crm_web.events WHERE page_id=p.id));END IF;
 RAISE EXCEPTION 'Ação inválida' USING ERRCODE='22023';
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA crm_web FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.web_pages_admin(text,uuid,jsonb,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.web_pages_admin(text,uuid,jsonb,integer) TO authenticated;
CREATE OR REPLACE FUNCTION public.mcp_request_guard()
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p text := trim(both '/' from coalesce(current_setting('request.path',true),''));
BEGIN
  IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN
    IF p NOT IN ('rpc/web_pages_admin','rpc/inbound_admin','rpc/zernio_context','rpc/mcp_automation','rpc/mcp_agent_admin','rpc/playground_crm_action','rpc/mcp_configure_operational_skill','rpc/playground_mark_deal_lost','rpc/playground_notify_human','rpc/mcp_playground_job','rpc/playground_qualify_lead','rpc/mcp_agent_operation','rpc/agent_playground_context','rpc/playground_now_br','rpc/playground_change_stage','rpc/playground_update_lead','rpc/playground_schedule_meeting','rpc/mcp_team','rpc/playground_check_availability','rpc/forms_admin','rpc/mcp_history','rpc/mcp_agent_edit','rpc/mcp_crm','rpc/mcp_agent_setup','rpc/mcp_implementation','rpc/mcp_context','rpc/mcp_list_pipelines','rpc/mcp_create_pipeline','rpc/mcp_create_agent_draft','rpc/mcp_list_agents') THEN
      RAISE EXCEPTION 'Esta conexão só pode usar as operações MCP autorizadas' USING ERRCODE='42501'; END IF;
    PERFORM crm_mcp.context();
  ELSIF auth.jwt()->>'role'='authenticated' AND public.get_tenant_id() IS NULL
    AND p NOT IN ('rpc/tenant_onboard','config') THEN
    RAISE EXCEPTION 'Conclua o cadastro da sua empresa' USING ERRCODE='42501';
  END IF;
END;
$function$
;
COMMIT;

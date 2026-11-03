CREATE OR REPLACE FUNCTION public.web_pages_admin(p_action text,p_id uuid DEFAULT NULL,p_data jsonb DEFAULT '{}',p_days integer DEFAULT 30) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tid uuid:=public.get_tenant_id();ctx jsonb;uid uuid;w boolean;p crm_web.pages;r jsonb;u text;start_at timestamptz;BEGIN
 IF nullif(auth.jwt()->>'client_id','') IS NOT NULL THEN ctx:=crm_mcp.context();tid:=(ctx->>'tenant_id')::uuid;uid:=(ctx->>'member_id')::uuid;w:=(ctx->>'can_write')::boolean;
 ELSE SELECT m.id,m.role='admin' INTO uid,w FROM public.team_members m JOIN public.tenants t ON t.id=m.tenant_id WHERE m.auth_user_id=auth.uid() AND m.tenant_id=tid AND m.is_active AND t.is_active;END IF;
 IF uid IS NULL OR tid IS NULL THEN RAISE EXCEPTION 'Membro ativo obrigatório' USING ERRCODE='42501';END IF;
 IF p_days IS NULL OR p_days NOT BETWEEN 1 AND 366 THEN RAISE EXCEPTION 'Período inválido' USING ERRCODE='22023';END IF;start_at:=now()-make_interval(days=>p_days);
 IF p_action='list' THEN SELECT coalesce(jsonb_agg(x),'[]') INTO r FROM(SELECT pg.*, (SELECT max(created_at) FROM crm_web.events WHERE page_id=pg.id) last_event FROM crm_web.pages pg WHERE pg.tenant_id=tid ORDER BY pg.created_at DESC)x;RETURN r;END IF;
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

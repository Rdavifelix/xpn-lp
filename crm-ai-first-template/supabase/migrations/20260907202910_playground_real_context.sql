BEGIN;
ALTER TABLE public.agents_sessions ADD COLUMN playground_context jsonb;
CREATE FUNCTION public.agent_playground_context(p_lead_id uuid,p_deal_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE tenant uuid:=public.get_tenant_id(); lead public.leads%ROWTYPE; deal public.deals%ROWTYPE;
 notes jsonb; activities jsonb; stages jsonb; team jsonb; pipe jsonb; result jsonb;
BEGIN
 IF auth.uid() IS NULL OR tenant IS NULL OR nullif(auth.jwt()->>'client_id','') IS NOT NULL OR NOT EXISTS(
  SELECT 1 FROM public.team_members WHERE auth_user_id=auth.uid() AND tenant_id=tenant AND is_active AND role='admin'
 ) THEN RAISE EXCEPTION 'Administrador da empresa obrigatório' USING ERRCODE='42501'; END IF;
 SELECT * INTO lead FROM public.leads WHERE id=p_lead_id AND tenant_id=tenant;
 IF NOT FOUND THEN RAISE EXCEPTION 'Contato não encontrado nesta empresa' USING ERRCODE='42501'; END IF;
 IF p_deal_id IS NOT NULL THEN
  SELECT * INTO deal FROM public.deals WHERE id=p_deal_id AND lead_id=lead.id AND tenant_id=tenant;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oportunidade não pertence ao contato selecionado' USING ERRCODE='42501'; END IF;
 END IF;
 SELECT coalesce(jsonb_agg(n),'[]') INTO notes FROM (
  SELECT id,content,note_type,created_at FROM public.sales_notes WHERE tenant_id=tenant
   AND (lead_id=lead.id OR (p_deal_id IS NOT NULL AND deal_id=p_deal_id)) ORDER BY created_at DESC LIMIT 20
 ) n;
 SELECT coalesce(jsonb_agg(n),'[]') INTO activities FROM (
  SELECT id,name,description,task_type,status,scheduled_at,duration_minutes,responsavel_id,completed
  FROM public.company_activities WHERE tenant_id=tenant AND lead_id=lead.id ORDER BY created_at DESC LIMIT 20
 ) n;
 SELECT jsonb_build_object('id',p.id,'name',p.name) INTO pipe FROM public.sales_pipelines p
 WHERE p.id=deal.pipeline_id AND p.tenant_id=tenant;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'position',s.position,'won',s.is_won,'lost',s.is_lost) ORDER BY s.position),'[]')
 INTO stages FROM public.sales_pipeline_stages s WHERE s.pipeline_id=deal.pipeline_id AND s.tenant_id=tenant;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'role',m.role)),'[]') INTO team
 FROM public.team_members m WHERE m.tenant_id=tenant AND m.is_active;
 result:=jsonb_build_object('lead_id',lead.id,'deal_id',p_deal_id,'lead',to_jsonb(lead)-'tenant_id',
  'deal',CASE WHEN p_deal_id IS NULL THEN NULL ELSE to_jsonb(deal)-'tenant_id' END,
  'pipeline',pipe,'stages',stages,'notes',notes,'activities',activities,'team',team,
  'history_limit',20,'execution_mode','real','loaded_at',now());
 IF octet_length(result::text)>100000 THEN RAISE EXCEPTION 'Contexto excede 100 KB. Reduza notas/campos extensos antes de testar.' USING ERRCODE='22023'; END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.agent_playground_context(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.agent_playground_context(uuid,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;

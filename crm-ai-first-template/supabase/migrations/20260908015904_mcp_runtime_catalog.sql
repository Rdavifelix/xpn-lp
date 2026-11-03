BEGIN;
CREATE OR REPLACE FUNCTION public.mcp_agent_setup(p_action text,p_request_id uuid DEFAULT NULL,p_agent_id uuid DEFAULT NULL,p_config jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r jsonb;skills jsonb;BEGIN
 r:=crm_mcp.agent_setup(p_action,p_request_id,p_agent_id,p_config);
 IF p_action='catalog' THEN
  SELECT jsonb_agg(s||jsonb_build_object('playground_supported',coalesce((s->>'playground_supported')::boolean,false) OR s->>'slug'=ANY(ARRAY['criar_lead','criar_deal','hot_leads','my_deals','pipeline_summary']))) INTO skills FROM jsonb_array_elements(r->'skills') s;
  r:=jsonb_set(r,'{skills}',skills);
 END IF;
 RETURN r;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

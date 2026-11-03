CREATE OR REPLACE FUNCTION public.dispatch_instagram_enrichment() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE token text;url text;BEGIN
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE name='instagram_worker_secret';
 SELECT value INTO url FROM public.config WHERE key='SUPABASE_PROJECT_URL';
 IF token IS NOT NULL AND url ~ '^https://[a-z0-9]+[.]supabase[.]co$' THEN PERFORM net.http_post(url:=url||'/functions/v1/enrich-instagram-leads',headers:=jsonb_build_object('Content-Type','application/json','x-worker-secret',token),body:='{}'::jsonb,timeout_milliseconds:=120000);END IF;
END $$;

-- Existing SELECT RLS continues to scope Realtime delivery to tenant members.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='zernio_accounts') THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.zernio_accounts;
 END IF;
END $$;

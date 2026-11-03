-- RLS remains enforced for all subscribed rows; no credentials are published.
DO $$ DECLARE target text; BEGIN
 FOREACH target IN ARRAY ARRAY['zernio_conversations','instagram_messages','instagram_conversations'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=target) THEN
   EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',target);
  END IF;
 END LOOP;
END $$;

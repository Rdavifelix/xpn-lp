ALTER TABLE public.instagram_conversations ADD COLUMN IF NOT EXISTS is_ignored boolean NOT NULL DEFAULT false;
NOTIFY pgrst, 'reload schema';

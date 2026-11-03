-- Fresh distributions require the owner's verified sender; no inherited sender.
-- Condicional: em banco limpo a coluna from_email não existe em email_templates
-- (só em instalações com drift histórico); sem o guard a instalação nova falhava.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'email_templates' AND column_name = 'from_email'
  ) THEN
    ALTER TABLE public.email_templates ALTER COLUMN from_email DROP DEFAULT;
  END IF;
END $$;

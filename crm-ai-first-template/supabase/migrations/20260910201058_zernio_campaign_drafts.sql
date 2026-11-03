BEGIN;
CREATE TABLE public.zernio_campaigns(id uuid PRIMARY KEY,tenant_id uuid NOT NULL REFERENCES public.tenants(id),account_id text NOT NULL,config jsonb NOT NULL,remote_id text,created_at timestamptz NOT NULL DEFAULT now(),FOREIGN KEY(tenant_id,account_id) REFERENCES public.zernio_accounts(tenant_id,id));
ALTER TABLE public.zernio_campaigns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.zernio_campaigns FROM anon,authenticated;GRANT ALL ON public.zernio_campaigns TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

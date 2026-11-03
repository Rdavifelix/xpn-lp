-- Seed do tenant default (fallback de public.get_tenant_id()).
-- Necessário em instalações novas: várias migrations e defaults de coluna
-- referenciam o tenant 00000000-0000-0000-0000-000000000001.
INSERT INTO public.tenants (id, name, slug, is_active)
VALUES ('00000000-0000-0000-0000-000000000001', 'Default', 'default', true)
ON CONFLICT (id) DO NOTHING;

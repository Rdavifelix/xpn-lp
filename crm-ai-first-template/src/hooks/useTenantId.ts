// Helper pra ler tenant_id do team_member autenticado.
// Mantém arquitetura: RLS é a fonte de verdade pra leitura via policies + JWT.
// Este hook serve só pra INSERTs, RPC calls com p_tenant_id, e queryKey discriminator.
import { useAuth } from "@/contexts/AuthContext";

export function useTenantId(): string | null {
  const { teamMember } = useAuth();
  return teamMember?.tenant_id ?? null;
}

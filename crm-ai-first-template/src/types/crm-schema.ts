import type { Database } from './database.types';

// Complemento das tabelas CRM ausentes no arquivo gerado legado.
// Atualizar a geração completa de tipos após aplicar as migrations no ambiente real.
export type CrmTeamMemberRow = {
  id: string; email: string; name: string;
  role: 'admin' | 'cs' | 'comercial' | 'closer' | 'sdr' | 'geral' | 'user';
  team: 'cs' | 'comercial' | 'marketing' | 'suporte' | 'admin' | null;
  phone: string | null; avatar_url: string | null; is_active: boolean;
  auth_user_id: string | null; tenant_id: string | null; whatsapp_instance_id: string | null;
  google_calendar_connected: boolean; google_calendar_watch_channel_id: string | null;
  google_calendar_watch_expiration: string | null; focus_mode_enabled: boolean; created_at: string;
  is_superadmin?: boolean;
};
export type TenantConfigOverrideRow = {
  tenant_id: string; key: string; value: string | null; updated_at: string | null;
};
type Table<Row, RequiredKeys extends keyof Row> = {
  Row: Row; Insert: Partial<Row> & Pick<Row, RequiredKeys>; Update: Partial<Row>; Relationships: [];
};
export type CrmDatabase = Omit<Database,'public'> & {
  public: Omit<Database['public'],'Tables'> & {
    Tables: Database['public']['Tables'] & {
      team_members: Table<CrmTeamMemberRow,'email'|'name'>;
      config: Table<{key:string;value:string | null},'key'>;
      tenant_config_overrides: Table<TenantConfigOverrideRow,'tenant_id'|'key'>;
    };
  };
};

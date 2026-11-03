import { supabase } from "@/lib/supabase";

/**
 * Mantém whatsapp_conversations (tabela denormalizada do inbox) atualizada
 * após o frontend inserir mensagem diretamente em whatsapp_messages.
 *
 * Regras:
 * - Chamar SOMENTE após INSERT bem-sucedido (nunca em erro/dup — unread duplicaria).
 * - Tenant é forçado pelo JWT dentro da RPC (p_tenant_id é ignorado pra authenticated).
 * - Fire-and-forget: erro aqui é logado e nunca quebra o envio da mensagem.
 */
export async function upsertConversationSnapshot(p: {
  leadId?: string | null;
  groupId?: string | null;
  instanceId?: string | null;
  content?: string | null;
  senderName?: string | null;
  isFromMe: boolean;
  contactPhone?: string | null;
}): Promise<void> {
  try {
    if (!p.leadId && !p.groupId) return;
    const { error } = await supabase.rpc("upsert_whatsapp_conversation", {
      p_tenant_id: null, // derivado do JWT na RPC
      p_lead_id: p.leadId ?? null,
      p_group_id: p.groupId ?? null,
      p_instance_id: p.instanceId ?? null,
      p_last_message: p.content ?? null,
      p_last_message_at: new Date().toISOString(),
      p_last_sender_name: p.senderName ?? null,
      p_is_from_me: p.isFromMe,
      p_contact_phone: p.contactPhone ?? null,
      p_conversation_name: null,
    });
    if (error) console.error("[upsertConversationSnapshot] non-fatal:", error.message);
  } catch (e) {
    console.error("[upsertConversationSnapshot] non-fatal:", (e as Error)?.message);
  }
}

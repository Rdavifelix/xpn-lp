/**
 * Serviço de envio de mensagens WhatsApp via UAZAPI
 */

import { supabase } from '@/lib/supabase';
import { callUazapi } from '@/lib/uazapiProxy';

export interface SendWhatsAppMessageInput {
  phone: string; // Número do cliente (ex: 5511999887766)
  message: string;
  instanceName?: string; // Nome da instância UAZAPI
}

export interface SendWhatsAppResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

/**
 * Busca a instância UAZAPI ativa (sem credenciais — o envio passa pela edge uazapi-proxy)
 */
async function getActiveInstance(): Promise<{ instanceId: string; instanceName: string } | null> {
  const { data, error } = await (supabase as any)
    .from('whatsapp_instances')
    .select('id, name')
    .eq('status', 'connected')
    .limit(1)
    .single();

  if (error || !data) {
    console.error('Nenhuma instância WhatsApp conectada:', error);
    return null;
  }

  return {
    instanceId: data.id,
    instanceName: data.name,
  };
}

/**
 * Formata número de telefone para o formato do WhatsApp
 */
function formatPhoneForWhatsApp(phone: string): string {
  // Remove caracteres não numéricos
  let cleaned = phone.replace(/\D/g, '');
  // Números BR sem código de país: 10-11 dígitos (DDD + 8-9 dígitos)
  // Números internacionais já com código: 12+ dígitos
  // Só adiciona 55 se parecer ser BR sem código (até 11 dígitos)
  if (!cleaned.startsWith('55') && cleaned.length <= 11) {
    cleaned = `55${cleaned}`;
  }
  return cleaned;
}

/**
 * Envia mensagem de texto via WhatsApp
 */
export async function sendWhatsAppMessage(input: SendWhatsAppMessageInput): Promise<SendWhatsAppResult> {
  try {
    const instance = await getActiveInstance();
    
    if (!instance) {
      return {
        success: false,
        error: 'Nenhuma instância WhatsApp conectada',
      };
    }

    const number = formatPhoneForWhatsApp(input.phone);

    // Envio via edge uazapi-proxy (endpoint padrão /send/text) — token nunca chega ao browser
    const response = await callUazapi('send_text', instance.instanceId, {
      number,
      text: input.message,
    });

    const result: any = response.data || {};

    if (!response.ok) {
      return {
        success: false,
        error: result.message || result.error || 'Erro ao enviar mensagem',
      };
    }

    return {
      success: true,
      messageId: result.messageId || result.id,
    };
  } catch (error) {
    console.error('Erro ao enviar WhatsApp:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Erro desconhecido',
    };
  }
}

/**
 * Gera mensagem de confirmação de agendamento
 */
export function generateScheduleConfirmationMessage(params: {
  clientName: string;
  dateTime: string;
  meetLink: string;
  productName?: string;
}): string {
  const date = new Date(params.dateTime);
  const formattedDate = date.toLocaleDateString('pt-BR', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
  });
  const formattedTime = date.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  });

  return `Olá ${params.clientName}! 👋

Sua call de onboarding${params.productName ? ` do ${params.productName}` : ''} está confirmada! ✅

📅 *Data:* ${formattedDate}
⏰ *Horário:* ${formattedTime}
🔗 *Link da reunião:* ${params.meetLink}

Qualquer dúvida, é só chamar aqui! 😊`;
}

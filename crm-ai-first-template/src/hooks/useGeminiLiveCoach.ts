/**
 * Compatibility facade for the former browser-side Gemini Live client.
 * AI requests now go through the authenticated coach-suggestion Edge Function,
 * so provider credentials never reach the browser.
 */

import { useRef, useCallback, useState } from 'react';
import { supabase } from '@/lib/supabase';

interface CoachResponse {
  type: 'objection_handler' | 'question' | 'closing' | 'tip' | 'info';
  text: string;
  completed_items?: string[];
}

interface UseGeminiLiveCoachOptions {
  onSuggestion: (response: CoachResponse) => void;
  onError?: (error: string) => void;
}

export function useGeminiLiveCoach({ onSuggestion, onError }: UseGeminiLiveCoachOptions) {
  const [isConnected, setIsConnected] = useState(false);
  const systemInstructionRef = useRef('');
  const isRequestingRef = useRef(false);
  const onSuggestionRef = useRef(onSuggestion);
  const onErrorRef = useRef(onError);
  onSuggestionRef.current = onSuggestion;
  onErrorRef.current = onError;

  const connect = useCallback(async (systemInstruction: string) => {
    systemInstructionRef.current = systemInstruction;
    setIsConnected(true);
  }, []);

  const sendTranscription = useCallback(async (text: string) => {
    if (!isConnected || isRequestingRef.current || !text.trim()) return;
    isRequestingRef.current = true;
    try {
      const { data, error } = await supabase.functions.invoke('coach-suggestion', {
        body: {
          transcription: text,
          phase_name: 'Geral',
          playbook_context: systemInstructionRef.current,
        },
      });
      if (error) throw error;
      if (data?.has_suggestion && data.suggestion?.text) {
        onSuggestionRef.current({
          type: data.suggestion.type || 'tip',
          text: data.suggestion.text,
          completed_items: Array.isArray(data.completed_items) ? data.completed_items : [],
        });
      }
    } catch (error) {
      onErrorRef.current?.(error instanceof Error ? error.message : 'Coach indisponível');
    } finally {
      isRequestingRef.current = false;
    }
  }, [isConnected]);

  const disconnect = useCallback(() => {
    systemInstructionRef.current = '';
    setIsConnected(false);
  }, []);

  return {
    connect,
    sendTranscription,
    disconnect,
    isConnected,
  };
}

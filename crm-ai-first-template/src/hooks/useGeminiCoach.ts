import { useRef, useCallback } from 'react';
import { supabase } from '@/lib/supabase';

interface CoachRequest {
  transcription: string;
  phaseName: string;
  phaseDescription?: string;
  phaseChecklist?: Array<{ id: string; text: string }>;
  leadContext?: string;
}

interface CoachResponse {
  has_suggestion: boolean;
  suggestion?: {
    type: 'tip' | 'question' | 'objection_handler' | 'closing' | 'info';
    text: string;
    confidence: number;
  };
  completed_items?: string[];
}

export function useGeminiCoach() {
  const isRequestingRef = useRef(false);
  const lastRequestTimeRef = useRef(0);

  const requestCoachSuggestion = useCallback(async (req: CoachRequest): Promise<CoachResponse> => {
    // Prevent concurrent
    if (isRequestingRef.current) {
      return { has_suggestion: false };
    }

    // Cooldown 1.5s
    const now = Date.now();
    if (now - lastRequestTimeRef.current < 1500) {
      return { has_suggestion: false };
    }

    isRequestingRef.current = true;
    lastRequestTimeRef.current = now;

    try {
      const startTime = Date.now();
      const { data, error } = await supabase.functions.invoke('coach-suggestion', {
        body: {
          transcription: req.transcription,
          phase_name: req.phaseName,
          phase_description: req.phaseDescription,
          phase_checklist: req.phaseChecklist || [],
          playbook_context: req.leadContext || '',
        },
      });
      const latency = Date.now() - startTime;
      console.log(`[GeminiCoach] Server response in ${latency}ms`);
      if (error || !data?.has_suggestion) return { has_suggestion: false };
      return data as CoachResponse;
    } catch (err: any) {
      console.error('[GeminiCoach] Error:', err.message);
      return { has_suggestion: false };
    } finally {
      isRequestingRef.current = false;
    }
  }, []);

  return { requestCoachSuggestion };
}

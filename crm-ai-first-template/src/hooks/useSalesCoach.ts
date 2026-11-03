import { useState, useRef, useCallback, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
// Live API only supports audio models, not text. Using chat multi-turn instead.
import type {
  CoachPlaybook,
  CoachSession,
  CoachState,
  CoachSuggestion,
  CoachAlert,
  PlaybookPhase,
  ChecklistItemStatus,
  CoachSessionEvent,
  LeadBriefingData,
} from '@/types/coach.types';

interface UseSalesCoachOptions {
  playbook?: CoachPlaybook | null;
  leadId?: string;
  callId?: string;
  sellerName?: string;
  clientName?: string;
  onSuggestion?: (suggestion: CoachSuggestion) => void;
  onAlert?: (alert: CoachAlert) => void;
}

interface UseSalesCoachReturn {
  // State
  state: CoachState;
  isLoading: boolean;
  error: string | null;

  // Actions
  startSession: () => Promise<void>;
  endSession: () => Promise<void>;

  // Phase management
  nextPhase: () => void;
  previousPhase: () => void;
  goToPhase: (index: number) => void;

  // Checklist
  toggleChecklistItem: (itemId: string) => void;

  // Suggestions
  requestSuggestion: (transcription: string) => Promise<void>;
  dismissSuggestion: () => void;

  // Alerts
  dismissAlert: (alertId: string) => void;

  // Briefing
  generateBriefing: () => Promise<string | null>;

  // Helpers
  getCurrentPhase: () => PlaybookPhase | null;
  getPhaseProgress: () => { completed: number; total: number };
}

const SUGGESTION_COOLDOWN_MS = 1000; // 1 second between suggestions

// Debug logging
const LOG_PREFIX = '[SalesCoach]';
const DEBUG = true;

function log(...args: any[]) {
  if (DEBUG) console.log(LOG_PREFIX, ...args);
}

function logWarn(...args: any[]) {
  if (DEBUG) console.warn(LOG_PREFIX, ...args);
}

function logError(...args: any[]) {
  console.error(LOG_PREFIX, ...args);
}

export function useSalesCoach(options: UseSalesCoachOptions): UseSalesCoachReturn {
  const { playbook, leadId, callId, sellerName, clientName, onSuggestion, onAlert } = options;
  const [state, setState] = useState<CoachState>({
    isActive: false,
    currentPhaseIndex: 0,
    checklistState: {},
    suggestionHistory: [],
    activeAlerts: [],
    phasesCompleted: 0,
    alertsTriggered: 0,
    suggestionsShown: 0,
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sessionIdRef = useRef<string | null>(null);
  const lastSuggestionTimeRef = useRef<number>(0);
  const isActiveRef = useRef(false);
  const isRequestingRef = useRef(false);
  const eventsRef = useRef<CoachSessionEvent[]>([]);
  const playbookRef = useRef(playbook);

  // Manter refs atualizados
  useEffect(() => {
    playbookRef.current = playbook;
  }, [playbook]);

  useEffect(() => {
    isActiveRef.current = state.isActive;
  }, [state.isActive]);

  // Initialize state when playbook changes
  useEffect(() => {
    if (playbook) {
      log('📚 Playbook carregado:', playbook.name, '|', playbook.phases?.length, 'fases');
      setState((prev) => ({
        ...prev,
        playbook,
        currentPhaseIndex: 0,
        checklistState: {},
      }));
    }
  }, [playbook]);

  // Log de inicialização (apenas na primeira montagem com playbook)
  const hasLoggedInitRef = useRef(false);
  useEffect(() => {
    if (playbook && !hasLoggedInitRef.current) {
      hasLoggedInitRef.current = true;
      log('🎬 Hook inicializado com playbook', {
        playbookName: playbook?.name,
        leadId,
        callId,
      });
    }
  }, [playbook, leadId, callId]);

  // Add event to history
  const addEvent = useCallback((type: CoachSessionEvent['type'], data: Record<string, unknown>) => {
    const event: CoachSessionEvent = {
      id: Math.random().toString(36).substring(2, 9),
      type,
      timestamp: new Date().toISOString(),
      data,
    };
    eventsRef.current = [...eventsRef.current, event];
    return event;
  }, []);

  // Start a new coaching session
  const startSession = useCallback(async () => {
    // Usar ref para pegar valor mais atual do playbook
    const currentPlaybook = playbookRef.current;

    log('▶️ startSession chamado', { hasPlaybook: !!currentPlaybook, playbookName: currentPlaybook?.name });

    if (!currentPlaybook) {
      log('📝 Modo transcrição (sem playbook)');
      setState((prev) => ({
        ...prev,
        isActive: true,
        startedAt: new Date().toISOString(),
      }));
      return;
    }

    log('📋 Iniciando sessão com playbook:', currentPlaybook.name);
    log('📋 Fases do playbook:', currentPlaybook.phases?.map(p => p.name));
    log('📋 Fase 1 checklist:', currentPlaybook.phases?.[0]?.checklist);

    setIsLoading(true);
    setError(null);

    try {
      const { data: user } = await supabase.auth.getUser();
      const { data: teamMember } = await supabase
        .from('team_members')
        .select('id')
        .eq('auth_user_id', user.user?.id)
        .maybeSingle();

      // call_id FK references call_history — only pass if it's a real call, not a meeting
      const { data: session, error: sessionError } = await supabase
        .from('coach_sessions')
        .insert({
          playbook_id: currentPlaybook.id,
          lead_id: leadId || null,
          team_member_id: teamMember?.id || null,
          current_phase_index: 0,
          checklist_state: {},
          events: [],
          started_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (sessionError) throw sessionError;

      sessionIdRef.current = session.id;

      setState((prev) => ({
        ...prev,
        isActive: true,
        sessionId: session.id,
        playbook: currentPlaybook,
        currentPhaseIndex: 0,
        checklistState: {},
        suggestionHistory: [],
        activeAlerts: [],
        phasesCompleted: 0,
        alertsTriggered: 0,
        suggestionsShown: 0,
        startedAt: new Date().toISOString(),
      }));

      addEvent('phase_change', { phaseIndex: 0, phaseName: currentPlaybook.phases[0]?.name });

      log('✅ Sessão iniciada com sucesso', {
        sessionId: session.id,
        playbookName: currentPlaybook.name,
        firstPhaseName: currentPlaybook.phases[0]?.name,
        checklistItems: currentPlaybook.phases[0]?.checklist?.length,
      });

      log('🤖 Chat multi-turn pronto (memória nativa)');
    } catch (err: any) {
      logError('❌ Erro ao iniciar sessão:', err);
      setError(err.message || 'Erro ao iniciar sessão');
    } finally {
      setIsLoading(false);
    }
  }, [leadId, addEvent]); // Removido playbook das deps - usamos ref

  // End the coaching session
  const endSession = useCallback(async () => {
    if (sessionIdRef.current) {
      try {
        await supabase
          .from('coach_sessions')
          .update({
            ended_at: new Date().toISOString(),
            events: eventsRef.current,
            phases_completed: state.phasesCompleted,
            alerts_triggered: state.alertsTriggered,
            suggestions_shown: state.suggestionsShown,
            checklist_state: state.checklistState,
            current_phase_index: state.currentPhaseIndex,
          })
          .eq('id', sessionIdRef.current);
      } catch (err) {
        console.error('Error ending coach session:', err);
      }
    }

    setState({
      isActive: false,
      currentPhaseIndex: 0,
      checklistState: {},
      suggestionHistory: [],
      activeAlerts: [],
      phasesCompleted: 0,
      alertsTriggered: 0,
      suggestionsShown: 0,
    });

    sessionIdRef.current = null;
    eventsRef.current = [];
  }, [state]);

  // Phase management
  const nextPhase = useCallback(() => {
    const currentPlaybook = playbookRef.current;
    if (!currentPlaybook) return;
    const nextIndex = Math.min(state.currentPhaseIndex + 1, currentPlaybook.phases.length - 1);
    if (nextIndex !== state.currentPhaseIndex) {
      addEvent('phase_change', {
        fromPhase: state.currentPhaseIndex,
        toPhase: nextIndex,
        phaseName: currentPlaybook.phases[nextIndex].name,
      });
      setState((prev) => ({
        ...prev,
        currentPhaseIndex: nextIndex,
        phasesCompleted: prev.phasesCompleted + 1,
      }));
    }
  }, [state.currentPhaseIndex, addEvent]);

  const previousPhase = useCallback(() => {
    const prevIndex = Math.max(state.currentPhaseIndex - 1, 0);
    if (prevIndex !== state.currentPhaseIndex) {
      setState((prev) => ({
        ...prev,
        currentPhaseIndex: prevIndex,
      }));
    }
  }, [state.currentPhaseIndex]);

  const goToPhase = useCallback((index: number) => {
    const currentPlaybook = playbookRef.current;
    if (!currentPlaybook || index < 0 || index >= currentPlaybook.phases.length) return;
    if (index !== state.currentPhaseIndex) {
      addEvent('phase_change', {
        fromPhase: state.currentPhaseIndex,
        toPhase: index,
        phaseName: currentPlaybook.phases[index].name,
      });
      setState((prev) => ({
        ...prev,
        currentPhaseIndex: index,
      }));
    }
  }, [state.currentPhaseIndex, addEvent]);

  // Checklist management
  const toggleChecklistItem = useCallback((itemId: string) => {
    log('✅ toggleChecklistItem:', itemId);

    setState((prev) => {
      const currentStatus = prev.checklistState[itemId];
      const newStatus: ChecklistItemStatus = currentStatus === 'completed' ? 'pending' : 'completed';

      log('  Status:', currentStatus, '->', newStatus);
      log('  ChecklistState atual:', prev.checklistState);

      addEvent('checklist_item_completed', { itemId, status: newStatus });

      return {
        ...prev,
        checklistState: {
          ...prev.checklistState,
          [itemId]: newStatus,
        },
      };
    });
  }, [addEvent]);

  // Request AI suggestion via edge function
  const requestSuggestion = useCallback(async (transcription: string) => {
    const currentPlaybook = playbookRef.current;

    log('🤖 requestSuggestion chamado', {
      hasPlaybook: !!currentPlaybook,
      isActive: state.isActive,
      transcriptionLength: transcription?.length,
    });

    if (!currentPlaybook || !isActiveRef.current) {
      log('⏭️ Pulando sugestão:', { noPlaybook: !currentPlaybook, notActive: !isActiveRef.current });
      return;
    }

    // Prevent concurrent requests
    if (isRequestingRef.current) {
      log('⏳ Request já em andamento, ignorando');
      return;
    }

    // Check cooldown
    const now = Date.now();
    const timeSinceLastSuggestion = now - lastSuggestionTimeRef.current;
    if (timeSinceLastSuggestion < SUGGESTION_COOLDOWN_MS) {
      return; // Silent skip during cooldown
    }

    isRequestingRef.current = true;

    const currentPhase = currentPlaybook.phases[state.currentPhaseIndex];
    if (!currentPhase) {
      logWarn('⚠️ Fase atual não encontrada');
      return;
    }

    log('📍 Fase atual:', currentPhase.name, '| Checklist:', currentPhase.checklist?.length, 'itens');

    // Check for alerts (triggers from playbook)
    const alerts = currentPhase.alerts || [];
    const triggeredAlerts: CoachAlert[] = [];

    log('🔍 Verificando', alerts.length, 'gatilhos de alerta...');

    for (const alertConfig of alerts) {
      if (!transcription) continue;

      // Handle both string (just trigger word) and object formats
      const isString = typeof alertConfig === 'string';
      const trigger = isString ? alertConfig : alertConfig?.trigger;

      if (!trigger) continue;

      if (transcription.toLowerCase().includes(trigger.toLowerCase())) {
        log('🚨 ALERTA DISPARADO! Gatilho:', trigger);
        const alert: CoachAlert = {
          id: Math.random().toString(36).substring(2, 9),
          message: isString
            ? `⚠️ Mencionou "${trigger}" - cuidado nesta fase!`
            : (alertConfig.message || `Alerta: ${trigger}`),
          severity: isString ? 'warning' : (alertConfig.severity || 'warning'),
          timestamp: new Date().toISOString(),
          phaseId: currentPhase.id,
          dismissed: false,
        };
        triggeredAlerts.push(alert);
        addEvent('alert_triggered', { alertId: alert.id, message: alert.message });
        onAlert?.(alert);
      }
    }

    if (triggeredAlerts.length > 0) {
      log('🚨 Total de alertas disparados:', triggeredAlerts.length);
      setState((prev) => ({
        ...prev,
        activeAlerts: [...prev.activeAlerts, ...triggeredAlerts],
        alertsTriggered: prev.alertsTriggered + triggeredAlerts.length,
      }));
    }

    try {
      lastSuggestionTimeRef.current = now;

      const checklistItems = currentPhase.checklist.map((item, i) => {
        const id = typeof item === 'string' ? `item-${i}` : (item as any).id || `item-${i}`;
        const text = typeof item === 'string' ? item : (item as any).text;
        return { id, text: text || 'Item' };
      });
      // Build checklist status: mark which items are already done
      const completedIds = checklistItems
        .filter(i => state.checklistState[i.id] === 'completed')
        .map(i => i.id);
      const startTime = Date.now();
      const { data, error: coachError } = await supabase.functions.invoke('coach-suggestion', {
        body: {
          transcription,
          phase_name: currentPhase.name,
          phase_description: currentPhase.description,
          phase_checklist: checklistItems,
          playbook_context: [
            sellerName ? `Vendedor: ${sellerName}` : '',
            clientName ? `Cliente: ${clientName}` : '',
            `Fases: ${currentPlaybook.phases.map((phase) => phase.name).join(', ')}`,
            completedIds.length ? `Checklist já concluído: ${completedIds.join(', ')}` : '',
          ].filter(Boolean).join('\n'),
          lead_id: leadId,
        },
      });

      const latency = Date.now() - startTime;
      log(`⏱️ Coach server respondeu em ${latency}ms`);
      if (coachError || !data?.has_suggestion) return;
      if (data.suggestion?.text) {
        const suggestion: CoachSuggestion = {
          id: Math.random().toString(36).substring(2, 9),
          type: data.suggestion.type || 'tip',
          text: data.suggestion.text,
          confidence: data.suggestion.confidence || 0.8,
          timestamp: new Date().toISOString(),
        };
        addEvent('suggestion_shown', { suggestionId: suggestion.id, type: suggestion.type });
        onSuggestion?.(suggestion);
        setState((prev) => ({
          ...prev,
          currentSuggestion: suggestion,
          suggestionHistory: [suggestion, ...prev.suggestionHistory].slice(0, 20),
          suggestionsShown: prev.suggestionsShown + 1,
        }));
      }

      if (data.completed_items?.length > 0) {
        // Only mark items that are actually pending AND exist in the current phase checklist
        const validIds = new Set(checklistItems.map(i => i.id));
        const newCompleted = data.completed_items.filter(
          (id: string) => validIds.has(id) && state.checklistState[id] !== 'completed'
        );
        if (newCompleted.length > 0) {
          log('✅ Auto-complete:', newCompleted);
          setState((prev) => {
            const cs = { ...prev.checklistState };
            for (const id of newCompleted) { cs[id] = 'completed'; }
            return { ...prev, checklistState: cs };
          });
        }
      }
    } catch (err) {
      logError('❌ Erro:', err);
    } finally {
      isRequestingRef.current = false;
    }
  }, [state.isActive, state.currentPhaseIndex, state.checklistState, addEvent, onAlert, sellerName, clientName, leadId, onSuggestion]); // Removido state.isActive - usamos ref

  // Dismiss current suggestion
  const dismissSuggestion = useCallback(() => {
    setState((prev) => ({
      ...prev,
      currentSuggestion: undefined,
    }));
  }, []);

  // Dismiss an alert
  const dismissAlert = useCallback((alertId: string) => {
    setState((prev) => ({
      ...prev,
      activeAlerts: prev.activeAlerts.map((a) =>
        a.id === alertId ? { ...a, dismissed: true } : a
      ),
    }));
  }, []);

  // Generate AI briefing
  const generateBriefing = useCallback(async (): Promise<string | null> => {
    if (!leadId) return null;

    const currentPlaybook = playbookRef.current;
    log('📋 generateBriefing chamado', { leadId, hasPlaybook: !!currentPlaybook });

    setIsLoading(true);
    try {
      const { data, error: fnError } = await supabase.functions.invoke('generate-briefing', {
        body: {
          lead_id: leadId,
          playbook_context: currentPlaybook?.context,
        },
      });

      if (fnError) throw fnError;

      // Format briefing from structured data to readable text
      const briefingData = data?.briefing;
      let briefingText: string | null = null;

      if (briefingData) {
        const parts = [];
        if (briefingData.who) parts.push(`👤 ${briefingData.who}`);
        if (briefingData.how_found_us) parts.push(`📍 Origem: ${briefingData.how_found_us}`);
        if (briefingData.last_conversation) parts.push(`💬 Último contato: ${briefingData.last_conversation}`);
        if (briefingData.known_objections?.length > 0) {
          parts.push(`⚠️ Objeções: ${briefingData.known_objections.join(', ')}`);
        }
        if (briefingData.interests?.length > 0) {
          parts.push(`✨ Interesses: ${briefingData.interests.join(', ')}`);
        }
        if (briefingData.opening_hook) parts.push(`🎯 Abertura: "${briefingData.opening_hook}"`);
        if (briefingData.call_objective) parts.push(`📌 Objetivo: ${briefingData.call_objective}`);

        briefingText = parts.join('\n');
      }

      if (briefingText && sessionIdRef.current) {
        await supabase
          .from('coach_sessions')
          .update({ briefing: briefingText })
          .eq('id', sessionIdRef.current);
      }

      setState((prev) => ({
        ...prev,
        briefing: briefingText,
      }));

      log('✅ Briefing gerado com sucesso:', briefingText?.substring(0, 100));
      return briefingText;
    } catch (err: any) {
      logError('❌ Erro ao gerar briefing:', err);
      setError(err.message || 'Erro ao gerar briefing');
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [leadId]); // Removido playbook das deps - usamos ref

  // Helper: Get current phase
  const getCurrentPhase = useCallback((): PlaybookPhase | null => {
    const currentPlaybook = playbookRef.current;
    if (!currentPlaybook) return null;
    return currentPlaybook.phases[state.currentPhaseIndex] || null;
  }, [state.currentPhaseIndex]);

  // Helper: Get phase progress
  const getPhaseProgress = useCallback(() => {
    const phase = getCurrentPhase();
    if (!phase) return { completed: 0, total: 0 };

    const total = phase.checklist.length;
    const completed = phase.checklist.filter((item, index) => {
      // Handle both string and object formats
      const itemId = typeof item === 'string' ? `item-${index}` : item.id;
      return state.checklistState[itemId] === 'completed';
    }).length;

    return { completed, total };
  }, [getCurrentPhase, state.checklistState]);

  return {
    state,
    isLoading,
    error,
    startSession,
    endSession,
    nextPhase,
    previousPhase,
    goToPhase,
    toggleChecklistItem,
    requestSuggestion,
    dismissSuggestion,
    dismissAlert,
    generateBriefing,
    getCurrentPhase,
    getPhaseProgress,
  };
}

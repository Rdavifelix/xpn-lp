import { QueryClient } from '@tanstack/react-query';

// QueryClient único da aplicação. Exportado daqui (e não criado em App.tsx)
// para que o AuthContext consiga limpar o cache em sign-out / troca de tenant
// sem precisar de um segundo client.
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error: any) => {
        const status = error?.status || error?.code;
        const msg = error?.message || '';
        console.warn(`[RQ] Query falhou (tentativa ${failureCount + 1}):`, status, msg);
        // Não retry em erros de auth (401/403) — recovery cuida disso
        if (status === 401 || status === 403) return false;
        // Até 3 retries com backoff para erros de rede/timeout
        return failureCount < 3;
      },
      retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
      staleTime: 30000, // 30s - evita refetch excessivo
      refetchOnWindowFocus: true, // Re-habilitado — essencial para recovery de queries que falharam
      refetchOnReconnect: true,
      gcTime: 1000 * 60 * 10, // 10 min — cache persiste mais tempo, evita loading ao voltar
    },
  },
});

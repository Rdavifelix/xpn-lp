import UnifiedInbox from './pages/UnifiedInbox';
import { SocialInbox } from '@/components/zernio/SocialInbox';
import React, { useEffect, Component, type ReactNode, type ErrorInfo } from "react";
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "@/lib/query-client";
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useLocation } from "react-router-dom";
import { AuthProvider, useAuth } from "@/contexts/AuthContext";
import { CallProvider } from "@/contexts/CallContext";
import { MeetingProvider } from "@/contexts/MeetingContext";
import { GlobalTranscriptionPanel } from "@/components/meeting/GlobalTranscriptionPanel";
import { MeetingRecoveryBanner } from "@/components/meeting/MeetingRecoveryBanner";
import { NotificationProvider } from "@/hooks/useNotifications";
import { CallModals } from "@/components/calls";
import { FocusModeProvider } from "@/contexts/FocusModeContext";
import { ThemeProvider } from "@/contexts/ThemeContext";
import { DemoModeProvider } from "@/contexts/DemoModeContext";
import { FocusModeOverlay } from "@/components/focus-mode/FocusModeOverlay";

// Error Boundary para componentes auxiliares (toast discreto)
class ErrorBoundary extends Component<{ children: ReactNode; name?: string }, { hasError: boolean; error?: Error }> {
  state = { hasError: false, error: undefined as Error | undefined };
  static getDerivedStateFromError(error: Error) { return { hasError: true, error }; }
  componentDidCatch(error: Error, info: ErrorInfo) { console.error(`[ErrorBoundary${this.props.name ? `:${this.props.name}` : ''}]`, error, info); }
  render() {
    if (this.state.hasError) {
      return (
        <div className="fixed bottom-4 right-4 z-50 bg-red-50 border border-red-200 rounded-lg p-3 max-w-sm shadow-lg">
          <p className="text-sm font-medium text-red-800">Erro no componente{this.props.name ? ` ${this.props.name}` : ''}</p>
          <p className="text-xs text-red-600 mt-1">{this.state.error?.message}</p>
          <button className="text-xs text-red-700 underline mt-2" onClick={() => this.setState({ hasError: false })}>Tentar novamente</button>
        </div>
      );
    }
    return this.props.children;
  }
}

// Error Boundary para rotas — tela cheia com reload
class RouteErrorBoundary extends Component<{ children: ReactNode }, { hasError: boolean; error?: Error }> {
  state = { hasError: false, error: undefined as Error | undefined };
  static getDerivedStateFromError(error: Error) { return { hasError: true, error }; }
  componentDidCatch(error: Error, info: ErrorInfo) { console.error('[RouteErrorBoundary]', error, info); }
  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-background p-6">
          <div className="text-center max-w-md space-y-4">
            <div className="text-4xl">:(</div>
            <h1 className="text-xl font-bold text-foreground">Algo deu errado</h1>
            <p className="text-sm text-muted-foreground">
              {this.state.error?.message || 'Erro inesperado na aplicação'}
            </p>
            <div className="flex gap-3 justify-center">
              <button
                className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm font-medium hover:bg-primary/90"
                onClick={() => this.setState({ hasError: false })}
              >
                Tentar novamente
              </button>
              <button
                className="px-4 py-2 bg-muted text-foreground rounded-md text-sm font-medium hover:bg-muted/80"
                onClick={() => window.location.reload()}
              >
                Recarregar pagina
              </button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

// Auth pages
import Login from "./pages/Login";
import McpConsent from "./pages/McpConsent";
import McpConnect from "./pages/McpConnect";
import TenantOnboarding from "./pages/TenantOnboarding";
import ForgotPassword from "./pages/ForgotPassword";
import ResetPassword from "./pages/ResetPassword";
import NotFound from "./pages/NotFound";

// Settings unificada + WhatsApp
import SettingsUnified from "./pages/SettingsUnified";
const MyWhatsApp = React.lazy(() => import("./pages/MyWhatsApp"));

// Sales/Commercial pages (core CRM)
import SalesDashboard from "./pages/SalesDashboardV3";
import SalesLeads from "./pages/SalesLeads";
import SalesPipeline from "./pages/SalesPipeline";
import SalesDeals from "./pages/SalesDeals";
import SalesWhatsAppInbox from "./pages/SalesWhatsAppInbox";
import SalesLeadDetail from "./pages/SalesLeadDetail";
import SalesDealDetail from "./pages/SalesDealDetail";
import Products from "./pages/Products";
import Commissions from "./pages/Commissions";
import SalesPlaybook from "./pages/SalesPlaybook";
import SalesWorkspace from "./pages/SalesWorkspace";
import SalesAgenda from "./pages/SalesAgendaV2";
import SocialSellingConfig from "./pages/SocialSellingConfig";
import SalesMaterialsConfig from "./pages/SalesMaterialsConfig";

// Módulo Marketing (lazy)
const MarketingDashboard = React.lazy(() => import("./pages/MarketingDashboard"));
const EmailMarketingHub = React.lazy(() => import("./pages/EmailMarketingHub"));
const EmailCampaignDetail = React.lazy(() => import("./pages/EmailCampaignDetail"));
const EmailTemplates = React.lazy(() => import("./pages/EmailTemplates"));
const EmailTemplateEditor = React.lazy(() => import("./pages/EmailTemplateEditor"));
const MarketingAutomations = React.lazy(() => import("./pages/marketing/MarketingAutomations"));
const MarketingAutomationEditor = React.lazy(() => import("./pages/marketing/MarketingAutomationEditor"));
const MarketingPages = React.lazy(() => import("./pages/MarketingPages"));
const SocialCommand = React.lazy(() => import("./pages/SocialCommand"));
const MarketingForms = React.lazy(() => import("./pages/MarketingForms"));
const FormEmbed = React.lazy(() => import("./pages/public/FormEmbed"));
const CommunityRedirect = React.lazy(() => import("./pages/public/CommunityRedirect"));
const CanaisEntrada = React.lazy(() => import("./pages/CanaisEntrada"));
const MetaLeadAds = React.lazy(() => import("./pages/MetaLeadAds"));
const ImportLeads = React.lazy(() => import("./pages/ImportLeads"));
const WhatsAppTemplates = React.lazy(() => import("./pages/WhatsAppTemplates"));
const WhatsAppTemplateNew = React.lazy(() => import("./pages/WhatsAppTemplateNew"));
const SalesCampaigns = React.lazy(() => import("./pages/SalesCampaigns"));
const SalesCampaignNew = React.lazy(() => import("./pages/SalesCampaignNew"));
const SalesCampaignDetail = React.lazy(() => import("./pages/SalesCampaignDetail"));
const Unsubscribe = React.lazy(() => import("./pages/public/Unsubscribe"));

// Agents Platform (lazy)
const AgentList = React.lazy(() => import("./agents-platform/pages/AgentList"));
const AgentConfigPage = React.lazy(() => import("./agents-platform/pages/AgentConfigPage"));
const AgentChatPage = React.lazy(() => import("./agents-platform/pages/AgentChatPage"));
const AgentPlaygroundPage = React.lazy(() => import("./agents-platform/pages/AgentPlaygroundPage"));
const AgentSkillsLibraryPage = React.lazy(() => import("./agents-platform/pages/AgentSkillsLibraryPage"));
const SaasAIAdminPage = React.lazy(() => import("./agents-platform/pages/SaasAIAdminPage"));
const PlatformTenantsPage = React.lazy(() => import("./pages/PlatformTenantsPage"));
const AgentCredentialsPage = React.lazy(() => import("./agents-platform/pages/AgentCredentialsPage"));
const AgentSessionsPage = React.lazy(() => import("./agents-platform/pages/AgentSessionsPage"));
const AgentMetricsPage = React.lazy(() => import("./agents-platform/pages/AgentMetricsPage"));
const AgentOrgChartPage = React.lazy(() => import("./agents-platform/pages/AgentOrgChartPage"));

// Módulo Prospecção (lazy)
const ProspeccaoSearch = React.lazy(() => import("./modules/prospeccao/pages/ProspeccaoSearch"));
const ProspeccaoDescobertos = React.lazy(() => import("./modules/prospeccao/pages/ProspeccaoDescobertos"));
const ProspeccaoDiagnostico = React.lazy(() => import("./modules/prospeccao/pages/ProspeccaoDiagnostico"));
const ProspeccaoDiagnosticoPrint = React.lazy(() => import("./modules/prospeccao/pages/ProspeccaoDiagnosticoPrint"));
const ProspeccaoConfiguracoes = React.lazy(() => import("./modules/prospeccao/pages/ProspeccaoConfiguracoes"));
import SalesTraining from "./pages/SalesTraining";
import CockpitShell from "./pages/CockpitShell";

// Gestão básica
import TaskManagement from "./pages/TaskManagement";
import TeamCalendar from "./pages/TeamCalendar";
import TeamMeetings from "./pages/TeamMeetings";

// Public booking
const BookMeeting = React.lazy(() => import("./pages/BookMeeting"));


function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, teamMember, loading, isPasswordRecovery } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

  // If user is in password recovery mode, redirect to reset page
  if (isPasswordRecovery) {
    return <Navigate to="/reset-password" replace />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (!teamMember?.is_active || !teamMember.tenant_id || teamMember.auth_user_id !== user.id || teamMember.tenant_id !== user.app_metadata?.tenant_id) {
    return <Navigate to="/criar-empresa" replace />;
  }

  return <>{children}</>;
}

// Escuta eventos 'app-navigate' disparados de fora do BrowserRouter (ex: notificações)
// e faz navegação client-side sem recarregar a página (preserva chamadas WaVoIP ativas)
const NavigationListener = () => {
  const navigate = useNavigate();
  useEffect(() => {
    const handler = (e: Event) => {
      const url = (e as CustomEvent<string>).detail;
      if (url) navigate(url);
    };
    window.addEventListener('app-navigate', handler);
    return () => window.removeEventListener('app-navigate', handler);
  }, [navigate]);
  return null;
};

const AppRoutes = () => {
  return (
    <Routes>
      {/* Rotas públicas */}
      <Route path="/login" element={<Login />} />
      <Route path="/imersao" element={<Navigate to="/login?cadastro=1" replace />} />
      <Route path="/criar-empresa" element={<TenantOnboarding />} />
      <Route path="/oauth/consent" element={<McpConsent />} />
      <Route path="/conectar-ia" element={<ProtectedRoute><McpConnect /></ProtectedRoute>} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/reset-password" element={<ResetPassword />} />
      {/* /agendar usa o token da instalação (env); /agendar/:token é o link público por empresa */}
      {["/agendar", "/agendar/:token"].map((path) => (
        <Route key={path} path={path} element={
          <React.Suspense fallback={<div className="min-h-screen bg-gray-50 flex items-center justify-center"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div></div>}>
            <BookMeeting />
          </React.Suspense>
        } />
      ))}
      {/* Formulário público de captação (embed) — SEM autenticação */}
      <Route path="/form/:id" element={
        <React.Suspense fallback={<div className="min-h-screen bg-gray-50 flex items-center justify-center"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div></div>}>
          <FormEmbed />
        </React.Suspense>
      } />
      <Route path="/c/:slug" element={
        <React.Suspense fallback={<div />}><CommunityRedirect /></React.Suspense>
      } />

      {/* Home → Dashboard Comercial */}
      <Route path="/" element={<Navigate to="/comercial" replace />} />

      {/* Configurações */}
      <Route path="/configuracoes" element={<ProtectedRoute><SettingsUnified /></ProtectedRoute>} />
      <Route path="/settings" element={<Navigate to="/configuracoes" replace />} />
      <Route path="/whatsapp" element={<Navigate to="/configuracoes?s=whatsapp" replace />} />
      <Route path="/meu-whatsapp" element={<ProtectedRoute><React.Suspense fallback={<div />}><MyWhatsApp /></React.Suspense></ProtectedRoute>} />

      {/* Sales/Commercial routes */}
      <Route path="/comercial/cockpit" element={<ProtectedRoute><CockpitShell /></ProtectedRoute>} />
      <Route path="/comercial/meu-dia" element={<Navigate to="/comercial/cockpit" replace />} />
      <Route path="/comercial/agenda" element={<ProtectedRoute><SalesAgenda /></ProtectedRoute>} />
      <Route path="/comercial" element={<ProtectedRoute><SalesDashboard /></ProtectedRoute>} />
      <Route path="/comercial/workspace" element={<ProtectedRoute><SalesWorkspace /></ProtectedRoute>} />
      <Route path="/comercial/leads" element={<ProtectedRoute><SalesLeads /></ProtectedRoute>} />
      <Route path="/comercial/leads/:id" element={<ProtectedRoute><SalesLeadDetail /></ProtectedRoute>} />
      <Route path="/comercial/pipeline" element={<ProtectedRoute><SalesPipeline /></ProtectedRoute>} />
      <Route path="/comercial/deals" element={<ProtectedRoute><SalesDeals /></ProtectedRoute>} />
      <Route path="/comercial/deals/:id" element={<ProtectedRoute><SalesDealDetail /></ProtectedRoute>} />
      <Route path="/comercial/inbox/social-tools" element={<ProtectedRoute><SocialInbox /></ProtectedRoute>} />
      <Route path="/comercial/inbox/whatsapp" element={<ProtectedRoute><SalesWhatsAppInbox /></ProtectedRoute>} />
      <Route path="/comercial/inbox" element={<ProtectedRoute><SocialInboxRoute /></ProtectedRoute>} />
      <Route path="/configuracoes/social-selling" element={<ProtectedRoute><SocialSellingConfig /></ProtectedRoute>} />
      <Route path="/comercial/relatorios" element={<Navigate to="/comercial?tab=gestao" replace />} />
      <Route path="/comercial/produtos" element={<ProtectedRoute><Products /></ProtectedRoute>} />
      <Route path="/comercial/comissoes" element={<ProtectedRoute><Commissions /></ProtectedRoute>} />
      <Route path="/comercial/playbook" element={<ProtectedRoute><SalesPlaybook /></ProtectedRoute>} />
      <Route path="/comercial/configuracoes" element={<Navigate to="/configuracoes?s=pipeline" replace />} />
      <Route path="/comercial/materiais" element={<ProtectedRoute><SalesMaterialsConfig /></ProtectedRoute>} />
      <Route path="/comercial/treinamento" element={<ProtectedRoute><SalesTraining /></ProtectedRoute>} />
      <Route path="/comercial/agente-ia" element={<Navigate to="/configuracoes?s=agente-ia" replace />} />

      {/* ── Marketing Email ────────────────────────────────────────────── */}
      <Route path="/marketing" element={<ProtectedRoute><React.Suspense fallback={<div />}><MarketingDashboard /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/campanhas" element={<ProtectedRoute><React.Suspense fallback={<div />}><EmailMarketingHub /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/campanhas/:id" element={<ProtectedRoute><React.Suspense fallback={<div />}><EmailCampaignDetail /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/templates" element={<ProtectedRoute><React.Suspense fallback={<div />}><EmailTemplates /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/templates/:id" element={<ProtectedRoute><React.Suspense fallback={<div />}><EmailTemplateEditor /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/automacoes" element={<ProtectedRoute><React.Suspense fallback={<div />}><MarketingAutomations /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/automacoes/nova" element={<ProtectedRoute><React.Suspense fallback={<div />}><MarketingAutomationEditor /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/automacoes/:id" element={<ProtectedRoute><React.Suspense fallback={<div />}><MarketingAutomationEditor /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/paginas" element={<ProtectedRoute><React.Suspense fallback={<div />}><MarketingPages /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/redes" element={<ProtectedRoute><React.Suspense fallback={<div />}><SocialCommand /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/formularios" element={<ProtectedRoute><React.Suspense fallback={<div />}><MarketingForms /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/canais-entrada" element={<ProtectedRoute><React.Suspense fallback={<div />}><CanaisEntrada /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/lead-ads" element={<ProtectedRoute><React.Suspense fallback={<div />}><MetaLeadAds /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/importar" element={<ProtectedRoute><React.Suspense fallback={<div />}><ImportLeads /></React.Suspense></ProtectedRoute>} />

      {/* ── Marketing WhatsApp ────────────────────────────────────────── */}
      <Route path="/marketing/whatsapp-templates" element={<ProtectedRoute><React.Suspense fallback={<div />}><WhatsAppTemplates /></React.Suspense></ProtectedRoute>} />
      <Route path="/marketing/whatsapp-templates/novo" element={<ProtectedRoute><React.Suspense fallback={<div />}><WhatsAppTemplateNew /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/campanhas" element={<ProtectedRoute><React.Suspense fallback={<div />}><SalesCampaigns /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/campanhas/nova" element={<ProtectedRoute><React.Suspense fallback={<div />}><SalesCampaignNew /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/campanhas/:id" element={<ProtectedRoute><React.Suspense fallback={<div />}><SalesCampaignDetail /></React.Suspense></ProtectedRoute>} />

      {/* ── Públicas (LGPD) ───────────────────────────────────────────── */}
      <Route path="/unsubscribe" element={<React.Suspense fallback={<div />}><Unsubscribe /></React.Suspense>} />

      {/* Módulo Prospecção (isolado) */}
      <Route path="/comercial/prospeccao" element={<ProtectedRoute><React.Suspense fallback={<div />}><ProspeccaoSearch /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/prospeccao/busca/:buscaId" element={<ProtectedRoute><React.Suspense fallback={<div />}><ProspeccaoDescobertos /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/prospeccao/diagnostico/:diagnosticoId" element={<ProtectedRoute><React.Suspense fallback={<div />}><ProspeccaoDiagnostico /></React.Suspense></ProtectedRoute>} />
      <Route path="/comercial/prospeccao/diagnostico/:diagnosticoId/print" element={<React.Suspense fallback={<div />}><ProspeccaoDiagnosticoPrint /></React.Suspense>} />
      <Route path="/comercial/prospeccao/configuracoes" element={<ProtectedRoute><React.Suspense fallback={<div />}><ProspeccaoConfiguracoes /></React.Suspense></ProtectedRoute>} />

      {/* ── Agents Platform ───────────────────────────────────────────── */}
      {/* Redirects de URLs antigas (/plataforma/agentes → /agentes) */}
      <Route path="/plataforma/agentes" element={<Navigate to="/agentes" replace />} />
      <Route path="/plataforma/agentes/habilidades" element={<Navigate to="/agentes/habilidades" replace />} />
      <Route path="/plataforma/agentes/credenciais" element={<Navigate to="/agentes/credenciais" replace />} />
      <Route path="/plataforma/agentes/organograma" element={<Navigate to="/agentes/organograma" replace />} />
      <Route path="/plataforma/agentes/sessoes" element={<Navigate to="/agentes/sessoes" replace />} />
      <Route path="/plataforma/agentes/metricas" element={<Navigate to="/agentes/metricas" replace />} />
      <Route path="/plataforma/agentes/playground" element={<Navigate to="/agentes/playground" replace />} />
      <Route path="/agentes" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentList /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/habilidades" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentSkillsLibraryPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/superadmin/ia" element={<ProtectedRoute><React.Suspense fallback={<div />}><SaasAIAdminPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/superadmin/empresas" element={<ProtectedRoute><React.Suspense fallback={<div />}><PlatformTenantsPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/credenciais" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentCredentialsPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/organograma" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentOrgChartPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/sessoes" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentSessionsPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/metricas" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentMetricsPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/playground" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentPlaygroundPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/:slug" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentConfigPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/:slug/config" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentConfigPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/:slug/chat" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentChatPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/:slug/playground" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentPlaygroundPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/:slug/sessoes" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentSessionsPage /></React.Suspense></ProtectedRoute>} />
      <Route path="/agentes/:slug/metricas" element={<ProtectedRoute><React.Suspense fallback={<div />}><AgentMetricsPage /></React.Suspense></ProtectedRoute>} />

      {/* Gestão básica (tarefas, calendário, reuniões) */}
      <Route path="/gestao/tarefas" element={<ProtectedRoute><TaskManagement /></ProtectedRoute>} />
      <Route path="/gestao/calendario" element={<ProtectedRoute><TeamCalendar /></ProtectedRoute>} />
      <Route path="/gestao/reunioes" element={<ProtectedRoute><TeamMeetings /></ProtectedRoute>} />

      <Route path="*" element={<NotFound />} />
    </Routes>
  );
};

const App = () => (
  <ThemeProvider>
    <QueryClientProvider client={queryClient}>
      <DemoModeProvider>
    <AuthProvider>
      <CallProvider>
        <MeetingProvider>
          <NotificationProvider>
            <TooltipProvider>
              <Toaster />
              <Sonner />
              <BrowserRouter>
                <NavigationListener />
                <FocusModeProvider>
                  <ErrorBoundary name="Calls"><CallModals /></ErrorBoundary>
                  <ErrorBoundary name="Meeting"><GlobalTranscriptionPanel /><MeetingRecoveryBanner /></ErrorBoundary>
                  <FocusModeOverlay />
                  <RouteErrorBoundary><AppRoutes /></RouteErrorBoundary>
                </FocusModeProvider>
              </BrowserRouter>
            </TooltipProvider>
          </NotificationProvider>
        </MeetingProvider>
      </CallProvider>
    </AuthProvider>
      </DemoModeProvider>
    </QueryClientProvider>
  </ThemeProvider>
);

export default App;

function SocialInboxRoute(){ return <UnifiedInbox />; }

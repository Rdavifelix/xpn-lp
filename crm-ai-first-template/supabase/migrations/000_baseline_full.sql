-- ============================================================
-- CRM AI-FIRST · BASELINE COMPLETO DO BANCO (IDEMPOTENTE)
-- Gerado em: 2026-05-28 via pg_dump (schema-only)
-- Baseline completo do CRM (schema + functions + policies)
--
-- Conteúdo:
-- ✅ 173 tabelas         (CREATE TABLE IF NOT EXISTS)
-- ✅ 103 funções/RPCs    (CREATE OR REPLACE FUNCTION)
-- ✅ 381 indexes         (CREATE INDEX IF NOT EXISTS)
-- ✅ 75 triggers         (DROP IF EXISTS + CREATE)
-- ✅ 533 RLS policies    (DROP IF EXISTS + CREATE)
-- ✅ 15 enum types       (DO block com EXCEPTION)
-- ✅ FKs/constraints     (DO block com EXCEPTION)
-- ✅ Views, sequences, extensions
--
-- 🔒 IDEMPOTENTE — pode rodar VÁRIAS vezes em banco existente
--    sem quebrar. Tabelas que já existem ficam intactas (dados
--    preservados), tabelas faltando são criadas, RPCs/triggers/
--    policies são substituídas pela versão atual.
--
-- SEM DADOS — só estrutura.
--
-- Como aplicar:
--   Opção 1 (recomendada): Supabase Dashboard → SQL Editor → cola tudo → Run
--   Opção 2: psql "$DATABASE_URL" -f este_arquivo
--   Opção 3: salva em supabase/migrations/000_baseline_full.sql + db push
-- ============================================================

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION pg_cron; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL';


--
-- Name: pg_net; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA public;


--
-- Name: EXTENSION pg_net; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_net IS 'Async HTTP';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: contact_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.contact_status AS ENUM (
    'lead',
    'qualified',
    'customer',
    'churned'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: contact_type; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.contact_type AS ENUM (
    'person',
    'company'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: cs_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.cs_status AS ENUM (
    'active',
    'paused',
    'churned'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: health_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.health_status AS ENUM (
    'healthy',
    'alert',
    'risk'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: interaction_type; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.interaction_type AS ENUM (
    'call',
    'message',
    'email',
    'meeting',
    'support',
    'feedback',
    'other'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: journey_stage; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.journey_stage AS ENUM (
    'pending_onboard',
    'onboarding',
    'monitoring_7d',
    'ongoing',
    'at_risk',
    'churned'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: member_role; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.member_role AS ENUM (
    'owner',
    'admin',
    'member',
    'viewer',
    'sponsor',
    'champion',
    'executor'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: member_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.member_status AS ENUM (
    'active',
    'invited',
    'inactive',
    'removed'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: objective_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.objective_status AS ENUM (
    'pending',
    'in_progress',
    'completed',
    'cancelled'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: onboarding_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.onboarding_status AS ENUM (
    'pending',
    'in_progress',
    'completed',
    'skipped'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: organization_status; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.organization_status AS ENUM (
    'active',
    'churned',
    'paused',
    'trial'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: organization_type; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.organization_type AS ENUM (
    'individual',
    'company',
    'agency'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: sentiment; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.sentiment AS ENUM (
    'positive',
    'neutral',
    'negative'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: touchpoint_channel; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.touchpoint_channel AS ENUM (
    'whatsapp',
    'zoom',
    'email',
    'phone',
    'in_app',
    'other'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: touchpoint_type; Type: TYPE; Schema: public; Owner: -
--

DO $idem$ BEGIN
  CREATE TYPE public.touchpoint_type AS ENUM (
    'onboarding',
    'checkin',
    'support',
    'training',
    'review',
    'renewal',
    'other'
);
EXCEPTION WHEN duplicate_object THEN null; END $idem$;


--
-- Name: _audit_deal_stage_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public._audit_deal_stage_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
    INSERT INTO _deal_stage_audit (deal_id, old_stage_id, new_stage_id, old_stage_name, new_stage_name)
    SELECT 
      NEW.id,
      OLD.pipeline_stage_id,
      NEW.pipeline_stage_id,
      (SELECT name FROM sales_pipeline_stages WHERE id = OLD.pipeline_stage_id),
      (SELECT name FROM sales_pipeline_stages WHERE id = NEW.pipeline_stage_id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: acted_targets_for_lead(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.acted_targets_for_lead(p_lead_id uuid, p_action text DEFAULT NULL::text) RETURNS SETOF text
    LANGUAGE sql STABLE
    AS $$
  SELECT DISTINCT instagram_target
  FROM social_selling_interactions
  WHERE lead_id = p_lead_id AND status = 'success'
    AND instagram_target IS NOT NULL
    AND (p_action IS NULL OR action_type = p_action)
$$;


--
-- Name: actions_today(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.actions_today(p_tenant_id uuid, p_action text DEFAULT NULL::text) RETURNS integer
    LANGUAGE sql STABLE
    AS $$
  SELECT COUNT(*)::int
  FROM social_selling_interactions i
  JOIN leads l ON l.id = i.lead_id
  WHERE l.tenant_id = p_tenant_id AND i.status = 'success'
    AND i.created_at >= date_trunc('day', now())
    AND (p_action IS NULL OR i.action_type = p_action)
$$;


--
-- Name: already_acted(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.already_acted(p_lead_id uuid, p_action text, p_target text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT EXISTS(
    SELECT 1 FROM social_selling_interactions
    WHERE lead_id = p_lead_id AND action_type = p_action
      AND instagram_target = p_target AND status = 'success'
  )
$$;


--
-- Name: assign_conversation_agent(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.assign_conversation_agent(p_conversation_key text, p_agent_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE cs_inbox_metrics SET
    assigned_agent_id = p_agent_id,
    assigned_at = NOW(),
    updated_at = NOW()
  WHERE conversation_key = p_conversation_key;
END;
$$;


--
-- Name: ativar_leads_no_playbook(uuid[], integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.ativar_leads_no_playbook(lead_ids uuid[], max_leads integer DEFAULT 20) RETURNS TABLE(id uuid, name text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_tid uuid;
BEGIN
  v_tid := (SELECT public.get_tenant_id());
  RETURN QUERY
  UPDATE leads l
  SET
    acao_de_hoje = 'ENVIAR_MENSAGEM',
    etapa_funil = 'novo',
    dia_do_playbook = 1,
    tentativas_de_contato = 0,
    status_de_resposta = 'NAO_RESPONDEU',
    ultima_acao = NULL
  WHERE l.id = ANY(lead_ids)
    AND l.tenant_id = v_tid
    AND l.acao_de_hoje IN ('AGUARDAR', 'ENCERRAR')
    AND NOT EXISTS (SELECT 1 FROM organizations o WHERE o.primary_contact_id = l.id AND o.tenant_id = v_tid)
    AND NOT EXISTS (SELECT 1 FROM deals d WHERE d.lead_id = l.id AND d.status = 'won' AND d.tenant_id = v_tid)
  RETURNING l.id, l.name;
END;
$$;


--
-- Name: auto_clear_handled_on_new_message(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.auto_clear_handled_on_new_message() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.is_from_me = false THEN
    IF NEW.lead_id IS NOT NULL THEN
      DELETE FROM cs_conversation_handled WHERE lead_id = NEW.lead_id AND tenant_id = NEW.tenant_id;
    ELSIF NEW.group_id IS NOT NULL THEN
      DELETE FROM cs_conversation_handled WHERE group_id = NEW.group_id AND tenant_id = NEW.tenant_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: auto_move_deal_to_em_contato(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.auto_move_deal_to_em_contato(p_lead_id uuid, p_tenant_id uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_deal RECORD;
  v_em_contato_stage_id UUID;
  v_tid UUID;
BEGIN
  v_tid := COALESCE(p_tenant_id, (SELECT public.get_tenant_id()));

  FOR v_deal IN
    SELECT d.id as deal_id, sps.pipeline_id
    FROM deals d
    JOIN sales_pipeline_stages sps ON sps.id = d.pipeline_stage_id
    WHERE d.lead_id = p_lead_id
      AND d.tenant_id = v_tid
      AND sps.position = 1
      AND d.status NOT IN ('won', 'lost')
  LOOP
    SELECT id INTO v_em_contato_stage_id
    FROM sales_pipeline_stages
    WHERE pipeline_id = v_deal.pipeline_id
      AND tenant_id = v_tid
      AND position = 2;

    IF v_em_contato_stage_id IS NOT NULL THEN
      UPDATE deals
      SET pipeline_stage_id = v_em_contato_stage_id, updated_at = NOW()
      WHERE id = v_deal.deal_id AND tenant_id = v_tid;
    END IF;
  END LOOP;
END;
$$;


--
-- Name: bulk_transfer_deals(uuid, uuid, uuid, uuid, boolean, uuid, uuid, uuid, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.bulk_transfer_deals(p_tenant_id uuid, p_source_pipeline_id uuid DEFAULT NULL::uuid, p_source_stage_id uuid DEFAULT NULL::uuid, p_source_sales_rep_id uuid DEFAULT NULL::uuid, p_include_no_rep boolean DEFAULT false, p_target_sales_rep_id uuid DEFAULT NULL::uuid, p_target_stage_id uuid DEFAULT NULL::uuid, p_target_pipeline_id uuid DEFAULT NULL::uuid, p_transfer_leads_too boolean DEFAULT true, p_transferred_by text DEFAULT 'Gestor'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_deal RECORD;
  v_count INT := 0;
  v_deal_ids UUID[] := '{}';
  v_lead_ids UUID[] := '{}';
BEGIN
  FOR v_deal IN
    SELECT d.id AS deal_id, d.lead_id, d.sales_rep_id AS old_rep_id,
           l.name AS lead_name,
           tm_old.name AS old_rep_name
    FROM deals d
    LEFT JOIN leads l ON l.id = d.lead_id
    LEFT JOIN team_members tm_old ON tm_old.id = d.sales_rep_id
    WHERE d.tenant_id = p_tenant_id
      AND d.status NOT IN ('won', 'lost')
      AND (p_source_pipeline_id IS NULL OR d.pipeline_id = p_source_pipeline_id)
      AND (p_source_stage_id IS NULL OR d.pipeline_stage_id = p_source_stage_id)
      AND (
        -- No rep filter = all deals
        (p_source_sales_rep_id IS NULL AND p_include_no_rep = FALSE)
        -- Specific rep
        OR (p_source_sales_rep_id IS NOT NULL AND d.sales_rep_id = p_source_sales_rep_id)
        -- Only deals without rep
        OR (p_include_no_rep = TRUE AND d.sales_rep_id IS NULL)
      )
  LOOP
    UPDATE deals SET
      sales_rep_id = COALESCE(p_target_sales_rep_id, sales_rep_id),
      pipeline_stage_id = COALESCE(p_target_stage_id, pipeline_stage_id),
      pipeline_id = COALESCE(p_target_pipeline_id, pipeline_id),
      updated_at = now()
    WHERE id = v_deal.deal_id;

    IF p_transfer_leads_too AND v_deal.lead_id IS NOT NULL THEN
      UPDATE leads SET
        sales_rep_id = COALESCE(p_target_sales_rep_id, sales_rep_id),
        pipeline_stage_id = COALESCE(p_target_stage_id, pipeline_stage_id),
        updated_at = now()
      WHERE id = v_deal.lead_id;

      v_lead_ids := array_append(v_lead_ids, v_deal.lead_id);
    END IF;

    v_deal_ids := array_append(v_deal_ids, v_deal.deal_id);
    v_count := v_count + 1;
  END LOOP;

  -- Create timeline entries
  IF v_count > 0 AND array_length(v_lead_ids, 1) > 0 THEN
    INSERT INTO company_activities (
      tenant_id, lead_id, name, description, task_type, team,
      completed, completed_at, scheduled_at, metadata
    )
    SELECT
      p_tenant_id,
      unnest(v_lead_ids),
      'Transferencia em massa',
      'Lead transferido para ' || COALESCE((SELECT name FROM team_members WHERE id = p_target_sales_rep_id), 'sem responsavel') || ' por ' || p_transferred_by,
      'note',
      'sales',
      true,
      now(),
      now(),
      jsonb_build_object(
        'event_type', 'bulk_transfer',
        'transferred_by', p_transferred_by,
        'target_sales_rep_id', p_target_sales_rep_id,
        'target_stage_id', p_target_stage_id,
        'target_pipeline_id', p_target_pipeline_id,
        'total_transferred', v_count
      );
  END IF;

  RETURN jsonb_build_object(
    'transferred_count', v_count,
    'deal_ids', to_jsonb(v_deal_ids),
    'lead_ids', to_jsonb(v_lead_ids)
  );
END;
$$;


--
-- Name: bulk_transfer_deals(uuid, uuid, uuid, uuid, boolean, uuid, uuid, uuid, boolean, text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.bulk_transfer_deals(p_tenant_id uuid, p_source_pipeline_id uuid DEFAULT NULL::uuid, p_source_stage_id uuid DEFAULT NULL::uuid, p_source_sales_rep_id uuid DEFAULT NULL::uuid, p_include_no_rep boolean DEFAULT false, p_target_sales_rep_id uuid DEFAULT NULL::uuid, p_target_stage_id uuid DEFAULT NULL::uuid, p_target_pipeline_id uuid DEFAULT NULL::uuid, p_transfer_leads_too boolean DEFAULT true, p_transferred_by text DEFAULT 'Gestor'::text, p_created_after timestamp with time zone DEFAULT NULL::timestamp with time zone, p_created_before timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_deal RECORD;
  v_count INT := 0;
  v_deal_ids UUID[] := '{}';
  v_lead_ids UUID[] := '{}';
BEGIN
  FOR v_deal IN
    SELECT d.id AS deal_id, d.lead_id, d.sales_rep_id AS old_rep_id
    FROM deals d
    LEFT JOIN leads l ON l.id = d.lead_id
    WHERE d.tenant_id = p_tenant_id
      AND (p_source_pipeline_id IS NULL OR d.pipeline_id = p_source_pipeline_id)
      AND (p_source_stage_id IS NULL OR d.pipeline_stage_id = p_source_stage_id)
      AND (
        (p_source_sales_rep_id IS NULL AND p_include_no_rep = FALSE)
        OR (p_source_sales_rep_id IS NOT NULL AND d.sales_rep_id = p_source_sales_rep_id)
        OR (p_include_no_rep = TRUE AND d.sales_rep_id IS NULL)
      )
      AND (p_created_after IS NULL OR d.created_at >= p_created_after)
      AND (p_created_before IS NULL OR d.created_at <= p_created_before)
  LOOP
    UPDATE deals SET
      sales_rep_id = COALESCE(p_target_sales_rep_id, sales_rep_id),
      pipeline_stage_id = COALESCE(p_target_stage_id, pipeline_stage_id),
      pipeline_id = COALESCE(p_target_pipeline_id, pipeline_id),
      updated_at = now()
    WHERE id = v_deal.deal_id;

    IF p_transfer_leads_too AND v_deal.lead_id IS NOT NULL THEN
      UPDATE leads SET
        sales_rep_id = COALESCE(p_target_sales_rep_id, sales_rep_id),
        pipeline_stage_id = COALESCE(p_target_stage_id, pipeline_stage_id),
        updated_at = now()
      WHERE id = v_deal.lead_id;
      v_lead_ids := array_append(v_lead_ids, v_deal.lead_id);
    END IF;

    v_deal_ids := array_append(v_deal_ids, v_deal.deal_id);
    v_count := v_count + 1;
  END LOOP;

  IF v_count > 0 AND array_length(v_lead_ids, 1) > 0 THEN
    INSERT INTO company_activities (
      tenant_id, lead_id, name, description, task_type, team,
      completed, completed_at, scheduled_at, metadata
    )
    SELECT
      p_tenant_id, unnest(v_lead_ids),
      'Transferencia em massa',
      'Lead transferido para ' || COALESCE((SELECT name FROM team_members WHERE id = p_target_sales_rep_id), 'sem responsavel') || ' por ' || p_transferred_by,
      'note', 'sales', true, now(), now(),
      jsonb_build_object('event_type','bulk_transfer','transferred_by',p_transferred_by,'target_sales_rep_id',p_target_sales_rep_id,'target_stage_id',p_target_stage_id,'target_pipeline_id',p_target_pipeline_id,'total_transferred',v_count);
  END IF;

  RETURN jsonb_build_object('transferred_count',v_count,'deal_ids',to_jsonb(v_deal_ids),'lead_ids',to_jsonb(v_lead_ids));
END;
$$;


--
-- Name: bulk_transfer_deals(uuid, uuid, uuid, uuid, boolean, uuid, uuid, uuid, boolean, text, timestamp with time zone, timestamp with time zone, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.bulk_transfer_deals(p_tenant_id uuid, p_source_pipeline_id uuid DEFAULT NULL::uuid, p_source_stage_id uuid DEFAULT NULL::uuid, p_source_sales_rep_id uuid DEFAULT NULL::uuid, p_include_no_rep boolean DEFAULT false, p_target_sales_rep_id uuid DEFAULT NULL::uuid, p_target_stage_id uuid DEFAULT NULL::uuid, p_target_pipeline_id uuid DEFAULT NULL::uuid, p_transfer_leads_too boolean DEFAULT true, p_transferred_by text DEFAULT 'Gestor'::text, p_created_after timestamp with time zone DEFAULT NULL::timestamp with time zone, p_created_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_specific_deal_ids uuid[] DEFAULT NULL::uuid[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_deal RECORD;
  v_count INT := 0;
  v_deal_ids UUID[] := '{}';
  v_lead_ids UUID[] := '{}';
  v_target_is_won BOOLEAN := FALSE;
  v_target_is_lost BOOLEAN := FALSE;
  v_new_status TEXT;
BEGIN
  -- Check if target stage is won/lost to set correct status
  IF p_target_stage_id IS NOT NULL THEN
    SELECT is_won, is_lost INTO v_target_is_won, v_target_is_lost
    FROM sales_pipeline_stages WHERE id = p_target_stage_id;
    
    IF v_target_is_won THEN
      v_new_status := 'won';
    ELSIF v_target_is_lost THEN
      v_new_status := 'lost';
    ELSE
      v_new_status := 'negotiation';
    END IF;
  END IF;

  FOR v_deal IN
    SELECT d.id AS deal_id, d.lead_id, d.status AS current_status
    FROM deals d
    WHERE d.tenant_id = p_tenant_id
      AND (
        (p_specific_deal_ids IS NOT NULL AND d.id = ANY(p_specific_deal_ids))
        OR
        (p_specific_deal_ids IS NULL
          AND (p_source_pipeline_id IS NULL OR d.pipeline_id = p_source_pipeline_id)
          AND (p_source_stage_id IS NULL OR d.pipeline_stage_id = p_source_stage_id)
          AND (
            (p_source_sales_rep_id IS NULL AND p_include_no_rep = FALSE)
            OR (p_source_sales_rep_id IS NOT NULL AND d.sales_rep_id = p_source_sales_rep_id)
            OR (p_include_no_rep = TRUE AND d.sales_rep_id IS NULL)
          )
          AND (p_created_after IS NULL OR d.created_at >= p_created_after)
          AND (p_created_before IS NULL OR d.created_at <= p_created_before)
        )
      )
  LOOP
    UPDATE deals SET
      sales_rep_id = COALESCE(p_target_sales_rep_id, sales_rep_id),
      pipeline_stage_id = COALESCE(p_target_stage_id, pipeline_stage_id),
      pipeline_id = COALESCE(p_target_pipeline_id, pipeline_id),
      status = CASE 
        WHEN v_new_status IS NOT NULL THEN v_new_status
        ELSE status
      END,
      won_at = CASE 
        WHEN v_new_status = 'won' THEN COALESCE(won_at, now())
        WHEN v_new_status = 'negotiation' THEN NULL
        ELSE won_at
      END,
      lost_at = CASE 
        WHEN v_new_status = 'lost' THEN COALESCE(lost_at, now())
        WHEN v_new_status = 'negotiation' THEN NULL
        ELSE lost_at
      END,
      updated_at = now()
    WHERE id = v_deal.deal_id;

    IF p_transfer_leads_too AND v_deal.lead_id IS NOT NULL THEN
      UPDATE leads SET
        sales_rep_id = COALESCE(p_target_sales_rep_id, sales_rep_id),
        pipeline_stage_id = COALESCE(p_target_stage_id, pipeline_stage_id),
        updated_at = now()
      WHERE id = v_deal.lead_id;
      v_lead_ids := array_append(v_lead_ids, v_deal.lead_id);
    END IF;

    v_deal_ids := array_append(v_deal_ids, v_deal.deal_id);
    v_count := v_count + 1;
  END LOOP;

  IF v_count > 0 AND array_length(v_lead_ids, 1) > 0 THEN
    INSERT INTO company_activities (
      tenant_id, lead_id, name, description, task_type, team,
      completed, completed_at, scheduled_at, metadata
    )
    SELECT
      p_tenant_id, unnest(v_lead_ids),
      'Transferencia em massa',
      'Lead transferido para ' || COALESCE((SELECT name FROM team_members WHERE id = p_target_sales_rep_id), 'sem responsavel') || ' por ' || p_transferred_by,
      'note', 'sales', true, now(), now(),
      jsonb_build_object('event_type','bulk_transfer','transferred_by',p_transferred_by,'target_sales_rep_id',p_target_sales_rep_id,'target_stage_id',p_target_stage_id,'target_pipeline_id',p_target_pipeline_id,'total_transferred',v_count);
  END IF;

  RETURN jsonb_build_object('transferred_count',v_count,'deal_ids',to_jsonb(v_deal_ids),'lead_ids',to_jsonb(v_lead_ids));
END;
$$;


--
-- Name: calculate_wait_minutes(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.calculate_wait_minutes(wait_start timestamp with time zone) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  IF wait_start IS NULL THEN
    RETURN 0;
  END IF;
  RETURN GREATEST(0, (EXTRACT(EPOCH FROM (NOW() - wait_start)) / 60)::INTEGER);
END;
$$;


--
-- Name: cancel_orphaned_tasks_on_deal_rep_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.cancel_orphaned_tasks_on_deal_rep_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.sales_rep_id IS NOT NULL 
     AND NEW.sales_rep_id IS DISTINCT FROM OLD.sales_rep_id
     AND NEW.lead_id IS NOT NULL THEN
    
    UPDATE company_activities
    SET status = 'cancelled',
        completed = true,
        completed_at = NOW(),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'cancelled_reason', 'deal_reassigned',
          'old_sales_rep_id', OLD.sales_rep_id::text,
          'new_sales_rep_id', NEW.sales_rep_id::text,
          'cancelled_at', NOW()::text
        )
    WHERE lead_id = NEW.lead_id
      AND responsavel_id = OLD.sales_rep_id
      AND completed = false;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: cancel_orphaned_tasks_on_rep_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.cancel_orphaned_tasks_on_rep_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only fire when sales_rep_id actually changes
  IF OLD.sales_rep_id IS NOT NULL 
     AND NEW.sales_rep_id IS DISTINCT FROM OLD.sales_rep_id THEN
    
    UPDATE company_activities
    SET status = 'cancelled',
        completed = true,
        completed_at = NOW(),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'cancelled_reason', 'lead_reassigned',
          'old_sales_rep_id', OLD.sales_rep_id::text,
          'new_sales_rep_id', NEW.sales_rep_id::text,
          'cancelled_at', NOW()::text
        )
    WHERE lead_id = NEW.id
      AND responsavel_id = OLD.sales_rep_id
      AND completed = false;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: get_tenant_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_tenant_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(
    nullif(
      (current_setting('request.jwt.claims', true)::jsonb
        -> 'app_metadata' ->> 'tenant_id'),
      ''
    )::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid
  )
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_agent_message_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_message_queue (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    message_id uuid,
    conversation_id uuid,
    message_content text,
    message_metadata jsonb DEFAULT '{}'::jsonb,
    scheduled_for timestamp with time zone NOT NULL,
    status text DEFAULT 'pending'::text,
    result jsonb,
    error_message text,
    attempts integer DEFAULT 0,
    max_attempts integer DEFAULT 3,
    created_at timestamp with time zone DEFAULT now(),
    processed_at timestamp with time zone,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: claim_queue_messages(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.claim_queue_messages(p_batch_size integer DEFAULT 10) RETURNS SETOF public.ai_agent_message_queue
    LANGUAGE plpgsql
    AS $$ BEGIN RETURN QUERY UPDATE ai_agent_message_queue SET status = 'processing', attempts = attempts + 1 WHERE id IN (SELECT id FROM ai_agent_message_queue WHERE status = 'pending' AND scheduled_for <= now() AND attempts < max_attempts ORDER BY scheduled_for ASC LIMIT p_batch_size FOR UPDATE SKIP LOCKED) RETURNING *; END $$;


--
-- Name: ai_agent_scheduled_followups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_scheduled_followups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    conversation_id uuid,
    agent_id uuid,
    scheduled_at timestamp with time zone NOT NULL,
    context_note text,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT (current_setting('app.settings.tenant_id'::text, true))::uuid NOT NULL
);


--
-- Name: claim_scheduled_followups(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.claim_scheduled_followups(p_batch_size integer DEFAULT 5) RETURNS SETOF public.ai_agent_scheduled_followups
    LANGUAGE plpgsql
    AS $$ BEGIN RETURN QUERY UPDATE ai_agent_scheduled_followups SET status = 'processing', attempts = attempts + 1 WHERE id IN (SELECT id FROM ai_agent_scheduled_followups WHERE status = 'pending' AND scheduled_at <= now() AND attempts < 3 ORDER BY scheduled_at ASC LIMIT p_batch_size FOR UPDATE SKIP LOCKED) RETURNING *; END $$;


--
-- Name: clear_tenant_from_jwt(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.clear_tenant_from_jwt() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  UPDATE auth.users
  SET raw_app_meta_data = raw_app_meta_data - 'tenant_id'
  WHERE id = auth.uid();
END;
$$;


--
-- Name: count_deals_for_transfer(uuid, uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.count_deals_for_transfer(p_tenant_id uuid, p_source_pipeline_id uuid DEFAULT NULL::uuid, p_source_stage_id uuid DEFAULT NULL::uuid, p_source_sales_rep_id uuid DEFAULT NULL::uuid, p_include_no_rep boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
  FROM deals d
  WHERE d.tenant_id = p_tenant_id
    AND d.status NOT IN ('won', 'lost')
    AND (p_source_pipeline_id IS NULL OR d.pipeline_id = p_source_pipeline_id)
    AND (p_source_stage_id IS NULL OR d.pipeline_stage_id = p_source_stage_id)
    AND (
      (p_source_sales_rep_id IS NULL AND p_include_no_rep = FALSE)
      OR (p_source_sales_rep_id IS NOT NULL AND d.sales_rep_id = p_source_sales_rep_id)
      OR (p_include_no_rep = TRUE AND d.sales_rep_id IS NULL)
    );

  RETURN v_count;
END;
$$;


--
-- Name: count_deals_for_transfer(uuid, uuid, uuid, uuid, boolean, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.count_deals_for_transfer(p_tenant_id uuid, p_source_pipeline_id uuid DEFAULT NULL::uuid, p_source_stage_id uuid DEFAULT NULL::uuid, p_source_sales_rep_id uuid DEFAULT NULL::uuid, p_include_no_rep boolean DEFAULT false, p_created_after timestamp with time zone DEFAULT NULL::timestamp with time zone, p_created_before timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
  FROM deals d
  WHERE d.tenant_id = p_tenant_id
    AND (p_source_pipeline_id IS NULL OR d.pipeline_id = p_source_pipeline_id)
    AND (p_source_stage_id IS NULL OR d.pipeline_stage_id = p_source_stage_id)
    AND (
      (p_source_sales_rep_id IS NULL AND p_include_no_rep = FALSE)
      OR (p_source_sales_rep_id IS NOT NULL AND d.sales_rep_id = p_source_sales_rep_id)
      OR (p_include_no_rep = TRUE AND d.sales_rep_id IS NULL)
    )
    AND (p_created_after IS NULL OR d.created_at >= p_created_after)
    AND (p_created_before IS NULL OR d.created_at <= p_created_before);
  RETURN v_count;
END;
$$;


--
-- Name: create_impersonation_token(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.create_impersonation_token(target_member_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_admin_id UUID;
  v_admin_role TEXT;
  v_target_auth_id UUID;
  v_tenant_id UUID;
  v_token TEXT;
BEGIN
  -- Get caller's team member
  SELECT tm.id, tm.role, tm.tenant_id INTO v_admin_id, v_admin_role, v_tenant_id
  FROM team_members tm
  WHERE tm.auth_user_id = auth.uid()
    AND tm.is_active = true
  LIMIT 1;

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Team member not found';
  END IF;

  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can impersonate';
  END IF;

  -- Verify target exists and has auth
  SELECT auth_user_id INTO v_target_auth_id
  FROM team_members
  WHERE id = target_member_id AND is_active = true AND tenant_id = v_tenant_id;

  IF v_target_auth_id IS NULL THEN
    RAISE EXCEPTION 'Target member not found or has no auth account';
  END IF;

  -- Create token (5 min expiry, single use)
  INSERT INTO admin_impersonation_tokens (admin_member_id, target_member_id, tenant_id)
  VALUES (v_admin_id, target_member_id, v_tenant_id)
  RETURNING token INTO v_token;

  RETURN v_token;
END;
$$;


--
-- Name: create_lead_and_deal_from_pain_registration(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.create_lead_and_deal_from_pain_registration() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_lead_id UUID;
  v_is_internal BOOLEAN := false;
  v_deal_id UUID;
  v_pipeline_id UUID;
  v_pipeline_stage_id UUID;
  v_default_sales_rep_id UUID;
  v_product_id TEXT := 'pain';
  v_product_price NUMERIC := 25000;
  v_tid UUID;
BEGIN
  v_tid := NEW.tenant_id;

  SELECT id, COALESCE(is_internal_contact, false) INTO v_lead_id, v_is_internal
  FROM leads
  WHERE tenant_id = v_tid
    AND (LOWER(email) = LOWER(NEW.email)
      OR (NEW.phone IS NOT NULL AND phone LIKE '%' || REGEXP_REPLACE(NEW.phone, '[^0-9]', '', 'g') || '%'))
  LIMIT 1;

  IF v_lead_id IS NULL THEN
    INSERT INTO leads (
      name, email, phone, company_name, sales_stage,
      utm_source, utm_medium, utm_campaign, utm_term, utm_content, created_at, tenant_id
    ) VALUES (
      UPPER(SPLIT_PART(NEW.name, ' ', 1)),
      NEW.email,
      REGEXP_REPLACE(NEW.phone, '[^0-9]', '', 'g'),
      NEW.company_name, 'new',
      NEW.utm_source, NEW.utm_medium, NEW.utm_campaign, NEW.utm_term, NEW.utm_content,
      NOW(), v_tid
    )
    RETURNING id INTO v_lead_id;
  ELSE
    IF NEW.company_name IS NOT NULL AND NEW.company_name != '' THEN
      UPDATE leads SET company_name = NEW.company_name, updated_at = NOW()
      WHERE id = v_lead_id AND tenant_id = v_tid AND (company_name IS NULL OR company_name = '');
    END IF;
  END IF;

  NEW.lead_id := v_lead_id;

  IF v_is_internal THEN RETURN NEW; END IF;

  SELECT id, default_sales_rep_id INTO v_pipeline_id, v_default_sales_rep_id
  FROM sales_pipelines
  WHERE tenant_id = v_tid AND is_default = true AND is_active = true
  LIMIT 1;

  SELECT id INTO v_pipeline_stage_id
  FROM sales_pipeline_stages
  WHERE pipeline_id = v_pipeline_id AND tenant_id = v_tid
    AND is_won = false AND is_lost = false
  ORDER BY position LIMIT 1;

  IF NOT EXISTS (SELECT 1 FROM deals WHERE lead_id = v_lead_id AND pipeline_id = v_pipeline_id AND tenant_id = v_tid) THEN
    INSERT INTO deals (
      lead_id, product_id, pipeline_id, pipeline_stage_id, sales_rep_id,
      original_price, negotiated_price, status, notes, created_at, tenant_id
    ) VALUES (
      v_lead_id, v_product_id, v_pipeline_id, v_pipeline_stage_id, v_default_sales_rep_id,
      v_product_price, v_product_price, 'open',
      'Criado automaticamente via Pain Registration. Opcao de pagamento: ' || COALESCE(NEW.payment_option, 'nao informado'),
      NOW(), v_tid
    )
    RETURNING id INTO v_deal_id;

    IF v_default_sales_rep_id IS NOT NULL THEN
      UPDATE leads SET sales_rep_id = v_default_sales_rep_id, updated_at = NOW()
      WHERE id = v_lead_id AND tenant_id = v_tid AND sales_rep_id IS NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: dispatch_email_automation_event(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.dispatch_email_automation_event() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_event TEXT;
  v_lead_id UUID;
  v_tenant_id UUID;
  v_context JSONB := '{}'::jsonb;
BEGIN
  IF TG_TABLE_NAME = 'leads' THEN
    IF TG_OP = 'INSERT' THEN
      v_event := 'lead_created';
      v_lead_id := NEW.id;
      v_tenant_id := NEW.tenant_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
      v_event := 'lead_stage_changed';
      v_lead_id := NEW.id;
      v_tenant_id := NEW.tenant_id;
      v_context := jsonb_build_object('from_stage', OLD.pipeline_stage_id, 'to_stage', NEW.pipeline_stage_id);
    ELSE
      RETURN NEW;
    END IF;
  ELSIF TG_TABLE_NAME = 'deals' THEN
    IF TG_OP = 'INSERT' THEN
      v_event := 'deal_created';
      v_lead_id := NEW.lead_id;
      v_tenant_id := NEW.tenant_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
      IF NEW.status = 'won' THEN v_event := 'deal_won';
      ELSIF NEW.status = 'lost' THEN v_event := 'deal_lost';
      ELSE RETURN NEW;
      END IF;
      v_lead_id := NEW.lead_id;
      v_tenant_id := NEW.tenant_id;
    ELSE
      RETURN NEW;
    END IF;
  ELSE
    RETURN NEW;
  END IF;

  -- URL do projeto vem da config (SUPABASE_PROJECT_URL) — nunca hardcoded.
  IF (SELECT value FROM config WHERE key = 'SUPABASE_PROJECT_URL') IS NULL THEN
    RETURN NEW;
  END IF;
  PERFORM net.http_post(
    url := (SELECT value FROM config WHERE key = 'SUPABASE_PROJECT_URL') || '/functions/v1/email-automation-trigger',
    headers := public.edge_request_headers(),
    body := jsonb_build_object(
      'event', v_event,
      'lead_id', v_lead_id,
      'tenant_id', v_tenant_id,
      'context', v_context
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END $$;


--
-- Name: dispatch_meta_ads_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.dispatch_meta_ads_sync() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  rec RECORD;
  base_url TEXT;
BEGIN
  -- URL do projeto vem da config (SUPABASE_PROJECT_URL) — nunca hardcoded.
  SELECT value || '/functions/v1/sync-meta-account' INTO base_url FROM config WHERE key = 'SUPABASE_PROJECT_URL';
  IF base_url IS NULL THEN RETURN; END IF;
  FOR rec IN
    SELECT account_id, organization_id, tenant_id
    FROM meta_ads_accounts
    WHERE is_active = true
  LOOP
    PERFORM net.http_post(
      url := base_url,
      headers := public.edge_request_headers(),
      body := jsonb_build_object(
        'account_id', rec.account_id,
        'organization_id', rec.organization_id,
        'tenant_id', rec.tenant_id
      )
    );
  END LOOP;
END;
$$;


--
-- Name: enqueue_message_for_ai_agent(uuid, uuid, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.enqueue_message_for_ai_agent(p_lead_id uuid, p_message_id uuid, p_message_content text, p_debounce_seconds integer DEFAULT 30) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ DECLARE v_queue_id UUID; v_conversation_id UUID; v_agent_active BOOLEAN; BEGIN SELECT EXISTS(SELECT 1 FROM ai_sales_agents WHERE is_active = true) INTO v_agent_active; IF NOT v_agent_active THEN RETURN NULL; END IF; SELECT id INTO v_conversation_id FROM ai_agent_conversations WHERE lead_id = p_lead_id AND status = 'active' LIMIT 1; IF v_conversation_id IS NULL THEN INSERT INTO ai_agent_conversations (lead_id, agent_id, status) SELECT p_lead_id, id, 'active' FROM ai_sales_agents WHERE is_active = true LIMIT 1 RETURNING id INTO v_conversation_id; END IF; UPDATE ai_agent_message_queue SET status = 'cancelled' WHERE lead_id = p_lead_id AND status = 'pending' AND message_content NOT LIKE '[INTERNAL:%'; INSERT INTO ai_agent_message_queue (lead_id, message_id, conversation_id, message_content, scheduled_for) VALUES (p_lead_id, p_message_id, v_conversation_id, p_message_content, now() + (p_debounce_seconds || ' seconds')::interval) RETURNING id INTO v_queue_id; RETURN v_queue_id; END $$;


--
-- Name: enroll_lead_in_cadence(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.enroll_lead_in_cadence() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_agent RECORD;
  v_stage_name TEXT;
  v_steps JSONB;
  v_has_meeting BOOLEAN;
BEGIN
  IF OLD.pipeline_stage_id IS NOT DISTINCT FROM NEW.pipeline_stage_id THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_agent FROM ai_sales_agents WHERE is_active = true LIMIT 1;
  IF v_agent IS NULL THEN RETURN NEW; END IF;

  SELECT name INTO v_stage_name FROM sales_pipeline_stages WHERE id = NEW.pipeline_stage_id;

  v_steps := v_agent.cadence_steps->v_stage_name;
  IF v_steps IS NULL OR jsonb_array_length(v_steps) = 0 THEN RETURN NEW; END IF;

  SELECT EXISTS(
    SELECT 1 FROM company_activities
    WHERE lead_id = NEW.id
      AND task_type IN ('call', 'meeting')
      AND status IN ('pending', 'confirmed')
      AND scheduled_at > now()
  ) INTO v_has_meeting;
  IF v_has_meeting THEN RETURN NEW; END IF;

  UPDATE ai_agent_cadence_enrollments
  SET status = 'cancelled', updated_at = now()
  WHERE lead_id = NEW.id AND status = 'active';

  INSERT INTO ai_agent_cadence_enrollments (lead_id, agent_id, stage, current_step, next_action_at, tenant_id)
  VALUES (
    NEW.id,
    v_agent.id,
    v_stage_name,
    0,
    now() + ((v_steps->0->>'delay_minutes')::INT || ' minutes')::interval,
    NEW.tenant_id
  )
  ON CONFLICT (lead_id, agent_id, stage) DO UPDATE SET
    status = 'active',
    current_step = 0,
    next_action_at = now() + ((v_steps->0->>'delay_minutes')::INT || ' minutes')::interval,
    completed_at = NULL,
    updated_at = now();

  RETURN NEW;
END;
$$;


--
-- Name: find_lead_by_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.find_lead_by_phone(p_phone text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_lead_id UUID;
  v_clean_phone TEXT;
BEGIN
  v_clean_phone := regexp_replace(p_phone, '[^0-9]', '', 'g');
  SELECT id INTO v_lead_id
  FROM leads
  WHERE regexp_replace(phone, '[^0-9]', '', 'g') = v_clean_phone
     OR regexp_replace(phone, '[^0-9]', '', 'g') = '55' || v_clean_phone
     OR '55' || regexp_replace(phone, '[^0-9]', '', 'g') = v_clean_phone
  LIMIT 1;
  RETURN v_lead_id;
END;
$$;


--
-- Name: find_lead_by_phone_suffix(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.find_lead_by_phone_suffix(p_suffix text) RETURNS TABLE(id uuid, name text, phone text, email text, sales_rep_id uuid, source text, utm_source text, utm_medium text, utm_campaign text, utm_content text, original_source text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT l.id, l.name, l.phone, l.email, l.sales_rep_id, l.source,
         l.utm_source, l.utm_medium, l.utm_campaign, l.utm_content, l.original_source
  FROM leads l
  WHERE RIGHT(REGEXP_REPLACE(l.phone, '[^0-9]', '', 'g'), 8) = p_suffix
  LIMIT 1;
$$;


--
-- Name: find_lead_by_phone_suffix(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.find_lead_by_phone_suffix(p_suffix text, p_tenant_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, name text, phone text, email text, sales_rep_id uuid, source text, utm_source text, utm_medium text, utm_campaign text, utm_content text, original_source text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT l.id, l.name, l.phone, l.email, l.sales_rep_id, l.source,
         l.utm_source, l.utm_medium, l.utm_campaign, l.utm_content, l.original_source
  FROM leads l
  WHERE RIGHT(REGEXP_REPLACE(l.phone, '[^0-9]', '', 'g'), 8) = p_suffix
  AND (p_tenant_id IS NULL OR l.tenant_id = p_tenant_id)
  LIMIT 1;
$$;


--
-- Name: fn_config_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.fn_config_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_user_name TEXT;
  v_old JSONB;
  v_new JSONB;
  v_changed TEXT[];
  v_tenant UUID;
  v_record_id TEXT;
  k TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NOT NULL THEN
    SELECT name INTO v_user_name FROM team_members WHERE auth_user_id = v_user_id LIMIT 1;
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    v_new := NULL;
    v_record_id := OLD.id::text;
    v_tenant := OLD.tenant_id;
  ELSIF TG_OP = 'INSERT' THEN
    v_old := NULL;
    v_new := to_jsonb(NEW);
    v_record_id := NEW.id::text;
    v_tenant := NEW.tenant_id;
  ELSE
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_record_id := NEW.id::text;
    v_tenant := NEW.tenant_id;
    
    v_changed := '{}';
    FOR k IN SELECT jsonb_object_keys(v_new)
    LOOP
      -- Ignorar campos de update automático E current_activity (presença)
      IF k NOT IN ('updated_at', 'created_at', 'current_activity', 'current_activity_at', 'current_activity_meta') 
         AND (v_old->k IS DISTINCT FROM v_new->k) THEN
        v_changed := array_append(v_changed, k);
      END IF;
    END LOOP;
    
    IF array_length(v_changed, 1) IS NULL THEN
      RETURN NEW;
    END IF;
  END IF;

  INSERT INTO config_audit_log (table_name, record_id, action, changed_by_user_id, changed_by_name, old_data, new_data, changed_fields, tenant_id)
  VALUES (TG_TABLE_NAME, v_record_id, TG_OP, v_user_id, v_user_name, v_old, v_new, v_changed, v_tenant);

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;


--
-- Name: get_ai_agent_status_for_lead(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_ai_agent_status_for_lead(p_lead_id uuid) RETURNS TABLE(has_agent boolean, agent_name text, conversation_status text, messages_sent integer, last_processed_at timestamp with time zone, is_paused boolean, paused_by_name text, pause_reason text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT (c.id IS NOT NULL), a.name, c.status, COALESCE(c.total_messages_sent, 0), c.last_processed_at, (c.paused_at IS NOT NULL), tm.name, c.pause_reason FROM ai_agent_conversations c LEFT JOIN ai_sales_agents a ON a.id = c.agent_id LEFT JOIN team_members tm ON tm.id = c.paused_by WHERE c.lead_id = p_lead_id ORDER BY c.updated_at DESC LIMIT 1; $$;


--
-- Name: get_avg_first_response_time(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_avg_first_response_time(p_start timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE(avg_hours double precision, sample_size bigint)
    LANGUAGE sql STABLE
    AS $$
  WITH 
  -- Effective window (defaults to last 30 days)
  win AS (
    SELECT 
      COALESCE(p_start, now() - interval '30 days') AS w_start,
      COALESCE(p_end, now()) AS w_end,
      get_tenant_id() AS tid
  ),
  -- Only fetch deals within the window for this tenant
  target_deals AS (
    SELECT d.id, d.lead_id, d.created_at
    FROM deals d, win
    WHERE d.tenant_id = win.tid
      AND d.lead_id IS NOT NULL
      AND d.created_at >= win.w_start
      AND d.created_at <= win.w_end
      AND d.metadata @> '{"source": "receive-lead"}'
  ),
  -- First call AFTER deal creation, scoped to lead_ids in window
  first_call AS (
    SELECT ch.lead_id, MIN(ch.started_at) AS first_at
    FROM call_history ch, win
    WHERE ch.lead_id IN (SELECT lead_id FROM target_deals)
      AND LOWER(ch.direction) IN ('outbound', 'outgoing')
      AND ch.started_at >= win.w_start
      AND ch.started_at <= win.w_end + interval '7 days'
    GROUP BY ch.lead_id
  ),
  -- First whatsapp message AFTER deal creation, scoped + tenant filter
  first_msg AS (
    SELECT wm.lead_id, MIN(wm.created_at) AS first_at
    FROM whatsapp_messages wm, win
    WHERE wm.tenant_id = win.tid
      AND wm.lead_id IN (SELECT lead_id FROM target_deals)
      AND wm.is_from_me = true
      AND wm.created_at >= win.w_start
      AND wm.created_at <= win.w_end + interval '7 days'
    GROUP BY wm.lead_id
  ),
  response_times AS (
    SELECT td.id,
      EXTRACT(EPOCH FROM (LEAST(fc.first_at, fm.first_at) - td.created_at)) / 3600.0 AS hours
    FROM target_deals td
    LEFT JOIN first_call fc ON fc.lead_id = td.lead_id
    LEFT JOIN first_msg fm ON fm.lead_id = td.lead_id
    WHERE LEAST(fc.first_at, fm.first_at) IS NOT NULL
      AND EXTRACT(EPOCH FROM (LEAST(fc.first_at, fm.first_at) - td.created_at)) > 0
  )
  SELECT
    AVG(hours) AS avg_hours,
    COUNT(*) AS sample_size
  FROM response_times;
$$;


--
-- Name: get_call_analytics(date, date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_call_analytics(p_date_from date DEFAULT ((CURRENT_DATE - '30 days'::interval))::date, p_date_to date DEFAULT CURRENT_DATE, p_team_member_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_calls', (
      SELECT COUNT(*) FROM call_history ch
      WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
        AND ch.status = 'completed'
        AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
    ),
    'by_outcome', (
      SELECT COALESCE(jsonb_object_agg(outcome, cnt), '{}'::jsonb)
      FROM (
        SELECT COALESCE(ch.call_outcome, 'no_action') AS outcome, COUNT(*) AS cnt
        FROM call_history ch
        WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
          AND ch.status = 'completed'
          AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
        GROUP BY COALESCE(ch.call_outcome, 'no_action')
      ) sub
    ),
    'by_gender', (
      SELECT COALESCE(jsonb_object_agg(gender_val, cnt), '{}'::jsonb)
      FROM (
        SELECT COALESCE(l.gender, 'desconhecido') AS gender_val, COUNT(*) AS cnt
        FROM call_history ch
        JOIN leads l ON l.id = ch.lead_id
        WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
          AND ch.status = 'completed'
          AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
        GROUP BY COALESCE(l.gender, 'desconhecido')
      ) sub
    ),
    'by_business_type', (
      SELECT COALESCE(jsonb_object_agg(btype, cnt), '{}'::jsonb)
      FROM (
        SELECT COALESCE(l.business_type, 'desconhecido') AS btype, COUNT(*) AS cnt
        FROM call_history ch
        JOIN leads l ON l.id = ch.lead_id
        WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
          AND ch.status = 'completed'
          AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
        GROUP BY COALESCE(l.business_type, 'desconhecido')
      ) sub
    ),
    'by_revenue_range', (
      SELECT COALESCE(jsonb_object_agg(rrange, cnt), '{}'::jsonb)
      FROM (
        SELECT COALESCE(l.revenue_range, 'desconhecido') AS rrange, COUNT(*) AS cnt
        FROM call_history ch
        JOIN leads l ON l.id = ch.lead_id
        WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
          AND ch.status = 'completed'
          AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
        GROUP BY COALESCE(l.revenue_range, 'desconhecido')
      ) sub
    ),
    'icp_rate', (
      SELECT COALESCE(
        ROUND(
          COUNT(*) FILTER (WHERE l.is_icp = true)::numeric /
          NULLIF(COUNT(*) FILTER (WHERE l.is_icp IS NOT NULL), 0)::numeric * 100
        , 1)
      , 0)
      FROM call_history ch
      JOIN leads l ON l.id = ch.lead_id
      WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
        AND ch.status = 'completed'
        AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
    ),
    'conversion_by_outcome', (
      SELECT COALESCE(jsonb_object_agg(outcome, conversion_rate), '{}'::jsonb)
      FROM (
        SELECT
          COALESCE(ch.call_outcome, 'no_action') AS outcome,
          ROUND(
            COUNT(*) FILTER (WHERE d.status = 'won')::numeric /
            NULLIF(COUNT(*), 0)::numeric * 100
          , 1) AS conversion_rate
        FROM call_history ch
        LEFT JOIN deals d ON d.lead_id = ch.lead_id
        WHERE ch.started_at::date BETWEEN p_date_from AND p_date_to
          AND ch.status = 'completed'
          AND (p_team_member_id IS NULL OR ch.team_member_id = p_team_member_id)
        GROUP BY COALESCE(ch.call_outcome, 'no_action')
      ) sub
    )
  ) INTO result;

  RETURN result;
END;
$$;


--
-- Name: get_campaign_audience_count(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_campaign_audience_count(p_tenant_id uuid, p_filters jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_count INTEGER;
BEGIN
  IF p_filters ? 'lead_ids' AND jsonb_array_length(p_filters->'lead_ids') > 0 THEN
    SELECT count(*) INTO v_count FROM leads l
    WHERE l.tenant_id = p_tenant_id
      AND l.id::text IN (SELECT jsonb_array_elements_text(p_filters->'lead_ids'))
      AND l.phone IS NOT NULL AND l.phone != '';
    RETURN v_count;
  END IF;

  SELECT count(*) INTO v_count FROM leads l
  WHERE l.tenant_id = p_tenant_id
    AND l.phone IS NOT NULL AND l.phone != ''
    AND (NOT p_filters ? 'pipeline_stage_ids' OR jsonb_array_length(p_filters->'pipeline_stage_ids') = 0 OR l.pipeline_stage_id::text IN (SELECT jsonb_array_elements_text(p_filters->'pipeline_stage_ids')))
    AND (NOT p_filters ? 'states' OR jsonb_array_length(p_filters->'states') = 0 OR l.state IN (SELECT jsonb_array_elements_text(p_filters->'states')))
    AND (NOT p_filters ? 'cities' OR jsonb_array_length(p_filters->'cities') = 0 OR l.city_name IN (SELECT jsonb_array_elements_text(p_filters->'cities')))
    AND (NOT p_filters ? 'utm_sources' OR jsonb_array_length(p_filters->'utm_sources') = 0 OR l.utm_source IN (SELECT jsonb_array_elements_text(p_filters->'utm_sources')))
    AND (NOT p_filters ? 'utm_campaigns' OR jsonb_array_length(p_filters->'utm_campaigns') = 0 OR l.utm_campaign IN (SELECT jsonb_array_elements_text(p_filters->'utm_campaigns')))
    AND (NOT p_filters ? 'sales_rep_ids' OR jsonb_array_length(p_filters->'sales_rep_ids') = 0 OR l.sales_rep_id::text IN (SELECT jsonb_array_elements_text(p_filters->'sales_rep_ids')))
    AND ((p_filters->>'score_min') IS NULL OR l.sales_score >= (p_filters->>'score_min')::numeric)
    AND ((p_filters->>'score_max') IS NULL OR l.sales_score <= (p_filters->>'score_max')::numeric)
    AND ((p_filters->>'created_after') IS NULL OR l.created_at >= (p_filters->>'created_after')::timestamptz)
    AND ((p_filters->>'created_before') IS NULL OR l.created_at <= (p_filters->>'created_before')::timestamptz)
    AND (NOT (p_filters ? 'no_sales_rep' AND (p_filters->>'no_sales_rep')::boolean) OR l.sales_rep_id IS NULL)
    AND (NOT (p_filters ? 'bant_budget' AND (p_filters->>'bant_budget')::boolean) OR l.bant_budget = true)
    AND (NOT (p_filters ? 'bant_authority' AND (p_filters->>'bant_authority')::boolean) OR l.bant_authority = true)
    AND (NOT (p_filters ? 'bant_need' AND (p_filters->>'bant_need')::boolean) OR l.bant_need = true)
    AND (NOT (p_filters ? 'bant_timeline' AND (p_filters->>'bant_timeline')::boolean) OR l.bant_timeline = true);
  RETURN v_count;
END $$;


--
-- Name: get_conversation_messages(uuid, uuid, integer, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_conversation_messages(p_lead_id uuid DEFAULT NULL::uuid, p_group_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 50, p_instance_id uuid DEFAULT NULL::uuid, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, instance_id uuid, lead_id uuid, group_id uuid, message_id text, remote_jid text, sender_phone text, sender_name text, content text, message_type text, media_url text, is_from_me boolean, status text, sent_at timestamp with time zone, metadata jsonb, created_at timestamp with time zone, reactions jsonb, is_edited boolean, is_deleted boolean, edited_at timestamp with time zone, instance_team text, instance_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT * FROM (SELECT m.id, m.instance_id, m.lead_id, m.group_id, m.message_id, m.remote_jid, m.sender_phone, m.sender_name, m.content, m.message_type, m.media_url, m.is_from_me, m.status, m.sent_at, m.metadata, m.created_at, m.reactions, m.is_edited, m.is_deleted, m.edited_at, COALESCE(wi.teams[1], 'comercial') AS instance_team, wi.name AS instance_name FROM whatsapp_messages m LEFT JOIN whatsapp_instances wi ON wi.id = m.instance_id WHERE (p_lead_id IS NULL OR m.lead_id = p_lead_id) AND (p_group_id IS NULL OR m.group_id = p_group_id) AND (p_instance_id IS NULL OR m.instance_id = p_instance_id) AND (p_lead_id IS NOT NULL OR p_group_id IS NOT NULL) ORDER BY m.sent_at DESC OFFSET p_offset LIMIT p_limit) recent ORDER BY recent.sent_at ASC; $$;


--
-- Name: get_conversation_notes(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_conversation_notes(p_lead_id uuid DEFAULT NULL::uuid, p_group_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, content text, note_type text, is_pinned boolean, created_by uuid, created_by_name text, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT n.id, n.content, n.note_type::TEXT, n.is_pinned, n.created_by,
    pr.name AS created_by_name, n.created_at
  FROM cs_conversation_notes n
  LEFT JOIN profiles pr ON n.created_by = pr.id
  WHERE n.tenant_id = (SELECT public.get_tenant_id())
    AND ((p_lead_id IS NOT NULL AND n.lead_id = p_lead_id)
      OR (p_group_id IS NOT NULL AND n.group_id = p_group_id))
  ORDER BY n.is_pinned DESC, n.created_at DESC;
END;
$$;


--
-- Name: get_cs_inbox_with_metrics(uuid, integer, text, text, text, boolean, text, text, boolean, boolean, text, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_cs_inbox_with_metrics(p_instance_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 50, p_product_filter text DEFAULT NULL::text, p_health_filter text DEFAULT NULL::text, p_sla_filter text DEFAULT NULL::text, p_only_pending boolean DEFAULT false, p_search text DEFAULT NULL::text, p_sort_mode text DEFAULT 'recent'::text, p_hide_handled boolean DEFAULT false, p_only_with_tasks boolean DEFAULT false, p_funnel_filter text DEFAULT NULL::text, p_pipeline_id uuid DEFAULT NULL::uuid, p_stage_id uuid DEFAULT NULL::uuid, p_team_filter text DEFAULT NULL::text) RETURNS TABLE(conversation_id text, conversation_type text, lead_id uuid, group_id uuid, contact_phone text, conversation_name text, last_message text, last_message_at timestamp with time zone, last_sender_name text, is_from_me boolean, unread_count bigint, organization_id uuid, organization_name text, health_status text, health_score integer, instance_id uuid, instance_name text, lead_photo_url text, lead_products text[], pending_reply boolean, wait_minutes integer, sla_status text, assigned_agent_id uuid, assigned_agent_name text, is_handled boolean, handled_at timestamp with time zone, handled_reason text, pending_tasks_count integer, lead_company_name text, lead_job_title text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN RETURN QUERY
  WITH conversations AS (
    SELECT DISTINCT ON (CASE WHEN m.group_id IS NOT NULL THEN m.group_id::TEXT ELSE m.lead_id::TEXT END)
      CASE WHEN m.group_id IS NOT NULL THEN m.group_id::TEXT ELSE m.lead_id::TEXT END AS conv_id,
      CASE WHEN m.group_id IS NOT NULL THEN 'grupo' ELSE 'individual' END AS conv_type,
      CASE WHEN m.group_id IS NULL THEN m.lead_id ELSE NULL END AS m_lead_id, m.group_id AS m_group_id,
      CASE WHEN m.group_id IS NOT NULL THEN m.sender_phone ELSE COALESCE(l.phone, m.sender_phone) END AS m_contact_phone,
      COALESCE(g.name, l.name, m.sender_name) AS conv_name, m.content AS last_msg, m.created_at AS last_msg_at, m.sender_name AS last_sender,
      m.is_from_me AS m_is_from_me, 0::BIGINT AS unread, NULL::uuid AS m_org_id, NULL::text AS org_name,
      m.instance_id AS m_instance_id, wi.name AS inst_name, l.photo_url AS photo_url, ARRAY[]::TEXT[] AS products,
      (NOT m.is_from_me) AS pending, GREATEST(0, EXTRACT(EPOCH FROM (NOW() - m.created_at))::INTEGER / 60) AS wait_mins,
      false AS m_is_handled, NULL::timestamptz AS m_handled_at, NULL::text AS m_handled_reason,
      0 AS m_pending_tasks, l.company_name AS m_company_name, l.job_title AS m_job_title
    FROM whatsapp_messages m LEFT JOIN leads l ON m.lead_id = l.id LEFT JOIN whatsapp_groups g ON m.group_id = g.id LEFT JOIN whatsapp_instances wi ON m.instance_id = wi.id
    WHERE (p_instance_id IS NULL OR m.instance_id = p_instance_id)
      AND (p_search IS NULL OR LENGTH(p_search) < 3 OR COALESCE(g.name, l.name, m.sender_name) ILIKE '%' || p_search || '%' OR m.sender_phone ILIKE '%' || p_search || '%' OR l.phone ILIKE '%' || p_search || '%' OR l.company_name ILIKE '%' || p_search || '%')
    ORDER BY CASE WHEN m.group_id IS NOT NULL THEN m.group_id::TEXT ELSE m.lead_id::TEXT END, m.created_at DESC
  ), filtered AS (
    SELECT c.*, 'unknown' AS final_health_status, NULL::INTEGER AS final_health_score,
      CASE WHEN c.pending AND c.wait_mins > 120 THEN 'critical' WHEN c.pending AND c.wait_mins > 30 THEN 'warning' ELSE 'ok' END AS final_sla_status
    FROM conversations c WHERE (p_sla_filter IS NULL OR (p_sla_filter = 'critical' AND c.pending AND c.wait_mins > 120) OR (p_sla_filter = 'warning' AND c.pending AND c.wait_mins > 30 AND c.wait_mins <= 120) OR (p_sla_filter = 'ok' AND (NOT c.pending OR c.wait_mins <= 30))) AND (NOT p_only_pending OR c.pending)
  )
  SELECT f.conv_id::TEXT, f.conv_type::TEXT, f.m_lead_id, f.m_group_id, f.m_contact_phone::TEXT, f.conv_name::TEXT, f.last_msg::TEXT, f.last_msg_at, f.last_sender::TEXT, f.m_is_from_me, f.unread, f.m_org_id, f.org_name, f.final_health_status::TEXT, f.final_health_score, f.m_instance_id, f.inst_name::TEXT, f.photo_url::TEXT, f.products, f.pending, f.wait_mins::INTEGER, f.final_sla_status::TEXT, NULL::UUID, NULL::TEXT, f.m_is_handled, f.m_handled_at, f.m_handled_reason, f.m_pending_tasks, f.m_company_name::TEXT, f.m_job_title::TEXT
  FROM filtered f ORDER BY CASE WHEN p_sort_mode = 'priority' THEN CASE WHEN f.pending AND NOT f.m_is_handled THEN 0 ELSE 1 END ELSE 0 END, CASE WHEN p_sort_mode = 'priority' THEN f.wait_mins ELSE 0 END DESC, f.last_msg_at DESC LIMIT p_limit;
END; $$;


--
-- Name: get_daily_activity_summary(date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_daily_activity_summary(p_date date DEFAULT CURRENT_DATE, p_team_member_id uuid DEFAULT NULL::uuid) RETURNS TABLE(calls_count bigint, messages_sent bigint, messages_received bigint, tasks_completed bigint, deals_created bigint, leads_created bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ SELECT (SELECT COUNT(*)::bigint FROM call_history WHERE created_at::date = p_date AND (p_team_member_id IS NULL OR team_member_id = p_team_member_id)), (SELECT COUNT(*)::bigint FROM whatsapp_messages WHERE created_at::date = p_date AND is_from_me = true), (SELECT COUNT(*)::bigint FROM whatsapp_messages WHERE created_at::date = p_date AND is_from_me = false), (SELECT COUNT(*)::bigint FROM company_activities WHERE completed = true AND updated_at::date = p_date AND (p_team_member_id IS NULL OR responsavel_id = p_team_member_id)), (SELECT COUNT(*)::bigint FROM deals WHERE created_at::date = p_date AND (p_team_member_id IS NULL OR sales_rep_id = p_team_member_id)), (SELECT COUNT(*)::bigint FROM leads WHERE created_at::date = p_date AND (p_team_member_id IS NULL OR sales_rep_id = p_team_member_id)); $$;


--
-- Name: get_email_audience_count(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_email_audience_count(p_tenant_id uuid, p_filters jsonb DEFAULT '{}'::jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_count INT;
BEGIN
  IF p_filters ? 'lead_ids' AND jsonb_array_length(p_filters->'lead_ids') > 0 THEN
    SELECT count(*) INTO v_count
    FROM leads l
    WHERE l.tenant_id = p_tenant_id
      AND l.id::text IN (SELECT jsonb_array_elements_text(p_filters->'lead_ids'))
      AND l.email IS NOT NULL AND l.email != ''
      AND (l.email_opted_out IS NULL OR l.email_opted_out = false)
      AND NOT EXISTS (SELECT 1 FROM email_unsubscribes u WHERE u.tenant_id = p_tenant_id AND u.email = l.email);
    RETURN v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM leads l
  WHERE l.tenant_id = p_tenant_id
    AND l.email IS NOT NULL AND l.email != ''
    AND (l.email_opted_out IS NULL OR l.email_opted_out = false)
    AND NOT EXISTS (SELECT 1 FROM email_unsubscribes u WHERE u.tenant_id = p_tenant_id AND u.email = l.email)
    AND (p_filters->'pipeline_stage_ids' IS NULL OR jsonb_array_length(p_filters->'pipeline_stage_ids') = 0 OR l.pipeline_stage_id::text IN (SELECT jsonb_array_elements_text(p_filters->'pipeline_stage_ids')))
    AND (p_filters->'states' IS NULL OR jsonb_array_length(p_filters->'states') = 0 OR l.state IN (SELECT jsonb_array_elements_text(p_filters->'states')))
    AND (p_filters->'cities' IS NULL OR jsonb_array_length(p_filters->'cities') = 0 OR l.city_name IN (SELECT jsonb_array_elements_text(p_filters->'cities')))
    AND (p_filters->'utm_sources' IS NULL OR jsonb_array_length(p_filters->'utm_sources') = 0 OR l.utm_source IN (SELECT jsonb_array_elements_text(p_filters->'utm_sources')))
    AND ((p_filters->>'score_min') IS NULL OR l.sales_score >= (p_filters->>'score_min')::int)
    AND ((p_filters->>'score_max') IS NULL OR l.sales_score <= (p_filters->>'score_max')::int)
    AND ((p_filters->>'created_after') IS NULL OR l.created_at >= (p_filters->>'created_after')::timestamptz)
    AND ((p_filters->>'created_before') IS NULL OR l.created_at <= (p_filters->>'created_before')::timestamptz)
    AND (p_filters->'sales_rep_ids' IS NULL OR jsonb_array_length(p_filters->'sales_rep_ids') = 0 OR l.sales_rep_id::text IN (SELECT jsonb_array_elements_text(p_filters->'sales_rep_ids')))
    AND ((p_filters->>'exclude_campaign_days') IS NULL OR NOT EXISTS (
      SELECT 1 FROM email_campaign_leads ecl JOIN email_campaigns ec ON ec.id = ecl.campaign_id
      WHERE ecl.lead_id = l.id AND ecl.status IN ('sent','delivered','opened','clicked')
        AND ecl.sent_at > now() - ((p_filters->>'exclude_campaign_days')::int || ' days')::interval));
  RETURN v_count;
END $$;


--
-- Name: get_focus_stage_mapping(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_focus_stage_mapping(p_tenant_id uuid, p_pipeline_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_config tenant_sales_config;
  v_mapping JSONB;
  v_stages RECORD;
  v_new_leads UUID;
  v_not_answered UUID;
  v_answered UUID;
  v_standby UUID;
  v_won UUID;
  v_lost UUID;
  v_nurturing UUID[] := ARRAY[]::UUID[];
  v_role_key TEXT;
BEGIN
  SELECT * INTO v_config FROM tenant_sales_config WHERE tenant_id = p_tenant_id;
  
  IF v_config.stage_role_mapping IS NOT NULL THEN
    -- Check if mapping is nested (has sdr/closer keys)
    IF v_config.stage_role_mapping ? 'sdr' OR v_config.stage_role_mapping ? 'closer' THEN
      -- Determine which sub-key to use based on pipeline_id
      IF p_pipeline_id = v_config.sdr_pipeline_id THEN
        v_role_key := 'sdr';
      ELSIF p_pipeline_id = v_config.closer_pipeline_id THEN
        v_role_key := 'closer';
      END IF;
      
      IF v_role_key IS NOT NULL AND v_config.stage_role_mapping ? v_role_key THEN
        RETURN v_config.stage_role_mapping -> v_role_key;
      END IF;
    ELSE
      -- Flat mapping (legacy), return as-is
      RETURN v_config.stage_role_mapping;
    END IF;
  END IF;

  -- Auto-derive from pipeline stages by position (1-based)
  FOR v_stages IN
    SELECT id, position, is_won, is_lost
    FROM sales_pipeline_stages
    WHERE pipeline_id = p_pipeline_id
    ORDER BY position ASC
  LOOP
    IF v_stages.is_won THEN
      v_won := v_stages.id;
    ELSIF v_stages.is_lost THEN
      v_lost := v_stages.id;
    ELSIF v_stages.position = 1 THEN
      v_new_leads := v_stages.id;
    ELSIF v_stages.position = 2 THEN
      v_not_answered := v_stages.id;
    ELSIF v_stages.position = 3 THEN
      v_answered := v_stages.id;
    ELSIF v_stages.position = 4 THEN
      v_standby := v_stages.id;
    ELSE
      v_nurturing := array_append(v_nurturing, v_stages.id);
    END IF;
  END LOOP;

  v_mapping := jsonb_build_object(
    'new_leads', v_new_leads,
    'not_answered', v_not_answered,
    'answered', v_answered,
    'standby', v_standby,
    'won', v_won,
    'lost', v_lost,
    'nurturing', to_jsonb(v_nurturing)
  );

  RETURN v_mapping;
END;
$$;


--
-- Name: get_inbox_dashboard_metrics(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_inbox_dashboard_metrics(p_instance_id uuid DEFAULT NULL::uuid) RETURNS TABLE(total_pending bigint, critical_count bigint, warning_count bigint, ok_count bigint, avg_wait_minutes integer, max_wait_minutes integer, resolved_today bigint, total_conversations bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN RETURN QUERY
  WITH latest_messages AS (
    SELECT DISTINCT ON (COALESCE(wm.lead_id::TEXT, wm.group_id::TEXT))
      COALESCE(wm.lead_id::TEXT, wm.group_id::TEXT) AS conversation_id, wm.is_from_me, wm.created_at,
      EXTRACT(EPOCH FROM (NOW() - wm.created_at))::INTEGER / 60 AS wait_minutes
    FROM whatsapp_messages wm WHERE (p_instance_id IS NULL OR wm.instance_id = p_instance_id)
    ORDER BY COALESCE(wm.lead_id::TEXT, wm.group_id::TEXT), wm.created_at DESC
  ), pending AS (SELECT * FROM latest_messages WHERE NOT is_from_me)
  SELECT (SELECT COUNT(*) FROM pending)::BIGINT, (SELECT COUNT(*) FROM pending WHERE wait_minutes > 120)::BIGINT,
    (SELECT COUNT(*) FROM pending WHERE wait_minutes > 30 AND wait_minutes <= 120)::BIGINT,
    (SELECT COUNT(*) FROM pending WHERE wait_minutes <= 30)::BIGINT,
    COALESCE((SELECT AVG(wait_minutes)::INTEGER FROM pending), 0),
    COALESCE((SELECT MAX(wait_minutes)::INTEGER FROM pending), 0),
    (SELECT COUNT(*) FROM latest_messages WHERE is_from_me AND created_at >= CURRENT_DATE)::BIGINT,
    (SELECT COUNT(*) FROM latest_messages)::BIGINT;
END; $$;


--
-- Name: get_inbox_dashboard_metrics(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_inbox_dashboard_metrics(p_instance_id uuid, p_team_filter text) RETURNS TABLE(total_pending bigint, critical_count bigint, warning_count bigint, ok_count bigint, avg_wait_minutes integer, max_wait_minutes integer, resolved_today bigint, total_conversations bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ SELECT * FROM public.get_inbox_dashboard_metrics(p_instance_id); $$;


--
-- Name: get_instagram_inbox(uuid, text, text, uuid, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_instagram_inbox(p_account_id uuid DEFAULT NULL::uuid, p_stage_slug text DEFAULT NULL::text, p_status text DEFAULT 'open'::text, p_assigned_to uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, account_id uuid, lead_id uuid, thread_id text, participant_username text, participant_name text, participant_profile_pic text, status text, assigned_to uuid, stage_id uuid, stage_name text, stage_slug text, stage_color text, stage_position integer, last_message text, last_message_at timestamp with time zone, last_client_message_at timestamp with time zone, unread_count integer, total_messages integer, created_at timestamp with time zone, lead_name text, lead_phone text, lead_instagram text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.account_id, c.lead_id, c.thread_id,
    c.participant_username, c.participant_name, c.participant_profile_pic,
    c.status, c.assigned_to,
    s.id as stage_id, s.name as stage_name, s.slug as stage_slug,
    s.color as stage_color, s.position as stage_position,
    c.last_message, c.last_message_at, c.last_client_message_at,
    c.unread_count, c.total_messages, c.created_at,
    l.name as lead_name, l.phone as lead_phone, l.instagram as lead_instagram
  FROM instagram_conversations c
  LEFT JOIN social_seller_stages s ON c.social_seller_stage_id = s.id
  LEFT JOIN leads l ON c.lead_id = l.id
  WHERE c.tenant_id = (SELECT public.get_tenant_id())
    AND (p_account_id IS NULL OR c.account_id = p_account_id)
    AND (p_status IS NULL OR c.status = p_status)
    AND (p_stage_slug IS NULL OR s.slug = p_stage_slug)
    AND (p_assigned_to IS NULL OR c.assigned_to = p_assigned_to)
    AND (p_search IS NULL
      OR c.participant_username ILIKE '%' || p_search || '%'
      OR c.participant_name ILIKE '%' || p_search || '%'
      OR l.name ILIKE '%' || p_search || '%')
  ORDER BY c.last_message_at DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;


--
-- Name: get_last_interaction_by_leads(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_last_interaction_by_leads(p_lead_ids uuid[]) RETURNS TABLE(lead_id uuid, last_interaction timestamp with time zone, is_from_me boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ SELECT DISTINCT ON (wm.lead_id) wm.lead_id, wm.created_at, wm.is_from_me FROM whatsapp_messages wm WHERE wm.lead_id = ANY(p_lead_ids) ORDER BY wm.lead_id, wm.created_at DESC; $$;


--
-- Name: get_lead_by_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_lead_by_phone(p_phone text) RETURNS TABLE(id uuid, name text, phone text, email text, sales_score integer, company_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT l.id, l.name, l.phone, l.email, l.sales_score, l.company_name FROM leads l WHERE l.phone = p_phone OR regexp_replace(l.phone, '[^0-9]', '', 'g') = regexp_replace(p_phone, '[^0-9]', '', 'g') LIMIT 1; $$;


--
-- Name: get_next_distribution_member(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_next_distribution_member(p_config_id uuid, p_require_availability boolean DEFAULT false) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_last_member_id UUID;
  v_last_position INTEGER;
  v_next_member_id UUID;
  v_member_count INTEGER;
  v_tid uuid;
BEGIN
  v_tid := (SELECT public.get_tenant_id());

  SELECT COUNT(*) INTO v_member_count
  FROM lead_distribution_members
  WHERE config_id = p_config_id AND is_active = true AND tenant_id = v_tid;

  IF v_member_count = 0 THEN RETURN NULL; END IF;

  SELECT team_member_id INTO v_last_member_id
  FROM lead_distribution_log
  WHERE config_id = p_config_id AND tenant_id = v_tid
  ORDER BY created_at DESC LIMIT 1;

  IF v_last_member_id IS NOT NULL THEN
    SELECT position INTO v_last_position
    FROM lead_distribution_members
    WHERE config_id = p_config_id AND team_member_id = v_last_member_id AND is_active = true AND tenant_id = v_tid;
  END IF;

  IF v_last_position IS NULL THEN v_last_position := -1; END IF;

  IF p_require_availability THEN
    SELECT dm.team_member_id INTO v_next_member_id
    FROM lead_distribution_members dm
    JOIN team_members tm ON tm.id = dm.team_member_id
    WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.position > v_last_position
      AND dm.tenant_id = v_tid
      AND (tm.current_activity IS NULL OR tm.current_activity = 'available')
    ORDER BY dm.position ASC LIMIT 1;

    IF v_next_member_id IS NULL THEN
      SELECT dm.team_member_id INTO v_next_member_id
      FROM lead_distribution_members dm
      JOIN team_members tm ON tm.id = dm.team_member_id
      WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.tenant_id = v_tid
        AND (tm.current_activity IS NULL OR tm.current_activity = 'available')
      ORDER BY dm.position ASC LIMIT 1;
    END IF;
  ELSE
    SELECT dm.team_member_id INTO v_next_member_id
    FROM lead_distribution_members dm
    WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.position > v_last_position
      AND dm.tenant_id = v_tid
    ORDER BY dm.position ASC LIMIT 1;

    IF v_next_member_id IS NULL THEN
      SELECT dm.team_member_id INTO v_next_member_id
      FROM lead_distribution_members dm
      WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.tenant_id = v_tid
      ORDER BY dm.position ASC LIMIT 1;
    END IF;
  END IF;

  RETURN v_next_member_id;
END;
$$;


--
-- Name: get_next_distribution_member(uuid, boolean, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_next_distribution_member(p_config_id uuid, p_require_availability boolean DEFAULT false, p_tenant_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_last_member_id UUID;
  v_last_position INTEGER;
  v_next_member_id UUID;
  v_member_count INTEGER;
  v_tid uuid;
BEGIN
  -- Use explicit tenant_id if provided, otherwise fallback to JWT
  v_tid := COALESCE(p_tenant_id, (SELECT public.get_tenant_id()));

  SELECT COUNT(*) INTO v_member_count
  FROM lead_distribution_members
  WHERE config_id = p_config_id AND is_active = true AND tenant_id = v_tid;

  IF v_member_count = 0 THEN RETURN NULL; END IF;

  SELECT team_member_id INTO v_last_member_id
  FROM lead_distribution_log
  WHERE config_id = p_config_id AND tenant_id = v_tid
  ORDER BY created_at DESC LIMIT 1;

  IF v_last_member_id IS NOT NULL THEN
    SELECT position INTO v_last_position
    FROM lead_distribution_members
    WHERE config_id = p_config_id AND team_member_id = v_last_member_id AND is_active = true AND tenant_id = v_tid;
  END IF;

  IF v_last_position IS NULL THEN v_last_position := -1; END IF;

  IF p_require_availability THEN
    SELECT dm.team_member_id INTO v_next_member_id
    FROM lead_distribution_members dm
    JOIN team_members tm ON tm.id = dm.team_member_id
    WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.position > v_last_position
      AND dm.tenant_id = v_tid
      AND (tm.current_activity IS NULL OR tm.current_activity = 'available')
    ORDER BY dm.position ASC LIMIT 1;

    IF v_next_member_id IS NULL THEN
      SELECT dm.team_member_id INTO v_next_member_id
      FROM lead_distribution_members dm
      JOIN team_members tm ON tm.id = dm.team_member_id
      WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.tenant_id = v_tid
        AND (tm.current_activity IS NULL OR tm.current_activity = 'available')
      ORDER BY dm.position ASC LIMIT 1;
    END IF;
  ELSE
    SELECT dm.team_member_id INTO v_next_member_id
    FROM lead_distribution_members dm
    WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.position > v_last_position
      AND dm.tenant_id = v_tid
    ORDER BY dm.position ASC LIMIT 1;

    IF v_next_member_id IS NULL THEN
      SELECT dm.team_member_id INTO v_next_member_id
      FROM lead_distribution_members dm
      WHERE dm.config_id = p_config_id AND dm.is_active = true AND dm.tenant_id = v_tid
      ORDER BY dm.position ASC LIMIT 1;
    END IF;
  END IF;

  RETURN v_next_member_id;
END;
$$;


--
-- Name: get_next_franchise_member(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_next_franchise_member(p_campaign_id uuid, p_city text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_last_member_id UUID;
  v_last_position INTEGER;
  v_next_member_id UUID;
  v_member_count INTEGER;
BEGIN
  -- Count active members (optionally filtered by city)
  SELECT COUNT(*) INTO v_member_count
  FROM franchise_members
  WHERE campaign_id = p_campaign_id AND is_active = true
    AND (p_city IS NULL OR cities = '{}' OR p_city = ANY(cities));

  IF v_member_count = 0 THEN RETURN NULL; END IF;

  -- Get last distributed member
  SELECT franchise_member_id INTO v_last_member_id
  FROM franchise_distribution_log
  WHERE campaign_id = p_campaign_id
  ORDER BY created_at DESC LIMIT 1;

  IF v_last_member_id IS NOT NULL THEN
    SELECT position INTO v_last_position
    FROM franchise_members
    WHERE campaign_id = p_campaign_id AND id = v_last_member_id AND is_active = true;
  END IF;

  IF v_last_position IS NULL THEN v_last_position := -1; END IF;

  -- Get next member after last position
  SELECT id INTO v_next_member_id
  FROM franchise_members
  WHERE campaign_id = p_campaign_id AND is_active = true AND position > v_last_position
    AND (p_city IS NULL OR cities = '{}' OR p_city = ANY(cities))
  ORDER BY position ASC LIMIT 1;

  -- Wrap around if needed
  IF v_next_member_id IS NULL THEN
    SELECT id INTO v_next_member_id
    FROM franchise_members
    WHERE campaign_id = p_campaign_id AND is_active = true
      AND (p_city IS NULL OR cities = '{}' OR p_city = ANY(cities))
    ORDER BY position ASC LIMIT 1;
  END IF;

  RETURN v_next_member_id;
END;
$$;


--
-- Name: get_response_templates(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_response_templates(p_team text DEFAULT 'cs'::text, p_category text DEFAULT NULL::text) RETURNS TABLE(id uuid, name text, content text, category text, shortcut text, usage_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.name, t.content, t.category, t.shortcut, t.usage_count
  FROM cs_response_templates t
  WHERE t.tenant_id = (SELECT public.get_tenant_id())
    AND t.team = p_team AND t.is_active = TRUE
    AND (p_category IS NULL OR t.category = p_category)
  ORDER BY t.usage_count DESC, t.name;
END;
$$;


--
-- Name: get_sales_performance(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_sales_performance(p_date_from date DEFAULT NULL::date, p_date_to date DEFAULT NULL::date) RETURNS TABLE(team_member_id uuid, team_member_name text, deals_count bigint, total_revenue numeric, won_count bigint, lost_count bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ SELECT tm.id, tm.name, COUNT(d.id)::bigint, COALESCE(SUM(d.negotiated_price) FILTER (WHERE d.status = 'won'), 0)::numeric, COUNT(d.id) FILTER (WHERE d.status = 'won')::bigint, COUNT(d.id) FILTER (WHERE d.status = 'lost')::bigint FROM team_members tm LEFT JOIN deals d ON d.sales_rep_id = tm.id AND (p_date_from IS NULL OR d.created_at::date >= p_date_from) AND (p_date_to IS NULL OR d.created_at::date <= p_date_to) GROUP BY tm.id, tm.name ORDER BY 4 DESC; $$;


--
-- Name: get_social_seller_funnel_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_social_seller_funnel_stats(p_account_id uuid DEFAULT NULL::uuid) RETURNS TABLE(stage_slug text, stage_name text, stage_color text, stage_position integer, conversation_count bigint, unread_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT s.slug as stage_slug, s.name as stage_name,
    s.color as stage_color, s.position as stage_position,
    COUNT(c.id) as conversation_count,
    COALESCE(SUM(c.unread_count), 0) as unread_count
  FROM social_seller_stages s
  LEFT JOIN instagram_conversations c ON c.social_seller_stage_id = s.id
    AND c.status = 'open'
    AND c.tenant_id = (SELECT public.get_tenant_id())
    AND (p_account_id IS NULL OR c.account_id = p_account_id)
  WHERE s.tenant_id = (SELECT public.get_tenant_id())
    AND s.is_active = true
  GROUP BY s.id, s.slug, s.name, s.color, s.position
  ORDER BY s.position;
END;
$$;


--
-- Name: get_stale_leads_never_contacted(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_stale_leads_never_contacted() RETURNS TABLE(deal_id uuid, deal_created_at timestamp with time zone, deal_updated_at timestamp with time zone, deal_pipeline_stage_id uuid, deal_sales_rep_id uuid, lead_id uuid, lead_name text, lead_phone text, lead_email text, rep_name text, waiting_hours numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_new_lead_stages uuid[];
BEGIN
  -- Etapas "leads novos" vêm da config PIPELINE_ROLES (stages.sdr_leads_novos / stages.closer_leads_novos).
  -- Sem config → sem alertas (comportamento neutro em instalações novas).
  SELECT ARRAY_REMOVE(ARRAY[
    ((c.value)::jsonb->'stages'->>'sdr_leads_novos')::uuid,
    ((c.value)::jsonb->'stages'->>'closer_leads_novos')::uuid
  ], NULL)
  INTO v_new_lead_stages
  FROM config c WHERE c.key = 'PIPELINE_ROLES';

  IF v_new_lead_stages IS NULL OR array_length(v_new_lead_stages, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    d.id,
    d.created_at,
    d.updated_at,
    d.pipeline_stage_id,
    d.sales_rep_id,
    l.id,
    l.name,
    l.phone,
    l.email,
    tm.name,
    round(EXTRACT(EPOCH FROM (now() - d.created_at)) / 3600.0, 1)
  FROM deals d
  JOIN leads l ON l.id = d.lead_id
  LEFT JOIN team_members tm ON tm.id = d.sales_rep_id
  WHERE d.tenant_id = get_tenant_id()
    AND d.status = 'negotiation'
    AND d.pipeline_stage_id = ANY(v_new_lead_stages)
    AND d.metadata @> '{"source": "receive-lead"}'
    -- Nunca teve ligação
    AND NOT EXISTS (
      SELECT 1 FROM call_history ch WHERE ch.lead_id = l.id
    )
    -- Nunca recebeu WhatsApp do vendedor
    AND NOT EXISTS (
      SELECT 1 FROM whatsapp_messages wm WHERE wm.lead_id = l.id AND wm.is_from_me = true
    )
    -- Não tem deal ativo em outra etapa (já trabalhado em outro pipeline)
    AND NOT EXISTS (
      SELECT 1 FROM deals d2 
      WHERE d2.lead_id = l.id 
        AND d2.id != d.id 
        AND NOT (d2.pipeline_stage_id = ANY(v_new_lead_stages))
        AND d2.status = 'negotiation'
    )
  ORDER BY d.created_at ASC;
END;
$$;


--
-- Name: team_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.team_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    role text DEFAULT 'user'::text NOT NULL,
    team text,
    phone text,
    avatar_url text,
    is_active boolean DEFAULT true,
    auth_user_id uuid,
    google_access_token text,
    google_refresh_token text,
    google_token_expires_at timestamp with time zone,
    google_calendar_connected boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    google_calendar_sync_token text,
    google_calendar_watch_channel_id text,
    google_calendar_watch_resource_id text,
    google_calendar_watch_expiration timestamp with time zone,
    whatsapp_instance_id uuid,
    focus_mode_enabled boolean DEFAULT false,
    zadarma_enabled boolean DEFAULT false,
    zadarma_sip text,
    zadarma_caller_id text,
    zadarma_sip_password text,
    telnyx_enabled boolean DEFAULT false,
    telnyx_caller_id text,
    focus_mode_config jsonb DEFAULT '{}'::jsonb,
    availability_status text DEFAULT 'available'::text NOT NULL,
    paused_at timestamp with time zone,
    paused_reason text,
    current_activity text DEFAULT 'available'::text,
    current_activity_meta jsonb DEFAULT '{}'::jsonb,
    current_activity_at timestamp with time zone,
    twilio_enabled boolean DEFAULT false,
    twilio_caller_id text,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    sub_role text,
    is_superadmin boolean DEFAULT false,
    wavoip_device_id uuid,
    working_hours jsonb DEFAULT '{"fri": {"end": "18:00", "start": "09:00"}, "mon": {"end": "18:00", "start": "09:00"}, "thu": {"end": "18:00", "start": "09:00"}, "tue": {"end": "18:00", "start": "09:00"}, "wed": {"end": "18:00", "start": "09:00"}}'::jsonb,
    meeting_duration_minutes integer DEFAULT 60,
    CONSTRAINT chk_availability_status CHECK ((availability_status = ANY (ARRAY['available'::text, 'paused'::text, 'break'::text, 'offline'::text]))),
    CONSTRAINT team_members_current_activity_check CHECK ((current_activity = ANY (ARRAY['available'::text, 'dialing'::text, 'on_call'::text, 'in_meeting'::text, 'post_call'::text]))),
    CONSTRAINT team_members_sub_role_check CHECK ((sub_role = ANY (ARRAY['sdr'::text, 'closer'::text])))
);


--
-- Name: COLUMN team_members.availability_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_members.availability_status IS 'Current availability: available, paused, break, offline';


--
-- Name: COLUMN team_members.paused_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_members.paused_at IS 'When the member paused/went on break';


--
-- Name: COLUMN team_members.paused_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_members.paused_reason IS 'Optional reason for pause (almoco, banheiro, etc)';


--
-- Name: COLUMN team_members.current_activity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_members.current_activity IS 'Persistent activity: available, dialing, on_call, in_meeting, post_call';


--
-- Name: COLUMN team_members.current_activity_meta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_members.current_activity_meta IS 'Activity metadata: {leadId, leadName, phone, callId, meetingId, direction}';


--
-- Name: COLUMN team_members.current_activity_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_members.current_activity_at IS 'When the current activity started';


--
-- Name: get_team_member_by_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_team_member_by_email(user_email text) RETURNS SETOF public.team_members
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY SELECT *
  FROM team_members tm 
  WHERE tm.email = user_email AND tm.is_active = true 
  LIMIT 1;
END;
$$;


--
-- Name: get_tenant_branding(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_tenant_branding(lookup_domain text DEFAULT NULL::text, lookup_name text DEFAULT NULL::text) RETURNS TABLE(company_name text, logo_url text, favicon_url text, primary_color text, secondary_color text, background_color text, text_color text, custom_domain text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT tc.company_name, tc.logo_url, tc.favicon_url, tc.primary_color, 
         tc.secondary_color, tc.background_color, tc.text_color, tc.custom_domain
  FROM tenant_config tc
  WHERE (lookup_domain IS NOT NULL AND tc.custom_domain = lookup_domain)
     OR (lookup_name IS NOT NULL AND LOWER(tc.company_name) = LOWER(lookup_name))
  LIMIT 1;
END;
$$;


--
-- Name: get_tenant_options_for_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_tenant_options_for_email(user_email text) RETURNS TABLE(tenant_id uuid, tenant_name text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY SELECT DISTINCT tm.tenant_id, t.name as tenant_name
  FROM team_members tm JOIN tenants t ON t.id = tm.tenant_id
  WHERE tm.email = user_email AND tm.is_active = true;
END;
$$;


--
-- Name: tenant_sales_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.tenant_sales_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    has_sdr_closer_split boolean DEFAULT false NOT NULL,
    sdr_pipeline_id uuid,
    closer_pipeline_id uuid,
    transfer_required_fields jsonb DEFAULT '["timing_negocio", "regiao_interesse", "capital_disponivel"]'::jsonb NOT NULL,
    transfer_auto_assign_closer boolean DEFAULT true NOT NULL,
    closer_distribution_config_id uuid,
    closer_accept_required boolean DEFAULT true NOT NULL,
    cadence_rules jsonb DEFAULT '[{"maxDays": 30, "callsPerDay": 3, "frequencyDays": 1}, {"maxDays": 60, "callsPerDay": 1, "frequencyDays": 3}, {"maxDays": 90, "callsPerDay": 1, "frequencyDays": 5}, {"maxDays": null, "callsPerDay": 1, "frequencyDays": 7}]'::jsonb NOT NULL,
    sla_minutes integer DEFAULT 4 NOT NULL,
    retry_cooldown_minutes integer DEFAULT 180 NOT NULL,
    meeting_prep_window_minutes integer DEFAULT 10 NOT NULL,
    task_grace_minutes integer DEFAULT 5 NOT NULL,
    sdr_daily_call_target integer DEFAULT 200,
    closer_daily_call_target integer DEFAULT 50,
    stage_role_mapping jsonb,
    noshow_auto_return boolean DEFAULT false NOT NULL,
    noshow_return_after_hours integer DEFAULT 24,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: get_tenant_sales_config(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_tenant_sales_config(p_tenant_id uuid) RETURNS SETOF public.tenant_sales_config
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Create default if not exists
  INSERT INTO tenant_sales_config (tenant_id)
  VALUES (p_tenant_id)
  ON CONFLICT (tenant_id) DO NOTHING;

  RETURN QUERY
  SELECT * FROM tenant_sales_config WHERE tenant_id = p_tenant_id LIMIT 1;
END;
$$;


--
-- Name: get_unread_messages_by_leads(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_unread_messages_by_leads(p_lead_ids uuid[]) RETURNS TABLE(lead_id uuid, unread_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ SELECT wm.lead_id, COUNT(*)::bigint FROM whatsapp_messages wm WHERE wm.lead_id = ANY(p_lead_ids) AND NOT wm.is_from_me GROUP BY wm.lead_id; $$;


--
-- Name: get_user_by_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.get_user_by_email(p_email text) RETURNS TABLE(id uuid, email text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY SELECT u.id, u.email::text FROM auth.users u WHERE u.email = p_email LIMIT 1;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, tenant_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_app_meta_data->>'tenant_id')::uuid, public.get_tenant_id())
  );
  RETURN NEW;
END;
$$;


--
-- Name: health_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.health_check() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_active INT; v_max INT; v_slow JSONB; v_tables JSONB;
BEGIN
  SELECT count(*) INTO v_active FROM pg_stat_activity WHERE pid != pg_backend_pid();
  SELECT setting::int INTO v_max FROM pg_settings WHERE name = 'max_connections';
  SELECT COALESCE(jsonb_agg(jsonb_build_object('duration', round(EXTRACT(EPOCH FROM (now() - query_start)))::text || 's', 'query', left(query, 120), 'state', state)), '[]'::jsonb) INTO v_slow FROM pg_stat_activity WHERE state = 'active' AND query_start < now() - interval '10 seconds' AND pid != pg_backend_pid() AND query NOT LIKE '%health_check%' AND query NOT LIKE '%START_REPLICATION%' AND query NOT LIKE '%autovacuum%' AND backend_type = 'client backend';
  SELECT COALESCE(jsonb_agg(jsonb_build_object('name', relname, 'size_mb', round((pg_total_relation_size(c.oid) / 1048576.0)::numeric, 0)) ORDER BY pg_total_relation_size(c.oid) DESC), '[]'::jsonb) INTO v_tables FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind = 'r' AND pg_total_relation_size(c.oid) > 100 * 1048576;
  RETURN jsonb_build_object('active_connections', v_active, 'max_connections', v_max, 'slow_queries', v_slow, 'big_tables', v_tables, 'checked_at', now());
END; $$;


--
-- Name: increment_campaign_counter(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.increment_campaign_counter(p_campaign_id uuid, p_field text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
  IF auth.uid() IS NULL AND current_setting('request.jwt.claims', true)::jsonb->>'role' != 'service_role' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  EXECUTE format('UPDATE campaigns SET %I = COALESCE(%I, 0) + 1, updated_at = now() WHERE id = $1', p_field, p_field) USING p_campaign_id;
END;
$_$;


--
-- Name: increment_email_campaign_counter(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.increment_email_campaign_counter(p_campaign_id uuid, p_field text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
  IF auth.uid() IS NULL AND current_setting('request.jwt.claims', true)::jsonb->>'role' != 'service_role' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  EXECUTE format('UPDATE email_campaigns SET %I = COALESCE(%I, 0) + 1, updated_at = now() WHERE id = $1', p_field, p_field) USING p_campaign_id;
END;
$_$;


--
-- Name: is_marketing_manager(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.is_marketing_manager() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE auth_user_id = auth.uid()
      AND role = 'admin'
      AND is_active = true
      AND tenant_id = public.get_tenant_id()
  );
$$;


--
-- Name: is_superadmin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.is_superadmin() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM team_members 
    WHERE auth_user_id = auth.uid() 
    AND is_superadmin = true
  );
END;
$$;


--
-- Name: is_tenant_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.is_tenant_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE auth_user_id = auth.uid()
      AND role = 'admin'
      AND tenant_id = get_tenant_id()
  )
$$;


--
-- Name: link_auth_user_to_team_member(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.link_auth_user_to_team_member(user_email text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_count int; v_first_tenant text;
BEGIN
  -- Linka TODOS os team_members do email (multi-tenant)
  UPDATE team_members SET auth_user_id = auth.uid()
  WHERE email = user_email AND auth_user_id IS NULL AND is_active = true;

  -- Conta quantos tenants o usuario tem
  SELECT COUNT(*), MIN(tenant_id::text) INTO v_count, v_first_tenant
  FROM team_members WHERE email = user_email AND is_active = true;

  -- So stampa JWT automaticamente se tiver 1 unico tenant
  IF v_count = 1 THEN
    UPDATE auth.users SET raw_app_meta_data = COALESCE(raw_app_meta_data,'{}'::jsonb)
      || jsonb_build_object('tenant_id', v_first_tenant)
    WHERE id = auth.uid() AND (raw_app_meta_data->>'tenant_id' IS NULL
      OR raw_app_meta_data->>'tenant_id' != v_first_tenant);
  END IF;
END;
$$;


--
-- Name: log_ai_agent_event(uuid, text, text, text, uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.log_ai_agent_event(p_lead_id uuid, p_event_type text, p_message text, p_reason text DEFAULT NULL::text, p_agent_id uuid DEFAULT NULL::uuid, p_conversation_id uuid DEFAULT NULL::uuid, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    AS $$ INSERT INTO public.ai_agent_chat_events (lead_id, agent_id, conversation_id, event_type, reason, message, metadata) VALUES (p_lead_id, p_agent_id, p_conversation_id, p_event_type, p_reason, p_message, p_metadata) RETURNING id; $$;


--
-- Name: mark_conversation_handled(uuid, uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.mark_conversation_handled(p_lead_id uuid DEFAULT NULL::uuid, p_group_id uuid DEFAULT NULL::uuid, p_handled_by uuid DEFAULT NULL::uuid, p_reason text DEFAULT 'replied_manually'::text, p_notes text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_tid uuid;
BEGIN
  v_tid := (SELECT public.get_tenant_id());
  IF p_lead_id IS NULL AND p_group_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'lead_id ou group_id obrigatorio');
  END IF;
  IF p_lead_id IS NOT NULL THEN
    INSERT INTO cs_conversation_handled (lead_id, group_id, handled_by, reason, notes, handled_at, tenant_id)
    VALUES (p_lead_id, NULL, p_handled_by, p_reason, p_notes, NOW(), v_tid)
    ON CONFLICT (lead_id) WHERE lead_id IS NOT NULL
    DO UPDATE SET
      handled_by = EXCLUDED.handled_by,
      reason = EXCLUDED.reason,
      notes = EXCLUDED.notes,
      handled_at = NOW();
  ELSE
    INSERT INTO cs_conversation_handled (lead_id, group_id, handled_by, reason, notes, handled_at, tenant_id)
    VALUES (NULL, p_group_id, p_handled_by, p_reason, p_notes, NOW(), v_tid)
    ON CONFLICT (group_id) WHERE group_id IS NOT NULL
    DO UPDATE SET
      handled_by = EXCLUDED.handled_by,
      reason = EXCLUDED.reason,
      notes = EXCLUDED.notes,
      handled_at = NOW();
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: minutes_since_last_action(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.minutes_since_last_action(p_lead_id uuid) RETURNS integer
    LANGUAGE sql STABLE
    AS $$
  SELECT COALESCE(EXTRACT(EPOCH FROM (now() - max(created_at)))::int / 60, 99999)
  FROM social_selling_interactions
  WHERE lead_id = p_lead_id AND status = 'success'
$$;


--
-- Name: normalize_phone_last8(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.normalize_phone_last8(p_phone text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN RIGHT(REGEXP_REPLACE(COALESCE(p_phone, ''), '[^0-9]', '', 'g'), 8);
END;
$$;


--
-- Name: populate_campaign_leads(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.populate_campaign_leads(p_campaign_id uuid, p_tenant_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE v_filters JSONB; v_count INTEGER; v_query TEXT;
BEGIN
  SELECT audience_filters INTO v_filters FROM campaigns WHERE id = p_campaign_id AND tenant_id = p_tenant_id;
  IF v_filters IS NULL THEN RAISE EXCEPTION 'Campaign not found or no filters'; END IF;

  IF v_filters ? 'lead_ids' AND jsonb_array_length(v_filters->'lead_ids') > 0 THEN
    INSERT INTO campaign_leads (tenant_id, campaign_id, lead_id, assigned_to)
    SELECT p_tenant_id, p_campaign_id, l.id, l.sales_rep_id
    FROM leads l
    WHERE l.tenant_id = p_tenant_id
      AND l.id::text IN (SELECT jsonb_array_elements_text(v_filters->'lead_ids'))
      AND l.phone IS NOT NULL AND l.phone != ''
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    UPDATE campaigns SET total_leads = v_count, audience_count = v_count, updated_at = now() WHERE id = p_campaign_id;
    RETURN v_count;
  END IF;

  v_query := 'INSERT INTO campaign_leads (tenant_id, campaign_id, lead_id, assigned_to)
    SELECT $1, $3, l.id, l.sales_rep_id FROM leads l WHERE l.tenant_id = $1';

  IF v_filters ? 'pipeline_stage_ids' AND jsonb_array_length(v_filters->'pipeline_stage_ids') > 0 THEN
    v_query := v_query || ' AND l.pipeline_stage_id IN (SELECT jsonb_array_elements_text($2->''pipeline_stage_ids'')::UUID)';
  END IF;
  IF v_filters ? 'sales_stages' AND jsonb_array_length(v_filters->'sales_stages') > 0 THEN
    v_query := v_query || ' AND l.sales_stage IN (SELECT jsonb_array_elements_text($2->''sales_stages''))';
  END IF;
  IF v_filters ? 'created_after' THEN v_query := v_query || ' AND l.created_at >= ($2->>''created_after'')::TIMESTAMPTZ'; END IF;
  IF v_filters ? 'created_before' THEN v_query := v_query || ' AND l.created_at <= ($2->>''created_before'')::TIMESTAMPTZ'; END IF;
  IF v_filters ? 'last_interaction_after' THEN v_query := v_query || ' AND l.last_interaction_at >= ($2->>''last_interaction_after'')::TIMESTAMPTZ'; END IF;
  IF v_filters ? 'last_interaction_before' THEN v_query := v_query || ' AND l.last_interaction_at <= ($2->>''last_interaction_before'')::TIMESTAMPTZ'; END IF;
  IF v_filters ? 'capital_min' THEN v_query := v_query || ' AND (l.metadata->>''capital_disponivel'')::NUMERIC >= ($2->>''capital_min'')::NUMERIC'; END IF;
  IF v_filters ? 'capital_max' THEN v_query := v_query || ' AND (l.metadata->>''capital_disponivel'')::NUMERIC <= ($2->>''capital_max'')::NUMERIC'; END IF;
  IF v_filters ? 'cities' AND jsonb_array_length(v_filters->'cities') > 0 THEN v_query := v_query || ' AND l.city_name IN (SELECT jsonb_array_elements_text($2->''cities''))'; END IF;
  IF v_filters ? 'states' AND jsonb_array_length(v_filters->'states') > 0 THEN v_query := v_query || ' AND l.state IN (SELECT jsonb_array_elements_text($2->''states''))'; END IF;
  IF v_filters ? 'utm_sources' AND jsonb_array_length(v_filters->'utm_sources') > 0 THEN v_query := v_query || ' AND l.utm_source IN (SELECT jsonb_array_elements_text($2->''utm_sources''))'; END IF;
  IF v_filters ? 'utm_campaigns' AND jsonb_array_length(v_filters->'utm_campaigns') > 0 THEN v_query := v_query || ' AND l.utm_campaign IN (SELECT jsonb_array_elements_text($2->''utm_campaigns''))'; END IF;
  IF v_filters ? 'score_min' THEN v_query := v_query || ' AND l.sales_score >= ($2->>''score_min'')::NUMERIC'; END IF;
  IF v_filters ? 'score_max' THEN v_query := v_query || ' AND l.sales_score <= ($2->>''score_max'')::NUMERIC'; END IF;
  IF v_filters ? 'sales_rep_ids' AND jsonb_array_length(v_filters->'sales_rep_ids') > 0 THEN v_query := v_query || ' AND l.sales_rep_id IN (SELECT jsonb_array_elements_text($2->''sales_rep_ids'')::UUID)'; END IF;
  IF v_filters ? 'no_sales_rep' AND (v_filters->>'no_sales_rep')::BOOLEAN THEN v_query := v_query || ' AND l.sales_rep_id IS NULL'; END IF;
  IF v_filters ? 'bant_budget' AND (v_filters->>'bant_budget')::BOOLEAN THEN v_query := v_query || ' AND l.bant_budget = true'; END IF;
  IF v_filters ? 'bant_authority' AND (v_filters->>'bant_authority')::BOOLEAN THEN v_query := v_query || ' AND l.bant_authority = true'; END IF;
  IF v_filters ? 'bant_need' AND (v_filters->>'bant_need')::BOOLEAN THEN v_query := v_query || ' AND l.bant_need = true'; END IF;
  IF v_filters ? 'bant_timeline' AND (v_filters->>'bant_timeline')::BOOLEAN THEN v_query := v_query || ' AND l.bant_timeline = true'; END IF;

  v_query := v_query || ' AND l.phone IS NOT NULL AND l.phone != ''''';

  IF v_filters ? 'exclude_campaign_days' THEN
    v_query := v_query || ' AND l.id NOT IN (SELECT cl.lead_id FROM campaign_leads cl JOIN campaigns c ON c.id = cl.campaign_id WHERE cl.status NOT IN (''skipped'',''failed'') AND cl.sent_at > now() - (($2->>''exclude_campaign_days'')::int || '' days'')::interval)';
  END IF;
  IF v_filters ? 'exclude_lead_ids' AND jsonb_array_length(v_filters->'exclude_lead_ids') > 0 THEN
    v_query := v_query || ' AND l.id::text NOT IN (SELECT jsonb_array_elements_text($2->''exclude_lead_ids''))';
  END IF;
  v_query := v_query || ' ON CONFLICT DO NOTHING';

  EXECUTE v_query USING p_tenant_id, v_filters, p_campaign_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  UPDATE campaigns SET total_leads = v_count, audience_count = v_count, updated_at = now() WHERE id = p_campaign_id;
  RETURN v_count;
END;
$_$;


--
-- Name: populate_email_campaign_leads(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.populate_email_campaign_leads(p_campaign_id uuid, p_tenant_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE v_count INT; v_filters JSONB;
BEGIN
  SELECT audience_filters INTO v_filters FROM email_campaigns WHERE id = p_campaign_id AND tenant_id = p_tenant_id;
  IF v_filters IS NULL THEN v_filters := '{}'; END IF;

  DELETE FROM email_campaign_leads WHERE campaign_id = p_campaign_id AND status = 'pending';

  IF v_filters ? 'lead_ids' AND jsonb_array_length(v_filters->'lead_ids') > 0 THEN
    INSERT INTO email_campaign_leads (tenant_id, campaign_id, lead_id, email, name)
    SELECT p_tenant_id, p_campaign_id, l.id, l.email, l.name
    FROM leads l
    WHERE l.tenant_id = p_tenant_id
      AND l.id::text IN (SELECT jsonb_array_elements_text(v_filters->'lead_ids'))
      AND l.email IS NOT NULL AND l.email != ''
      AND (l.email_opted_out IS NULL OR l.email_opted_out = false)
      AND NOT EXISTS (SELECT 1 FROM email_unsubscribes u WHERE u.tenant_id = p_tenant_id AND u.email = l.email)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
  END IF;

  INSERT INTO email_campaign_leads (tenant_id, campaign_id, lead_id, email, name)
  SELECT p_tenant_id, p_campaign_id, l.id, l.email, l.name
  FROM leads l
  WHERE l.tenant_id = p_tenant_id
    AND l.email IS NOT NULL AND l.email != ''
    AND (l.email_opted_out IS NULL OR l.email_opted_out = false)
    AND NOT EXISTS (SELECT 1 FROM email_unsubscribes u WHERE u.tenant_id = p_tenant_id AND u.email = l.email)
    AND (v_filters->'pipeline_stage_ids' IS NULL OR jsonb_array_length(v_filters->'pipeline_stage_ids') = 0 OR l.pipeline_stage_id::text IN (SELECT jsonb_array_elements_text(v_filters->'pipeline_stage_ids')))
    AND (v_filters->'states' IS NULL OR jsonb_array_length(v_filters->'states') = 0 OR l.state IN (SELECT jsonb_array_elements_text(v_filters->'states')))
    AND (v_filters->'cities' IS NULL OR jsonb_array_length(v_filters->'cities') = 0 OR l.city_name IN (SELECT jsonb_array_elements_text(v_filters->'cities')))
    AND (v_filters->'utm_sources' IS NULL OR jsonb_array_length(v_filters->'utm_sources') = 0 OR l.utm_source IN (SELECT jsonb_array_elements_text(v_filters->'utm_sources')))
    AND ((v_filters->>'score_min') IS NULL OR l.sales_score >= (v_filters->>'score_min')::int)
    AND ((v_filters->>'score_max') IS NULL OR l.sales_score <= (v_filters->>'score_max')::int)
    AND ((v_filters->>'created_after') IS NULL OR l.created_at >= (v_filters->>'created_after')::timestamptz)
    AND ((v_filters->>'created_before') IS NULL OR l.created_at <= (v_filters->>'created_before')::timestamptz)
    AND (v_filters->'sales_rep_ids' IS NULL OR jsonb_array_length(v_filters->'sales_rep_ids') = 0 OR l.sales_rep_id::text IN (SELECT jsonb_array_elements_text(v_filters->'sales_rep_ids')))
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;


--
-- Name: process_ai_agent_queue(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.process_ai_agent_queue() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ DECLARE v_url TEXT; BEGIN UPDATE ai_agent_message_queue SET status = 'pending' WHERE status = 'processing' AND processed_at IS NULL AND created_at < now() - interval '3 minutes'; SELECT value INTO v_url FROM config WHERE key = 'SUPABASE_PROJECT_URL'; IF v_url IS NULL THEN RETURN; END IF; IF EXISTS (SELECT 1 FROM ai_agent_message_queue WHERE status = 'pending' AND scheduled_for <= now()) THEN PERFORM net.http_post(url := v_url || '/functions/v1/ai-sales-agent', headers := public.edge_request_headers(), body := '{"action":"process_queue"}'::jsonb); END IF; END $$;


--
-- Name: release_agent_lock(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.release_agent_lock(p_lead_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ BEGIN UPDATE ai_agent_conversations SET processing_lock = NULL WHERE lead_id = p_lead_id; END $$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: search_leads_focus(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.search_leads_focus(search_term text, rep_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, name text, phone text, email text, company_name text, city_name text, state text, sales_score integer, sales_stage text, capital_disponivel text, deal_stage_name text, deal_pipeline_stage_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  normalized text;
  digits_only text;
  v_tid uuid;
BEGIN
  v_tid := (SELECT public.get_tenant_id());
  normalized := lower(extensions.unaccent(trim(search_term)));
  digits_only := regexp_replace(normalized, '[^0-9]', '', 'g');
  IF length(normalized) < 2 THEN RETURN; END IF;

  RETURN QUERY
  SELECT l.id, l.name, l.phone, l.email, l.company_name,
    l.city_name::text, l.state::text, l.sales_score::int,
    l.sales_stage::text, l.capital_disponivel,
    sps.name AS deal_stage_name, d.pipeline_stage_id AS deal_pipeline_stage_id
  FROM leads l
  LEFT JOIN LATERAL (
    SELECT dd.pipeline_stage_id FROM deals dd
    WHERE dd.lead_id = l.id AND dd.status IN ('open', 'negotiation') AND dd.tenant_id = v_tid
    ORDER BY dd.updated_at DESC LIMIT 1
  ) d ON true
  LEFT JOIN sales_pipeline_stages sps ON sps.id = d.pipeline_stage_id
  WHERE l.tenant_id = v_tid
    AND (rep_id IS NULL OR l.sales_rep_id = rep_id)
    AND (
      lower(extensions.unaccent(coalesce(l.name, ''))) ILIKE '%' || normalized || '%'
      OR lower(extensions.unaccent(coalesce(l.email, ''))) ILIKE '%' || normalized || '%'
      OR lower(extensions.unaccent(coalesce(l.company_name, ''))) ILIKE '%' || normalized || '%'
      OR lower(extensions.unaccent(coalesce(l.city_name::text, ''))) ILIKE '%' || normalized || '%'
      OR (length(digits_only) >= 3 AND regexp_replace(coalesce(l.phone, ''), '[^0-9]', '', 'g') LIKE '%' || digits_only || '%')
    )
  ORDER BY
    CASE WHEN lower(extensions.unaccent(coalesce(l.name, ''))) ILIKE '%' || normalized || '%' THEN 0 ELSE 1 END,
    l.sales_score DESC NULLS LAST
  LIMIT 20;
END;
$$;


--
-- Name: select_tenant_for_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.select_tenant_for_user(target_tenant_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE v_member_id uuid; v_member_role text;
BEGIN
  SELECT tm.id, tm.role::text INTO v_member_id, v_member_role
  FROM team_members tm WHERE tm.auth_user_id = auth.uid()
    AND tm.tenant_id = target_tenant_id AND tm.is_active = true LIMIT 1;
  IF v_member_id IS NULL THEN
    RAISE EXCEPTION 'User does not belong to tenant %', target_tenant_id USING ERRCODE='insufficient_privilege';
  END IF;
  UPDATE auth.users SET raw_app_meta_data = COALESCE(raw_app_meta_data,'{}'::jsonb)
    || jsonb_build_object('tenant_id', target_tenant_id::text) WHERE id = auth.uid();
  RETURN jsonb_build_object('tenant_id',target_tenant_id,'member_id',v_member_id,'role',v_member_role);
END; $$;


--
-- Name: set_email_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.set_email_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: ss_actions_today(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.ss_actions_today(p_action text DEFAULT NULL::text) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COUNT(*)::integer FROM social_selling_interactions
  WHERE executed_at >= date_trunc('day', now() AT TIME ZONE 'America/Sao_Paulo')
    AND status = 'success' AND (p_action IS NULL OR action_type = p_action);
$$;


--
-- Name: sync_instagram_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.sync_instagram_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.instagram IS DISTINCT FROM OLD.instagram AND NEW.instagram IS NOT NULL THEN
    NEW.instagram_username = NEW.instagram;
  ELSIF NEW.instagram_username IS DISTINCT FROM OLD.instagram_username AND NEW.instagram_username IS NOT NULL THEN
    NEW.instagram = NEW.instagram_username;
  END IF;
  RETURN NEW;
END $$;


--
-- Name: sync_lead_from_deal(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.sync_lead_from_deal() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- No INSERT: sempre sincronizar
  IF TG_OP = 'INSERT' THEN
    UPDATE leads
    SET 
      pipeline_stage_id = NEW.pipeline_stage_id,
      sales_rep_id = COALESCE(NEW.sales_rep_id, leads.sales_rep_id)
    WHERE id = NEW.lead_id;
    RETURN NEW;
  END IF;

  -- No UPDATE: sincronizar se stage ou rep mudou
  IF TG_OP = 'UPDATE' THEN
    -- Se o deal foi perdido/cancelado, buscar o deal ativo mais recente
    IF NEW.status IN ('lost', 'cancelled') AND OLD.status = 'negotiation' THEN
      UPDATE leads
      SET 
        pipeline_stage_id = sub.pipeline_stage_id,
        sales_rep_id = COALESCE(sub.sales_rep_id, leads.sales_rep_id)
      FROM (
        SELECT d.pipeline_stage_id, d.sales_rep_id
        FROM deals d
        WHERE d.lead_id = NEW.lead_id
          AND d.id != NEW.id
          AND d.status = 'negotiation'
        ORDER BY d.updated_at DESC
        LIMIT 1
      ) sub
      WHERE leads.id = NEW.lead_id;
      RETURN NEW;
    END IF;

    -- Sincronizar stage e rep se mudaram
    IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id
       OR OLD.sales_rep_id IS DISTINCT FROM NEW.sales_rep_id THEN
      UPDATE leads
      SET 
        pipeline_stage_id = NEW.pipeline_stage_id,
        sales_rep_id = COALESCE(NEW.sales_rep_id, leads.sales_rep_id)
      WHERE id = NEW.lead_id;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sync_lead_instagram_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.sync_lead_instagram_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.instagram IS NOT NULL THEN
    NEW.instagram := LOWER(TRIM(REGEXP_REPLACE(NEW.instagram, '^@+', '')));
  END IF;
  IF NEW.instagram_username IS NOT NULL THEN
    NEW.instagram_username := LOWER(TRIM(REGEXP_REPLACE(NEW.instagram_username, '^@+', '')));
  END IF;

  IF NEW.instagram IS NOT NULL AND NEW.instagram_username IS NULL THEN
    NEW.instagram_username := NEW.instagram;
  ELSIF NEW.instagram_username IS NOT NULL AND NEW.instagram IS NULL THEN
    NEW.instagram := NEW.instagram_username;
  ELSIF NEW.instagram IS NOT NULL AND NEW.instagram_username IS NOT NULL
        AND NEW.instagram <> NEW.instagram_username THEN
    IF TG_OP = 'UPDATE' THEN
      IF NEW.instagram IS DISTINCT FROM OLD.instagram THEN
        NEW.instagram_username := NEW.instagram;
      ELSIF NEW.instagram_username IS DISTINCT FROM OLD.instagram_username THEN
        NEW.instagram := NEW.instagram_username;
      END IF;
    ELSE
      NEW.instagram_username := NEW.instagram;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sync_partner_pipeline_stage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.sync_partner_pipeline_stage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF pg_trigger_depth() >= 2 THEN RETURN NEW; END IF;
  IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
    UPDATE leads SET pipeline_stage_id = NEW.pipeline_stage_id
    WHERE partner_lead_id = NEW.id AND pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id;
    IF NEW.partner_lead_id IS NOT NULL THEN
      UPDATE leads SET pipeline_stage_id = NEW.pipeline_stage_id
      WHERE id = NEW.partner_lead_id AND pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: sync_price_amount(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.sync_price_amount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.amount IS NOT NULL AND NEW.price IS NULL THEN
    NEW.price := NEW.amount;
  ELSIF NEW.price IS NOT NULL AND NEW.amount IS NULL THEN
    NEW.amount := NEW.price;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trg_auto_move_on_call(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.trg_auto_move_on_call() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.lead_id IS NOT NULL THEN
    PERFORM auto_move_deal_to_em_contato(NEW.lead_id, NEW.tenant_id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trg_auto_move_on_task(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.trg_auto_move_on_task() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Skip auto-move for SDR transfer tasks: the closer deal was JUST created
  -- at position 1 and must NOT be moved automatically.
  IF NEW.task_type = 'meeting'
     AND (NEW.metadata->>'source') = 'sdr_transfer' THEN
    RETURN NEW;
  END IF;

  IF NEW.lead_id IS NOT NULL THEN
    PERFORM auto_move_deal_to_em_contato(NEW.lead_id, NEW.tenant_id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trg_auto_move_on_whatsapp_message(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.trg_auto_move_on_whatsapp_message() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.is_from_me = true AND NEW.lead_id IS NOT NULL THEN
    PERFORM auto_move_deal_to_em_contato(NEW.lead_id, NEW.tenant_id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trigger_enqueue_for_ai_agent(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.trigger_enqueue_for_ai_agent() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ DECLARE v_agent RECORD; v_debounce INT; v_url TEXT; BEGIN IF NEW.is_from_me = true OR NEW.group_id IS NOT NULL OR NEW.lead_id IS NULL THEN RETURN NEW; END IF; SELECT * INTO v_agent FROM ai_sales_agents WHERE is_active = true AND tenant_id = NEW.tenant_id LIMIT 1; IF v_agent IS NULL THEN RETURN NEW; END IF; UPDATE ai_agent_cadence_enrollments SET status = 'replied', updated_at = now() WHERE lead_id = NEW.lead_id AND tenant_id = NEW.tenant_id AND status = 'active'; v_debounce := COALESCE((v_agent.settings->>'debounce_seconds')::INT, 10); PERFORM enqueue_message_for_ai_agent(NEW.lead_id, NEW.id, NEW.content, v_debounce); SELECT value INTO v_url FROM config WHERE key = 'SUPABASE_PROJECT_URL'; IF v_url IS NOT NULL THEN PERFORM net.http_post(url := v_url || '/functions/v1/ai-sales-agent', headers := public.edge_request_headers(), body := jsonb_build_object('action','process_with_debounce','lead_id',NEW.lead_id::text,'message_id',NEW.id::text)); END IF; RETURN NEW; END $$;


--
-- Name: try_acquire_agent_lock(uuid, interval); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.try_acquire_agent_lock(p_lead_id uuid, p_lock_duration interval DEFAULT '00:00:30'::interval) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ DECLARE v_acquired BOOLEAN := false; BEGIN UPDATE ai_agent_conversations SET processing_lock = now() WHERE lead_id = p_lead_id AND status = 'active' AND (processing_lock IS NULL OR processing_lock < now() - p_lock_duration) RETURNING true INTO v_acquired; RETURN COALESCE(v_acquired, false); END $$;


--
-- Name: unmark_conversation_handled(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.unmark_conversation_handled(p_lead_id uuid DEFAULT NULL::uuid, p_group_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF p_lead_id IS NOT NULL THEN
    DELETE FROM cs_conversation_handled
    WHERE lead_id = p_lead_id AND tenant_id = (SELECT public.get_tenant_id());
  ELSIF p_group_id IS NOT NULL THEN
    DELETE FROM cs_conversation_handled
    WHERE group_id = p_group_id AND tenant_id = (SELECT public.get_tenant_id());
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'lead_id ou group_id obrigatorio');
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: update_cs_events_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_cs_events_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_deal_payment_totals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_deal_payment_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_deal_id UUID;
  v_tid UUID;
  v_total_paid DECIMAL(12,2);
  v_negotiated_price DECIMAL(12,2);
  v_new_status TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_deal_id := OLD.deal_id;
    v_tid := OLD.tenant_id;
  ELSE
    v_deal_id := NEW.deal_id;
    v_tid := NEW.tenant_id;
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM deal_payments
  WHERE deal_id = v_deal_id AND tenant_id = v_tid AND status IN ('confirmed', 'received');

  SELECT negotiated_price INTO v_negotiated_price
  FROM deals WHERE id = v_deal_id AND tenant_id = v_tid;

  IF v_total_paid >= v_negotiated_price THEN
    v_new_status := 'paid';
  ELSIF v_total_paid > 0 THEN
    v_new_status := 'partial';
  ELSE
    v_new_status := 'pending';
  END IF;

  UPDATE deals
  SET total_paid = v_total_paid, payment_status = v_new_status, updated_at = NOW()
  WHERE id = v_deal_id AND tenant_id = v_tid;

  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: update_distribution_config_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_distribution_config_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: update_email_templates_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_email_templates_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_inbox_metrics_on_message(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_inbox_metrics_on_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  conv_key TEXT;
BEGIN
  IF NEW.lead_id IS NOT NULL AND NEW.group_id IS NULL THEN
    conv_key := 'lead_' || NEW.lead_id::TEXT;
  ELSIF NEW.group_id IS NOT NULL THEN
    conv_key := 'group_' || NEW.group_id::TEXT;
  ELSE
    RETURN NEW;
  END IF;

  IF NEW.is_from_me THEN
    INSERT INTO cs_inbox_metrics (
      lead_id, group_id, instance_id, conversation_key, tenant_id,
      last_response_at, first_response_at,
      is_waiting_response, wait_started_at, sla_status,
      total_messages_sent, total_interactions
    ) VALUES (
      NEW.lead_id, NEW.group_id, NEW.instance_id, conv_key, NEW.tenant_id,
      NEW.sent_at, NEW.sent_at,
      FALSE, NULL, 'ok',
      1, 1
    )
    ON CONFLICT (conversation_key) DO UPDATE SET
      last_response_at = NEW.sent_at,
      first_response_at = COALESCE(cs_inbox_metrics.first_response_at, NEW.sent_at),
      is_waiting_response = FALSE,
      wait_started_at = NULL,
      sla_status = 'ok',
      total_messages_sent = cs_inbox_metrics.total_messages_sent + 1,
      total_interactions = cs_inbox_metrics.total_interactions + 1,
      tenant_id = COALESCE(cs_inbox_metrics.tenant_id, NEW.tenant_id),
      updated_at = NOW();
  ELSE
    INSERT INTO cs_inbox_metrics (
      lead_id, group_id, instance_id, conversation_key, tenant_id,
      first_customer_message_at, last_customer_message_at,
      is_waiting_response, wait_started_at,
      total_messages_received, total_interactions
    ) VALUES (
      NEW.lead_id, NEW.group_id, NEW.instance_id, conv_key, NEW.tenant_id,
      NEW.sent_at, NEW.sent_at,
      TRUE, NEW.sent_at,
      1, 1
    )
    ON CONFLICT (conversation_key) DO UPDATE SET
      last_customer_message_at = NEW.sent_at,
      first_customer_message_at = COALESCE(cs_inbox_metrics.first_customer_message_at, NEW.sent_at),
      is_waiting_response = TRUE,
      wait_started_at = NEW.sent_at,
      total_messages_received = cs_inbox_metrics.total_messages_received + 1,
      total_interactions = cs_inbox_metrics.total_interactions + 1,
      tenant_id = COALESCE(cs_inbox_metrics.tenant_id, NEW.tenant_id),
      updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: update_sla_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_sla_status() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE cs_inbox_metrics SET
    sla_status = CASE
      WHEN NOT is_waiting_response THEN 'ok'
      WHEN calculate_wait_minutes(wait_started_at) > 120 THEN 'critical'
      WHEN calculate_wait_minutes(wait_started_at) > 30 THEN 'warning'
      ELSE 'ok'
    END,
    sla_breached_at = CASE
      WHEN sla_status != 'critical' AND calculate_wait_minutes(wait_started_at) > 120 THEN NOW()
      ELSE sla_breached_at
    END,
    total_sla_breaches = CASE
      WHEN sla_status != 'critical' AND calculate_wait_minutes(wait_started_at) > 120 THEN total_sla_breaches + 1
      ELSE total_sla_breaches
    END,
    updated_at = NOW()
  WHERE is_waiting_response = TRUE;
END;
$$;


--
-- Name: update_ssa_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_ssa_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


--
-- Name: update_sse_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_sse_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


--
-- Name: update_stage_changed_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_stage_changed_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
    NEW.stage_changed_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: use_response_template(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.use_response_template(p_template_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  UPDATE cs_response_templates
  SET usage_count = usage_count + 1, updated_at = NOW()
  WHERE id = p_template_id
    AND tenant_id = (SELECT public.get_tenant_id());
END;
$$;


--
-- Name: wa_communities_touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE OR REPLACE FUNCTION public.wa_communities_touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: ai_agent_cadence_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_cadence_enrollments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    agent_id uuid NOT NULL,
    stage text NOT NULL,
    current_step integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    next_action_at timestamp with time zone,
    enrolled_at timestamp with time zone DEFAULT now(),
    last_step_at timestamp with time zone,
    completed_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT (current_setting('app.settings.tenant_id'::text, true))::uuid NOT NULL
);


--
-- Name: ai_agent_chat_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_chat_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    agent_id uuid,
    conversation_id uuid,
    event_type text NOT NULL,
    reason text,
    message text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_agent_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    agent_id uuid,
    status text DEFAULT 'active'::text,
    messages_history jsonb DEFAULT '[]'::jsonb,
    total_messages_sent integer DEFAULT 0,
    total_messages_received integer DEFAULT 0,
    paused_by uuid,
    paused_at timestamp with time zone,
    pause_reason text,
    last_processed_at timestamp with time zone,
    last_message_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    processing_lock timestamp with time zone,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: ai_agent_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid,
    lead_id uuid,
    agent_id uuid,
    log_type text NOT NULL,
    data jsonb DEFAULT '{}'::jsonb,
    tokens_input integer,
    tokens_output integer,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: ai_agent_send_counts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_send_counts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instance_id uuid NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_type character varying NOT NULL,
    message_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT (current_setting('app.settings.tenant_id'::text, true))::uuid NOT NULL
);


--
-- Name: ai_agent_tools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_agent_tools (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agent_id uuid,
    name text NOT NULL,
    description text NOT NULL,
    parameters jsonb DEFAULT '{"type": "object", "required": [], "properties": {}}'::jsonb,
    action_type text NOT NULL,
    action_config jsonb DEFAULT '{}'::jsonb,
    priority integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: ai_sales_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.ai_sales_agents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    system_prompt text NOT NULL,
    personality_traits jsonb DEFAULT '[]'::jsonb,
    target_stages text[] DEFAULT ARRAY['captura'::text, 'qualificacao'::text],
    settings jsonb DEFAULT '{"working_days": [1, 2, 3, 4, 5, 6], "debounce_seconds": 10, "typing_speed_cpm": 300, "working_hours_end": "20:00", "working_hours_start": "08:00", "response_delay_max_ms": 5000, "response_delay_min_ms": 2000, "auto_pause_after_human_reply": true, "max_messages_per_conversation": 50}'::jsonb,
    model text DEFAULT 'gpt-4o-mini'::text,
    temperature numeric(3,2) DEFAULT 0.7,
    max_tokens integer DEFAULT 500,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    cadence_steps jsonb DEFAULT '{}'::jsonb,
    pipeline_id uuid,
    whatsapp_instance_id uuid
);


--
-- Name: analysis_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.analysis_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    prompt text NOT NULL,
    category text DEFAULT 'call_analysis'::text NOT NULL,
    is_default boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    CONSTRAINT analysis_templates_category_check CHECK ((category = ANY (ARRAY['call_analysis'::text, 'call_analysis_deep'::text, 'lead_insights'::text, 'message_generation'::text, 'proposal'::text])))
);


--
-- Name: asaas_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.asaas_customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    asaas_customer_id text NOT NULL,
    name text NOT NULL,
    cpf_cnpj text NOT NULL,
    email text,
    phone text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: asaas_webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.asaas_webhooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_type text NOT NULL,
    asaas_payment_id text,
    payload jsonb NOT NULL,
    processed boolean DEFAULT false,
    error text,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: calendar_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.calendar_blocks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_member_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    block_type text DEFAULT 'one_time'::text NOT NULL,
    start_datetime timestamp with time zone,
    end_datetime timestamp with time zone,
    recurrence_days integer[] DEFAULT '{}'::integer[],
    recurrence_start_time time without time zone,
    recurrence_end_time time without time zone,
    is_active boolean DEFAULT true,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT calendar_blocks_block_type_check CHECK ((block_type = ANY (ARRAY['one_time'::text, 'recurring'::text])))
);


--
-- Name: calendar_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.calendar_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    google_event_id text NOT NULL,
    calendar_id text DEFAULT 'primary'::text NOT NULL,
    team_member_id uuid,
    title text NOT NULL,
    description text,
    location text,
    start_datetime timestamp with time zone NOT NULL,
    end_datetime timestamp with time zone NOT NULL,
    all_day boolean DEFAULT false,
    timezone text DEFAULT 'America/Sao_Paulo'::text,
    attendees jsonb DEFAULT '[]'::jsonb,
    organizer_email text,
    meet_link text,
    html_link text,
    status text DEFAULT 'confirmed'::text,
    lead_id uuid,
    deal_id uuid,
    raw_event jsonb,
    synced_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: call_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.call_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wavoip_device_id uuid,
    wavoip_call_id text,
    wavoip_session_id text,
    team_member_id uuid,
    lead_id uuid,
    call_type text DEFAULT 'whatsapp'::text NOT NULL,
    direction text NOT NULL,
    status text DEFAULT 'CALLING'::text NOT NULL,
    caller_phone text,
    receiver_phone text,
    peer_phone text,
    peer_name text,
    peer_profile_picture text,
    duration_seconds integer DEFAULT 0,
    record_status text,
    record_url text,
    transcription text,
    ai_summary text,
    ai_sentiment text,
    ai_key_points jsonb DEFAULT '[]'::jsonb,
    ai_suggested_tasks jsonb DEFAULT '[]'::jsonb,
    ai_processed_at timestamp with time zone,
    ai_processing_error text,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    transcriptions jsonb DEFAULT '[]'::jsonb,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    call_outcome text,
    call_outcome_details jsonb,
    CONSTRAINT call_history_call_outcome_check CHECK ((call_outcome = ANY (ARRAY['schedule_partner_call'::text, 'schedule_payment'::text, 'lost'::text])))
);


--
-- Name: COLUMN call_history.transcriptions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.call_history.transcriptions IS 'Array de transcrições da chamada capturadas via Soniox em tempo real';


--
-- Name: campaign_instance_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.campaign_instance_stats (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    instance_id uuid NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    messages_sent_hour integer DEFAULT 0,
    messages_sent_day integer DEFAULT 0,
    blocks_detected_day integer DEFAULT 0,
    warmup_started_at timestamp with time zone,
    warmup_day integer DEFAULT 0,
    daily_limit_override integer,
    cooldown_until timestamp with time zone,
    last_block_at timestamp with time zone,
    hour_bucket integer DEFAULT EXTRACT(hour FROM now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: campaign_leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.campaign_leads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    resolved_message text,
    instance_id uuid,
    whatsapp_message_id text,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    read_at timestamp with time zone,
    responded_at timestamp with time zone,
    failed_at timestamp with time zone,
    error_message text,
    retry_count integer DEFAULT 0,
    assigned_to uuid,
    response_message_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT campaign_leads_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sending'::text, 'sent'::text, 'delivered'::text, 'read'::text, 'responded'::text, 'failed'::text, 'blocked'::text, 'skipped'::text])))
);


--
-- Name: campaign_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.campaign_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    content text NOT NULL,
    category text DEFAULT 'campaign'::text,
    variables text[] DEFAULT '{}'::text[],
    is_active boolean DEFAULT true,
    usage_count integer DEFAULT 0,
    last_used_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    status text DEFAULT 'draft'::text NOT NULL,
    template_id uuid,
    message_content text NOT NULL,
    audience_filters jsonb DEFAULT '{}'::jsonb NOT NULL,
    audience_count integer DEFAULT 0,
    instance_ids uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    assignment_mode text DEFAULT 'keep_current'::text NOT NULL,
    assignment_target_id uuid,
    assignment_distribution_config_id uuid,
    scheduled_at timestamp with time zone,
    business_hours_start time without time zone DEFAULT '08:00:00'::time without time zone,
    business_hours_end time without time zone DEFAULT '20:00:00'::time without time zone,
    delay_min_seconds integer DEFAULT 45,
    delay_max_seconds integer DEFAULT 90,
    batch_size integer DEFAULT 20,
    batch_pause_min_seconds integer DEFAULT 180,
    batch_pause_max_seconds integer DEFAULT 300,
    hourly_limit_per_instance integer DEFAULT 40,
    daily_limit_per_instance integer DEFAULT 500,
    total_leads integer DEFAULT 0,
    sent_count integer DEFAULT 0,
    delivered_count integer DEFAULT 0,
    read_count integer DEFAULT 0,
    responded_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    blocked_count integer DEFAULT 0,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    paused_at timestamp with time zone,
    pause_reason text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    message_contents jsonb DEFAULT '[]'::jsonb,
    provider text DEFAULT 'uazapi'::text NOT NULL,
    cloud_template_id uuid,
    cloud_template_params jsonb DEFAULT '[]'::jsonb,
    CONSTRAINT campaigns_assignment_mode_check CHECK ((assignment_mode = ANY (ARRAY['sdr_round_robin'::text, 'specific_sdr'::text, 'closer_round_robin'::text, 'specific_closer'::text, 'keep_current'::text]))),
    CONSTRAINT campaigns_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'sending'::text, 'paused'::text, 'completed'::text, 'cancelled'::text])))
);


--
-- Name: chat_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.chat_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    display_name text NOT NULL,
    system_prompt text NOT NULL,
    model text DEFAULT 'claude-3-5-sonnet-20241022'::text NOT NULL,
    temperature numeric DEFAULT 0.2,
    top_p numeric DEFAULT 1,
    tools jsonb DEFAULT '[]'::jsonb,
    provider text DEFAULT 'anthropic'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    tool_name text,
    token_count integer,
    raw jsonb,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: chat_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    config_id uuid NOT NULL,
    title text DEFAULT 'Nova conversa'::text,
    created_by uuid,
    summary text,
    token_budget integer DEFAULT 120000,
    last_response_id text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: client_onboarding_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.client_onboarding_data (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    tenant_id uuid NOT NULL,
    organization_id uuid,
    lead_id uuid,
    current_stage text,
    data jsonb DEFAULT '{}'::jsonb,
    completion_percent integer DEFAULT 0,
    transcript text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: coach_playbooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.coach_playbooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    type character varying(20) DEFAULT 'sales'::character varying NOT NULL,
    description text,
    context text,
    phases jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT true,
    is_default boolean DEFAULT false,
    created_by uuid,
    organization_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: coach_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.coach_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    call_id uuid,
    playbook_id uuid,
    lead_id uuid,
    team_member_id uuid,
    briefing text,
    current_phase_index integer DEFAULT 0,
    checklist_state jsonb DEFAULT '{}'::jsonb,
    events jsonb DEFAULT '[]'::jsonb,
    phases_completed integer DEFAULT 0,
    alerts_triggered integer DEFAULT 0,
    suggestions_shown integer DEFAULT 0,
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: commission_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.commission_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    sales_rep_id uuid,
    product_id text,
    commission_type text NOT NULL,
    commission_value numeric(10,2) NOT NULL,
    payment_trigger text DEFAULT 'on_payment'::text NOT NULL,
    calculate_on character varying DEFAULT 'gross'::character varying,
    is_active boolean DEFAULT true,
    priority integer DEFAULT 0,
    valid_from date,
    valid_to date,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: commissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.commissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    deal_payment_id uuid,
    sales_rep_id uuid NOT NULL,
    commission_rule_id uuid,
    base_amount numeric(12,2) NOT NULL,
    gateway_fee_amount numeric(12,2) DEFAULT 0,
    net_amount numeric(12,2) DEFAULT 0,
    commission_amount numeric(12,2) NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    paid_at timestamp with time zone,
    payment_reference text,
    reference_date timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: company_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.company_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    priority text DEFAULT 'medium'::text,
    assignee text,
    date date,
    completed boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    meeting_id uuid,
    parent_task_id uuid,
    source_type text,
    source_id uuid,
    ai_generated boolean DEFAULT false,
    status text DEFAULT 'not_started'::text,
    due_datetime timestamp with time zone,
    responsavel_id uuid,
    created_by_id uuid,
    task_type text DEFAULT 'internal'::text,
    team text DEFAULT 'internal'::text,
    lead_id uuid,
    organization_id uuid,
    notes text,
    completed_at timestamp with time zone,
    reminder_at timestamp with time zone,
    scheduled_at timestamp with time zone,
    confirmed_by_client boolean DEFAULT false,
    client_contact_method text,
    meeting_link text,
    product_id text,
    participants uuid[],
    end_datetime timestamp with time zone,
    is_all_day boolean DEFAULT false,
    google_event_id text,
    google_calendar_synced boolean DEFAULT false,
    outcome text,
    metadata jsonb DEFAULT '{}'::jsonb,
    reminder_sent_at timestamp with time zone,
    call_channel text,
    call_duration_seconds integer,
    recording_url text,
    external_call_id text,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    is_critical boolean DEFAULT false,
    event_id uuid,
    marketing_event_id uuid,
    is_recurring boolean DEFAULT false,
    recurrence_interval_days integer,
    recurrence_count integer DEFAULT 0,
    critical_last_reminded_at timestamp with time zone
);

ALTER TABLE ONLY public.company_activities REPLICA IDENTITY FULL;


--
-- Name: COLUMN company_activities.participants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_activities.participants IS 'Array de IDs de responsáveis que participam da tarefa além do responsável principal';


--
-- Name: config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.config (
    key text NOT NULL,
    value text,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: cs_conversation_handled; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_conversation_handled (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    group_id uuid,
    handled_by uuid,
    handled_at timestamp with time zone DEFAULT now(),
    reason text,
    notes text,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_conversation_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_conversation_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    group_id uuid,
    content text NOT NULL,
    note_type text DEFAULT 'general'::text,
    created_by uuid,
    is_pinned boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_engagement_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_engagement_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    member_area_last_access timestamp with time zone,
    member_area_total_lessons integer DEFAULT 0,
    member_area_completed_lessons integer DEFAULT 0,
    member_area_time_spent_minutes integer DEFAULT 0,
    whatsapp_group_last_message timestamp with time zone,
    whatsapp_group_total_messages integer DEFAULT 0,
    whatsapp_support_last_message timestamp with time zone,
    whatsapp_support_total_tickets integer DEFAULT 0,
    zoom_last_participation timestamp with time zone,
    zoom_total_participations integer DEFAULT 0,
    zoom_total_minutes integer DEFAULT 0,
    product_last_login timestamp with time zone,
    product_total_logins integer DEFAULT 0,
    product_features_used jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_event_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    requester_rsvp_id uuid NOT NULL,
    target_rsvp_id uuid NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cs_event_connections_check CHECK ((requester_rsvp_id <> target_rsvp_id)),
    CONSTRAINT cs_event_connections_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'declined'::character varying])::text[])))
);


--
-- Name: cs_event_feed_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_feed_likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid NOT NULL,
    rsvp_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_event_feed_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_feed_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    author_name character varying(200) NOT NULL,
    author_avatar_url character varying(500),
    content text NOT NULL,
    image_urls text[] DEFAULT '{}'::text[],
    is_pinned boolean DEFAULT false,
    likes_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_event_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    schedule_item_id uuid,
    title character varying(300) NOT NULL,
    description text,
    file_url character varying(1000) NOT NULL,
    file_type character varying(50),
    file_size bigint,
    category character varying(100),
    available_after timestamp with time zone,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_event_participant_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_participant_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rsvp_id uuid NOT NULL,
    event_id uuid NOT NULL,
    display_name character varying(200) NOT NULL,
    company character varying(200),
    job_title character varying(200),
    bio text,
    avatar_url character varying(500),
    skills text[] DEFAULT '{}'::text[],
    interests text[] DEFAULT '{}'::text[],
    linkedin_url character varying(500),
    show_email boolean DEFAULT false,
    show_phone boolean DEFAULT false,
    show_linkedin boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_event_participant_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_participant_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    rsvp_id uuid NOT NULL,
    token character varying(128) NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval) NOT NULL,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_event_rsvps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_rsvps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    guest_name character varying NOT NULL,
    guest_email character varying NOT NULL,
    guest_phone character varying,
    guest_company character varying,
    lead_id uuid,
    organization_id uuid,
    is_client boolean DEFAULT false,
    rsvp_status character varying DEFAULT 'confirmed'::character varying NOT NULL,
    confirmed_at timestamp with time zone DEFAULT now(),
    has_companion boolean DEFAULT false,
    companion_name character varying,
    companion_email character varying,
    companion_phone character varying,
    checked_in_at timestamp with time zone,
    checked_in_by uuid,
    companion_checked_in boolean DEFAULT false,
    companion_checked_in_at timestamp with time zone,
    dietary_restrictions character varying,
    notes text,
    custom_answers jsonb DEFAULT '{}'::jsonb,
    source character varying DEFAULT 'public_form'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_event_schedule_bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_schedule_bookmarks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    schedule_item_id uuid NOT NULL,
    rsvp_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_event_schedule_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_event_schedule_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    title character varying(300) NOT NULL,
    description text,
    speaker_name character varying(200),
    speaker_title character varying(200),
    speaker_avatar_url character varying(500),
    room character varying(100),
    day_date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    category character varying(100),
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cs_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    slug character varying,
    start_date date NOT NULL,
    end_date date,
    start_time time without time zone,
    end_time time without time zone,
    location character varying,
    location_details text,
    is_online boolean DEFAULT false,
    online_link character varying,
    capacity integer,
    rsvp_token character varying DEFAULT encode(extensions.gen_random_bytes(16), 'hex'::text) NOT NULL,
    rsvp_enabled boolean DEFAULT true,
    rsvp_deadline timestamp with time zone,
    allow_companion boolean DEFAULT false,
    max_companions_per_guest integer DEFAULT 1,
    product_id text,
    custom_questions jsonb DEFAULT '[]'::jsonb,
    settings jsonb DEFAULT '{}'::jsonb,
    banner_url character varying,
    status character varying DEFAULT 'draft'::character varying,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    guide_url character varying,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_health_current; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_health_current (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    overall_score integer NOT NULL,
    health_status public.health_status NOT NULL,
    engagement_score integer,
    objectives_score integer,
    sentiment_score integer,
    usage_score integer,
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_health_scores_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_health_scores_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    overall_score integer NOT NULL,
    health_status public.health_status NOT NULL,
    engagement_score integer,
    objectives_score integer,
    sentiment_score integer,
    usage_score integer,
    calculated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_inbox_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_inbox_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    group_id uuid,
    instance_id uuid,
    conversation_key text NOT NULL,
    first_customer_message_at timestamp with time zone,
    last_customer_message_at timestamp with time zone,
    first_response_at timestamp with time zone,
    last_response_at timestamp with time zone,
    is_waiting_response boolean DEFAULT false,
    wait_started_at timestamp with time zone,
    sla_status text DEFAULT 'ok'::text,
    sla_breached_at timestamp with time zone,
    total_sla_breaches integer DEFAULT 0,
    assigned_agent_id uuid,
    assigned_at timestamp with time zone,
    total_messages_received integer DEFAULT 0,
    total_messages_sent integer DEFAULT 0,
    total_interactions integer DEFAULT 0,
    avg_response_time_minutes numeric(10,2),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_interactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text,
    member_id uuid,
    interaction_timestamp timestamp with time zone DEFAULT now(),
    type public.interaction_type NOT NULL,
    title text NOT NULL,
    description text,
    sentiment public.sentiment,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    scheduled_at timestamp with time zone,
    status text DEFAULT 'active'::text,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_objectives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_objectives (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    description text NOT NULL,
    deadline date NOT NULL,
    days_target integer NOT NULL,
    status public.objective_status DEFAULT 'pending'::public.objective_status,
    completed_at timestamp with time zone,
    assigned_to uuid,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_response_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_response_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    content text NOT NULL,
    category text DEFAULT 'geral'::text,
    shortcut text,
    product_id text,
    team text DEFAULT 'cs'::text,
    usage_count integer DEFAULT 0,
    created_by uuid,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_success_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_success_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    testimonial_collected boolean DEFAULT false,
    testimonial_date date,
    testimonial_content text,
    testimonial_rating integer,
    testimonial_video_url text,
    upsell_done boolean DEFAULT false,
    upsell_value numeric,
    upsell_product text,
    upsell_date date,
    referrals_count integer DEFAULT 0,
    referrals_target integer DEFAULT 10,
    referrals_converted integer DEFAULT 0,
    is_success_case boolean DEFAULT false,
    success_case_url text,
    success_case_published_at timestamp with time zone,
    nps_score integer,
    nps_collected_at timestamp with time zone,
    nps_feedback text,
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: cs_touchpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.cs_touchpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    touchpoint_date date NOT NULL,
    type public.touchpoint_type NOT NULL,
    channel public.touchpoint_channel NOT NULL,
    summary text NOT NULL,
    sentiment public.sentiment,
    next_action text,
    next_contact_date date,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    status text DEFAULT 'completed'::text,
    follow_up_deadline timestamp with time zone,
    checkpoint_day integer,
    source text DEFAULT 'manual'::text,
    CONSTRAINT cs_touchpoints_checkpoint_day_check CHECK ((checkpoint_day = ANY (ARRAY[3, 7, 14, 30, 45, 60, 75, 90]))),
    CONSTRAINT cs_touchpoints_source_check CHECK ((source = ANY (ARRAY['manual'::text, 'cockpit'::text, 'webhook'::text, 'cadence'::text, 'system'::text]))),
    CONSTRAINT cs_touchpoints_status_check CHECK ((status = ANY (ARRAY['initiated'::text, 'awaiting_response'::text, 'client_replied'::text, 'no_response'::text, 'completed'::text])))
);


--
-- Name: deal_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.deal_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    role text,
    is_primary boolean DEFAULT false,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: deal_loss_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.deal_loss_reasons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    label text NOT NULL,
    "position" integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: deal_payment_installments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.deal_payment_installments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_payment_id uuid NOT NULL,
    installment_number integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    due_date date NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    paid_at timestamp with time zone,
    asaas_installment_id text,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: deal_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.deal_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    payer_lead_id uuid,
    description text,
    billing_type text NOT NULL,
    gateway text DEFAULT 'asaas'::text,
    amount numeric(12,2) NOT NULL,
    installments integer DEFAULT 1,
    installment_value numeric(12,2),
    asaas_payment_id text,
    asaas_invoice_number text,
    payment_link text,
    invoice_url text,
    status text DEFAULT 'pending'::text NOT NULL,
    due_date date NOT NULL,
    paid_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: deals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.deals (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    lead_id uuid NOT NULL,
    product_id text,
    sales_rep_id uuid,
    pipeline_id uuid,
    pipeline_stage_id uuid,
    title text,
    original_price numeric(10,2),
    negotiated_price numeric(10,2),
    discount_percent numeric(5,2),
    discount_reason text,
    payment_method text,
    installments integer DEFAULT 1,
    status text DEFAULT 'negotiation'::text,
    expected_close_date date,
    won_at timestamp with time zone,
    lost_at timestamp with time zone,
    lost_reason text,
    proposal_sent_at timestamp with time zone,
    proposal_url text,
    ai_win_probability integer DEFAULT 0,
    ai_proposal_suggestion jsonb,
    notes text,
    metadata jsonb,
    total_paid numeric(12,2) DEFAULT 0,
    payment_status text DEFAULT 'pending'::text,
    utm_source text,
    utm_campaign text,
    utm_content text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    stage_changed_at timestamp with time zone,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    sdr_id uuid
);

ALTER TABLE ONLY public.deals REPLICA IDENTITY FULL;


--
-- Name: dropdown_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.dropdown_options (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    field_type text NOT NULL,
    label text NOT NULL,
    value text NOT NULL,
    is_system boolean DEFAULT false,
    "position" integer DEFAULT 0,
    is_active boolean DEFAULT true,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_automation_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_automation_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_id uuid NOT NULL,
    lead_id uuid,
    template_id uuid,
    email_to text NOT NULL,
    status text NOT NULL,
    resend_id text,
    error_message text,
    sent_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid,
    automation_id uuid,
    current_node_id text,
    scheduled_next_at timestamp with time zone,
    context jsonb DEFAULT '{}'::jsonb,
    started_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone,
    CONSTRAINT email_automation_runs_status_check CHECK ((status = ANY (ARRAY['sent'::text, 'failed'::text, 'skipped'::text])))
);


--
-- Name: TABLE email_automation_runs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.email_automation_runs IS 'Histórico de envios de email das automações; usado pra idempotência (once_per_lead)';


--
-- Name: email_automations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_automations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    name text NOT NULL,
    description text,
    trigger_event text NOT NULL,
    trigger_filter jsonb DEFAULT '{}'::jsonb,
    flow_json jsonb,
    is_active boolean DEFAULT false,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_campaign_leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_campaign_leads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    campaign_id uuid NOT NULL,
    lead_id uuid,
    email text NOT NULL,
    name text,
    status text DEFAULT 'pending'::text NOT NULL,
    brevo_message_id text,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    opened_at timestamp with time zone,
    clicked_at timestamp with time zone,
    bounced_at timestamp with time zone,
    complained_at timestamp with time zone,
    unsubscribed_at timestamp with time zone,
    failed_at timestamp with time zone,
    error_message text,
    open_count integer DEFAULT 0,
    click_count integer DEFAULT 0,
    clicked_urls text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    status text DEFAULT 'draft'::text NOT NULL,
    template_id uuid,
    subject text DEFAULT ''::text NOT NULL,
    from_name text DEFAULT ''::text NOT NULL,
    from_email text DEFAULT ''::text NOT NULL,
    reply_to text,
    html_content text,
    audience_filters jsonb DEFAULT '{}'::jsonb,
    total_leads integer DEFAULT 0,
    sent_count integer DEFAULT 0,
    delivered_count integer DEFAULT 0,
    opened_count integer DEFAULT 0,
    clicked_count integer DEFAULT 0,
    bounced_count integer DEFAULT 0,
    complained_count integer DEFAULT 0,
    unsubscribed_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    scheduled_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    paused_at timestamp with time zone,
    pause_reason text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    preheader text,
    content_json jsonb,
    html_cache text,
    list_id uuid,
    settings jsonb DEFAULT '{}'::jsonb,
    source_type text DEFAULT 'campaign'::text,
    automation_id uuid,
    sent_at timestamp with time zone,
    total_recipients integer DEFAULT 0,
    total_sent integer DEFAULT 0,
    total_delivered integer DEFAULT 0,
    total_opened integer DEFAULT 0,
    total_clicked integer DEFAULT 0,
    total_bounced integer DEFAULT 0,
    total_unsubscribed integer DEFAULT 0,
    lead_ids uuid[] DEFAULT '{}'::uuid[]
);


--
-- Name: email_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    send_id uuid,
    event_type text NOT NULL,
    payload jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_lists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    name text NOT NULL,
    description text,
    criteria jsonb DEFAULT '{}'::jsonb,
    is_dynamic boolean DEFAULT true,
    is_active boolean DEFAULT true,
    total_count integer DEFAULT 0,
    last_calculated_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_sends; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_sends (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    campaign_id uuid,
    automation_run_id uuid,
    lead_id uuid,
    email text NOT NULL,
    resend_id text,
    status text DEFAULT 'pending'::text,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    opened_at timestamp with time zone,
    open_count integer DEFAULT 0,
    clicked_at timestamp with time zone,
    click_count integer DEFAULT 0,
    clicked_url text,
    bounced_at timestamp with time zone,
    bounce_reason text,
    error_message text,
    html text,
    user_agent text,
    device_type text,
    unsubscribed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT email_sends_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'delivered'::text, 'opened'::text, 'clicked'::text, 'bounced'::text, 'complained'::text, 'failed'::text])))
);


--
-- Name: email_sequence_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_sequence_enrollments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    sequence_id uuid NOT NULL,
    lead_id uuid,
    email text NOT NULL,
    name text,
    status text DEFAULT 'active'::text NOT NULL,
    current_step integer DEFAULT 0,
    next_step_at timestamp with time zone,
    exit_reason text,
    enrolled_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_sequence_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_sequence_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    enrollment_id uuid NOT NULL,
    step_id uuid NOT NULL,
    sequence_id uuid NOT NULL,
    lead_id uuid,
    email text NOT NULL,
    status text DEFAULT 'sent'::text NOT NULL,
    brevo_message_id text,
    sent_at timestamp with time zone DEFAULT now(),
    delivered_at timestamp with time zone,
    opened_at timestamp with time zone,
    clicked_at timestamp with time zone,
    bounced_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_sequence_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_sequence_steps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    sequence_id uuid NOT NULL,
    step_order integer DEFAULT 0 NOT NULL,
    template_id uuid,
    subject text DEFAULT ''::text NOT NULL,
    html_content text,
    delay_days integer DEFAULT 0,
    delay_hours integer DEFAULT 0,
    skip_if_opened boolean DEFAULT false,
    skip_if_clicked boolean DEFAULT false,
    sent_count integer DEFAULT 0,
    opened_count integer DEFAULT 0,
    clicked_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_sequences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    status text DEFAULT 'draft'::text NOT NULL,
    trigger_type text DEFAULT 'manual'::text,
    trigger_config jsonb DEFAULT '{}'::jsonb,
    from_name text DEFAULT ''::text NOT NULL,
    from_email text DEFAULT ''::text NOT NULL,
    reply_to text,
    exit_on_reply boolean DEFAULT true,
    exit_on_unsubscribe boolean DEFAULT true,
    exit_on_deal_won boolean DEFAULT false,
    exit_on_bounce boolean DEFAULT true,
    total_enrolled integer DEFAULT 0,
    total_completed integer DEFAULT 0,
    total_exited integer DEFAULT 0,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: email_subscribers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_subscribers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    lead_id uuid,
    email text NOT NULL,
    status text DEFAULT 'subscribed'::text NOT NULL,
    unsubscribe_token uuid DEFAULT gen_random_uuid(),
    consent_source text,
    consent_at timestamp with time zone,
    consent_ip text,
    unsubscribed_at timestamp with time zone,
    unsubscribe_reason text,
    bounce_reason text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT email_subscribers_status_check CHECK ((status = ANY (ARRAY['subscribed'::text, 'unsubscribed'::text, 'bounced'::text, 'complained'::text])))
);


--
-- Name: email_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    subject text DEFAULT ''::text NOT NULL,
    html_content text DEFAULT ''::text NOT NULL,
    text_content text,
    design_json jsonb,
    thumbnail_url text,
    category text DEFAULT 'geral'::text,
    variables text[] DEFAULT '{}'::text[],
    is_active boolean DEFAULT true,
    usage_count integer DEFAULT 0,
    last_used_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    preheader text,
    content_json jsonb
);


--
-- Name: TABLE email_templates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.email_templates IS 'Templates de email HTML reusáveis entre automações';


--
-- Name: email_unsubscribes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.email_unsubscribes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    email text NOT NULL,
    lead_id uuid,
    reason text,
    source text DEFAULT 'link'::text,
    unsubscribed_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: financial_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.financial_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    type character varying DEFAULT 'bank_account'::character varying NOT NULL,
    institution character varying,
    description character varying,
    is_active boolean DEFAULT true,
    is_default boolean DEFAULT false,
    color character varying DEFAULT '#6B7280'::character varying,
    icon character varying DEFAULT 'Wallet'::character varying,
    "position" integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: financial_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.financial_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    type character varying NOT NULL,
    parent_id uuid,
    color character varying DEFAULT '#6B7280'::character varying,
    icon character varying DEFAULT 'CircleDollarSign'::character varying,
    is_system boolean DEFAULT false,
    "position" integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: financial_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.financial_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    description character varying NOT NULL,
    amount numeric(12,2) NOT NULL,
    entry_date date NOT NULL,
    type character varying DEFAULT 'expense'::character varying NOT NULL,
    recurrence character varying DEFAULT 'none'::character varying,
    recurrence_end_date date,
    payment_method character varying,
    receipt_url character varying,
    notes text,
    tags text[] DEFAULT '{}'::text[],
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    status character varying DEFAULT 'paid'::character varying,
    due_date date,
    paid_at timestamp with time zone,
    financial_account_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: franchise_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.franchise_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    name text NOT NULL,
    api_key uuid DEFAULT gen_random_uuid() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    min_capital_tier text DEFAULT 'acima_de_r$_100_mil'::text NOT NULL,
    whatsapp_instance_id uuid,
    also_distribute_to_sellers boolean DEFAULT true NOT NULL,
    message_template text DEFAULT '🔔 *Novo Lead - {{campaign_name}}*

*Nome:* {{lead_name}}
*Tel:* {{lead_phone}}
*Email:* {{lead_email}}
*Cidade:* {{lead_city}}/{{lead_state}}
*Capital:* {{lead_capital}}
*Horário:* {{lead_horario}}

*Vendedor acompanhando:* {{seller_name}}'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: franchise_distribution_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.franchise_distribution_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    franchise_member_id uuid NOT NULL,
    lead_id uuid,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    whatsapp_sent boolean DEFAULT false,
    whatsapp_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: franchise_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.franchise_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    name text NOT NULL,
    phone text NOT NULL,
    cities text[] DEFAULT '{}'::text[],
    is_active boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    utm_identifier text
);


--
-- Name: google_ads_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.google_ads_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text NOT NULL,
    account_name text,
    organization_id uuid,
    is_active boolean DEFAULT true,
    last_synced_date date,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: google_ads_campaign_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.google_ads_campaign_data (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text NOT NULL,
    organization_id uuid,
    campaign_id text NOT NULL,
    campaign_name text,
    date date NOT NULL,
    impressions bigint DEFAULT 0,
    clicks bigint DEFAULT 0,
    cost_micros bigint DEFAULT 0,
    conversions numeric DEFAULT 0,
    ctr numeric,
    average_cpc_micros bigint,
    campaign_status text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: google_ads_daily_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.google_ads_daily_data (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text NOT NULL,
    organization_id uuid,
    date date NOT NULL,
    impressions bigint DEFAULT 0,
    clicks bigint DEFAULT 0,
    cost_micros bigint DEFAULT 0,
    conversions numeric DEFAULT 0,
    ctr numeric,
    average_cpc_micros bigint,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: import_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.import_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    created_by uuid,
    file_name text,
    total_rows integer DEFAULT 0,
    created_count integer DEFAULT 0,
    updated_count integer DEFAULT 0,
    skipped_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    config jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: instagram_business_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_business_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    facebook_page_id text,
    instagram_business_id text,
    instagram_username text NOT NULL,
    access_token text NOT NULL,
    token_expires_at timestamp with time zone,
    name text NOT NULL,
    status text DEFAULT 'connected'::text,
    teams text[] DEFAULT '{comercial}'::text[],
    webhook_verify_token text,
    profile_picture_url text,
    followers_count integer,
    biography text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: instagram_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    lead_id uuid,
    comment_id text NOT NULL,
    post_id text NOT NULL,
    post_url text,
    post_thumbnail_url text,
    parent_comment_id text,
    author_instagram_id text NOT NULL,
    author_username text,
    author_name text,
    author_profile_pic text,
    content text NOT NULL,
    status text DEFAULT 'new'::text,
    replied_at timestamp with time zone,
    replied_by uuid,
    reply_content text,
    commented_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: instagram_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    lead_id uuid,
    thread_id text NOT NULL,
    participant_instagram_id text NOT NULL,
    participant_username text,
    participant_name text,
    participant_profile_pic text,
    status text DEFAULT 'open'::text,
    assigned_to uuid,
    social_seller_stage_id uuid,
    stage_changed_at timestamp with time zone,
    stage_changed_by uuid,
    last_message text,
    last_message_at timestamp with time zone,
    last_client_message_at timestamp with time zone,
    last_agent_message_at timestamp with time zone,
    unread_count integer DEFAULT 0,
    total_messages integer DEFAULT 0,
    first_response_at timestamp with time zone,
    avg_response_time_minutes integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: instagram_engagement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_engagement (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    account_id uuid NOT NULL,
    total_dms integer DEFAULT 0,
    total_comments integer DEFAULT 0,
    total_story_replies integer DEFAULT 0,
    total_story_mentions integer DEFAULT 0,
    total_post_shares integer DEFAULT 0,
    last_dm_at timestamp with time zone,
    last_comment_at timestamp with time zone,
    last_story_reply_at timestamp with time zone,
    last_interaction_at timestamp with time zone,
    dms_last_7_days integer DEFAULT 0,
    dms_last_30_days integer DEFAULT 0,
    interactions_last_7_days integer DEFAULT 0,
    interactions_last_30_days integer DEFAULT 0,
    engagement_score integer DEFAULT 0,
    first_interaction_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: instagram_feed_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_feed_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    instagram_profile_id uuid,
    post_id text NOT NULL,
    code text,
    media_type integer,
    product_type text,
    thumbnail_url text,
    stored_thumbnail_url text,
    caption text,
    like_count integer DEFAULT 0,
    comment_count integer DEFAULT 0,
    play_count integer DEFAULT 0,
    taken_at timestamp with time zone,
    permalink text,
    hashtags text[] DEFAULT '{}'::text[],
    raw jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: instagram_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    instagram_message_id text,
    content text,
    message_type text DEFAULT 'text'::text,
    media_url text,
    is_from_me boolean DEFAULT false,
    sender_instagram_id text,
    sender_username text,
    reference_type text,
    reference_id text,
    reference_url text,
    reference_preview_url text,
    status text DEFAULT 'delivered'::text,
    error_message text,
    sent_at timestamp with time zone NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: instagram_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    username text NOT NULL,
    full_name text,
    biography text,
    external_url text,
    bio_links jsonb,
    category text,
    account_type integer,
    is_business boolean DEFAULT false,
    is_verified boolean DEFAULT false,
    is_private boolean DEFAULT false,
    follower_count integer DEFAULT 0,
    following_count integer DEFAULT 0,
    media_count integer DEFAULT 0,
    mutual_followers_count integer DEFAULT 0,
    instagram_user_id text,
    profile_picture_url_hd text,
    stored_profile_picture_url text,
    latest_reel_media_at timestamp with time zone,
    raw_profile jsonb,
    last_scraped_at timestamp with time zone DEFAULT now(),
    feed_last_sync timestamp with time zone,
    stories_last_sync timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: instagram_stories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.instagram_stories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    instagram_profile_id uuid,
    story_id text NOT NULL,
    media_type integer,
    media_url text,
    stored_media_url text,
    thumbnail_url text,
    stored_thumbnail_url text,
    has_audio boolean DEFAULT false,
    taken_at timestamp with time zone,
    expires_at timestamp with time zone,
    raw jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: integration_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.integration_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider text NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: lead_conversions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.lead_conversions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    conversion_type text DEFAULT 'new'::text NOT NULL,
    source text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    utm_term text,
    extra_data jsonb DEFAULT '{}'::jsonb,
    sales_rep_id uuid,
    deal_id uuid,
    origin text DEFAULT 'api'::text,
    raw_payload jsonb,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: TABLE lead_conversions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.lead_conversions IS 'Rastreia cada conversão/cadastro de um lead - primeira conversão e reconversões';


--
-- Name: COLUMN lead_conversions.conversion_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lead_conversions.conversion_type IS 'new = primeiro cadastro, reconversion = se cadastrou de novo';


--
-- Name: COLUMN lead_conversions.origin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lead_conversions.origin IS 'De onde veio: rdstation, api, pain_registration, manual';


--
-- Name: lead_diagnostics_v2; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.lead_diagnostics_v2 (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    lead_id uuid NOT NULL,
    business_stage character varying NOT NULL,
    age character varying,
    gender character varying,
    motivation text,
    ai_challenges text,
    monthly_revenue character varying,
    ai_course_experience character varying,
    biggest_dream text,
    immersion_content text,
    business_description text,
    time_consuming text,
    current_activity text,
    income_types text,
    qualification_score integer,
    other_goal text,
    which_ai_course text,
    ai_knowledge_level text,
    ai_knowledge_detail text,
    event_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: lead_distribution_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.lead_distribution_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text DEFAULT 'Distribuição Padrão'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    method text DEFAULT 'round_robin'::text NOT NULL,
    pipeline_id uuid,
    product_id text,
    first_stage_id uuid,
    require_availability boolean DEFAULT false NOT NULL,
    auto_create_deal boolean DEFAULT true NOT NULL,
    api_key uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    CONSTRAINT lead_distribution_config_method_check CHECK ((method = ANY (ARRAY['round_robin'::text, 'weighted'::text, 'by_source'::text])))
);


--
-- Name: lead_distribution_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.lead_distribution_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    config_id uuid,
    lead_id uuid,
    deal_id uuid,
    team_member_id uuid,
    method_used text DEFAULT 'round_robin'::text NOT NULL,
    source text DEFAULT 'api'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: lead_distribution_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.lead_distribution_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    config_id uuid NOT NULL,
    team_member_id uuid NOT NULL,
    weight integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: lead_interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.lead_interactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    interaction_type text,
    content text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_by uuid,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.leads (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    email text,
    phone text,
    instagram text,
    region text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    utm_term text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_interaction_at timestamp with time zone DEFAULT now(),
    last_message_sent_at timestamp with time zone,
    last_message_received_at timestamp with time zone,
    messages_count integer DEFAULT 0,
    engagement_score integer DEFAULT 0,
    document character varying(20),
    address text,
    address_number character varying(20),
    address_complement character varying(100),
    address_province character varying(100),
    postal_code character varying(10),
    city_name character varying(100),
    state character varying(50),
    country character varying(50),
    person_type character varying(20),
    sales_rep_id uuid,
    sales_stage text DEFAULT 'new'::text,
    sales_score integer DEFAULT 0,
    sales_score_reason text,
    bant_budget boolean,
    bant_authority boolean,
    bant_need boolean,
    bant_timeline boolean,
    expected_revenue numeric,
    ai_conversation_insights jsonb,
    ai_proposal_suggestion jsonb,
    ai_last_analysis_at timestamp with time zone,
    cpf_cnpj text,
    pipeline_stage_id uuid,
    attachments text[] DEFAULT '{}'::text[],
    context text,
    status text DEFAULT 'new'::text,
    instagram_id text,
    instagram_verified_at timestamp with time zone,
    company_name text,
    job_title text,
    photo_url text,
    source text,
    capital_disponivel text,
    melhor_horario_contato text,
    metadata jsonb DEFAULT '{}'::jsonb,
    is_internal_contact boolean DEFAULT false,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    timing_negocio text,
    regiao_interesse text,
    pode_completar_capital boolean,
    qualification jsonb DEFAULT '{}'::jsonb,
    franchise_campaign_id uuid,
    franchise_member_id uuid,
    franchise_member_name text,
    franchise_member_phone text,
    original_source text,
    original_utm_source text,
    original_utm_medium text,
    original_utm_campaign text,
    original_utm_content text,
    original_utm_term text,
    email_opted_out boolean DEFAULT false,
    gender text,
    business_type text,
    revenue_range text,
    is_icp boolean,
    webinar_config_id uuid,
    star_type text,
    acao_de_hoje text,
    status_de_resposta text,
    etapa_funil text,
    instagram_profile_id text,
    stage_changed_at timestamp with time zone,
    monthly_revenue numeric,
    partner_lead_id uuid,
    tags text[],
    instagram_username text
);


--
-- Name: COLUMN leads.utm_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.utm_source IS 'utm_source da última conversão (atualizado a cada reconversão)';


--
-- Name: COLUMN leads.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.source IS 'Source da última conversão (atualizado a cada reconversão)';


--
-- Name: COLUMN leads.is_internal_contact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.is_internal_contact IS 'Marks lead as internal contact (team member, partner, etc). Excluded from metrics, pipeline, focus mode.';


--
-- Name: COLUMN leads.qualification; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.qualification IS 'Campos de qualificação coletados pelo agente IA (business_type, years_in_business, business_model, unit_count, growth_objective, has_structured_team, monthly_revenue, is_qualified, qualification_reason)';


--
-- Name: COLUMN leads.original_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.original_source IS 'Source da primeira conversão (nunca sobrescrito)';


--
-- Name: COLUMN leads.original_utm_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.original_utm_source IS 'utm_source da primeira conversão (nunca sobrescrito)';


--
-- Name: COLUMN leads.webinar_config_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leads.webinar_config_id IS 'Webinário ativo no momento do cadastro do lead. Setado pela edge function quiz-api.';


--
-- Name: llm_provider_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.llm_provider_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    provider text NOT NULL,
    api_key text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT llm_provider_configs_provider_check CHECK ((provider = ANY (ARRAY['anthropic'::text, 'openai'::text, 'gemini'::text, 'groq'::text, 'deepseek'::text])))
);


--
-- Name: marketing_forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.marketing_forms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    name text NOT NULL,
    description text,
    fields jsonb DEFAULT '[]'::jsonb NOT NULL,
    style jsonb DEFAULT '{}'::jsonb NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    redirect_url text,
    success_message text DEFAULT 'Obrigado! Entraremos em contato em breve.'::text,
    is_active boolean DEFAULT true,
    submissions_count integer DEFAULT 0,
    last_submission_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE marketing_forms; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.marketing_forms IS 'Formulários embeddáveis para landing pages';


--
-- Name: COLUMN marketing_forms.fields; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.marketing_forms.fields IS 'Array de campos: [{id, type, label, placeholder, required, options, mask}]';


--
-- Name: COLUMN marketing_forms.style; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.marketing_forms.style IS 'Customização visual: {primary_color, bg_color, text_color, border_radius, font_family, logo_url}';


--
-- Name: COLUMN marketing_forms.settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.marketing_forms.settings IS 'Config: {distribution_key, source_name, show_logo, compact_mode}';


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meetings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    type text,
    participants jsonb NOT NULL,
    transcriptions jsonb,
    summary text,
    key_points jsonb,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'active'::text,
    organization_id uuid,
    lead_id uuid,
    activity_id uuid,
    created_by uuid,
    meeting_link character varying(500),
    meeting_type character varying(50) DEFAULT 'interno'::character varying,
    team character varying(50),
    audio_url character varying(500),
    soniox_session_id character varying(255),
    ai_analysis jsonb,
    processed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    CONSTRAINT meetings_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'no_show'::text, 'cancelled'::text])))
);


--
-- Name: member_calls_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.member_calls_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid,
    member_email text,
    member_user_id uuid,
    call_id uuid,
    call_title text,
    call_type text,
    call_date timestamp with time zone,
    join_time timestamp with time zone,
    leave_time timestamp with time zone,
    duration_minutes integer,
    call_total_duration integer,
    attendance_percentage numeric,
    created_at timestamp with time zone DEFAULT now(),
    lead_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: member_daily_activity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.member_daily_activity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid,
    member_email text,
    member_user_id uuid,
    activity_date date,
    sessions integer,
    page_views integer,
    time_minutes integer,
    lessons_watched integer,
    lessons_completed integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    lead_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: member_engagement_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.member_engagement_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid,
    member_user_id_external uuid,
    member_email text,
    member_name text,
    member_user_id uuid,
    snapshot_hour timestamp with time zone,
    last_access timestamp with time zone,
    days_since_last_access integer,
    total_sessions integer,
    sessions_last_7_days integer,
    sessions_last_30_days integer,
    total_time_minutes integer,
    lessons_started integer,
    lessons_completed integer,
    lessons_completion_rate numeric,
    calls_attended integer,
    calls_total_minutes integer,
    last_call_date timestamp with time zone,
    risk_score integer,
    risk_status text,
    created_at timestamp with time zone DEFAULT now(),
    lead_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: member_lessons_progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.member_lessons_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid,
    member_user_id uuid,
    member_email text,
    lesson_id text,
    lesson_title text,
    project_id text,
    completed boolean DEFAULT false,
    seconds_watched integer DEFAULT 0,
    completed_at timestamp with time zone,
    started_at timestamp with time zone,
    last_watched_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    lead_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: meta_ads_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_ads_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text NOT NULL,
    account_name text,
    is_active boolean DEFAULT true,
    last_synced_date date,
    is_syncing boolean DEFAULT false,
    organization_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: meta_ads_ad_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_ads_ad_data (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text NOT NULL,
    ad_id text NOT NULL,
    ad_name text,
    campaign_id text,
    campaign_name text,
    adset_id text,
    adset_name text,
    date date NOT NULL,
    aggregation_level text NOT NULL,
    spend numeric DEFAULT 0,
    impressions bigint DEFAULT 0,
    clicks bigint DEFAULT 0,
    ctr numeric DEFAULT 0,
    cpc numeric DEFAULT 0,
    frequency numeric DEFAULT 0,
    image_url text,
    thumbnail_url text,
    link_url text,
    body text,
    headline text,
    description text,
    status text,
    total_conversions bigint DEFAULT 0,
    primary_conversions bigint DEFAULT 0,
    cost_per_conversion numeric DEFAULT 0,
    campaign_objective text,
    organization_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: meta_ads_conversions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_ads_conversions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ad_data_id uuid,
    conversion_type text NOT NULL,
    conversion_count bigint DEFAULT 0,
    conversion_value numeric DEFAULT 0,
    cost_per_conversion numeric DEFAULT 0,
    organization_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: meta_ads_daily_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_ads_daily_data (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text NOT NULL,
    date date NOT NULL,
    aggregation_level text NOT NULL,
    total_spend numeric DEFAULT 0,
    total_impressions bigint DEFAULT 0,
    total_clicks bigint DEFAULT 0,
    total_leads bigint DEFAULT 0,
    ctr numeric DEFAULT 0,
    cpl numeric DEFAULT 0,
    conversion_rate numeric DEFAULT 0,
    frequency numeric DEFAULT 0,
    organization_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: meta_ads_sync_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_ads_sync_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id text,
    sync_type text NOT NULL,
    start_date date,
    end_date date,
    status text DEFAULT 'running'::text NOT NULL,
    records_processed integer DEFAULT 0,
    error_message text,
    execution_time_ms integer,
    completed_at timestamp with time zone,
    organization_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: meta_lead_ads_forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_lead_ads_forms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    page_id text NOT NULL,
    form_id text NOT NULL,
    form_name text NOT NULL,
    is_enabled boolean DEFAULT true,
    leads_count integer DEFAULT 0,
    last_lead_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: meta_lead_ads_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_lead_ads_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    page_id text,
    form_id text,
    form_name text,
    leadgen_id text,
    lead_name text,
    lead_email text,
    lead_phone text,
    status text DEFAULT 'success'::text,
    error_message text,
    lead_id uuid,
    deal_id uuid,
    assigned_to_name text,
    raw_data jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: meta_lead_ads_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.meta_lead_ads_pages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    page_id text NOT NULL,
    page_name text NOT NULL,
    page_access_token text NOT NULL,
    is_active boolean DEFAULT true,
    total_leads_synced integer DEFAULT 0,
    last_lead_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: noshow_followups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.noshow_followups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    deal_id uuid,
    attempt_number integer DEFAULT 1 NOT NULL,
    message_sent text,
    sent_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'sent'::text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: notification_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.notification_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_id uuid,
    rule_name character varying(255),
    event_id uuid,
    event_type character varying(50),
    channel character varying(50),
    target character varying(255),
    message text,
    status character varying(50) DEFAULT 'pending'::character varying,
    error_message text,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: notification_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.notification_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    trigger_type character varying(50) NOT NULL,
    trigger_event character varying(50),
    trigger_minutes integer,
    trigger_time time without time zone,
    trigger_days character varying[],
    action_channel character varying(50) NOT NULL,
    action_target_type character varying(50),
    action_target_id character varying(255),
    action_target_phone character varying(50),
    message_template text NOT NULL,
    enabled boolean DEFAULT true,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    action_instance_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: nps_survey_schedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.nps_survey_schedule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    lead_id uuid,
    milestone text NOT NULL,
    token uuid DEFAULT gen_random_uuid() NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    scheduled_for date NOT NULL,
    sent_at timestamp with time zone,
    completed_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: onboarding_stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.onboarding_stages (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    icon text DEFAULT 'circle'::text,
    color text DEFAULT '#6B7280'::text,
    is_final boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    checklist jsonb DEFAULT '[]'::jsonb
);


--
-- Name: onboardings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.onboardings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid,
    meeting_id uuid,
    activity_id uuid,
    product_id text DEFAULT 'pain'::text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    transcription_source text,
    transcription_raw text,
    dossier jsonb DEFAULT '{}'::jsonb,
    form_token text,
    form_url text,
    form_sent_at timestamp with time zone,
    form_opened_at timestamp with time zone,
    form_completed_at timestamp with time zone,
    confirmed_data jsonb DEFAULT '{}'::jsonb,
    additional_members jsonb DEFAULT '[]'::jsonb,
    plan text DEFAULT 'basic'::text,
    seats_limit integer DEFAULT 5,
    add_to_whatsapp boolean DEFAULT true,
    send_welcome boolean DEFAULT true,
    journey_config jsonb DEFAULT '{}'::jsonb,
    approved_at timestamp with time zone,
    approved_by uuid,
    rejected_at timestamp with time zone,
    rejected_by uuid,
    rejection_reason text,
    webhook_response jsonb,
    external_org_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    early_access_granted boolean DEFAULT false,
    early_access_at timestamp with time zone,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: organization_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.organization_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    user_id uuid,
    role public.member_role DEFAULT 'member'::public.member_role NOT NULL,
    job_title text,
    is_admin boolean DEFAULT false,
    can_invite boolean DEFAULT false,
    status public.member_status DEFAULT 'active'::public.member_status,
    invited_by uuid,
    invited_at timestamp with time zone,
    joined_at timestamp with time zone,
    invite_token text,
    invite_expires_at timestamp with time zone,
    whatsapp_in_group boolean DEFAULT false,
    whatsapp_added_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: organization_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.organization_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_id text NOT NULL,
    deal_id uuid,
    starts_at timestamp with time zone,
    expires_at timestamp with time zone,
    onboarding_status public.onboarding_status DEFAULT 'pending'::public.onboarding_status,
    onboarding_started_at timestamp with time zone,
    onboarding_completed_at timestamp with time zone,
    journey_stage public.journey_stage DEFAULT 'pending_onboard'::public.journey_stage,
    cs_status public.cs_status DEFAULT 'active'::public.cs_status,
    cs_rep_id uuid,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    primary_contact_id uuid,
    name text NOT NULL,
    slug text NOT NULL,
    org_type public.organization_type DEFAULT 'individual'::public.organization_type NOT NULL,
    plan text DEFAULT 'basic'::text,
    seats_limit integer DEFAULT 1,
    contract_start date,
    contract_end date,
    billing_contact_name text,
    billing_contact_email text,
    billing_contact_phone text,
    logo_url text,
    primary_color text,
    status public.organization_status DEFAULT 'active'::public.organization_status,
    churned_at timestamp with time zone,
    churn_reason text,
    settings jsonb DEFAULT '{}'::jsonb,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    external_member_area_org_id uuid,
    external_member_area_user_id uuid,
    ai_insights jsonb,
    early_access_granted boolean DEFAULT false,
    early_access_at timestamp with time zone,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: COLUMN organizations.ai_insights; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.organizations.ai_insights IS 'Insights gerados por IA sobre o cliente';


--
-- Name: pain_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.pain_registrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    name text NOT NULL,
    phone text NOT NULL,
    email text,
    company_name text,
    monthly_revenue text,
    payment_option text,
    status text DEFAULT 'pending'::text,
    notes text,
    assignee text,
    payment_method text,
    payment_details text,
    amount_paid integer DEFAULT 0,
    amount_total integer DEFAULT 0,
    amount_balance integer DEFAULT 0,
    payment_platform text,
    loss_reason text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_term text,
    utm_content text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: payment_gateway_fees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.payment_gateway_fees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    gateway_id uuid NOT NULL,
    billing_type character varying NOT NULL,
    fee_percent numeric(5,2) DEFAULT 0 NOT NULL,
    fee_fixed numeric(10,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: payment_gateways; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.payment_gateways (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.products (
    id text NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    logo_url text,
    primary_color text,
    cs_process_type text,
    cs_config jsonb,
    onboarding_required boolean DEFAULT true,
    onboarding_steps jsonb,
    is_active boolean DEFAULT true,
    settings jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    price numeric,
    category text,
    sku text,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    avatar_url text,
    role text DEFAULT 'user'::text NOT NULL,
    team text,
    phone text,
    is_active boolean DEFAULT true,
    google_access_token text,
    google_refresh_token text,
    google_token_expires_at timestamp with time zone,
    google_calendar_connected boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    whatsapp_instance_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: prospeccao_buscas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.prospeccao_buscas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    query text NOT NULL,
    query_normalizada text,
    intent_detectada jsonb DEFAULT '{}'::jsonb,
    nicho text,
    cidade text,
    uf text,
    fontes_selecionadas text[] DEFAULT ARRAY[]::text[],
    limite_solicitado integer DEFAULT 20,
    total_resultados integer DEFAULT 0,
    custo numeric DEFAULT 0,
    duracao_ms integer,
    status text DEFAULT 'pending'::text,
    erro text,
    resultados_raw jsonb,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: prospeccao_diagnosticos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.prospeccao_diagnosticos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_descoberto_id uuid,
    busca_id uuid,
    score_site integer,
    score_google_maps integer,
    score_instagram integer,
    score_facebook integer,
    score_linkedin integer,
    score_youtube integer,
    score_tiktok integer,
    score_doctoralia integer,
    score_reclame_aqui integer,
    score_ifood integer,
    score_meta_ads integer,
    score_google_ads integer,
    score_posicao_google integer,
    score_pagespeed integer,
    score_outros jsonb DEFAULT '{}'::jsonb,
    score_geral numeric,
    score_atracao numeric,
    score_qualificacao numeric,
    score_conversao numeric,
    score_retencao numeric,
    achados_site jsonb DEFAULT '{}'::jsonb,
    achados_maps jsonb DEFAULT '{}'::jsonb,
    achados_instagram jsonb DEFAULT '{}'::jsonb,
    achados_facebook jsonb DEFAULT '{}'::jsonb,
    achados_linkedin jsonb DEFAULT '{}'::jsonb,
    achados_youtube jsonb DEFAULT '{}'::jsonb,
    achados_tiktok jsonb DEFAULT '{}'::jsonb,
    achados_doctoralia jsonb DEFAULT '{}'::jsonb,
    achados_reclame_aqui jsonb DEFAULT '{}'::jsonb,
    achados_ifood jsonb DEFAULT '{}'::jsonb,
    achados_meta_ads jsonb DEFAULT '{}'::jsonb,
    achados_google_ads jsonb DEFAULT '{}'::jsonb,
    achados_posicao_google jsonb DEFAULT '{}'::jsonb,
    achados_pagespeed jsonb DEFAULT '{}'::jsonb,
    achados_contexto_negocio jsonb DEFAULT '{}'::jsonb,
    achados_outros jsonb DEFAULT '{}'::jsonb,
    oportunidades jsonb DEFAULT '[]'::jsonb,
    resumo_executivo text,
    custo_total numeric DEFAULT 0,
    tempo_analise_ms integer,
    fontes_consultadas text[] DEFAULT ARRAY[]::text[],
    fontes_falhadas text[] DEFAULT ARRAY[]::text[],
    fontes_pendentes text[] DEFAULT ARRAY[]::text[],
    status text DEFAULT 'pending'::text,
    erro text,
    pdf_url text,
    pdf_imagens_urls text[] DEFAULT ARRAY[]::text[],
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: prospeccao_leads_descobertos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.prospeccao_leads_descobertos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    busca_id uuid,
    nome text NOT NULL,
    categoria text,
    telefone text,
    endereco text,
    bairro text,
    cidade text,
    uf text,
    url_maps text,
    url_site text,
    instagram_handle text,
    facebook_url text,
    linkedin_url text,
    youtube_url text,
    tiktok_handle text,
    nota_google numeric,
    qtd_avaliacoes integer,
    faixa_preco text,
    status text DEFAULT 'descoberto'::text,
    selecionado_para_analise boolean DEFAULT false,
    virou_lead_em timestamp with time zone,
    lead_id uuid,
    deal_id uuid,
    raw_data jsonb DEFAULT '{}'::jsonb,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: prospeccao_prompts_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.prospeccao_prompts_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    label text NOT NULL,
    descricao text,
    prompt_text text NOT NULL,
    variables_help jsonb DEFAULT '{}'::jsonb,
    ai_model text DEFAULT 'gemini-2.5-flash'::text,
    temperature numeric DEFAULT 0.4,
    tom_voz text DEFAULT 'neutro'::text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: prospeccao_templates_nicho; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.prospeccao_templates_nicho (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nicho text NOT NULL,
    emoji text DEFAULT '🎯'::text,
    display_name text NOT NULL,
    descricao text,
    fontes_obrigatorias text[] DEFAULT ARRAY[]::text[],
    fontes_opcionais text[] DEFAULT ARRAY[]::text[],
    pesos_score jsonb DEFAULT '{}'::jsonb,
    prompt_oportunidades text,
    custo_estimado_lead numeric DEFAULT 0.13,
    is_default boolean DEFAULT true,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: prospeccao_uso_api; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.prospeccao_uso_api (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_provider text NOT NULL,
    endpoint text,
    fonte text,
    custo numeric DEFAULT 0,
    sucesso boolean DEFAULT true,
    duracao_ms integer,
    busca_id uuid,
    lead_descoberto_id uuid,
    erro text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_by_user_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: receive_lead_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.receive_lead_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    api_key text,
    config_id uuid,
    origin text,
    lead_name text,
    lead_email text,
    lead_phone text,
    lead_source text,
    status text DEFAULT 'pending'::text NOT NULL,
    lead_id uuid,
    deal_id uuid,
    assigned_to uuid,
    assigned_to_name text,
    dedup_match text,
    existing_lead_id uuid,
    error_message text,
    error_details jsonb,
    raw_payload jsonb,
    processing_ms integer,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_alerts (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    lead_id uuid NOT NULL,
    sales_rep_id uuid,
    alert_type text NOT NULL,
    title text NOT NULL,
    description text,
    priority integer DEFAULT 5,
    is_read boolean DEFAULT false,
    is_actioned boolean DEFAULT false,
    actioned_at timestamp with time zone,
    expires_at timestamp with time zone,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_automation_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_automation_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    trigger_type text NOT NULL,
    trigger_conditions jsonb DEFAULT '{}'::jsonb,
    action_type text NOT NULL,
    action_config jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    team text DEFAULT 'sales'::text,
    priority integer DEFAULT 10,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    CONSTRAINT sales_automation_rules_action_type_check CHECK ((action_type = ANY (ARRAY['move_deal_stage'::text, 'create_task'::text, 'send_notification'::text, 'update_lead_field'::text, 'send_webhook'::text, 'send_email'::text])))
);


--
-- Name: sales_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    type character varying(50) NOT NULL,
    file_url text NOT NULL,
    thumbnail_url text,
    file_size bigint,
    mime_type character varying(100),
    tags text[] DEFAULT '{}'::text[],
    usage_hint text,
    is_active boolean DEFAULT true,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    deal_id uuid,
    content text NOT NULL,
    note_type text DEFAULT 'note'::text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_pipeline_stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_pipeline_stages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    "position" integer NOT NULL,
    color text DEFAULT 'gray'::text,
    description text,
    is_won boolean DEFAULT false,
    is_lost boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    pipeline_id uuid NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_pipeline_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_pipeline_transitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_pipeline_id uuid,
    source_stage_id uuid,
    target_pipeline_id uuid,
    target_stage_id uuid,
    action character varying DEFAULT 'move'::character varying,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_pipelines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_pipelines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    "position" integer DEFAULT 0,
    is_default boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    default_sales_rep_id uuid,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: sales_playbook; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sales_playbook (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text,
    content text,
    is_active boolean DEFAULT true,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: scheduled_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.scheduled_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    instance_id uuid,
    content text,
    media_url text,
    message_type text DEFAULT 'text'::text,
    scheduled_at timestamp with time zone NOT NULL,
    sent_at timestamp with time zone,
    status text DEFAULT 'pending'::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: sdr_closer_transfers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.sdr_closer_transfers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    deal_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    sdr_id uuid NOT NULL,
    closer_id uuid,
    from_pipeline_id uuid NOT NULL,
    from_stage_id uuid NOT NULL,
    to_pipeline_id uuid NOT NULL,
    to_stage_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    qualification_snapshot jsonb DEFAULT '{}'::jsonb,
    return_reason text,
    return_notes text,
    transferred_at timestamp with time zone DEFAULT now() NOT NULL,
    accepted_at timestamp with time zone,
    returned_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sdr_closer_transfers_return_reason_check CHECK ((return_reason = ANY (ARRAY['no_show'::text, 'not_qualified'::text, 'unreachable'::text, 'other'::text]))),
    CONSTRAINT sdr_closer_transfers_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'returned'::text, 'expired'::text])))
);


--
-- Name: social_seller_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_seller_alerts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    lead_id uuid,
    rule_id uuid,
    alert_type text NOT NULL,
    title text NOT NULL,
    message text,
    trigger_message text,
    detected_keywords text[],
    from_stage text,
    to_stage text,
    status text DEFAULT 'pending'::text,
    viewed_at timestamp with time zone,
    actioned_at timestamp with time zone,
    actioned_by uuid,
    action_notes text,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: social_seller_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_seller_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    trigger_type text NOT NULL,
    trigger_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    from_stage_id uuid,
    to_stage_id uuid NOT NULL,
    create_alert boolean DEFAULT false,
    alert_message text,
    notify_whatsapp boolean DEFAULT false,
    notification_template text,
    is_active boolean DEFAULT true,
    priority integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: social_seller_stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_seller_stages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    color text DEFAULT '#6B7280'::text,
    icon text DEFAULT 'circle'::text,
    "position" integer NOT NULL,
    is_active boolean DEFAULT true,
    is_final boolean DEFAULT false,
    is_converted boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: social_selling_automations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_selling_automations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    emoji text DEFAULT '🎯'::text,
    is_active boolean DEFAULT true,
    trigger_type text NOT NULL,
    trigger_config jsonb DEFAULT '{}'::jsonb,
    qualification_config jsonb DEFAULT '{}'::jsonb,
    cadence_config jsonb DEFAULT '{"days": []}'::jsonb NOT NULL,
    on_reply_config jsonb DEFAULT '{}'::jsonb,
    rate_limit_overrides jsonb DEFAULT '{}'::jsonb,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    description text,
    CONSTRAINT social_selling_automations_trigger_type_check CHECK ((trigger_type = ANY (ARRAY['stage_change'::text, 'tag_added'::text, 'no_reply'::text, 'new_follower'::text, 'manual'::text])))
);


--
-- Name: social_selling_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_selling_enrollments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    flow_name text DEFAULT 'Aquecimento Padrão'::text NOT NULL,
    flow_config jsonb DEFAULT '{}'::jsonb,
    current_day integer DEFAULT 0,
    total_days integer DEFAULT 7,
    status text DEFAULT 'active'::text NOT NULL,
    instagram_username text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    last_action_at timestamp with time zone,
    next_action_at timestamp with time zone,
    completed_at timestamp with time zone,
    pause_reason text,
    metadata jsonb DEFAULT '{}'::jsonb,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_visited_at timestamp with time zone,
    automation_id uuid,
    CONSTRAINT social_selling_enrollments_status_check CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'replied'::text, 'completed'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: social_selling_interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_selling_interactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid NOT NULL,
    enrollment_id uuid,
    action_type text NOT NULL,
    day_number integer,
    content text,
    instagram_target text,
    status text DEFAULT 'success'::text NOT NULL,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb,
    executed_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT social_selling_interactions_status_check CHECK ((status = ANY (ARRAY['success'::text, 'failed'::text, 'skipped'::text, 'rate_limited'::text])))
);


--
-- Name: social_selling_known_followers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_selling_known_followers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    username text NOT NULL,
    instagram_user_id text,
    for_account text NOT NULL,
    full_name text,
    is_private boolean,
    is_verified boolean,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    qualified boolean,
    qualification_score integer,
    qualification_reason text,
    lead_id uuid,
    enrollment_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb
);


--
-- Name: social_selling_qualification_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.social_selling_qualification_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    automation_id uuid,
    instagram_username text NOT NULL,
    ai_score integer,
    ai_reason text,
    qualified boolean DEFAULT false,
    lead_id uuid,
    profile_data jsonb,
    analyzed_at timestamp with time zone DEFAULT now() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    instagram_profile_id uuid
);


--
-- Name: tenant_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.tenant_config (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    tenant_id uuid NOT NULL,
    company_name text NOT NULL,
    logo_url text,
    favicon_url text,
    primary_color text DEFAULT '#c8952e'::text,
    secondary_color text DEFAULT '#7a9182'::text,
    background_color text DEFAULT '#0c0c0e'::text,
    text_color text DEFAULT '#f8f6f1'::text,
    custom_domain text,
    features jsonb DEFAULT '{"agenda": true, "eventos": false, "playbook": true, "comissoes": true, "cs_module": false, "instagram": false, "materiais": true, "modo_foco": true, "financeiro": false, "meta_lead_ads": false, "monitoramento": true, "importar_leads": true, "email_marketing": false, "super_relatorio": true, "campanhas_whatsapp": true}'::jsonb,
    default_pipeline_id uuid,
    commission_type text DEFAULT 'percentual_fixo'::text,
    commission_config jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    api_key text DEFAULT (extensions.uuid_generate_v4())::text,
    email_from_email text,
    email_from_name text,
    email_reply_to text,
    email_company_address text,
    email_app_url text,
    email_is_active boolean DEFAULT false,
    email_domain_verified boolean DEFAULT false
);


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lead_id uuid,
    deal_id uuid,
    amount numeric DEFAULT 0,
    status text DEFAULT 'pending'::text,
    payment_method text,
    payment_platform text,
    transaction_date timestamp with time zone DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    tenant_id uuid DEFAULT '00000000-0000-0000-0000-000000000001'::uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: twilio_call_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.twilio_call_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    call_sid text NOT NULL,
    parent_call_sid text,
    call_status text NOT NULL,
    direction text,
    from_number text,
    to_number text,
    caller_id text,
    duration integer,
    sip_response_code text,
    error_code text,
    error_message text,
    "timestamp" timestamp with time zone DEFAULT now(),
    raw_params jsonb,
    call_history_id uuid,
    team_member_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: v_ai_agent_dashboard; Type: VIEW; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.v_ai_agent_dashboard AS
 SELECT a.id AS agent_id,
    a.name AS agent_name,
    a.is_active,
    a.tenant_id,
    count(DISTINCT c.id) AS total_conversations,
    count(DISTINCT
        CASE
            WHEN (c.status = 'active'::text) THEN c.id
            ELSE NULL::uuid
        END) AS active_conversations,
    count(DISTINCT
        CASE
            WHEN (c.status = 'paused_by_human'::text) THEN c.id
            ELSE NULL::uuid
        END) AS paused_conversations,
    COALESCE(sum(c.total_messages_sent), (0)::bigint) AS total_messages_sent,
    count(DISTINCT q.id) FILTER (WHERE (q.status = 'pending'::text)) AS pending_in_queue,
    count(DISTINCT q.id) FILTER (WHERE (q.status = 'failed'::text)) AS failed_in_queue
   FROM ((public.ai_sales_agents a
     LEFT JOIN public.ai_agent_conversations c ON ((c.agent_id = a.id)))
     LEFT JOIN public.ai_agent_message_queue q ON ((q.lead_id = c.lead_id)))
  GROUP BY a.id, a.name, a.is_active, a.tenant_id;


--
-- Name: wa_communities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_communities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instance_id uuid NOT NULL,
    community_jid text,
    name text NOT NULL,
    description text,
    picture_url text,
    invite_link text,
    member_count integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE wa_communities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_communities IS 'Comunidades do WhatsApp gerenciadas pelo módulo Marketing';


--
-- Name: wa_community_campaign_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_community_campaign_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    campaign_id uuid NOT NULL,
    community_id uuid NOT NULL,
    "position" integer NOT NULL,
    capacity integer DEFAULT 5000 NOT NULL,
    status text DEFAULT 'waiting'::text NOT NULL,
    clicks integer DEFAULT 0 NOT NULL,
    filled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_community_campaign_items_status_check CHECK ((status = ANY (ARRAY['waiting'::text, 'active'::text, 'full'::text, 'disabled'::text])))
);


--
-- Name: TABLE wa_community_campaign_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_community_campaign_items IS 'Comunidades inscritas em uma campanha, com ordem e capacidade';


--
-- Name: wa_community_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_community_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    fallback_url text,
    total_clicks integer DEFAULT 0 NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    webinar_config_id uuid
);


--
-- Name: TABLE wa_community_campaigns; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_community_campaigns IS 'Campanhas de roteamento de comunidades — link único distribui entre várias';


--
-- Name: COLUMN wa_community_campaigns.webinar_config_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wa_community_campaigns.webinar_config_id IS 'Vincula a campanha de distribuição ao webinário ativo. Usado pelo worker sync-community-members.';


--
-- Name: wa_community_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_community_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    community_id uuid NOT NULL,
    group_jid text,
    name text NOT NULL,
    description text,
    picture_url text,
    type text DEFAULT 'discussion'::text NOT NULL,
    invite_link text,
    member_count integer DEFAULT 0 NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_community_groups_type_check CHECK ((type = ANY (ARRAY['announcement'::text, 'discussion'::text])))
);


--
-- Name: TABLE wa_community_groups; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_community_groups IS 'Grupos vinculados a uma comunidade';


--
-- Name: wa_message_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_message_sequences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    community_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    trigger text DEFAULT 'manual'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_message_sequences_trigger_check CHECK ((trigger = ANY (ARRAY['manual'::text, 'on_join'::text])))
);


--
-- Name: TABLE wa_message_sequences; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_message_sequences IS 'Cadências/sequências de mensagens automatizadas';


--
-- Name: wa_scheduled_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_scheduled_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instance_id uuid NOT NULL,
    community_id uuid,
    target_group_id uuid,
    target_jid text NOT NULL,
    message_type text DEFAULT 'text'::text NOT NULL,
    content text,
    media_url text,
    scheduled_for timestamp with time zone NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    sent_at timestamp with time zone,
    error text,
    whatsapp_message_id text,
    sequence_id uuid,
    sequence_step_id uuid,
    enrollment_id uuid,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT wa_scheduled_messages_message_type_check CHECK ((message_type = ANY (ARRAY['text'::text, 'image'::text, 'video'::text, 'audio'::text, 'document'::text]))),
    CONSTRAINT wa_scheduled_messages_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sending'::text, 'sent'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: TABLE wa_scheduled_messages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_scheduled_messages IS 'Fila de mensagens agendadas (worker process-scheduled-messages)';


--
-- Name: wa_sequence_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_sequence_enrollments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sequence_id uuid NOT NULL,
    member_phone text,
    member_jid text,
    member_name text,
    current_step integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    next_run_at timestamp with time zone,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT wa_sequence_enrollments_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text, 'failed'::text])))
);


--
-- Name: TABLE wa_sequence_enrollments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_sequence_enrollments IS 'Membros inscritos numa sequência';


--
-- Name: wa_sequence_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wa_sequence_steps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sequence_id uuid NOT NULL,
    step_order integer NOT NULL,
    delay_value integer DEFAULT 0 NOT NULL,
    delay_unit text DEFAULT 'minutes'::text NOT NULL,
    target_group_id uuid,
    message_type text DEFAULT 'text'::text NOT NULL,
    content text,
    media_url text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_sequence_steps_delay_unit_check CHECK ((delay_unit = ANY (ARRAY['minutes'::text, 'hours'::text, 'days'::text]))),
    CONSTRAINT wa_sequence_steps_message_type_check CHECK ((message_type = ANY (ARRAY['text'::text, 'image'::text, 'video'::text, 'audio'::text, 'document'::text])))
);


--
-- Name: TABLE wa_sequence_steps; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wa_sequence_steps IS 'Passos de uma sequência (com delay relativo)';


--
-- Name: wavoip_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.wavoip_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_member_id uuid,
    token text NOT NULL,
    name text,
    phone_number text,
    status text DEFAULT 'disconnected'::text,
    webhook_configured boolean DEFAULT false,
    is_active boolean DEFAULT true,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: whatsapp_cloud_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_cloud_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    instance_id uuid,
    meta_template_id text,
    name text NOT NULL,
    language text DEFAULT 'pt_BR'::text,
    category text,
    status text DEFAULT 'PENDING'::text,
    components jsonb,
    rejection_reason text,
    example_payload jsonb,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT whatsapp_cloud_templates_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text, 'DISABLED'::text, 'PAUSED'::text, 'IN_APPEAL'::text])))
);


--
-- Name: whatsapp_group_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid,
    lead_id uuid,
    phone text NOT NULL,
    name text,
    is_admin boolean DEFAULT false,
    joined_at timestamp with time zone DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: whatsapp_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instance_id uuid,
    group_jid text NOT NULL,
    name text,
    description text,
    owner_jid text,
    participant_count integer DEFAULT 0,
    purposes text[] DEFAULT '{}'::text[],
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    photo_url text,
    group_type text DEFAULT 'group'::text,
    is_active boolean DEFAULT true,
    whatsapp_id text,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: whatsapp_instances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_instances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    phone_number text,
    teams text[] DEFAULT '{}'::text[],
    status text DEFAULT 'disconnected'::text,
    api_key text,
    webhook_url text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    api_url character varying(255),
    bypass_disconnect boolean DEFAULT false,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    purpose text DEFAULT 'inbox'::text NOT NULL,
    CONSTRAINT whatsapp_instances_purpose_check CHECK ((purpose = ANY (ARRAY['inbox'::text, 'campaign'::text])))
);

ALTER TABLE ONLY public.whatsapp_instances REPLICA IDENTITY FULL;


--
-- Name: COLUMN whatsapp_instances.bypass_disconnect; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.whatsapp_instances.bypass_disconnect IS 'When true, the disconnect banner is suppressed (e.g. when WhatsApp account is blocked)';


--
-- Name: whatsapp_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    instance_id uuid,
    lead_id uuid,
    group_id uuid,
    message_id text NOT NULL,
    remote_jid text,
    sender_phone text,
    sender_name text,
    content text,
    message_type text DEFAULT 'text'::text,
    media_url text,
    is_from_me boolean DEFAULT false,
    status text DEFAULT 'sent'::text,
    sent_at timestamp with time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    reactions jsonb DEFAULT '[]'::jsonb,
    is_edited boolean DEFAULT false,
    is_deleted boolean DEFAULT false,
    edited_at timestamp with time zone,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);

ALTER TABLE ONLY public.whatsapp_messages REPLICA IDENTITY FULL;


--
-- Name: whatsapp_task_bot_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_task_bot_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text DEFAULT 'Bot de Tarefas'::text NOT NULL,
    instance_id uuid,
    bot_mention_id text NOT NULL,
    enabled_group_ids uuid[] DEFAULT '{}'::uuid[],
    ai_prompt text DEFAULT 'Voce e um assistente que cria tarefas a partir de conversas de WhatsApp.'::text NOT NULL,
    context_messages_count integer DEFAULT 20,
    auto_assign_to_sender boolean DEFAULT true,
    default_task_type text DEFAULT 'follow_up'::text,
    notify_on_creation boolean DEFAULT true,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: whatsapp_task_bot_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_task_bot_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    config_id uuid,
    group_id uuid,
    trigger_message_id uuid,
    trigger_content text,
    sender_name text,
    sender_phone text,
    context_messages jsonb,
    ai_response jsonb,
    action_taken text,
    task_id uuid,
    response_message text,
    error text,
    created_at timestamp with time zone DEFAULT now(),
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL
);


--
-- Name: whatsapp_template_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE IF NOT EXISTS public.whatsapp_template_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid DEFAULT public.get_tenant_id() NOT NULL,
    template_id uuid,
    tag text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_agent_cadence_enrollments ai_agent_cadence_enrollments_lead_id_agent_id_stage_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_cadence_enrollments
    ADD CONSTRAINT ai_agent_cadence_enrollments_lead_id_agent_id_stage_key UNIQUE (lead_id, agent_id, stage);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_cadence_enrollments ai_agent_cadence_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_cadence_enrollments
    ADD CONSTRAINT ai_agent_cadence_enrollments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_chat_events ai_agent_chat_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_chat_events
    ADD CONSTRAINT ai_agent_chat_events_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_conversations ai_agent_conversations_lead_agent_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_conversations
    ADD CONSTRAINT ai_agent_conversations_lead_agent_key UNIQUE (lead_id, agent_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_conversations ai_agent_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_conversations
    ADD CONSTRAINT ai_agent_conversations_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_logs ai_agent_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_logs
    ADD CONSTRAINT ai_agent_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_message_queue ai_agent_message_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_message_queue
    ADD CONSTRAINT ai_agent_message_queue_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_scheduled_followups ai_agent_scheduled_followups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_scheduled_followups
    ADD CONSTRAINT ai_agent_scheduled_followups_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_send_counts ai_agent_send_counts_instance_id_window_start_window_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_send_counts
    ADD CONSTRAINT ai_agent_send_counts_instance_id_window_start_window_type_key UNIQUE (instance_id, window_start, window_type);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_send_counts ai_agent_send_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_send_counts
    ADD CONSTRAINT ai_agent_send_counts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_tools ai_agent_tools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_tools
    ADD CONSTRAINT ai_agent_tools_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_sales_agents ai_sales_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_sales_agents
    ADD CONSTRAINT ai_sales_agents_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: analysis_templates analysis_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.analysis_templates
    ADD CONSTRAINT analysis_templates_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: asaas_customers asaas_customers_asaas_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.asaas_customers
    ADD CONSTRAINT asaas_customers_asaas_customer_id_key UNIQUE (asaas_customer_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: asaas_customers asaas_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.asaas_customers
    ADD CONSTRAINT asaas_customers_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: asaas_webhooks asaas_webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.asaas_webhooks
    ADD CONSTRAINT asaas_webhooks_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_blocks calendar_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_blocks
    ADD CONSTRAINT calendar_blocks_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_events calendar_events_google_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_google_event_id_key UNIQUE (google_event_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: call_history call_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.call_history
    ADD CONSTRAINT call_history_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_instance_stats campaign_instance_stats_instance_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_instance_stats
    ADD CONSTRAINT campaign_instance_stats_instance_id_date_key UNIQUE (instance_id, date);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_instance_stats campaign_instance_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_instance_stats
    ADD CONSTRAINT campaign_instance_stats_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_campaign_id_lead_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_campaign_id_lead_id_key UNIQUE (campaign_id, lead_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_templates campaign_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_templates
    ADD CONSTRAINT campaign_templates_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_provider_check; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE public.campaigns
    ADD CONSTRAINT campaigns_provider_check CHECK ((provider = ANY (ARRAY['uazapi'::text, 'cloud_api'::text]))) NOT VALID;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_configs chat_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_configs
    ADD CONSTRAINT chat_configs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_configs chat_configs_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_configs
    ADD CONSTRAINT chat_configs_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_sessions chat_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_sessions
    ADD CONSTRAINT chat_sessions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: client_onboarding_data client_onboarding_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.client_onboarding_data
    ADD CONSTRAINT client_onboarding_data_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: client_onboarding_data client_onboarding_data_tenant_id_lead_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.client_onboarding_data
    ADD CONSTRAINT client_onboarding_data_tenant_id_lead_id_key UNIQUE (tenant_id, lead_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_playbooks coach_playbooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_playbooks
    ADD CONSTRAINT coach_playbooks_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_sessions coach_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_sessions
    ADD CONSTRAINT coach_sessions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commission_rules commission_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commission_rules
    ADD CONSTRAINT commission_rules_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commissions commissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_google_event_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_google_event_id_unique UNIQUE (google_event_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: config config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.config
    ADD CONSTRAINT config_pkey PRIMARY KEY (key);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_handled cs_conversation_handled_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_handled
    ADD CONSTRAINT cs_conversation_handled_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_notes cs_conversation_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_notes
    ADD CONSTRAINT cs_conversation_notes_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_engagement_metrics cs_engagement_metrics_org_product_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_engagement_metrics
    ADD CONSTRAINT cs_engagement_metrics_org_product_key UNIQUE (organization_id, product_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_engagement_metrics cs_engagement_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_engagement_metrics
    ADD CONSTRAINT cs_engagement_metrics_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_connections cs_event_connections_event_id_requester_rsvp_id_target_rsvp_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_connections
    ADD CONSTRAINT cs_event_connections_event_id_requester_rsvp_id_target_rsvp_key UNIQUE (event_id, requester_rsvp_id, target_rsvp_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_connections cs_event_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_connections
    ADD CONSTRAINT cs_event_connections_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_feed_likes cs_event_feed_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_feed_likes
    ADD CONSTRAINT cs_event_feed_likes_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_feed_likes cs_event_feed_likes_post_id_rsvp_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_feed_likes
    ADD CONSTRAINT cs_event_feed_likes_post_id_rsvp_id_key UNIQUE (post_id, rsvp_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_feed_posts cs_event_feed_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_feed_posts
    ADD CONSTRAINT cs_event_feed_posts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_materials cs_event_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_materials
    ADD CONSTRAINT cs_event_materials_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_profiles cs_event_participant_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_profiles
    ADD CONSTRAINT cs_event_participant_profiles_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_profiles cs_event_participant_profiles_rsvp_id_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_profiles
    ADD CONSTRAINT cs_event_participant_profiles_rsvp_id_event_id_key UNIQUE (rsvp_id, event_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_sessions cs_event_participant_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_sessions
    ADD CONSTRAINT cs_event_participant_sessions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_sessions cs_event_participant_sessions_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_sessions
    ADD CONSTRAINT cs_event_participant_sessions_token_key UNIQUE (token);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_event_id_guest_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_event_id_guest_email_key UNIQUE (event_id, guest_email);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_schedule_bookmarks cs_event_schedule_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_schedule_bookmarks
    ADD CONSTRAINT cs_event_schedule_bookmarks_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_schedule_bookmarks cs_event_schedule_bookmarks_schedule_item_id_rsvp_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_schedule_bookmarks
    ADD CONSTRAINT cs_event_schedule_bookmarks_schedule_item_id_rsvp_id_key UNIQUE (schedule_item_id, rsvp_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_schedule_items cs_event_schedule_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_schedule_items
    ADD CONSTRAINT cs_event_schedule_items_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events cs_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_events
    ADD CONSTRAINT cs_events_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events cs_events_rsvp_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_events
    ADD CONSTRAINT cs_events_rsvp_token_key UNIQUE (rsvp_token);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events cs_events_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_events
    ADD CONSTRAINT cs_events_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_current cs_health_current_org_product_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_current
    ADD CONSTRAINT cs_health_current_org_product_key UNIQUE (organization_id, product_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_current cs_health_current_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_current
    ADD CONSTRAINT cs_health_current_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_scores_history cs_health_scores_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_scores_history
    ADD CONSTRAINT cs_health_scores_history_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_conversation_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_conversation_key_key UNIQUE (conversation_key);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_interactions cs_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_interactions
    ADD CONSTRAINT cs_interactions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_objectives cs_objectives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_objectives
    ADD CONSTRAINT cs_objectives_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_response_templates cs_response_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_response_templates
    ADD CONSTRAINT cs_response_templates_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_success_metrics cs_success_metrics_org_product_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_success_metrics
    ADD CONSTRAINT cs_success_metrics_org_product_key UNIQUE (organization_id, product_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_success_metrics cs_success_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_success_metrics
    ADD CONSTRAINT cs_success_metrics_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_touchpoints cs_touchpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_touchpoints
    ADD CONSTRAINT cs_touchpoints_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_contacts deal_contacts_deal_id_lead_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_contacts
    ADD CONSTRAINT deal_contacts_deal_id_lead_id_key UNIQUE (deal_id, lead_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_contacts deal_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_contacts
    ADD CONSTRAINT deal_contacts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_loss_reasons deal_loss_reasons_label_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_loss_reasons
    ADD CONSTRAINT deal_loss_reasons_label_key UNIQUE (label);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_loss_reasons deal_loss_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_loss_reasons
    ADD CONSTRAINT deal_loss_reasons_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payment_installments deal_payment_installments_payment_installment_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payment_installments
    ADD CONSTRAINT deal_payment_installments_payment_installment_key UNIQUE (deal_payment_id, installment_number);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payment_installments deal_payment_installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payment_installments
    ADD CONSTRAINT deal_payment_installments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payments deal_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payments
    ADD CONSTRAINT deal_payments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: dropdown_options dropdown_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.dropdown_options
    ADD CONSTRAINT dropdown_options_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automation_runs email_automation_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automation_runs
    ADD CONSTRAINT email_automation_runs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automations email_automations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automations
    ADD CONSTRAINT email_automations_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_campaign_leads email_campaign_leads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_campaign_leads
    ADD CONSTRAINT email_campaign_leads_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_campaigns email_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_campaigns
    ADD CONSTRAINT email_campaigns_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_events email_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_events
    ADD CONSTRAINT email_events_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_lists email_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_lists
    ADD CONSTRAINT email_lists_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sends email_sends_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sends
    ADD CONSTRAINT email_sends_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_enrollments email_sequence_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_enrollments
    ADD CONSTRAINT email_sequence_enrollments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_logs email_sequence_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_logs
    ADD CONSTRAINT email_sequence_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_steps email_sequence_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_steps
    ADD CONSTRAINT email_sequence_steps_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequences email_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequences
    ADD CONSTRAINT email_sequences_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_subscribers email_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_subscribers
    ADD CONSTRAINT email_subscribers_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_subscribers email_subscribers_tenant_id_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_subscribers
    ADD CONSTRAINT email_subscribers_tenant_id_email_key UNIQUE (tenant_id, email);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_subscribers email_subscribers_unsubscribe_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_subscribers
    ADD CONSTRAINT email_subscribers_unsubscribe_token_key UNIQUE (unsubscribe_token);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_templates email_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_templates
    ADD CONSTRAINT email_templates_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_unsubscribes email_unsubscribes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_unsubscribes
    ADD CONSTRAINT email_unsubscribes_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_unsubscribes email_unsubscribes_tenant_id_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_unsubscribes
    ADD CONSTRAINT email_unsubscribes_tenant_id_email_key UNIQUE (tenant_id, email);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_accounts financial_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_accounts
    ADD CONSTRAINT financial_accounts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_categories financial_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_categories
    ADD CONSTRAINT financial_categories_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_entries financial_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_entries
    ADD CONSTRAINT financial_entries_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_campaigns franchise_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_campaigns
    ADD CONSTRAINT franchise_campaigns_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_distribution_log franchise_distribution_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_distribution_log
    ADD CONSTRAINT franchise_distribution_log_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_members franchise_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_members
    ADD CONSTRAINT franchise_members_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_accounts google_ads_accounts_account_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_accounts
    ADD CONSTRAINT google_ads_accounts_account_id_key UNIQUE (account_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_accounts google_ads_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_accounts
    ADD CONSTRAINT google_ads_accounts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_campaign_data google_ads_campaign_data_account_id_organization_id_campaig_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_campaign_data
    ADD CONSTRAINT google_ads_campaign_data_account_id_organization_id_campaig_key UNIQUE (account_id, organization_id, campaign_id, date);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_campaign_data google_ads_campaign_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_campaign_data
    ADD CONSTRAINT google_ads_campaign_data_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_daily_data google_ads_daily_data_account_id_organization_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_daily_data
    ADD CONSTRAINT google_ads_daily_data_account_id_organization_id_date_key UNIQUE (account_id, organization_id, date);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_daily_data google_ads_daily_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_daily_data
    ADD CONSTRAINT google_ads_daily_data_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_business_accounts ig_accounts_business_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_business_accounts
    ADD CONSTRAINT ig_accounts_business_id_key UNIQUE (instagram_business_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations ig_conversations_account_thread_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT ig_conversations_account_thread_key UNIQUE (account_id, thread_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_engagement ig_engagement_lead_account_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_engagement
    ADD CONSTRAINT ig_engagement_lead_account_key UNIQUE (lead_id, account_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_messages ig_messages_instagram_message_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_messages
    ADD CONSTRAINT ig_messages_instagram_message_id_key UNIQUE (instagram_message_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: import_jobs import_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.import_jobs
    ADD CONSTRAINT import_jobs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_business_accounts instagram_business_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_business_accounts
    ADD CONSTRAINT instagram_business_accounts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_comments instagram_comments_comment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_comments
    ADD CONSTRAINT instagram_comments_comment_id_key UNIQUE (comment_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_comments instagram_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_comments
    ADD CONSTRAINT instagram_comments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_engagement instagram_engagement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_engagement
    ADD CONSTRAINT instagram_engagement_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_feed_posts instagram_feed_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_feed_posts
    ADD CONSTRAINT instagram_feed_posts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_feed_posts instagram_feed_posts_tenant_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_feed_posts
    ADD CONSTRAINT instagram_feed_posts_tenant_id_post_id_key UNIQUE (tenant_id, post_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_messages instagram_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_messages
    ADD CONSTRAINT instagram_messages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_profiles instagram_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_profiles
    ADD CONSTRAINT instagram_profiles_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_profiles instagram_profiles_tenant_id_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_profiles
    ADD CONSTRAINT instagram_profiles_tenant_id_username_key UNIQUE (tenant_id, username);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_stories instagram_stories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_stories
    ADD CONSTRAINT instagram_stories_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_stories instagram_stories_tenant_id_story_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_stories
    ADD CONSTRAINT instagram_stories_tenant_id_story_id_key UNIQUE (tenant_id, story_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: integration_settings integration_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.integration_settings
    ADD CONSTRAINT integration_settings_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: integration_settings integration_settings_provider_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.integration_settings
    ADD CONSTRAINT integration_settings_provider_key UNIQUE (provider);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_conversions lead_conversions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_conversions
    ADD CONSTRAINT lead_conversions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_diagnostics_v2 lead_diagnostics_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_diagnostics_v2
    ADD CONSTRAINT lead_diagnostics_v2_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_config lead_distribution_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_config
    ADD CONSTRAINT lead_distribution_config_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_log lead_distribution_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_log
    ADD CONSTRAINT lead_distribution_log_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_members lead_distribution_members_config_id_team_member_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_members
    ADD CONSTRAINT lead_distribution_members_config_id_team_member_id_key UNIQUE (config_id, team_member_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_members lead_distribution_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_members
    ADD CONSTRAINT lead_distribution_members_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_interactions lead_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_interactions
    ADD CONSTRAINT lead_interactions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: llm_provider_configs llm_provider_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.llm_provider_configs
    ADD CONSTRAINT llm_provider_configs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: llm_provider_configs llm_provider_configs_tenant_id_provider_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.llm_provider_configs
    ADD CONSTRAINT llm_provider_configs_tenant_id_provider_key UNIQUE (tenant_id, provider);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: marketing_forms marketing_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.marketing_forms
    ADD CONSTRAINT marketing_forms_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_calls_history member_calls_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_calls_history
    ADD CONSTRAINT member_calls_history_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_daily_activity member_daily_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_daily_activity
    ADD CONSTRAINT member_daily_activity_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_engagement_snapshots member_engagement_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_engagement_snapshots
    ADD CONSTRAINT member_engagement_snapshots_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_lessons_progress member_lessons_progress_email_lesson_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_lessons_progress
    ADD CONSTRAINT member_lessons_progress_email_lesson_key UNIQUE (member_email, lesson_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_lessons_progress member_lessons_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_lessons_progress
    ADD CONSTRAINT member_lessons_progress_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_accounts meta_ads_accounts_account_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_accounts
    ADD CONSTRAINT meta_ads_accounts_account_id_key UNIQUE (account_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_accounts meta_ads_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_accounts
    ADD CONSTRAINT meta_ads_accounts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_ad_data meta_ads_ad_data_account_id_ad_id_date_aggregation_level_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_ad_data
    ADD CONSTRAINT meta_ads_ad_data_account_id_ad_id_date_aggregation_level_key UNIQUE (account_id, ad_id, date, aggregation_level);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_ad_data meta_ads_ad_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_ad_data
    ADD CONSTRAINT meta_ads_ad_data_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_conversions meta_ads_conversions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_conversions
    ADD CONSTRAINT meta_ads_conversions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_daily_data meta_ads_daily_data_account_id_date_aggregation_level_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_daily_data
    ADD CONSTRAINT meta_ads_daily_data_account_id_date_aggregation_level_key UNIQUE (account_id, date, aggregation_level);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_daily_data meta_ads_daily_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_daily_data
    ADD CONSTRAINT meta_ads_daily_data_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_sync_log meta_ads_sync_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_sync_log
    ADD CONSTRAINT meta_ads_sync_log_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_lead_ads_forms meta_lead_ads_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_lead_ads_forms
    ADD CONSTRAINT meta_lead_ads_forms_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_lead_ads_forms meta_lead_ads_forms_tenant_id_form_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_lead_ads_forms
    ADD CONSTRAINT meta_lead_ads_forms_tenant_id_form_id_key UNIQUE (tenant_id, form_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_lead_ads_logs meta_lead_ads_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_lead_ads_logs
    ADD CONSTRAINT meta_lead_ads_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_lead_ads_pages meta_lead_ads_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_lead_ads_pages
    ADD CONSTRAINT meta_lead_ads_pages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_lead_ads_pages meta_lead_ads_pages_tenant_id_page_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_lead_ads_pages
    ADD CONSTRAINT meta_lead_ads_pages_tenant_id_page_id_key UNIQUE (tenant_id, page_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: noshow_followups noshow_followups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.noshow_followups
    ADD CONSTRAINT noshow_followups_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_logs notification_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_logs
    ADD CONSTRAINT notification_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_rules notification_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_rules
    ADD CONSTRAINT notification_rules_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: nps_survey_schedule nps_survey_schedule_organization_id_product_id_milestone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.nps_survey_schedule
    ADD CONSTRAINT nps_survey_schedule_organization_id_product_id_milestone_key UNIQUE (organization_id, product_id, milestone);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: nps_survey_schedule nps_survey_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.nps_survey_schedule
    ADD CONSTRAINT nps_survey_schedule_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboarding_stages onboarding_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboarding_stages
    ADD CONSTRAINT onboarding_stages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_form_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_form_token_key UNIQUE (form_token);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_org_product_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_org_product_key UNIQUE (organization_id, product_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_members organization_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_products organization_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_products
    ADD CONSTRAINT organization_products_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: pain_registrations pain_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.pain_registrations
    ADD CONSTRAINT pain_registrations_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateway_fees payment_gateway_fees_gateway_id_billing_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateway_fees
    ADD CONSTRAINT payment_gateway_fees_gateway_id_billing_type_key UNIQUE (gateway_id, billing_type);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateway_fees payment_gateway_fees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateway_fees
    ADD CONSTRAINT payment_gateway_fees_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateways payment_gateways_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateways
    ADD CONSTRAINT payment_gateways_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateways payment_gateways_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateways
    ADD CONSTRAINT payment_gateways_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: products products_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: profiles profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_buscas prospeccao_buscas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_buscas
    ADD CONSTRAINT prospeccao_buscas_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_diagnosticos prospeccao_diagnosticos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_diagnosticos
    ADD CONSTRAINT prospeccao_diagnosticos_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_leads_descobertos prospeccao_leads_descobertos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_leads_descobertos
    ADD CONSTRAINT prospeccao_leads_descobertos_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_prompts_config prospeccao_prompts_config_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_prompts_config
    ADD CONSTRAINT prospeccao_prompts_config_key_key UNIQUE (key);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_prompts_config prospeccao_prompts_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_prompts_config
    ADD CONSTRAINT prospeccao_prompts_config_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_templates_nicho prospeccao_templates_nicho_nicho_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_templates_nicho
    ADD CONSTRAINT prospeccao_templates_nicho_nicho_key UNIQUE (nicho);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_templates_nicho prospeccao_templates_nicho_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_templates_nicho
    ADD CONSTRAINT prospeccao_templates_nicho_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_uso_api prospeccao_uso_api_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_uso_api
    ADD CONSTRAINT prospeccao_uso_api_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: receive_lead_logs receive_lead_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.receive_lead_logs
    ADD CONSTRAINT receive_lead_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_alerts sales_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_alerts
    ADD CONSTRAINT sales_alerts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_automation_rules sales_automation_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_automation_rules
    ADD CONSTRAINT sales_automation_rules_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_materials sales_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_materials
    ADD CONSTRAINT sales_materials_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_notes sales_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_notes
    ADD CONSTRAINT sales_notes_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_stages sales_pipeline_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_stages
    ADD CONSTRAINT sales_pipeline_stages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_transitions sales_pipeline_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_transitions
    ADD CONSTRAINT sales_pipeline_transitions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipelines sales_pipelines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipelines
    ADD CONSTRAINT sales_pipelines_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_playbook sales_playbook_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_playbook
    ADD CONSTRAINT sales_playbook_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: scheduled_messages scheduled_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.scheduled_messages
    ADD CONSTRAINT scheduled_messages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_alerts social_seller_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_alerts
    ADD CONSTRAINT social_seller_alerts_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_rules social_seller_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_rules
    ADD CONSTRAINT social_seller_rules_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_stages social_seller_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_stages
    ADD CONSTRAINT social_seller_stages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_stages social_seller_stages_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_stages
    ADD CONSTRAINT social_seller_stages_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_automations social_selling_automations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_automations
    ADD CONSTRAINT social_selling_automations_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_enrollments social_selling_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_enrollments
    ADD CONSTRAINT social_selling_enrollments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_interactions social_selling_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_interactions
    ADD CONSTRAINT social_selling_interactions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_known_followers social_selling_known_followers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_known_followers
    ADD CONSTRAINT social_selling_known_followers_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_qualification_log social_selling_qualification_l_instagram_username_tenant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_qualification_log
    ADD CONSTRAINT social_selling_qualification_l_instagram_username_tenant_id_key UNIQUE (instagram_username, tenant_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_qualification_log social_selling_qualification_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_qualification_log
    ADD CONSTRAINT social_selling_qualification_log_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: team_members team_members_email_tenant_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_email_tenant_key UNIQUE (email, tenant_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_config tenant_config_api_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_config
    ADD CONSTRAINT tenant_config_api_key_key UNIQUE (api_key);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_config tenant_config_custom_domain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_config
    ADD CONSTRAINT tenant_config_custom_domain_key UNIQUE (custom_domain);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_config tenant_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_config
    ADD CONSTRAINT tenant_config_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_config tenant_config_tenant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_config
    ADD CONSTRAINT tenant_config_tenant_id_key UNIQUE (tenant_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_sales_config tenant_sales_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_sales_config
    ADD CONSTRAINT tenant_sales_config_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenants tenants_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: twilio_call_logs twilio_call_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.twilio_call_logs
    ADD CONSTRAINT twilio_call_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_diagnostics_v2 unique_lead_event; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_diagnostics_v2
    ADD CONSTRAINT unique_lead_event UNIQUE (lead_id, event_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_sales_config unique_tenant_sales_config; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_sales_config
    ADD CONSTRAINT unique_tenant_sales_config UNIQUE (tenant_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_interactions uq_ssi_lead_action_target; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_interactions
    ADD CONSTRAINT uq_ssi_lead_action_target UNIQUE NULLS NOT DISTINCT (lead_id, action_type, instagram_target);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_communities wa_communities_community_jid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_communities
    ADD CONSTRAINT wa_communities_community_jid_key UNIQUE (community_jid);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_communities wa_communities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_communities
    ADD CONSTRAINT wa_communities_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaign_items wa_community_campaign_items_campaign_id_community_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaign_items
    ADD CONSTRAINT wa_community_campaign_items_campaign_id_community_id_key UNIQUE (campaign_id, community_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaign_items wa_community_campaign_items_campaign_id_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaign_items
    ADD CONSTRAINT wa_community_campaign_items_campaign_id_position_key UNIQUE (campaign_id, "position");
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaign_items wa_community_campaign_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaign_items
    ADD CONSTRAINT wa_community_campaign_items_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaigns wa_community_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaigns
    ADD CONSTRAINT wa_community_campaigns_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaigns wa_community_campaigns_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaigns
    ADD CONSTRAINT wa_community_campaigns_slug_key UNIQUE (slug);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_groups wa_community_groups_group_jid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_groups
    ADD CONSTRAINT wa_community_groups_group_jid_key UNIQUE (group_jid);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_groups wa_community_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_groups
    ADD CONSTRAINT wa_community_groups_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_message_sequences wa_message_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_message_sequences
    ADD CONSTRAINT wa_message_sequences_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_sequence_enrollments wa_sequence_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_sequence_enrollments
    ADD CONSTRAINT wa_sequence_enrollments_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_sequence_steps wa_sequence_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_sequence_steps
    ADD CONSTRAINT wa_sequence_steps_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_sequence_steps wa_sequence_steps_sequence_id_step_order_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_sequence_steps
    ADD CONSTRAINT wa_sequence_steps_sequence_id_step_order_key UNIQUE (sequence_id, step_order);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wavoip_devices wavoip_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wavoip_devices
    ADD CONSTRAINT wavoip_devices_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_cloud_templates whatsapp_cloud_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_cloud_templates
    ADD CONSTRAINT whatsapp_cloud_templates_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_group_members whatsapp_group_members_group_id_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_group_members
    ADD CONSTRAINT whatsapp_group_members_group_id_phone_key UNIQUE (group_id, phone);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_group_members whatsapp_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_group_members
    ADD CONSTRAINT whatsapp_group_members_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_groups whatsapp_groups_instance_id_group_jid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_groups
    ADD CONSTRAINT whatsapp_groups_instance_id_group_jid_key UNIQUE (instance_id, group_jid);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_groups whatsapp_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_groups
    ADD CONSTRAINT whatsapp_groups_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_instances whatsapp_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_instances
    ADD CONSTRAINT whatsapp_instances_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_messages whatsapp_messages_instance_id_message_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_instance_id_message_id_key UNIQUE (instance_id, message_id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_messages whatsapp_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_config whatsapp_task_bot_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_config
    ADD CONSTRAINT whatsapp_task_bot_config_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_logs whatsapp_task_bot_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_logs
    ADD CONSTRAINT whatsapp_task_bot_logs_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_template_tags whatsapp_template_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_template_tags
    ADD CONSTRAINT whatsapp_template_tags_pkey PRIMARY KEY (id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_template_tags whatsapp_template_tags_template_id_tag_key; Type: CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_template_tags
    ADD CONSTRAINT whatsapp_template_tags_template_id_tag_key UNIQUE (template_id, tag);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_handled_group_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX IF NOT EXISTS cs_conversation_handled_group_id_unique ON public.cs_conversation_handled USING btree (group_id) WHERE (group_id IS NOT NULL);


--
-- Name: cs_conversation_handled_lead_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX IF NOT EXISTS cs_conversation_handled_lead_id_unique ON public.cs_conversation_handled USING btree (lead_id) WHERE (lead_id IS NOT NULL);


--
-- Name: email_events_unique_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX IF NOT EXISTS email_events_unique_event ON public.email_events USING btree (send_id, event_type, ((payload ->> 'created_at'::text)));


--
-- Name: idx_activities_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_activities_lead ON public.company_activities USING btree (lead_id);


--
-- Name: idx_activities_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_activities_org ON public.company_activities USING btree (organization_id);


--
-- Name: idx_activities_responsavel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_activities_responsavel ON public.company_activities USING btree (responsavel_id);


--
-- Name: idx_activities_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_activities_scheduled ON public.company_activities USING btree (scheduled_at);


--
-- Name: idx_activities_team; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_activities_team ON public.company_activities USING btree (team);


--
-- Name: idx_ai_agent_cadence_enrollments_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_cadence_enrollments_tenant ON public.ai_agent_cadence_enrollments USING btree (tenant_id);


--
-- Name: idx_ai_agent_chat_events_lead_id_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_chat_events_lead_id_created ON public.ai_agent_chat_events USING btree (lead_id, created_at DESC);


--
-- Name: idx_ai_agent_conversations_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_conversations_lead ON public.ai_agent_conversations USING btree (lead_id);


--
-- Name: idx_ai_agent_conversations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_conversations_status ON public.ai_agent_conversations USING btree (status);


--
-- Name: idx_ai_agent_conversations_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_conversations_tenant_id ON public.ai_agent_conversations USING btree (tenant_id);


--
-- Name: idx_ai_agent_logs_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_logs_conversation ON public.ai_agent_logs USING btree (conversation_id);


--
-- Name: idx_ai_agent_logs_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_logs_tenant_id ON public.ai_agent_logs USING btree (tenant_id);


--
-- Name: idx_ai_agent_message_queue_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_message_queue_tenant_id ON public.ai_agent_message_queue USING btree (tenant_id);


--
-- Name: idx_ai_agent_queue_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_queue_scheduled ON public.ai_agent_message_queue USING btree (scheduled_for);


--
-- Name: idx_ai_agent_queue_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_queue_status ON public.ai_agent_message_queue USING btree (status);


--
-- Name: idx_ai_agent_scheduled_followups_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_scheduled_followups_tenant ON public.ai_agent_scheduled_followups USING btree (tenant_id);


--
-- Name: idx_ai_agent_send_counts_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_send_counts_tenant ON public.ai_agent_send_counts USING btree (tenant_id);


--
-- Name: idx_ai_agent_tools_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_agent_tools_tenant_id ON public.ai_agent_tools USING btree (tenant_id);


--
-- Name: idx_ai_sales_agents_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ai_sales_agents_tenant_id ON public.ai_sales_agents USING btree (tenant_id);


--
-- Name: idx_analysis_templates_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_analysis_templates_tenant_id ON public.analysis_templates USING btree (tenant_id);


--
-- Name: idx_asaas_customers_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_asaas_customers_tenant_id ON public.asaas_customers USING btree (tenant_id);


--
-- Name: idx_asaas_webhooks_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_asaas_webhooks_tenant_id ON public.asaas_webhooks USING btree (tenant_id);


--
-- Name: idx_automation_runs_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_automation_runs_scheduled ON public.email_automation_runs USING btree (scheduled_next_at) WHERE (status = 'active'::text);


--
-- Name: idx_automation_runs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_automation_runs_tenant ON public.email_automation_runs USING btree (tenant_id);


--
-- Name: idx_cadence_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cadence_agent ON public.ai_agent_cadence_enrollments USING btree (agent_id);


--
-- Name: idx_cadence_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cadence_lead ON public.ai_agent_cadence_enrollments USING btree (lead_id);


--
-- Name: idx_cadence_next; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cadence_next ON public.ai_agent_cadence_enrollments USING btree (next_action_at) WHERE (status = 'active'::text);


--
-- Name: idx_calendar_events_google; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_calendar_events_google ON public.calendar_events USING btree (google_event_id);


--
-- Name: idx_calendar_events_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_calendar_events_member ON public.calendar_events USING btree (team_member_id);


--
-- Name: idx_calendar_events_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_calendar_events_tenant_id ON public.calendar_events USING btree (tenant_id);


--
-- Name: idx_call_history_has_transcriptions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_has_transcriptions ON public.call_history USING btree ((((transcriptions IS NOT NULL) AND (transcriptions <> '[]'::jsonb))));


--
-- Name: idx_call_history_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_lead ON public.call_history USING btree (lead_id);


--
-- Name: idx_call_history_lead_direction_started; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_lead_direction_started ON public.call_history USING btree (lead_id, started_at) WHERE (lead_id IS NOT NULL);


--
-- Name: idx_call_history_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_member ON public.call_history USING btree (team_member_id);


--
-- Name: idx_call_history_peer_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_peer_phone ON public.call_history USING btree (peer_phone);


--
-- Name: idx_call_history_started; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_started ON public.call_history USING btree (started_at);


--
-- Name: idx_call_history_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_started_at ON public.call_history USING btree (started_at DESC);


--
-- Name: idx_call_history_team_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_team_member ON public.call_history USING btree (team_member_id);


--
-- Name: idx_call_history_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_tenant_created ON public.call_history USING btree (tenant_id, created_at DESC);


--
-- Name: idx_call_history_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_tenant_id ON public.call_history USING btree (tenant_id);


--
-- Name: idx_call_history_transcriptions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_transcriptions ON public.call_history USING gin (transcriptions);


--
-- Name: idx_call_history_wavoip_call; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_wavoip_call ON public.call_history USING btree (wavoip_call_id);


--
-- Name: idx_call_history_wavoip_device; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_call_history_wavoip_device ON public.call_history USING btree (wavoip_device_id);


--
-- Name: idx_campaign_instance_stats_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaign_instance_stats_tenant ON public.campaign_instance_stats USING btree (tenant_id);


--
-- Name: idx_campaign_leads_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaign_leads_tenant ON public.campaign_leads USING btree (tenant_id);


--
-- Name: idx_campaign_templates_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaign_templates_tenant ON public.campaign_templates USING btree (tenant_id);


--
-- Name: idx_campaigns_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaigns_provider ON public.campaigns USING btree (tenant_id, provider);


--
-- Name: idx_campaigns_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaigns_scheduled ON public.campaigns USING btree (scheduled_at) WHERE (status = 'scheduled'::text);


--
-- Name: idx_campaigns_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaigns_status ON public.campaigns USING btree (status);


--
-- Name: idx_campaigns_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_campaigns_tenant ON public.campaigns USING btree (tenant_id);


--
-- Name: idx_chat_configs_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_configs_slug ON public.chat_configs USING btree (slug);


--
-- Name: idx_chat_configs_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_configs_tenant_id ON public.chat_configs USING btree (tenant_id);


--
-- Name: idx_chat_messages_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON public.chat_messages USING btree (session_id);


--
-- Name: idx_chat_messages_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_messages_tenant_id ON public.chat_messages USING btree (tenant_id);


--
-- Name: idx_chat_sessions_config_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_sessions_config_id ON public.chat_sessions USING btree (config_id);


--
-- Name: idx_chat_sessions_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_sessions_created_by ON public.chat_sessions USING btree (created_by);


--
-- Name: idx_chat_sessions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_chat_sessions_tenant_id ON public.chat_sessions USING btree (tenant_id);


--
-- Name: idx_cl_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cl_campaign ON public.campaign_leads USING btree (campaign_id);


--
-- Name: idx_cl_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cl_lead ON public.campaign_leads USING btree (lead_id);


--
-- Name: idx_cl_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cl_pending ON public.campaign_leads USING btree (campaign_id) WHERE (status = 'pending'::text);


--
-- Name: idx_cl_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cl_status ON public.campaign_leads USING btree (campaign_id, status);


--
-- Name: idx_client_onboarding_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_client_onboarding_lead ON public.client_onboarding_data USING btree (tenant_id, lead_id);


--
-- Name: idx_client_onboarding_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_client_onboarding_org ON public.client_onboarding_data USING btree (tenant_id, organization_id);


--
-- Name: idx_coach_playbooks_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_coach_playbooks_tenant_id ON public.coach_playbooks USING btree (tenant_id);


--
-- Name: idx_coach_sessions_call; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_coach_sessions_call ON public.coach_sessions USING btree (call_id);


--
-- Name: idx_coach_sessions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_coach_sessions_tenant_id ON public.coach_sessions USING btree (tenant_id);


--
-- Name: idx_commission_rules_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_commission_rules_tenant_id ON public.commission_rules USING btree (tenant_id);


--
-- Name: idx_commissions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_commissions_tenant_id ON public.commissions USING btree (tenant_id);


--
-- Name: idx_company_activities_external_call_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_company_activities_external_call_id ON public.company_activities USING btree (external_call_id) WHERE (external_call_id IS NOT NULL);


--
-- Name: idx_company_activities_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_company_activities_tenant_created ON public.company_activities USING btree (tenant_id, created_at DESC);


--
-- Name: idx_company_activities_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_company_activities_tenant_id ON public.company_activities USING btree (tenant_id);


--
-- Name: idx_connections_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_connections_event ON public.cs_event_connections USING btree (event_id);


--
-- Name: idx_connections_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_connections_requester ON public.cs_event_connections USING btree (requester_rsvp_id);


--
-- Name: idx_connections_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_connections_target ON public.cs_event_connections USING btree (target_rsvp_id);


--
-- Name: idx_cs_conversation_handled_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_conversation_handled_tenant_id ON public.cs_conversation_handled USING btree (tenant_id);


--
-- Name: idx_cs_conversation_notes_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_conversation_notes_lead ON public.cs_conversation_notes USING btree (lead_id);


--
-- Name: idx_cs_conversation_notes_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_conversation_notes_tenant_id ON public.cs_conversation_notes USING btree (tenant_id);


--
-- Name: idx_cs_engagement_metrics_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_engagement_metrics_tenant_id ON public.cs_engagement_metrics USING btree (tenant_id);


--
-- Name: idx_cs_engagement_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_engagement_org ON public.cs_engagement_metrics USING btree (organization_id);


--
-- Name: idx_cs_event_rsvps_checked_in; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_event_rsvps_checked_in ON public.cs_event_rsvps USING btree (checked_in_at);


--
-- Name: idx_cs_event_rsvps_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_event_rsvps_email ON public.cs_event_rsvps USING btree (guest_email);


--
-- Name: idx_cs_event_rsvps_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_event_rsvps_event ON public.cs_event_rsvps USING btree (event_id);


--
-- Name: idx_cs_event_rsvps_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_event_rsvps_event_id ON public.cs_event_rsvps USING btree (event_id);


--
-- Name: idx_cs_event_rsvps_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_event_rsvps_status ON public.cs_event_rsvps USING btree (rsvp_status);


--
-- Name: idx_cs_event_rsvps_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_event_rsvps_tenant_id ON public.cs_event_rsvps USING btree (tenant_id);


--
-- Name: idx_cs_events_rsvp_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_events_rsvp_token ON public.cs_events USING btree (rsvp_token);


--
-- Name: idx_cs_events_start_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_events_start_date ON public.cs_events USING btree (start_date);


--
-- Name: idx_cs_events_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_events_status ON public.cs_events USING btree (status);


--
-- Name: idx_cs_events_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_events_tenant_id ON public.cs_events USING btree (tenant_id);


--
-- Name: idx_cs_health_current_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_health_current_org ON public.cs_health_current USING btree (organization_id);


--
-- Name: idx_cs_health_current_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_health_current_tenant_id ON public.cs_health_current USING btree (tenant_id);


--
-- Name: idx_cs_health_history_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_health_history_org ON public.cs_health_scores_history USING btree (organization_id);


--
-- Name: idx_cs_health_scores_history_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_health_scores_history_tenant_id ON public.cs_health_scores_history USING btree (tenant_id);


--
-- Name: idx_cs_inbox_metrics_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_inbox_metrics_key ON public.cs_inbox_metrics USING btree (conversation_key);


--
-- Name: idx_cs_inbox_metrics_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_inbox_metrics_lead ON public.cs_inbox_metrics USING btree (lead_id);


--
-- Name: idx_cs_inbox_metrics_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_inbox_metrics_tenant_id ON public.cs_inbox_metrics USING btree (tenant_id);


--
-- Name: idx_cs_interactions_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_interactions_org ON public.cs_interactions USING btree (organization_id);


--
-- Name: idx_cs_interactions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_interactions_tenant_id ON public.cs_interactions USING btree (tenant_id);


--
-- Name: idx_cs_objectives_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_objectives_org ON public.cs_objectives USING btree (organization_id);


--
-- Name: idx_cs_objectives_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_objectives_tenant_id ON public.cs_objectives USING btree (tenant_id);


--
-- Name: idx_cs_response_templates_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_response_templates_tenant_id ON public.cs_response_templates USING btree (tenant_id);


--
-- Name: idx_cs_success_metrics_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_success_metrics_tenant_id ON public.cs_success_metrics USING btree (tenant_id);


--
-- Name: idx_cs_success_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_success_org ON public.cs_success_metrics USING btree (organization_id);


--
-- Name: idx_cs_touchpoints_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_touchpoints_org ON public.cs_touchpoints USING btree (organization_id);


--
-- Name: idx_cs_touchpoints_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_cs_touchpoints_tenant_id ON public.cs_touchpoints USING btree (tenant_id);


--
-- Name: idx_deal_contacts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_deal_contacts_tenant_id ON public.deal_contacts USING btree (tenant_id);


--
-- Name: idx_deal_loss_reasons_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_deal_loss_reasons_tenant_id ON public.deal_loss_reasons USING btree (tenant_id);


--
-- Name: idx_deal_payment_installments_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_deal_payment_installments_tenant_id ON public.deal_payment_installments USING btree (tenant_id);


--
-- Name: idx_deal_payments_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_deal_payments_tenant_id ON public.deal_payments USING btree (tenant_id);


--
-- Name: idx_deals_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_deals_tenant_created ON public.deals USING btree (tenant_id, created_at DESC);


--
-- Name: idx_deals_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_deals_tenant_id ON public.deals USING btree (tenant_id);


--
-- Name: idx_distribution_config_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX IF NOT EXISTS idx_distribution_config_api_key ON public.lead_distribution_config USING btree (api_key);


--
-- Name: idx_distribution_log_config; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_distribution_log_config ON public.lead_distribution_log USING btree (config_id, created_at DESC);


--
-- Name: idx_distribution_log_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_distribution_log_member ON public.lead_distribution_log USING btree (team_member_id, created_at DESC);


--
-- Name: idx_distribution_members_config; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_distribution_members_config ON public.lead_distribution_members USING btree (config_id);


--
-- Name: idx_email_automations_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_automations_tenant ON public.email_automations USING btree (tenant_id);


--
-- Name: idx_email_campaign_leads_brevo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaign_leads_brevo ON public.email_campaign_leads USING btree (brevo_message_id);


--
-- Name: idx_email_campaign_leads_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaign_leads_campaign ON public.email_campaign_leads USING btree (campaign_id);


--
-- Name: idx_email_campaign_leads_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaign_leads_lead ON public.email_campaign_leads USING btree (lead_id);


--
-- Name: idx_email_campaign_leads_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaign_leads_status ON public.email_campaign_leads USING btree (status);


--
-- Name: idx_email_campaign_leads_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaign_leads_tenant ON public.email_campaign_leads USING btree (tenant_id);


--
-- Name: idx_email_campaigns_automation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaigns_automation ON public.email_campaigns USING btree (automation_id) WHERE (automation_id IS NOT NULL);


--
-- Name: idx_email_campaigns_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaigns_source ON public.email_campaigns USING btree (source_type);


--
-- Name: idx_email_campaigns_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaigns_status ON public.email_campaigns USING btree (status);


--
-- Name: idx_email_campaigns_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_campaigns_tenant ON public.email_campaigns USING btree (tenant_id);


--
-- Name: idx_email_events_send; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_events_send ON public.email_events USING btree (send_id);


--
-- Name: idx_email_events_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_events_tenant ON public.email_events USING btree (tenant_id);


--
-- Name: idx_email_lists_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_lists_tenant ON public.email_lists USING btree (tenant_id);


--
-- Name: idx_email_runs_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_runs_lead ON public.email_automation_runs USING btree (lead_id);


--
-- Name: idx_email_runs_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_runs_rule ON public.email_automation_runs USING btree (rule_id);


--
-- Name: idx_email_runs_rule_lead_sent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_runs_rule_lead_sent ON public.email_automation_runs USING btree (rule_id, lead_id) WHERE (status = 'sent'::text);


--
-- Name: idx_email_sends_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sends_campaign ON public.email_sends USING btree (campaign_id);


--
-- Name: idx_email_sends_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sends_lead ON public.email_sends USING btree (lead_id);


--
-- Name: idx_email_sends_resend; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sends_resend ON public.email_sends USING btree (resend_id);


--
-- Name: idx_email_sends_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sends_tenant ON public.email_sends USING btree (tenant_id);


--
-- Name: idx_email_sequence_enrollments_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_enrollments_lead ON public.email_sequence_enrollments USING btree (lead_id);


--
-- Name: idx_email_sequence_enrollments_next; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_enrollments_next ON public.email_sequence_enrollments USING btree (next_step_at) WHERE (status = 'active'::text);


--
-- Name: idx_email_sequence_enrollments_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_enrollments_sequence ON public.email_sequence_enrollments USING btree (sequence_id);


--
-- Name: idx_email_sequence_enrollments_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_enrollments_tenant ON public.email_sequence_enrollments USING btree (tenant_id);


--
-- Name: idx_email_sequence_logs_brevo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_logs_brevo ON public.email_sequence_logs USING btree (brevo_message_id);


--
-- Name: idx_email_sequence_logs_enrollment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_logs_enrollment ON public.email_sequence_logs USING btree (enrollment_id);


--
-- Name: idx_email_sequence_logs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_logs_tenant ON public.email_sequence_logs USING btree (tenant_id);


--
-- Name: idx_email_sequence_steps_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_steps_sequence ON public.email_sequence_steps USING btree (sequence_id);


--
-- Name: idx_email_sequence_steps_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequence_steps_tenant ON public.email_sequence_steps USING btree (tenant_id);


--
-- Name: idx_email_sequences_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_sequences_tenant ON public.email_sequences USING btree (tenant_id);


--
-- Name: idx_email_subscribers_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_subscribers_lead ON public.email_subscribers USING btree (lead_id);


--
-- Name: idx_email_subscribers_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_subscribers_tenant ON public.email_subscribers USING btree (tenant_id);


--
-- Name: idx_email_templates_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_templates_name ON public.email_templates USING btree (name);


--
-- Name: idx_email_templates_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_templates_tenant ON public.email_templates USING btree (tenant_id);


--
-- Name: idx_email_unsubscribes_tenant_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_email_unsubscribes_tenant_email ON public.email_unsubscribes USING btree (tenant_id, email);


--
-- Name: idx_feed_likes_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_feed_likes_post ON public.cs_event_feed_likes USING btree (post_id);


--
-- Name: idx_feed_likes_rsvp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_feed_likes_rsvp ON public.cs_event_feed_likes USING btree (rsvp_id);


--
-- Name: idx_feed_posts_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_feed_posts_event ON public.cs_event_feed_posts USING btree (event_id);


--
-- Name: idx_feed_posts_pinned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_feed_posts_pinned ON public.cs_event_feed_posts USING btree (event_id, is_pinned DESC, created_at DESC);


--
-- Name: idx_financial_accounts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_accounts_tenant_id ON public.financial_accounts USING btree (tenant_id);


--
-- Name: idx_financial_categories_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_categories_tenant_id ON public.financial_categories USING btree (tenant_id);


--
-- Name: idx_financial_entries_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_entries_account ON public.financial_entries USING btree (financial_account_id);


--
-- Name: idx_financial_entries_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_entries_category ON public.financial_entries USING btree (category_id);


--
-- Name: idx_financial_entries_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_entries_date ON public.financial_entries USING btree (entry_date);


--
-- Name: idx_financial_entries_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_entries_tenant_id ON public.financial_entries USING btree (tenant_id);


--
-- Name: idx_financial_entries_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_financial_entries_type ON public.financial_entries USING btree (type);


--
-- Name: idx_followups_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_followups_lead ON public.ai_agent_scheduled_followups USING btree (lead_id);


--
-- Name: idx_followups_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_followups_pending ON public.ai_agent_scheduled_followups USING btree (status, scheduled_at) WHERE (status = 'pending'::text);


--
-- Name: idx_franchise_campaigns_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_franchise_campaigns_api_key ON public.franchise_campaigns USING btree (api_key);


--
-- Name: idx_franchise_campaigns_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_franchise_campaigns_tenant ON public.franchise_campaigns USING btree (tenant_id);


--
-- Name: idx_franchise_distribution_log_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_franchise_distribution_log_campaign ON public.franchise_distribution_log USING btree (campaign_id);


--
-- Name: idx_franchise_distribution_log_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_franchise_distribution_log_tenant ON public.franchise_distribution_log USING btree (tenant_id);


--
-- Name: idx_franchise_members_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_franchise_members_campaign ON public.franchise_members USING btree (campaign_id);


--
-- Name: idx_franchise_members_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_franchise_members_tenant ON public.franchise_members USING btree (tenant_id);


--
-- Name: idx_google_ads_accounts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_accounts_tenant_id ON public.google_ads_accounts USING btree (tenant_id);


--
-- Name: idx_google_ads_campaign_data_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_campaign_data_campaign ON public.google_ads_campaign_data USING btree (campaign_id);


--
-- Name: idx_google_ads_campaign_data_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_campaign_data_date ON public.google_ads_campaign_data USING btree (date);


--
-- Name: idx_google_ads_campaign_data_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_campaign_data_org ON public.google_ads_campaign_data USING btree (organization_id);


--
-- Name: idx_google_ads_campaign_data_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_campaign_data_tenant_id ON public.google_ads_campaign_data USING btree (tenant_id);


--
-- Name: idx_google_ads_daily_data_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_daily_data_date ON public.google_ads_daily_data USING btree (date);


--
-- Name: idx_google_ads_daily_data_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_daily_data_org ON public.google_ads_daily_data USING btree (organization_id);


--
-- Name: idx_google_ads_daily_data_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_daily_data_tenant_id ON public.google_ads_daily_data USING btree (tenant_id);


--
-- Name: idx_google_ads_daily_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_google_ads_daily_org_date ON public.google_ads_daily_data USING btree (organization_id, date);


--
-- Name: idx_ig_comments_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_comments_account ON public.instagram_comments USING btree (account_id);


--
-- Name: idx_ig_comments_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_comments_post ON public.instagram_comments USING btree (post_id);


--
-- Name: idx_ig_conversations_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_conversations_account ON public.instagram_conversations USING btree (account_id);


--
-- Name: idx_ig_conversations_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_conversations_lead ON public.instagram_conversations USING btree (lead_id);


--
-- Name: idx_ig_conversations_thread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_conversations_thread ON public.instagram_conversations USING btree (thread_id);


--
-- Name: idx_ig_engagement_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_engagement_lead ON public.instagram_engagement USING btree (lead_id);


--
-- Name: idx_ig_messages_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_messages_conversation ON public.instagram_messages USING btree (conversation_id);


--
-- Name: idx_ig_messages_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ig_messages_sent_at ON public.instagram_messages USING btree (sent_at);


--
-- Name: idx_import_jobs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_import_jobs_tenant ON public.import_jobs USING btree (tenant_id);


--
-- Name: idx_instagram_business_accounts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_business_accounts_tenant_id ON public.instagram_business_accounts USING btree (tenant_id);


--
-- Name: idx_instagram_comments_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_comments_tenant_id ON public.instagram_comments USING btree (tenant_id);


--
-- Name: idx_instagram_conversations_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_conversations_tenant_id ON public.instagram_conversations USING btree (tenant_id);


--
-- Name: idx_instagram_engagement_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_engagement_tenant_id ON public.instagram_engagement USING btree (tenant_id);


--
-- Name: idx_instagram_feed_posts_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_feed_posts_profile ON public.instagram_feed_posts USING btree (instagram_profile_id);


--
-- Name: idx_instagram_feed_posts_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_feed_posts_tenant ON public.instagram_feed_posts USING btree (tenant_id);


--
-- Name: idx_instagram_messages_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_messages_tenant_id ON public.instagram_messages USING btree (tenant_id);


--
-- Name: idx_instagram_profiles_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_profiles_tenant ON public.instagram_profiles USING btree (tenant_id);


--
-- Name: idx_instagram_profiles_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_profiles_username ON public.instagram_profiles USING btree (username);


--
-- Name: idx_instagram_stories_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_stories_profile ON public.instagram_stories USING btree (instagram_profile_id);


--
-- Name: idx_instagram_stories_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_instagram_stories_tenant ON public.instagram_stories USING btree (tenant_id);


--
-- Name: idx_integration_settings_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_integration_settings_tenant_id ON public.integration_settings USING btree (tenant_id);


--
-- Name: idx_lead_conversions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_conversions_created_at ON public.lead_conversions USING btree (created_at DESC);


--
-- Name: idx_lead_conversions_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_conversions_lead_id ON public.lead_conversions USING btree (lead_id);


--
-- Name: idx_lead_conversions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_conversions_tenant_id ON public.lead_conversions USING btree (tenant_id);


--
-- Name: idx_lead_diagnostics_v2_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_diagnostics_v2_tenant_id ON public.lead_diagnostics_v2 USING btree (tenant_id);


--
-- Name: idx_lead_distribution_config_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_distribution_config_tenant_id ON public.lead_distribution_config USING btree (tenant_id);


--
-- Name: idx_lead_distribution_log_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_distribution_log_tenant_id ON public.lead_distribution_log USING btree (tenant_id);


--
-- Name: idx_lead_distribution_members_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_lead_distribution_members_tenant_id ON public.lead_distribution_members USING btree (tenant_id);


--
-- Name: idx_leads_franchise_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_leads_franchise_campaign ON public.leads USING btree (franchise_campaign_id) WHERE (franchise_campaign_id IS NOT NULL);


--
-- Name: idx_leads_instagram_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_leads_instagram_username ON public.leads USING btree (instagram_username) WHERE (instagram_username IS NOT NULL);


--
-- Name: idx_leads_internal_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_leads_internal_contact ON public.leads USING btree (is_internal_contact) WHERE (is_internal_contact = true);


--
-- Name: idx_leads_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_leads_tenant_created ON public.leads USING btree (tenant_id, created_at DESC);


--
-- Name: idx_leads_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_leads_tenant_id ON public.leads USING btree (tenant_id);


--
-- Name: idx_leads_webinar_config; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_leads_webinar_config ON public.leads USING btree (webinar_config_id) WHERE (webinar_config_id IS NOT NULL);


--
-- Name: idx_marketing_forms_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_marketing_forms_active ON public.marketing_forms USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_marketing_forms_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_marketing_forms_tenant ON public.marketing_forms USING btree (tenant_id);


--
-- Name: idx_materials_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_materials_event ON public.cs_event_materials USING btree (event_id);


--
-- Name: idx_materials_schedule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_materials_schedule ON public.cs_event_materials USING btree (schedule_item_id);


--
-- Name: idx_meetings_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meetings_lead ON public.meetings USING btree (lead_id);


--
-- Name: idx_meetings_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meetings_org ON public.meetings USING btree (organization_id);


--
-- Name: idx_meetings_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meetings_tenant_id ON public.meetings USING btree (tenant_id);


--
-- Name: idx_member_activity_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_activity_org ON public.member_daily_activity USING btree (organization_id);


--
-- Name: idx_member_calls_history_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_calls_history_tenant_id ON public.member_calls_history USING btree (tenant_id);


--
-- Name: idx_member_calls_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_calls_org ON public.member_calls_history USING btree (organization_id);


--
-- Name: idx_member_daily_activity_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_daily_activity_tenant_id ON public.member_daily_activity USING btree (tenant_id);


--
-- Name: idx_member_engagement_snapshots_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_engagement_snapshots_tenant_id ON public.member_engagement_snapshots USING btree (tenant_id);


--
-- Name: idx_member_lessons_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_lessons_org ON public.member_lessons_progress USING btree (organization_id);


--
-- Name: idx_member_lessons_progress_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_lessons_progress_tenant_id ON public.member_lessons_progress USING btree (tenant_id);


--
-- Name: idx_member_snapshots_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_member_snapshots_org ON public.member_engagement_snapshots USING btree (organization_id);


--
-- Name: idx_meta_ads_accounts_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_accounts_organization_id ON public.meta_ads_accounts USING btree (organization_id);


--
-- Name: idx_meta_ads_accounts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_accounts_tenant_id ON public.meta_ads_accounts USING btree (tenant_id);


--
-- Name: idx_meta_ads_ad_data_account_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_ad_data_account_date ON public.meta_ads_ad_data USING btree (account_id, date DESC);


--
-- Name: idx_meta_ads_ad_data_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_ad_data_campaign ON public.meta_ads_ad_data USING btree (campaign_id, date DESC);


--
-- Name: idx_meta_ads_ad_data_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_ad_data_organization_id ON public.meta_ads_ad_data USING btree (organization_id);


--
-- Name: idx_meta_ads_ad_data_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_ad_data_tenant_id ON public.meta_ads_ad_data USING btree (tenant_id);


--
-- Name: idx_meta_ads_conversions_ad_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_conversions_ad_data ON public.meta_ads_conversions USING btree (ad_data_id);


--
-- Name: idx_meta_ads_conversions_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_conversions_organization_id ON public.meta_ads_conversions USING btree (organization_id);


--
-- Name: idx_meta_ads_conversions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_conversions_tenant_id ON public.meta_ads_conversions USING btree (tenant_id);


--
-- Name: idx_meta_ads_daily_data_account_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_daily_data_account_date ON public.meta_ads_daily_data USING btree (account_id, date DESC);


--
-- Name: idx_meta_ads_daily_data_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_daily_data_organization_id ON public.meta_ads_daily_data USING btree (organization_id);


--
-- Name: idx_meta_ads_daily_data_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_daily_data_tenant_id ON public.meta_ads_daily_data USING btree (tenant_id);


--
-- Name: idx_meta_ads_daily_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_daily_org_date ON public.meta_ads_daily_data USING btree (organization_id, date);


--
-- Name: idx_meta_ads_sync_log_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_sync_log_date ON public.meta_ads_sync_log USING btree (created_at DESC);


--
-- Name: idx_meta_ads_sync_log_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_sync_log_organization_id ON public.meta_ads_sync_log USING btree (organization_id);


--
-- Name: idx_meta_ads_sync_log_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_ads_sync_log_tenant_id ON public.meta_ads_sync_log USING btree (tenant_id);


--
-- Name: idx_meta_forms_page; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_forms_page ON public.meta_lead_ads_forms USING btree (page_id);


--
-- Name: idx_meta_lead_ads_logs_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_lead_ads_logs_tenant ON public.meta_lead_ads_logs USING btree (tenant_id);


--
-- Name: idx_meta_logs_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_meta_logs_created ON public.meta_lead_ads_logs USING btree (created_at DESC);


--
-- Name: idx_noshow_followups_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_noshow_followups_lead ON public.noshow_followups USING btree (lead_id, sent_at DESC);


--
-- Name: idx_noshow_followups_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_noshow_followups_status ON public.noshow_followups USING btree (status);


--
-- Name: idx_notification_logs_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_notification_logs_rule ON public.notification_logs USING btree (rule_id);


--
-- Name: idx_notification_logs_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_notification_logs_tenant_id ON public.notification_logs USING btree (tenant_id);


--
-- Name: idx_notification_rules_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_notification_rules_tenant_id ON public.notification_rules USING btree (tenant_id);


--
-- Name: idx_notification_rules_trigger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_notification_rules_trigger ON public.notification_rules USING btree (trigger_type);


--
-- Name: idx_nps_schedule_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_nps_schedule_pending ON public.nps_survey_schedule USING btree (status, scheduled_for);


--
-- Name: idx_nps_schedule_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_nps_schedule_token ON public.nps_survey_schedule USING btree (token);


--
-- Name: idx_onboarding_stages_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_onboarding_stages_tenant ON public.onboarding_stages USING btree (tenant_id, "position");


--
-- Name: idx_onboardings_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_onboardings_org ON public.onboardings USING btree (organization_id);


--
-- Name: idx_onboardings_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_onboardings_tenant_id ON public.onboardings USING btree (tenant_id);


--
-- Name: idx_organization_members_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_organization_members_tenant_id ON public.organization_members USING btree (tenant_id);


--
-- Name: idx_organization_products_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_organization_products_tenant_id ON public.organization_products USING btree (tenant_id);


--
-- Name: idx_organizations_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_organizations_tenant_id ON public.organizations USING btree (tenant_id);


--
-- Name: idx_pain_registrations_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pain_registrations_tenant_id ON public.pain_registrations USING btree (tenant_id);


--
-- Name: idx_participant_profiles_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_participant_profiles_event ON public.cs_event_participant_profiles USING btree (event_id);


--
-- Name: idx_participant_profiles_rsvp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_participant_profiles_rsvp ON public.cs_event_participant_profiles USING btree (rsvp_id);


--
-- Name: idx_participant_sessions_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_participant_sessions_event ON public.cs_event_participant_sessions USING btree (event_id);


--
-- Name: idx_participant_sessions_rsvp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_participant_sessions_rsvp ON public.cs_event_participant_sessions USING btree (rsvp_id);


--
-- Name: idx_participant_sessions_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_participant_sessions_token ON public.cs_event_participant_sessions USING btree (token);


--
-- Name: idx_payment_gateway_fees_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_payment_gateway_fees_tenant_id ON public.payment_gateway_fees USING btree (tenant_id);


--
-- Name: idx_payment_gateways_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_payment_gateways_tenant_id ON public.payment_gateways USING btree (tenant_id);


--
-- Name: idx_pb_nicho; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pb_nicho ON public.prospeccao_buscas USING btree (nicho);


--
-- Name: idx_pb_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pb_status ON public.prospeccao_buscas USING btree (status);


--
-- Name: idx_pb_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pb_user ON public.prospeccao_buscas USING btree (created_by_user_id, created_at DESC);


--
-- Name: idx_pd_busca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pd_busca ON public.prospeccao_diagnosticos USING btree (busca_id);


--
-- Name: idx_pd_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pd_lead ON public.prospeccao_diagnosticos USING btree (lead_descoberto_id);


--
-- Name: idx_pd_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pd_status ON public.prospeccao_diagnosticos USING btree (status);


--
-- Name: idx_pd_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pd_user ON public.prospeccao_diagnosticos USING btree (created_by_user_id, created_at DESC);


--
-- Name: idx_pld_busca; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pld_busca ON public.prospeccao_leads_descobertos USING btree (busca_id);


--
-- Name: idx_pld_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pld_lead ON public.prospeccao_leads_descobertos USING btree (lead_id) WHERE (lead_id IS NOT NULL);


--
-- Name: idx_pld_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pld_status ON public.prospeccao_leads_descobertos USING btree (status);


--
-- Name: idx_pld_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pld_user ON public.prospeccao_leads_descobertos USING btree (created_by_user_id);


--
-- Name: idx_ppc_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ppc_active ON public.prospeccao_prompts_config USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_ppc_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ppc_key ON public.prospeccao_prompts_config USING btree (key);


--
-- Name: idx_products_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON public.products USING btree (tenant_id);


--
-- Name: idx_profiles_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles USING btree (tenant_id);


--
-- Name: idx_ptn_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ptn_active ON public.prospeccao_templates_nicho USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_ptn_nicho; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ptn_nicho ON public.prospeccao_templates_nicho USING btree (nicho);


--
-- Name: idx_pua_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pua_provider ON public.prospeccao_uso_api USING btree (api_provider);


--
-- Name: idx_pua_user_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_pua_user_month ON public.prospeccao_uso_api USING btree (created_by_user_id, created_at DESC);


--
-- Name: idx_qualification_log_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_qualification_log_profile ON public.social_selling_qualification_log USING btree (instagram_profile_id);


--
-- Name: idx_receive_lead_logs_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_receive_lead_logs_created ON public.receive_lead_logs USING btree (created_at DESC);


--
-- Name: idx_receive_lead_logs_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_receive_lead_logs_lead ON public.receive_lead_logs USING btree (lead_id);


--
-- Name: idx_receive_lead_logs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_receive_lead_logs_status ON public.receive_lead_logs USING btree (status);


--
-- Name: idx_receive_lead_logs_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_receive_lead_logs_tenant_id ON public.receive_lead_logs USING btree (tenant_id);


--
-- Name: idx_sales_alerts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_alerts_tenant_id ON public.sales_alerts USING btree (tenant_id);


--
-- Name: idx_sales_automation_rules_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_automation_rules_tenant_id ON public.sales_automation_rules USING btree (tenant_id);


--
-- Name: idx_sales_materials_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_materials_tenant_id ON public.sales_materials USING btree (tenant_id);


--
-- Name: idx_sales_notes_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_notes_tenant_id ON public.sales_notes USING btree (tenant_id);


--
-- Name: idx_sales_pipeline_stages_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_pipeline_stages_tenant_id ON public.sales_pipeline_stages USING btree (tenant_id);


--
-- Name: idx_sales_pipeline_transitions_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_pipeline_transitions_tenant_id ON public.sales_pipeline_transitions USING btree (tenant_id);


--
-- Name: idx_sales_pipelines_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sales_pipelines_tenant_id ON public.sales_pipelines USING btree (tenant_id);


--
-- Name: idx_schedule_bookmarks_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_schedule_bookmarks_item ON public.cs_event_schedule_bookmarks USING btree (schedule_item_id);


--
-- Name: idx_schedule_bookmarks_rsvp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_schedule_bookmarks_rsvp ON public.cs_event_schedule_bookmarks USING btree (rsvp_id);


--
-- Name: idx_schedule_items_day; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_schedule_items_day ON public.cs_event_schedule_items USING btree (event_id, day_date, start_time);


--
-- Name: idx_schedule_items_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_schedule_items_event ON public.cs_event_schedule_items USING btree (event_id);


--
-- Name: idx_sdr_closer_transfers_closer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sdr_closer_transfers_closer_id ON public.sdr_closer_transfers USING btree (closer_id);


--
-- Name: idx_sdr_closer_transfers_deal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sdr_closer_transfers_deal_id ON public.sdr_closer_transfers USING btree (deal_id);


--
-- Name: idx_sdr_closer_transfers_sdr_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sdr_closer_transfers_sdr_id ON public.sdr_closer_transfers USING btree (sdr_id);


--
-- Name: idx_sdr_closer_transfers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sdr_closer_transfers_status ON public.sdr_closer_transfers USING btree (status);


--
-- Name: idx_sdr_closer_transfers_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sdr_closer_transfers_tenant_id ON public.sdr_closer_transfers USING btree (tenant_id);


--
-- Name: idx_send_counts_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_send_counts_lookup ON public.ai_agent_send_counts USING btree (instance_id, window_type, window_start);


--
-- Name: idx_social_alerts_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_social_alerts_conversation ON public.social_seller_alerts USING btree (conversation_id);


--
-- Name: idx_social_alerts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_social_alerts_status ON public.social_seller_alerts USING btree (status);


--
-- Name: idx_social_seller_alerts_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_social_seller_alerts_tenant_id ON public.social_seller_alerts USING btree (tenant_id);


--
-- Name: idx_social_seller_rules_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_social_seller_rules_tenant_id ON public.social_seller_rules USING btree (tenant_id);


--
-- Name: idx_social_seller_stages_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_social_seller_stages_tenant_id ON public.social_seller_stages USING btree (tenant_id);


--
-- Name: idx_ssa_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssa_active ON public.social_selling_automations USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_ssa_trigger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssa_trigger ON public.social_selling_automations USING btree (trigger_type) WHERE (is_active = true);


--
-- Name: idx_sse_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sse_lead_id ON public.social_selling_enrollments USING btree (lead_id);


--
-- Name: idx_sse_next_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sse_next_action ON public.social_selling_enrollments USING btree (next_action_at) WHERE (status = 'active'::text);


--
-- Name: idx_sse_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_sse_status ON public.social_selling_enrollments USING btree (status) WHERE (status = 'active'::text);


--
-- Name: idx_ssi_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssi_enrollment_id ON public.social_selling_interactions USING btree (enrollment_id);


--
-- Name: idx_ssi_executed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssi_executed_at ON public.social_selling_interactions USING btree (executed_at DESC);


--
-- Name: idx_ssi_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssi_lead_id ON public.social_selling_interactions USING btree (lead_id);


--
-- Name: idx_ssn_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssn_pending ON public.social_selling_known_followers USING btree (for_account, qualified, first_seen_at);


--
-- Name: idx_ssql_analyzed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssql_analyzed ON public.social_selling_qualification_log USING btree (analyzed_at DESC);


--
-- Name: idx_ssql_qualified; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssql_qualified ON public.social_selling_qualification_log USING btree (qualified) WHERE (qualified = true);


--
-- Name: idx_ssql_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_ssql_username ON public.social_selling_qualification_log USING btree (instagram_username);


--
-- Name: idx_team_members_email_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_team_members_email_tenant ON public.team_members USING btree (email, tenant_id);


--
-- Name: idx_team_members_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_team_members_tenant_id ON public.team_members USING btree (tenant_id);


--
-- Name: idx_tenant_config_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_tenant_config_api_key ON public.tenant_config USING btree (api_key);


--
-- Name: idx_tenant_config_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_tenant_config_domain ON public.tenant_config USING btree (custom_domain);


--
-- Name: idx_tenant_config_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_tenant_config_tenant ON public.tenant_config USING btree (tenant_id);


--
-- Name: idx_tenant_sales_config_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_tenant_sales_config_tenant_id ON public.tenant_sales_config USING btree (tenant_id);


--
-- Name: idx_touchpoints_awaiting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_touchpoints_awaiting ON public.cs_touchpoints USING btree (organization_id, status) WHERE (status = 'awaiting_response'::text);


--
-- Name: idx_touchpoints_checkpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_touchpoints_checkpoint ON public.cs_touchpoints USING btree (organization_id, checkpoint_day) WHERE (checkpoint_day IS NOT NULL);


--
-- Name: idx_touchpoints_follow_up_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_touchpoints_follow_up_deadline ON public.cs_touchpoints USING btree (follow_up_deadline) WHERE ((status = 'awaiting_response'::text) AND (follow_up_deadline IS NOT NULL));


--
-- Name: idx_twilio_call_logs_call_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_twilio_call_logs_call_history_id ON public.twilio_call_logs USING btree (call_history_id);


--
-- Name: idx_twilio_call_logs_call_sid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_twilio_call_logs_call_sid ON public.twilio_call_logs USING btree (call_sid);


--
-- Name: idx_twilio_call_logs_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_twilio_call_logs_timestamp ON public.twilio_call_logs USING btree ("timestamp" DESC);


--
-- Name: idx_wa_campaign_items_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_campaign_items_campaign ON public.wa_community_campaign_items USING btree (campaign_id, "position");


--
-- Name: idx_wa_campaign_items_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_campaign_items_status ON public.wa_community_campaign_items USING btree (campaign_id, status) WHERE (status = ANY (ARRAY['waiting'::text, 'active'::text]));


--
-- Name: idx_wa_campaigns_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_campaigns_slug ON public.wa_community_campaigns USING btree (slug) WHERE (is_active = true);


--
-- Name: idx_wa_cloud_templates_instance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_cloud_templates_instance ON public.whatsapp_cloud_templates USING btree (instance_id);


--
-- Name: idx_wa_cloud_templates_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_cloud_templates_status ON public.whatsapp_cloud_templates USING btree (status);


--
-- Name: idx_wa_cloud_templates_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_cloud_templates_tenant ON public.whatsapp_cloud_templates USING btree (tenant_id);


--
-- Name: idx_wa_communities_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_communities_created_at ON public.wa_communities USING btree (created_at DESC);


--
-- Name: idx_wa_communities_instance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_communities_instance ON public.wa_communities USING btree (instance_id);


--
-- Name: idx_wa_community_groups_community; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_community_groups_community ON public.wa_community_groups USING btree (community_id);


--
-- Name: idx_wa_enrollments_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_enrollments_due ON public.wa_sequence_enrollments USING btree (next_run_at) WHERE ((status = 'active'::text) AND (next_run_at IS NOT NULL));


--
-- Name: idx_wa_enrollments_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_enrollments_sequence ON public.wa_sequence_enrollments USING btree (sequence_id);


--
-- Name: idx_wa_scheduled_community; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_scheduled_community ON public.wa_scheduled_messages USING btree (community_id);


--
-- Name: idx_wa_scheduled_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_scheduled_due ON public.wa_scheduled_messages USING btree (scheduled_for) WHERE (status = 'pending'::text);


--
-- Name: idx_wa_scheduled_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_scheduled_group ON public.wa_scheduled_messages USING btree (target_group_id);


--
-- Name: idx_wa_scheduled_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_scheduled_status ON public.wa_scheduled_messages USING btree (status);


--
-- Name: idx_wa_sequence_steps_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_sequence_steps_sequence ON public.wa_sequence_steps USING btree (sequence_id, step_order);


--
-- Name: idx_wa_sequences_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_sequences_active ON public.wa_message_sequences USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_wa_sequences_community; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wa_sequences_community ON public.wa_message_sequences USING btree (community_id);


--
-- Name: idx_wavoip_devices_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wavoip_devices_member ON public.wavoip_devices USING btree (team_member_id);


--
-- Name: idx_wavoip_devices_team_member; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wavoip_devices_team_member ON public.wavoip_devices USING btree (team_member_id);


--
-- Name: idx_wavoip_devices_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wavoip_devices_tenant_id ON public.wavoip_devices USING btree (tenant_id);


--
-- Name: idx_wavoip_devices_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_wavoip_devices_token ON public.wavoip_devices USING btree (token);


--
-- Name: idx_whatsapp_group_members_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_group_members_group ON public.whatsapp_group_members USING btree (group_id);


--
-- Name: idx_whatsapp_group_members_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_group_members_tenant_id ON public.whatsapp_group_members USING btree (tenant_id);


--
-- Name: idx_whatsapp_groups_instance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_groups_instance ON public.whatsapp_groups USING btree (instance_id);


--
-- Name: idx_whatsapp_groups_jid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_groups_jid ON public.whatsapp_groups USING btree (group_jid);


--
-- Name: idx_whatsapp_groups_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_groups_tenant_id ON public.whatsapp_groups USING btree (tenant_id);


--
-- Name: idx_whatsapp_instances_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_instances_tenant_id ON public.whatsapp_instances USING btree (tenant_id);


--
-- Name: idx_whatsapp_messages_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_group ON public.whatsapp_messages USING btree (group_id);


--
-- Name: idx_whatsapp_messages_instance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_instance ON public.whatsapp_messages USING btree (instance_id);


--
-- Name: idx_whatsapp_messages_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_lead ON public.whatsapp_messages USING btree (lead_id);


--
-- Name: idx_whatsapp_messages_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_message_id ON public.whatsapp_messages USING btree (message_id);


--
-- Name: idx_whatsapp_messages_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_sent_at ON public.whatsapp_messages USING btree (sent_at);


--
-- Name: idx_whatsapp_messages_tenant_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_tenant_created ON public.whatsapp_messages USING btree (tenant_id, created_at DESC);


--
-- Name: idx_whatsapp_messages_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_tenant_id ON public.whatsapp_messages USING btree (tenant_id);


--
-- Name: idx_whatsapp_messages_tenant_isfromme_lead_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_tenant_isfromme_lead_created ON public.whatsapp_messages USING btree (tenant_id, lead_id, created_at) WHERE ((is_from_me = true) AND (lead_id IS NOT NULL));


--
-- Name: idx_whatsapp_messages_tenant_lead_sent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_tenant_lead_sent ON public.whatsapp_messages USING btree (tenant_id, lead_id, sent_at DESC);


--
-- Name: idx_whatsapp_task_bot_config_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_task_bot_config_tenant_id ON public.whatsapp_task_bot_config USING btree (tenant_id);


--
-- Name: idx_whatsapp_task_bot_logs_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX IF NOT EXISTS idx_whatsapp_task_bot_logs_tenant_id ON public.whatsapp_task_bot_logs USING btree (tenant_id);


--
-- Name: uq_ssn_username_account; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX IF NOT EXISTS uq_ssn_username_account ON public.social_selling_known_followers USING btree (username, for_account);


--
-- Name: deals _trg_audit_deal_stage; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS _trg_audit_deal_stage ON public.deals;
CREATE TRIGGER _trg_audit_deal_stage AFTER UPDATE ON public.deals FOR EACH ROW EXECUTE FUNCTION public._audit_deal_stage_change();


--
-- Name: ai_sales_agents audit_ai_sales_agents; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_ai_sales_agents ON public.ai_sales_agents;
CREATE TRIGGER audit_ai_sales_agents AFTER INSERT OR DELETE OR UPDATE ON public.ai_sales_agents FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: franchise_campaigns audit_franchise_campaigns; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_franchise_campaigns ON public.franchise_campaigns;
CREATE TRIGGER audit_franchise_campaigns AFTER INSERT OR DELETE OR UPDATE ON public.franchise_campaigns FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: integration_settings audit_integration_settings; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_integration_settings ON public.integration_settings;
CREATE TRIGGER audit_integration_settings AFTER INSERT OR DELETE OR UPDATE ON public.integration_settings FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: lead_distribution_config audit_lead_distribution_config; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_lead_distribution_config ON public.lead_distribution_config;
CREATE TRIGGER audit_lead_distribution_config AFTER INSERT OR DELETE OR UPDATE ON public.lead_distribution_config FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: lead_distribution_members audit_lead_distribution_members; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_lead_distribution_members ON public.lead_distribution_members;
CREATE TRIGGER audit_lead_distribution_members AFTER INSERT OR DELETE OR UPDATE ON public.lead_distribution_members FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: notification_rules audit_notification_rules; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_notification_rules ON public.notification_rules;
CREATE TRIGGER audit_notification_rules AFTER INSERT OR DELETE OR UPDATE ON public.notification_rules FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: sales_automation_rules audit_sales_automation_rules; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_sales_automation_rules ON public.sales_automation_rules;
CREATE TRIGGER audit_sales_automation_rules AFTER INSERT OR DELETE OR UPDATE ON public.sales_automation_rules FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: sales_pipeline_stages audit_sales_pipeline_stages; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_sales_pipeline_stages ON public.sales_pipeline_stages;
CREATE TRIGGER audit_sales_pipeline_stages AFTER INSERT OR DELETE OR UPDATE ON public.sales_pipeline_stages FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: sales_pipelines audit_sales_pipelines; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_sales_pipelines ON public.sales_pipelines;
CREATE TRIGGER audit_sales_pipelines AFTER INSERT OR DELETE OR UPDATE ON public.sales_pipelines FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: team_members audit_team_members; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_team_members ON public.team_members;
CREATE TRIGGER audit_team_members AFTER UPDATE ON public.team_members FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: tenant_sales_config audit_tenant_sales_config; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS audit_tenant_sales_config ON public.tenant_sales_config;
CREATE TRIGGER audit_tenant_sales_config AFTER INSERT OR DELETE OR UPDATE ON public.tenant_sales_config FOR EACH ROW EXECUTE FUNCTION public.fn_config_audit();


--
-- Name: call_history auto_move_deal_on_call; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS auto_move_deal_on_call ON public.call_history;
CREATE TRIGGER auto_move_deal_on_call AFTER INSERT ON public.call_history FOR EACH ROW EXECUTE FUNCTION public.trg_auto_move_on_call();


--
-- Name: company_activities auto_move_deal_on_task; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS auto_move_deal_on_task ON public.company_activities;
CREATE TRIGGER auto_move_deal_on_task AFTER INSERT ON public.company_activities FOR EACH ROW EXECUTE FUNCTION public.trg_auto_move_on_task();


--
-- Name: whatsapp_messages auto_move_deal_on_whatsapp_message; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS auto_move_deal_on_whatsapp_message ON public.whatsapp_messages;
CREATE TRIGGER auto_move_deal_on_whatsapp_message AFTER INSERT ON public.whatsapp_messages FOR EACH ROW EXECUTE FUNCTION public.trg_auto_move_on_whatsapp_message();


--
-- Name: deal_contacts deal_contacts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS deal_contacts_updated_at ON public.deal_contacts;
CREATE TRIGGER deal_contacts_updated_at BEFORE UPDATE ON public.deal_contacts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: onboardings onboardings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS onboardings_updated_at ON public.onboardings;
CREATE TRIGGER onboardings_updated_at BEFORE UPDATE ON public.onboardings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cs_event_connections set_updated_at_connections; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS set_updated_at_connections ON public.cs_event_connections;
CREATE TRIGGER set_updated_at_connections BEFORE UPDATE ON public.cs_event_connections FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cs_event_feed_posts set_updated_at_feed_posts; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS set_updated_at_feed_posts ON public.cs_event_feed_posts;
CREATE TRIGGER set_updated_at_feed_posts BEFORE UPDATE ON public.cs_event_feed_posts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cs_event_materials set_updated_at_materials; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS set_updated_at_materials ON public.cs_event_materials;
CREATE TRIGGER set_updated_at_materials BEFORE UPDATE ON public.cs_event_materials FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cs_event_participant_profiles set_updated_at_participant_profiles; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS set_updated_at_participant_profiles ON public.cs_event_participant_profiles;
CREATE TRIGGER set_updated_at_participant_profiles BEFORE UPDATE ON public.cs_event_participant_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cs_event_schedule_items set_updated_at_schedule_items; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS set_updated_at_schedule_items ON public.cs_event_schedule_items;
CREATE TRIGGER set_updated_at_schedule_items BEFORE UPDATE ON public.cs_event_schedule_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: whatsapp_messages trg_auto_clear_handled; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_auto_clear_handled ON public.whatsapp_messages;
CREATE TRIGGER trg_auto_clear_handled AFTER INSERT ON public.whatsapp_messages FOR EACH ROW EXECUTE FUNCTION public.auto_clear_handled_on_new_message();


--
-- Name: deals trg_cancel_orphaned_tasks_on_deal_rep_change; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_cancel_orphaned_tasks_on_deal_rep_change ON public.deals;
CREATE TRIGGER trg_cancel_orphaned_tasks_on_deal_rep_change BEFORE UPDATE ON public.deals FOR EACH ROW WHEN ((old.sales_rep_id IS DISTINCT FROM new.sales_rep_id)) EXECUTE FUNCTION public.cancel_orphaned_tasks_on_deal_rep_change();


--
-- Name: leads trg_cancel_orphaned_tasks_on_lead_rep_change; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_cancel_orphaned_tasks_on_lead_rep_change ON public.leads;
CREATE TRIGGER trg_cancel_orphaned_tasks_on_lead_rep_change BEFORE UPDATE ON public.leads FOR EACH ROW WHEN ((old.sales_rep_id IS DISTINCT FROM new.sales_rep_id)) EXECUTE FUNCTION public.cancel_orphaned_tasks_on_rep_change();


--
-- Name: deals trg_deals_stage_changed; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_deals_stage_changed ON public.deals;
CREATE TRIGGER trg_deals_stage_changed BEFORE UPDATE ON public.deals FOR EACH ROW EXECUTE FUNCTION public.update_stage_changed_at();


--
-- Name: deals trg_email_automation_deals; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_email_automation_deals ON public.deals;
CREATE TRIGGER trg_email_automation_deals AFTER INSERT OR UPDATE ON public.deals FOR EACH ROW EXECUTE FUNCTION public.dispatch_email_automation_event();


--
-- Name: leads trg_email_automation_leads; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_email_automation_leads ON public.leads;
CREATE TRIGGER trg_email_automation_leads AFTER INSERT OR UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.dispatch_email_automation_event();


--
-- Name: email_automations trg_email_automations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_email_automations_updated_at ON public.email_automations;
CREATE TRIGGER trg_email_automations_updated_at BEFORE UPDATE ON public.email_automations FOR EACH ROW EXECUTE FUNCTION public.set_email_updated_at();


--
-- Name: email_lists trg_email_lists_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_email_lists_updated_at ON public.email_lists;
CREATE TRIGGER trg_email_lists_updated_at BEFORE UPDATE ON public.email_lists FOR EACH ROW EXECUTE FUNCTION public.set_email_updated_at();


--
-- Name: email_subscribers trg_email_subscribers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_email_subscribers_updated_at ON public.email_subscribers;
CREATE TRIGGER trg_email_subscribers_updated_at BEFORE UPDATE ON public.email_subscribers FOR EACH ROW EXECUTE FUNCTION public.set_email_updated_at();


--
-- Name: email_templates trg_email_templates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_email_templates_updated_at ON public.email_templates;
CREATE TRIGGER trg_email_templates_updated_at BEFORE UPDATE ON public.email_templates FOR EACH ROW EXECUTE FUNCTION public.update_email_templates_updated_at();


--
-- Name: whatsapp_messages trg_enqueue_for_ai_agent; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_enqueue_for_ai_agent ON public.whatsapp_messages;
CREATE TRIGGER trg_enqueue_for_ai_agent AFTER INSERT ON public.whatsapp_messages FOR EACH ROW EXECUTE FUNCTION public.trigger_enqueue_for_ai_agent();


--
-- Name: leads trg_enroll_lead_in_cadence; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_enroll_lead_in_cadence ON public.leads;
CREATE TRIGGER trg_enroll_lead_in_cadence AFTER UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.enroll_lead_in_cadence();


--
-- Name: social_selling_automations trg_ssa_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_ssa_updated_at ON public.social_selling_automations;
CREATE TRIGGER trg_ssa_updated_at BEFORE UPDATE ON public.social_selling_automations FOR EACH ROW EXECUTE FUNCTION public.update_ssa_updated_at();


--
-- Name: social_selling_enrollments trg_sse_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_sse_updated_at ON public.social_selling_enrollments;
CREATE TRIGGER trg_sse_updated_at BEFORE UPDATE ON public.social_selling_enrollments FOR EACH ROW EXECUTE FUNCTION public.update_sse_updated_at();


--
-- Name: leads trg_sync_instagram_fields; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_sync_instagram_fields ON public.leads;
CREATE TRIGGER trg_sync_instagram_fields BEFORE UPDATE OF instagram, instagram_username ON public.leads FOR EACH ROW EXECUTE FUNCTION public.sync_instagram_fields();


--
-- Name: deals trg_sync_lead_from_deal_insert; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_sync_lead_from_deal_insert ON public.deals;
CREATE TRIGGER trg_sync_lead_from_deal_insert AFTER INSERT ON public.deals FOR EACH ROW EXECUTE FUNCTION public.sync_lead_from_deal();


--
-- Name: deals trg_sync_lead_from_deal_update; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_sync_lead_from_deal_update ON public.deals;
CREATE TRIGGER trg_sync_lead_from_deal_update AFTER UPDATE ON public.deals FOR EACH ROW EXECUTE FUNCTION public.sync_lead_from_deal();


--
-- Name: leads trg_sync_lead_instagram; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_sync_lead_instagram ON public.leads;
CREATE TRIGGER trg_sync_lead_instagram BEFORE INSERT OR UPDATE OF instagram, instagram_username ON public.leads FOR EACH ROW EXECUTE FUNCTION public.sync_lead_instagram_fields();


--
-- Name: leads trg_sync_partner_pipeline_stage; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_sync_partner_pipeline_stage ON public.leads;
CREATE TRIGGER trg_sync_partner_pipeline_stage AFTER UPDATE OF pipeline_stage_id ON public.leads FOR EACH ROW EXECUTE FUNCTION public.sync_partner_pipeline_stage();


--
-- Name: whatsapp_messages trg_update_inbox_metrics; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_update_inbox_metrics ON public.whatsapp_messages;
CREATE TRIGGER trg_update_inbox_metrics AFTER INSERT ON public.whatsapp_messages FOR EACH ROW EXECUTE FUNCTION public.update_inbox_metrics_on_message();


--
-- Name: wa_community_campaigns trg_wa_campaigns_updated; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_wa_campaigns_updated ON public.wa_community_campaigns;
CREATE TRIGGER trg_wa_campaigns_updated BEFORE UPDATE ON public.wa_community_campaigns FOR EACH ROW EXECUTE FUNCTION public.wa_communities_touch_updated_at();


--
-- Name: wa_communities trg_wa_communities_updated; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_wa_communities_updated ON public.wa_communities;
CREATE TRIGGER trg_wa_communities_updated BEFORE UPDATE ON public.wa_communities FOR EACH ROW EXECUTE FUNCTION public.wa_communities_touch_updated_at();


--
-- Name: wa_community_groups trg_wa_community_groups_updated; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_wa_community_groups_updated ON public.wa_community_groups;
CREATE TRIGGER trg_wa_community_groups_updated BEFORE UPDATE ON public.wa_community_groups FOR EACH ROW EXECUTE FUNCTION public.wa_communities_touch_updated_at();


--
-- Name: wa_message_sequences trg_wa_message_sequences_updated; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_wa_message_sequences_updated ON public.wa_message_sequences;
CREATE TRIGGER trg_wa_message_sequences_updated BEFORE UPDATE ON public.wa_message_sequences FOR EACH ROW EXECUTE FUNCTION public.wa_communities_touch_updated_at();


--
-- Name: whatsapp_cloud_templates trg_whatsapp_cloud_templates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trg_whatsapp_cloud_templates_updated_at ON public.whatsapp_cloud_templates;
CREATE TRIGGER trg_whatsapp_cloud_templates_updated_at BEFORE UPDATE ON public.whatsapp_cloud_templates FOR EACH ROW EXECUTE FUNCTION public.set_email_updated_at();


--
-- Name: asaas_customers trigger_asaas_customers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_asaas_customers_updated_at ON public.asaas_customers;
CREATE TRIGGER trigger_asaas_customers_updated_at BEFORE UPDATE ON public.asaas_customers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: commission_rules trigger_commission_rules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_commission_rules_updated_at ON public.commission_rules;
CREATE TRIGGER trigger_commission_rules_updated_at BEFORE UPDATE ON public.commission_rules FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: commissions trigger_commissions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_commissions_updated_at ON public.commissions;
CREATE TRIGGER trigger_commissions_updated_at BEFORE UPDATE ON public.commissions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: pain_registrations trigger_create_lead_deal_on_pain_registration; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_create_lead_deal_on_pain_registration ON public.pain_registrations;
CREATE TRIGGER trigger_create_lead_deal_on_pain_registration BEFORE INSERT ON public.pain_registrations FOR EACH ROW EXECUTE FUNCTION public.create_lead_and_deal_from_pain_registration();


--
-- Name: cs_event_rsvps trigger_cs_event_rsvps_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_cs_event_rsvps_updated_at ON public.cs_event_rsvps;
CREATE TRIGGER trigger_cs_event_rsvps_updated_at BEFORE UPDATE ON public.cs_event_rsvps FOR EACH ROW EXECUTE FUNCTION public.update_cs_events_updated_at();


--
-- Name: cs_events trigger_cs_events_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_cs_events_updated_at ON public.cs_events;
CREATE TRIGGER trigger_cs_events_updated_at BEFORE UPDATE ON public.cs_events FOR EACH ROW EXECUTE FUNCTION public.update_cs_events_updated_at();


--
-- Name: deal_payments trigger_deal_payments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_deal_payments_updated_at ON public.deal_payments;
CREATE TRIGGER trigger_deal_payments_updated_at BEFORE UPDATE ON public.deal_payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: lead_distribution_config trigger_distribution_config_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_distribution_config_updated_at ON public.lead_distribution_config;
CREATE TRIGGER trigger_distribution_config_updated_at BEFORE UPDATE ON public.lead_distribution_config FOR EACH ROW EXECUTE FUNCTION public.update_distribution_config_updated_at();


--
-- Name: deal_payments trigger_update_deal_payment_totals; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_update_deal_payment_totals ON public.deal_payments;
CREATE TRIGGER trigger_update_deal_payment_totals AFTER INSERT ON public.deal_payments FOR EACH ROW EXECUTE FUNCTION public.update_deal_payment_totals();


--
-- Name: meetings trigger_update_meetings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_update_meetings_updated_at ON public.meetings;
CREATE TRIGGER trigger_update_meetings_updated_at BEFORE UPDATE ON public.meetings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: sales_materials trigger_update_sales_materials_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_update_sales_materials_updated_at ON public.sales_materials;
CREATE TRIGGER trigger_update_sales_materials_updated_at BEFORE UPDATE ON public.sales_materials FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: sales_notes trigger_update_sales_notes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS trigger_update_sales_notes_updated_at ON public.sales_notes;
CREATE TRIGGER trigger_update_sales_notes_updated_at BEFORE UPDATE ON public.sales_notes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_agent_conversations update_ai_agent_conversations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_ai_agent_conversations_updated_at ON public.ai_agent_conversations;
CREATE TRIGGER update_ai_agent_conversations_updated_at BEFORE UPDATE ON public.ai_agent_conversations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_agent_tools update_ai_agent_tools_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_ai_agent_tools_updated_at ON public.ai_agent_tools;
CREATE TRIGGER update_ai_agent_tools_updated_at BEFORE UPDATE ON public.ai_agent_tools FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_sales_agents update_ai_sales_agents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_ai_sales_agents_updated_at ON public.ai_sales_agents;
CREATE TRIGGER update_ai_sales_agents_updated_at BEFORE UPDATE ON public.ai_sales_agents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_agent_cadence_enrollments update_cadence_enrollments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_cadence_enrollments_updated_at ON public.ai_agent_cadence_enrollments;
CREATE TRIGGER update_cadence_enrollments_updated_at BEFORE UPDATE ON public.ai_agent_cadence_enrollments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: call_history update_call_history_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_call_history_updated_at ON public.call_history;
CREATE TRIGGER update_call_history_updated_at BEFORE UPDATE ON public.call_history FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: company_activities update_company_activities_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_company_activities_updated_at ON public.company_activities;
CREATE TRIGGER update_company_activities_updated_at BEFORE UPDATE ON public.company_activities FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: instagram_business_accounts update_instagram_business_accounts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_instagram_business_accounts_updated_at ON public.instagram_business_accounts;
CREATE TRIGGER update_instagram_business_accounts_updated_at BEFORE UPDATE ON public.instagram_business_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: instagram_conversations update_instagram_conversations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_instagram_conversations_updated_at ON public.instagram_conversations;
CREATE TRIGGER update_instagram_conversations_updated_at BEFORE UPDATE ON public.instagram_conversations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: lead_diagnostics_v2 update_lead_diagnostics_v2_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_lead_diagnostics_v2_updated_at ON public.lead_diagnostics_v2;
CREATE TRIGGER update_lead_diagnostics_v2_updated_at BEFORE UPDATE ON public.lead_diagnostics_v2 FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: leads update_leads_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_leads_updated_at ON public.leads;
CREATE TRIGGER update_leads_updated_at BEFORE UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: llm_provider_configs update_llm_provider_configs_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_llm_provider_configs_updated_at ON public.llm_provider_configs;
CREATE TRIGGER update_llm_provider_configs_updated_at BEFORE UPDATE ON public.llm_provider_configs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: profiles update_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_agent_scheduled_followups update_scheduled_followups_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_scheduled_followups_updated_at ON public.ai_agent_scheduled_followups;
CREATE TRIGGER update_scheduled_followups_updated_at BEFORE UPDATE ON public.ai_agent_scheduled_followups FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: social_seller_rules update_social_seller_rules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_social_seller_rules_updated_at ON public.social_seller_rules;
CREATE TRIGGER update_social_seller_rules_updated_at BEFORE UPDATE ON public.social_seller_rules FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: social_seller_stages update_social_seller_stages_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_social_seller_stages_updated_at ON public.social_seller_stages;
CREATE TRIGGER update_social_seller_stages_updated_at BEFORE UPDATE ON public.social_seller_stages FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: wavoip_devices update_wavoip_devices_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

DROP TRIGGER IF EXISTS update_wavoip_devices_updated_at ON public.wavoip_devices;
CREATE TRIGGER update_wavoip_devices_updated_at BEFORE UPDATE ON public.wavoip_devices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_agent_cadence_enrollments ai_agent_cadence_enrollments_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_cadence_enrollments
    ADD CONSTRAINT ai_agent_cadence_enrollments_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.ai_sales_agents(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_cadence_enrollments ai_agent_cadence_enrollments_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_cadence_enrollments
    ADD CONSTRAINT ai_agent_cadence_enrollments_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_chat_events ai_agent_chat_events_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_chat_events
    ADD CONSTRAINT ai_agent_chat_events_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.ai_sales_agents(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_chat_events ai_agent_chat_events_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_chat_events
    ADD CONSTRAINT ai_agent_chat_events_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.ai_agent_conversations(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_chat_events ai_agent_chat_events_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_chat_events
    ADD CONSTRAINT ai_agent_chat_events_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_conversations ai_agent_conversations_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_conversations
    ADD CONSTRAINT ai_agent_conversations_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.ai_sales_agents(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_conversations ai_agent_conversations_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_conversations
    ADD CONSTRAINT ai_agent_conversations_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_conversations ai_agent_conversations_paused_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_conversations
    ADD CONSTRAINT ai_agent_conversations_paused_by_fkey FOREIGN KEY (paused_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_conversations ai_agent_conversations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_conversations
    ADD CONSTRAINT ai_agent_conversations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_logs ai_agent_logs_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_logs
    ADD CONSTRAINT ai_agent_logs_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.ai_sales_agents(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_logs ai_agent_logs_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_logs
    ADD CONSTRAINT ai_agent_logs_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.ai_agent_conversations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_logs ai_agent_logs_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_logs
    ADD CONSTRAINT ai_agent_logs_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_logs ai_agent_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_logs
    ADD CONSTRAINT ai_agent_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_message_queue ai_agent_message_queue_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_message_queue
    ADD CONSTRAINT ai_agent_message_queue_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.ai_agent_conversations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_message_queue ai_agent_message_queue_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_message_queue
    ADD CONSTRAINT ai_agent_message_queue_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_message_queue ai_agent_message_queue_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_message_queue
    ADD CONSTRAINT ai_agent_message_queue_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.whatsapp_messages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_message_queue ai_agent_message_queue_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_message_queue
    ADD CONSTRAINT ai_agent_message_queue_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_scheduled_followups ai_agent_scheduled_followups_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_scheduled_followups
    ADD CONSTRAINT ai_agent_scheduled_followups_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.ai_sales_agents(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_scheduled_followups ai_agent_scheduled_followups_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_scheduled_followups
    ADD CONSTRAINT ai_agent_scheduled_followups_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.ai_agent_conversations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_scheduled_followups ai_agent_scheduled_followups_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_scheduled_followups
    ADD CONSTRAINT ai_agent_scheduled_followups_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_tools ai_agent_tools_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_tools
    ADD CONSTRAINT ai_agent_tools_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.ai_sales_agents(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_agent_tools ai_agent_tools_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_agent_tools
    ADD CONSTRAINT ai_agent_tools_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_sales_agents ai_sales_agents_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_sales_agents
    ADD CONSTRAINT ai_sales_agents_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_sales_agents ai_sales_agents_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_sales_agents
    ADD CONSTRAINT ai_sales_agents_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.sales_pipelines(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_sales_agents ai_sales_agents_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_sales_agents
    ADD CONSTRAINT ai_sales_agents_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: ai_sales_agents ai_sales_agents_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.ai_sales_agents
    ADD CONSTRAINT ai_sales_agents_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: analysis_templates analysis_templates_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.analysis_templates
    ADD CONSTRAINT analysis_templates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: asaas_customers asaas_customers_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.asaas_customers
    ADD CONSTRAINT asaas_customers_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: asaas_customers asaas_customers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.asaas_customers
    ADD CONSTRAINT asaas_customers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: asaas_webhooks asaas_webhooks_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.asaas_webhooks
    ADD CONSTRAINT asaas_webhooks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_blocks calendar_blocks_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_blocks
    ADD CONSTRAINT calendar_blocks_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_blocks calendar_blocks_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_blocks
    ADD CONSTRAINT calendar_blocks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_events calendar_events_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_events calendar_events_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_events calendar_events_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: calendar_events calendar_events_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: call_history call_history_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.call_history
    ADD CONSTRAINT call_history_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: call_history call_history_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.call_history
    ADD CONSTRAINT call_history_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: call_history call_history_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.call_history
    ADD CONSTRAINT call_history_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: call_history call_history_wavoip_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.call_history
    ADD CONSTRAINT call_history_wavoip_device_id_fkey FOREIGN KEY (wavoip_device_id) REFERENCES public.wavoip_devices(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_instance_stats campaign_instance_stats_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_instance_stats
    ADD CONSTRAINT campaign_instance_stats_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_instance_stats campaign_instance_stats_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_instance_stats
    ADD CONSTRAINT campaign_instance_stats_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_leads campaign_leads_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_templates campaign_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_templates
    ADD CONSTRAINT campaign_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaign_templates campaign_templates_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaign_templates
    ADD CONSTRAINT campaign_templates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_assignment_distribution_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_assignment_distribution_config_id_fkey FOREIGN KEY (assignment_distribution_config_id) REFERENCES public.lead_distribution_config(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_assignment_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_assignment_target_id_fkey FOREIGN KEY (assignment_target_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_cloud_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_cloud_template_id_fkey FOREIGN KEY (cloud_template_id) REFERENCES public.whatsapp_cloud_templates(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.campaign_templates(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: campaigns campaigns_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_configs chat_configs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_configs
    ADD CONSTRAINT chat_configs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_messages chat_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.chat_sessions(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_messages chat_messages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_sessions chat_sessions_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_sessions
    ADD CONSTRAINT chat_sessions_config_id_fkey FOREIGN KEY (config_id) REFERENCES public.chat_configs(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: chat_sessions chat_sessions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.chat_sessions
    ADD CONSTRAINT chat_sessions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: client_onboarding_data client_onboarding_data_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.client_onboarding_data
    ADD CONSTRAINT client_onboarding_data_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: client_onboarding_data client_onboarding_data_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.client_onboarding_data
    ADD CONSTRAINT client_onboarding_data_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: client_onboarding_data client_onboarding_data_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.client_onboarding_data
    ADD CONSTRAINT client_onboarding_data_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_playbooks coach_playbooks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_playbooks
    ADD CONSTRAINT coach_playbooks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_playbooks coach_playbooks_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_playbooks
    ADD CONSTRAINT coach_playbooks_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_playbooks coach_playbooks_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_playbooks
    ADD CONSTRAINT coach_playbooks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_sessions coach_sessions_call_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_sessions
    ADD CONSTRAINT coach_sessions_call_id_fkey FOREIGN KEY (call_id) REFERENCES public.call_history(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_sessions coach_sessions_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_sessions
    ADD CONSTRAINT coach_sessions_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_sessions coach_sessions_playbook_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_sessions
    ADD CONSTRAINT coach_sessions_playbook_id_fkey FOREIGN KEY (playbook_id) REFERENCES public.coach_playbooks(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_sessions coach_sessions_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_sessions
    ADD CONSTRAINT coach_sessions_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: coach_sessions coach_sessions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.coach_sessions
    ADD CONSTRAINT coach_sessions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commission_rules commission_rules_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commission_rules
    ADD CONSTRAINT commission_rules_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commission_rules commission_rules_sales_rep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commission_rules
    ADD CONSTRAINT commission_rules_sales_rep_id_fkey FOREIGN KEY (sales_rep_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commission_rules commission_rules_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commission_rules
    ADD CONSTRAINT commission_rules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commissions commissions_commission_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_commission_rule_id_fkey FOREIGN KEY (commission_rule_id) REFERENCES public.commission_rules(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commissions commissions_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commissions commissions_deal_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_deal_payment_id_fkey FOREIGN KEY (deal_payment_id) REFERENCES public.deal_payments(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commissions commissions_sales_rep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_sales_rep_id_fkey FOREIGN KEY (sales_rep_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: commissions commissions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_responsavel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities company_activities_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT company_activities_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_handled cs_conversation_handled_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_handled
    ADD CONSTRAINT cs_conversation_handled_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.whatsapp_groups(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_handled cs_conversation_handled_handled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_handled
    ADD CONSTRAINT cs_conversation_handled_handled_by_fkey FOREIGN KEY (handled_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_handled cs_conversation_handled_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_handled
    ADD CONSTRAINT cs_conversation_handled_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_handled cs_conversation_handled_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_handled
    ADD CONSTRAINT cs_conversation_handled_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_notes cs_conversation_notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_notes
    ADD CONSTRAINT cs_conversation_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_notes cs_conversation_notes_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_notes
    ADD CONSTRAINT cs_conversation_notes_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.whatsapp_groups(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_notes cs_conversation_notes_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_notes
    ADD CONSTRAINT cs_conversation_notes_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_conversation_notes cs_conversation_notes_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_conversation_notes
    ADD CONSTRAINT cs_conversation_notes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_engagement_metrics cs_engagement_metrics_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_engagement_metrics
    ADD CONSTRAINT cs_engagement_metrics_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_engagement_metrics cs_engagement_metrics_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_engagement_metrics
    ADD CONSTRAINT cs_engagement_metrics_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_engagement_metrics cs_engagement_metrics_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_engagement_metrics
    ADD CONSTRAINT cs_engagement_metrics_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_connections cs_event_connections_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_connections
    ADD CONSTRAINT cs_event_connections_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_connections cs_event_connections_requester_rsvp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_connections
    ADD CONSTRAINT cs_event_connections_requester_rsvp_id_fkey FOREIGN KEY (requester_rsvp_id) REFERENCES public.cs_event_rsvps(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_connections cs_event_connections_target_rsvp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_connections
    ADD CONSTRAINT cs_event_connections_target_rsvp_id_fkey FOREIGN KEY (target_rsvp_id) REFERENCES public.cs_event_rsvps(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_feed_likes cs_event_feed_likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_feed_likes
    ADD CONSTRAINT cs_event_feed_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.cs_event_feed_posts(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_feed_likes cs_event_feed_likes_rsvp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_feed_likes
    ADD CONSTRAINT cs_event_feed_likes_rsvp_id_fkey FOREIGN KEY (rsvp_id) REFERENCES public.cs_event_rsvps(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_feed_posts cs_event_feed_posts_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_feed_posts
    ADD CONSTRAINT cs_event_feed_posts_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_materials cs_event_materials_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_materials
    ADD CONSTRAINT cs_event_materials_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_materials cs_event_materials_schedule_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_materials
    ADD CONSTRAINT cs_event_materials_schedule_item_id_fkey FOREIGN KEY (schedule_item_id) REFERENCES public.cs_event_schedule_items(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_profiles cs_event_participant_profiles_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_profiles
    ADD CONSTRAINT cs_event_participant_profiles_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_profiles cs_event_participant_profiles_rsvp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_profiles
    ADD CONSTRAINT cs_event_participant_profiles_rsvp_id_fkey FOREIGN KEY (rsvp_id) REFERENCES public.cs_event_rsvps(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_sessions cs_event_participant_sessions_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_sessions
    ADD CONSTRAINT cs_event_participant_sessions_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_participant_sessions cs_event_participant_sessions_rsvp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_participant_sessions
    ADD CONSTRAINT cs_event_participant_sessions_rsvp_id_fkey FOREIGN KEY (rsvp_id) REFERENCES public.cs_event_rsvps(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_checked_in_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_checked_in_by_fkey FOREIGN KEY (checked_in_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_rsvps cs_event_rsvps_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_rsvps
    ADD CONSTRAINT cs_event_rsvps_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_schedule_bookmarks cs_event_schedule_bookmarks_rsvp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_schedule_bookmarks
    ADD CONSTRAINT cs_event_schedule_bookmarks_rsvp_id_fkey FOREIGN KEY (rsvp_id) REFERENCES public.cs_event_rsvps(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_schedule_bookmarks cs_event_schedule_bookmarks_schedule_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_schedule_bookmarks
    ADD CONSTRAINT cs_event_schedule_bookmarks_schedule_item_id_fkey FOREIGN KEY (schedule_item_id) REFERENCES public.cs_event_schedule_items(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_event_schedule_items cs_event_schedule_items_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_event_schedule_items
    ADD CONSTRAINT cs_event_schedule_items_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.cs_events(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events cs_events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_events
    ADD CONSTRAINT cs_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events cs_events_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_events
    ADD CONSTRAINT cs_events_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events cs_events_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_events
    ADD CONSTRAINT cs_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_current cs_health_current_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_current
    ADD CONSTRAINT cs_health_current_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_current cs_health_current_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_current
    ADD CONSTRAINT cs_health_current_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_current cs_health_current_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_current
    ADD CONSTRAINT cs_health_current_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_scores_history cs_health_scores_history_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_scores_history
    ADD CONSTRAINT cs_health_scores_history_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_scores_history cs_health_scores_history_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_scores_history
    ADD CONSTRAINT cs_health_scores_history_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_health_scores_history cs_health_scores_history_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_health_scores_history
    ADD CONSTRAINT cs_health_scores_history_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_assigned_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_assigned_agent_id_fkey FOREIGN KEY (assigned_agent_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.whatsapp_groups(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_inbox_metrics cs_inbox_metrics_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_inbox_metrics
    ADD CONSTRAINT cs_inbox_metrics_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_interactions cs_interactions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_interactions
    ADD CONSTRAINT cs_interactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_interactions cs_interactions_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_interactions
    ADD CONSTRAINT cs_interactions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_interactions cs_interactions_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_interactions
    ADD CONSTRAINT cs_interactions_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_interactions cs_interactions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_interactions
    ADD CONSTRAINT cs_interactions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_objectives cs_objectives_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_objectives
    ADD CONSTRAINT cs_objectives_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_objectives cs_objectives_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_objectives
    ADD CONSTRAINT cs_objectives_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_objectives cs_objectives_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_objectives
    ADD CONSTRAINT cs_objectives_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_objectives cs_objectives_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_objectives
    ADD CONSTRAINT cs_objectives_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_response_templates cs_response_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_response_templates
    ADD CONSTRAINT cs_response_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_response_templates cs_response_templates_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_response_templates
    ADD CONSTRAINT cs_response_templates_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_response_templates cs_response_templates_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_response_templates
    ADD CONSTRAINT cs_response_templates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_success_metrics cs_success_metrics_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_success_metrics
    ADD CONSTRAINT cs_success_metrics_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_success_metrics cs_success_metrics_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_success_metrics
    ADD CONSTRAINT cs_success_metrics_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_success_metrics cs_success_metrics_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_success_metrics
    ADD CONSTRAINT cs_success_metrics_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_touchpoints cs_touchpoints_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_touchpoints
    ADD CONSTRAINT cs_touchpoints_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_touchpoints cs_touchpoints_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_touchpoints
    ADD CONSTRAINT cs_touchpoints_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_touchpoints cs_touchpoints_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_touchpoints
    ADD CONSTRAINT cs_touchpoints_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_touchpoints cs_touchpoints_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.cs_touchpoints
    ADD CONSTRAINT cs_touchpoints_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_contacts deal_contacts_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_contacts
    ADD CONSTRAINT deal_contacts_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_contacts deal_contacts_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_contacts
    ADD CONSTRAINT deal_contacts_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_contacts deal_contacts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_contacts
    ADD CONSTRAINT deal_contacts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_loss_reasons deal_loss_reasons_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_loss_reasons
    ADD CONSTRAINT deal_loss_reasons_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payment_installments deal_payment_installments_deal_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payment_installments
    ADD CONSTRAINT deal_payment_installments_deal_payment_id_fkey FOREIGN KEY (deal_payment_id) REFERENCES public.deal_payments(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payment_installments deal_payment_installments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payment_installments
    ADD CONSTRAINT deal_payment_installments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payments deal_payments_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payments
    ADD CONSTRAINT deal_payments_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payments deal_payments_payer_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payments
    ADD CONSTRAINT deal_payments_payer_lead_id_fkey FOREIGN KEY (payer_lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deal_payments deal_payments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deal_payments
    ADD CONSTRAINT deal_payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_pipeline_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_pipeline_stage_id_fkey FOREIGN KEY (pipeline_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_sales_rep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_sales_rep_id_fkey FOREIGN KEY (sales_rep_id) REFERENCES public.team_members(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_sdr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_sdr_id_fkey FOREIGN KEY (sdr_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: deals deals_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.deals
    ADD CONSTRAINT deals_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automation_runs email_automation_runs_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automation_runs
    ADD CONSTRAINT email_automation_runs_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automation_runs email_automation_runs_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automation_runs
    ADD CONSTRAINT email_automation_runs_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.sales_automation_rules(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automation_runs email_automation_runs_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automation_runs
    ADD CONSTRAINT email_automation_runs_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.email_templates(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automations email_automations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automations
    ADD CONSTRAINT email_automations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_automations email_automations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_automations
    ADD CONSTRAINT email_automations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_campaign_leads email_campaign_leads_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_campaign_leads
    ADD CONSTRAINT email_campaign_leads_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.email_campaigns(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_campaign_leads email_campaign_leads_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_campaign_leads
    ADD CONSTRAINT email_campaign_leads_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_campaigns email_campaigns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_campaigns
    ADD CONSTRAINT email_campaigns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_campaigns email_campaigns_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_campaigns
    ADD CONSTRAINT email_campaigns_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.email_templates(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_events email_events_send_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_events
    ADD CONSTRAINT email_events_send_id_fkey FOREIGN KEY (send_id) REFERENCES public.email_sends(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_events email_events_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_events
    ADD CONSTRAINT email_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_lists email_lists_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_lists
    ADD CONSTRAINT email_lists_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_lists email_lists_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_lists
    ADD CONSTRAINT email_lists_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sends email_sends_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sends
    ADD CONSTRAINT email_sends_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.email_campaigns(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sends email_sends_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sends
    ADD CONSTRAINT email_sends_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sends email_sends_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sends
    ADD CONSTRAINT email_sends_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_enrollments email_sequence_enrollments_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_enrollments
    ADD CONSTRAINT email_sequence_enrollments_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_enrollments email_sequence_enrollments_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_enrollments
    ADD CONSTRAINT email_sequence_enrollments_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.email_sequences(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_logs email_sequence_logs_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_logs
    ADD CONSTRAINT email_sequence_logs_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES public.email_sequence_enrollments(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_logs email_sequence_logs_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_logs
    ADD CONSTRAINT email_sequence_logs_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_logs email_sequence_logs_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_logs
    ADD CONSTRAINT email_sequence_logs_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.email_sequences(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_logs email_sequence_logs_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_logs
    ADD CONSTRAINT email_sequence_logs_step_id_fkey FOREIGN KEY (step_id) REFERENCES public.email_sequence_steps(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_steps email_sequence_steps_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_steps
    ADD CONSTRAINT email_sequence_steps_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.email_sequences(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequence_steps email_sequence_steps_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequence_steps
    ADD CONSTRAINT email_sequence_steps_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.email_templates(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_sequences email_sequences_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_sequences
    ADD CONSTRAINT email_sequences_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_subscribers email_subscribers_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_subscribers
    ADD CONSTRAINT email_subscribers_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_subscribers email_subscribers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_subscribers
    ADD CONSTRAINT email_subscribers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_templates email_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_templates
    ADD CONSTRAINT email_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: email_unsubscribes email_unsubscribes_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.email_unsubscribes
    ADD CONSTRAINT email_unsubscribes_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_accounts financial_accounts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_accounts
    ADD CONSTRAINT financial_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_categories financial_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_categories
    ADD CONSTRAINT financial_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.financial_categories(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_categories financial_categories_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_categories
    ADD CONSTRAINT financial_categories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_entries financial_entries_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_entries
    ADD CONSTRAINT financial_entries_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.financial_categories(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_entries financial_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_entries
    ADD CONSTRAINT financial_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_entries financial_entries_financial_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_entries
    ADD CONSTRAINT financial_entries_financial_account_id_fkey FOREIGN KEY (financial_account_id) REFERENCES public.financial_accounts(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: financial_entries financial_entries_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.financial_entries
    ADD CONSTRAINT financial_entries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities fk_activity_meeting; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT fk_activity_meeting FOREIGN KEY (meeting_id) REFERENCES public.meetings(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings fk_onboarding_activity; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT fk_onboarding_activity FOREIGN KEY (activity_id) REFERENCES public.company_activities(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings fk_onboarding_meeting; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT fk_onboarding_meeting FOREIGN KEY (meeting_id) REFERENCES public.meetings(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: company_activities fk_parent_task; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.company_activities
    ADD CONSTRAINT fk_parent_task FOREIGN KEY (parent_task_id) REFERENCES public.company_activities(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_campaigns franchise_campaigns_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_campaigns
    ADD CONSTRAINT franchise_campaigns_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_distribution_log franchise_distribution_log_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_distribution_log
    ADD CONSTRAINT franchise_distribution_log_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.franchise_campaigns(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_distribution_log franchise_distribution_log_franchise_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_distribution_log
    ADD CONSTRAINT franchise_distribution_log_franchise_member_id_fkey FOREIGN KEY (franchise_member_id) REFERENCES public.franchise_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_distribution_log franchise_distribution_log_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_distribution_log
    ADD CONSTRAINT franchise_distribution_log_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: franchise_members franchise_members_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.franchise_members
    ADD CONSTRAINT franchise_members_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.franchise_campaigns(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_accounts google_ads_accounts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_accounts
    ADD CONSTRAINT google_ads_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_campaign_data google_ads_campaign_data_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_campaign_data
    ADD CONSTRAINT google_ads_campaign_data_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: google_ads_daily_data google_ads_daily_data_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.google_ads_daily_data
    ADD CONSTRAINT google_ads_daily_data_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: import_jobs import_jobs_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.import_jobs
    ADD CONSTRAINT import_jobs_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_business_accounts instagram_business_accounts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_business_accounts
    ADD CONSTRAINT instagram_business_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_comments instagram_comments_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_comments
    ADD CONSTRAINT instagram_comments_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.instagram_business_accounts(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_comments instagram_comments_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_comments
    ADD CONSTRAINT instagram_comments_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_comments instagram_comments_replied_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_comments
    ADD CONSTRAINT instagram_comments_replied_by_fkey FOREIGN KEY (replied_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_comments instagram_comments_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_comments
    ADD CONSTRAINT instagram_comments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.instagram_business_accounts(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_social_seller_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_social_seller_stage_id_fkey FOREIGN KEY (social_seller_stage_id) REFERENCES public.social_seller_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_stage_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_stage_changed_by_fkey FOREIGN KEY (stage_changed_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_conversations instagram_conversations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_conversations
    ADD CONSTRAINT instagram_conversations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_engagement instagram_engagement_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_engagement
    ADD CONSTRAINT instagram_engagement_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.instagram_business_accounts(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_engagement instagram_engagement_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_engagement
    ADD CONSTRAINT instagram_engagement_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_engagement instagram_engagement_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_engagement
    ADD CONSTRAINT instagram_engagement_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_feed_posts instagram_feed_posts_instagram_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_feed_posts
    ADD CONSTRAINT instagram_feed_posts_instagram_profile_id_fkey FOREIGN KEY (instagram_profile_id) REFERENCES public.instagram_profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_messages instagram_messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_messages
    ADD CONSTRAINT instagram_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.instagram_conversations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_messages instagram_messages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_messages
    ADD CONSTRAINT instagram_messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: instagram_stories instagram_stories_instagram_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.instagram_stories
    ADD CONSTRAINT instagram_stories_instagram_profile_id_fkey FOREIGN KEY (instagram_profile_id) REFERENCES public.instagram_profiles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: integration_settings integration_settings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.integration_settings
    ADD CONSTRAINT integration_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_conversions lead_conversions_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_conversions
    ADD CONSTRAINT lead_conversions_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_conversions lead_conversions_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_conversions
    ADD CONSTRAINT lead_conversions_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_conversions lead_conversions_sales_rep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_conversions
    ADD CONSTRAINT lead_conversions_sales_rep_id_fkey FOREIGN KEY (sales_rep_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_conversions lead_conversions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_conversions
    ADD CONSTRAINT lead_conversions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_diagnostics_v2 lead_diagnostics_v2_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_diagnostics_v2
    ADD CONSTRAINT lead_diagnostics_v2_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_diagnostics_v2 lead_diagnostics_v2_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_diagnostics_v2
    ADD CONSTRAINT lead_diagnostics_v2_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_config lead_distribution_config_first_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_config
    ADD CONSTRAINT lead_distribution_config_first_stage_id_fkey FOREIGN KEY (first_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_config lead_distribution_config_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_config
    ADD CONSTRAINT lead_distribution_config_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_config lead_distribution_config_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_config
    ADD CONSTRAINT lead_distribution_config_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_config lead_distribution_config_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_config
    ADD CONSTRAINT lead_distribution_config_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_log lead_distribution_log_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_log
    ADD CONSTRAINT lead_distribution_log_config_id_fkey FOREIGN KEY (config_id) REFERENCES public.lead_distribution_config(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_log lead_distribution_log_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_log
    ADD CONSTRAINT lead_distribution_log_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_log lead_distribution_log_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_log
    ADD CONSTRAINT lead_distribution_log_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_log lead_distribution_log_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_log
    ADD CONSTRAINT lead_distribution_log_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_members lead_distribution_members_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_members
    ADD CONSTRAINT lead_distribution_members_config_id_fkey FOREIGN KEY (config_id) REFERENCES public.lead_distribution_config(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_members lead_distribution_members_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_members
    ADD CONSTRAINT lead_distribution_members_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_distribution_members lead_distribution_members_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_distribution_members
    ADD CONSTRAINT lead_distribution_members_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: lead_interactions lead_interactions_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.lead_interactions
    ADD CONSTRAINT lead_interactions_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: leads leads_franchise_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_franchise_campaign_id_fkey FOREIGN KEY (franchise_campaign_id) REFERENCES public.franchise_campaigns(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: leads leads_franchise_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_franchise_member_id_fkey FOREIGN KEY (franchise_member_id) REFERENCES public.franchise_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: leads leads_pipeline_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pipeline_stage_id_fkey FOREIGN KEY (pipeline_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: leads leads_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: marketing_forms marketing_forms_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.marketing_forms
    ADD CONSTRAINT marketing_forms_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meetings meetings_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.company_activities(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meetings meetings_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meetings meetings_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meetings meetings_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meetings meetings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_calls_history member_calls_history_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_calls_history
    ADD CONSTRAINT member_calls_history_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_calls_history member_calls_history_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_calls_history
    ADD CONSTRAINT member_calls_history_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_calls_history member_calls_history_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_calls_history
    ADD CONSTRAINT member_calls_history_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_daily_activity member_daily_activity_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_daily_activity
    ADD CONSTRAINT member_daily_activity_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_daily_activity member_daily_activity_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_daily_activity
    ADD CONSTRAINT member_daily_activity_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_daily_activity member_daily_activity_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_daily_activity
    ADD CONSTRAINT member_daily_activity_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_engagement_snapshots member_engagement_snapshots_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_engagement_snapshots
    ADD CONSTRAINT member_engagement_snapshots_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_engagement_snapshots member_engagement_snapshots_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_engagement_snapshots
    ADD CONSTRAINT member_engagement_snapshots_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_engagement_snapshots member_engagement_snapshots_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_engagement_snapshots
    ADD CONSTRAINT member_engagement_snapshots_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_lessons_progress member_lessons_progress_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_lessons_progress
    ADD CONSTRAINT member_lessons_progress_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_lessons_progress member_lessons_progress_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_lessons_progress
    ADD CONSTRAINT member_lessons_progress_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: member_lessons_progress member_lessons_progress_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.member_lessons_progress
    ADD CONSTRAINT member_lessons_progress_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_accounts meta_ads_accounts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_accounts
    ADD CONSTRAINT meta_ads_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_ad_data meta_ads_ad_data_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_ad_data
    ADD CONSTRAINT meta_ads_ad_data_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_conversions meta_ads_conversions_ad_data_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_conversions
    ADD CONSTRAINT meta_ads_conversions_ad_data_id_fkey FOREIGN KEY (ad_data_id) REFERENCES public.meta_ads_ad_data(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_conversions meta_ads_conversions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_conversions
    ADD CONSTRAINT meta_ads_conversions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_daily_data meta_ads_daily_data_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_daily_data
    ADD CONSTRAINT meta_ads_daily_data_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: meta_ads_sync_log meta_ads_sync_log_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.meta_ads_sync_log
    ADD CONSTRAINT meta_ads_sync_log_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: noshow_followups noshow_followups_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.noshow_followups
    ADD CONSTRAINT noshow_followups_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: noshow_followups noshow_followups_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.noshow_followups
    ADD CONSTRAINT noshow_followups_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_logs notification_logs_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_logs
    ADD CONSTRAINT notification_logs_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.notification_rules(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_logs notification_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_logs
    ADD CONSTRAINT notification_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_rules notification_rules_action_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_rules
    ADD CONSTRAINT notification_rules_action_instance_id_fkey FOREIGN KEY (action_instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_rules notification_rules_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_rules
    ADD CONSTRAINT notification_rules_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: notification_rules notification_rules_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.notification_rules
    ADD CONSTRAINT notification_rules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: nps_survey_schedule nps_survey_schedule_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.nps_survey_schedule
    ADD CONSTRAINT nps_survey_schedule_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: nps_survey_schedule nps_survey_schedule_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.nps_survey_schedule
    ADD CONSTRAINT nps_survey_schedule_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: nps_survey_schedule nps_survey_schedule_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.nps_survey_schedule
    ADD CONSTRAINT nps_survey_schedule_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboarding_stages onboarding_stages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboarding_stages
    ADD CONSTRAINT onboarding_stages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: onboardings onboardings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.onboardings
    ADD CONSTRAINT onboardings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_members organization_members_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_members organization_members_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_members organization_members_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_members
    ADD CONSTRAINT organization_members_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_products organization_products_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_products
    ADD CONSTRAINT organization_products_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_products organization_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_products
    ADD CONSTRAINT organization_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organization_products organization_products_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organization_products
    ADD CONSTRAINT organization_products_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organizations organizations_primary_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_primary_contact_id_fkey FOREIGN KEY (primary_contact_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: organizations organizations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: pain_registrations pain_registrations_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.pain_registrations
    ADD CONSTRAINT pain_registrations_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: pain_registrations pain_registrations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.pain_registrations
    ADD CONSTRAINT pain_registrations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateway_fees payment_gateway_fees_gateway_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateway_fees
    ADD CONSTRAINT payment_gateway_fees_gateway_id_fkey FOREIGN KEY (gateway_id) REFERENCES public.payment_gateways(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateway_fees payment_gateway_fees_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateway_fees
    ADD CONSTRAINT payment_gateway_fees_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: payment_gateways payment_gateways_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.payment_gateways
    ADD CONSTRAINT payment_gateways_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: products products_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: profiles profiles_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: profiles profiles_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_diagnosticos prospeccao_diagnosticos_busca_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_diagnosticos
    ADD CONSTRAINT prospeccao_diagnosticos_busca_id_fkey FOREIGN KEY (busca_id) REFERENCES public.prospeccao_buscas(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_diagnosticos prospeccao_diagnosticos_lead_descoberto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_diagnosticos
    ADD CONSTRAINT prospeccao_diagnosticos_lead_descoberto_id_fkey FOREIGN KEY (lead_descoberto_id) REFERENCES public.prospeccao_leads_descobertos(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_leads_descobertos prospeccao_leads_descobertos_busca_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_leads_descobertos
    ADD CONSTRAINT prospeccao_leads_descobertos_busca_id_fkey FOREIGN KEY (busca_id) REFERENCES public.prospeccao_buscas(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_uso_api prospeccao_uso_api_busca_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_uso_api
    ADD CONSTRAINT prospeccao_uso_api_busca_id_fkey FOREIGN KEY (busca_id) REFERENCES public.prospeccao_buscas(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: prospeccao_uso_api prospeccao_uso_api_lead_descoberto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.prospeccao_uso_api
    ADD CONSTRAINT prospeccao_uso_api_lead_descoberto_id_fkey FOREIGN KEY (lead_descoberto_id) REFERENCES public.prospeccao_leads_descobertos(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: receive_lead_logs receive_lead_logs_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.receive_lead_logs
    ADD CONSTRAINT receive_lead_logs_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: receive_lead_logs receive_lead_logs_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.receive_lead_logs
    ADD CONSTRAINT receive_lead_logs_config_id_fkey FOREIGN KEY (config_id) REFERENCES public.lead_distribution_config(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: receive_lead_logs receive_lead_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.receive_lead_logs
    ADD CONSTRAINT receive_lead_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_alerts sales_alerts_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_alerts
    ADD CONSTRAINT sales_alerts_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_alerts sales_alerts_sales_rep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_alerts
    ADD CONSTRAINT sales_alerts_sales_rep_id_fkey FOREIGN KEY (sales_rep_id) REFERENCES public.team_members(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_alerts sales_alerts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_alerts
    ADD CONSTRAINT sales_alerts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_automation_rules sales_automation_rules_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_automation_rules
    ADD CONSTRAINT sales_automation_rules_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_automation_rules sales_automation_rules_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_automation_rules
    ADD CONSTRAINT sales_automation_rules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_materials sales_materials_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_materials
    ADD CONSTRAINT sales_materials_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_materials sales_materials_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_materials
    ADD CONSTRAINT sales_materials_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_notes sales_notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_notes
    ADD CONSTRAINT sales_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_notes sales_notes_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_notes
    ADD CONSTRAINT sales_notes_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_notes sales_notes_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_notes
    ADD CONSTRAINT sales_notes_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_notes sales_notes_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_notes
    ADD CONSTRAINT sales_notes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_stages sales_pipeline_stages_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_stages
    ADD CONSTRAINT sales_pipeline_stages_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_stages sales_pipeline_stages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_stages
    ADD CONSTRAINT sales_pipeline_stages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_transitions sales_pipeline_transitions_source_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_transitions
    ADD CONSTRAINT sales_pipeline_transitions_source_pipeline_id_fkey FOREIGN KEY (source_pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_transitions sales_pipeline_transitions_source_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_transitions
    ADD CONSTRAINT sales_pipeline_transitions_source_stage_id_fkey FOREIGN KEY (source_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_transitions sales_pipeline_transitions_target_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_transitions
    ADD CONSTRAINT sales_pipeline_transitions_target_pipeline_id_fkey FOREIGN KEY (target_pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_transitions sales_pipeline_transitions_target_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_transitions
    ADD CONSTRAINT sales_pipeline_transitions_target_stage_id_fkey FOREIGN KEY (target_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipeline_transitions sales_pipeline_transitions_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipeline_transitions
    ADD CONSTRAINT sales_pipeline_transitions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipelines sales_pipelines_default_sales_rep_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipelines
    ADD CONSTRAINT sales_pipelines_default_sales_rep_id_fkey FOREIGN KEY (default_sales_rep_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sales_pipelines sales_pipelines_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sales_pipelines
    ADD CONSTRAINT sales_pipelines_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: scheduled_messages scheduled_messages_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.scheduled_messages
    ADD CONSTRAINT scheduled_messages_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: scheduled_messages scheduled_messages_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.scheduled_messages
    ADD CONSTRAINT scheduled_messages_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_closer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_closer_id_fkey FOREIGN KEY (closer_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_from_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_from_pipeline_id_fkey FOREIGN KEY (from_pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_from_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_from_stage_id_fkey FOREIGN KEY (from_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_sdr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_sdr_id_fkey FOREIGN KEY (sdr_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_to_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_to_pipeline_id_fkey FOREIGN KEY (to_pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: sdr_closer_transfers sdr_closer_transfers_to_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.sdr_closer_transfers
    ADD CONSTRAINT sdr_closer_transfers_to_stage_id_fkey FOREIGN KEY (to_stage_id) REFERENCES public.sales_pipeline_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_alerts social_seller_alerts_actioned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_alerts
    ADD CONSTRAINT social_seller_alerts_actioned_by_fkey FOREIGN KEY (actioned_by) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_alerts social_seller_alerts_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_alerts
    ADD CONSTRAINT social_seller_alerts_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.instagram_conversations(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_alerts social_seller_alerts_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_alerts
    ADD CONSTRAINT social_seller_alerts_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_alerts social_seller_alerts_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_alerts
    ADD CONSTRAINT social_seller_alerts_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.social_seller_rules(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_alerts social_seller_alerts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_alerts
    ADD CONSTRAINT social_seller_alerts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_rules social_seller_rules_from_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_rules
    ADD CONSTRAINT social_seller_rules_from_stage_id_fkey FOREIGN KEY (from_stage_id) REFERENCES public.social_seller_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_rules social_seller_rules_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_rules
    ADD CONSTRAINT social_seller_rules_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_rules social_seller_rules_to_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_rules
    ADD CONSTRAINT social_seller_rules_to_stage_id_fkey FOREIGN KEY (to_stage_id) REFERENCES public.social_seller_stages(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_seller_stages social_seller_stages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_seller_stages
    ADD CONSTRAINT social_seller_stages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_enrollments social_selling_enrollments_automation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_enrollments
    ADD CONSTRAINT social_selling_enrollments_automation_id_fkey FOREIGN KEY (automation_id) REFERENCES public.social_selling_automations(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_enrollments social_selling_enrollments_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_enrollments
    ADD CONSTRAINT social_selling_enrollments_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_interactions social_selling_interactions_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_interactions
    ADD CONSTRAINT social_selling_interactions_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES public.social_selling_enrollments(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_interactions social_selling_interactions_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_interactions
    ADD CONSTRAINT social_selling_interactions_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_known_followers social_selling_known_followers_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_known_followers
    ADD CONSTRAINT social_selling_known_followers_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES public.social_selling_enrollments(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_known_followers social_selling_known_followers_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_known_followers
    ADD CONSTRAINT social_selling_known_followers_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_qualification_log social_selling_qualification_log_automation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_qualification_log
    ADD CONSTRAINT social_selling_qualification_log_automation_id_fkey FOREIGN KEY (automation_id) REFERENCES public.social_selling_automations(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_qualification_log social_selling_qualification_log_instagram_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_qualification_log
    ADD CONSTRAINT social_selling_qualification_log_instagram_profile_id_fkey FOREIGN KEY (instagram_profile_id) REFERENCES public.instagram_profiles(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: social_selling_qualification_log social_selling_qualification_log_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.social_selling_qualification_log
    ADD CONSTRAINT social_selling_qualification_log_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: team_members team_members_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: team_members team_members_wavoip_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_wavoip_device_id_fkey FOREIGN KEY (wavoip_device_id) REFERENCES public.wavoip_devices(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: team_members team_members_whatsapp_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_whatsapp_instance_id_fkey FOREIGN KEY (whatsapp_instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_config tenant_config_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_config
    ADD CONSTRAINT tenant_config_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_sales_config tenant_sales_config_closer_distribution_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_sales_config
    ADD CONSTRAINT tenant_sales_config_closer_distribution_config_id_fkey FOREIGN KEY (closer_distribution_config_id) REFERENCES public.lead_distribution_config(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_sales_config tenant_sales_config_closer_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_sales_config
    ADD CONSTRAINT tenant_sales_config_closer_pipeline_id_fkey FOREIGN KEY (closer_pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_sales_config tenant_sales_config_sdr_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_sales_config
    ADD CONSTRAINT tenant_sales_config_sdr_pipeline_id_fkey FOREIGN KEY (sdr_pipeline_id) REFERENCES public.sales_pipelines(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: tenant_sales_config tenant_sales_config_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.tenant_sales_config
    ADD CONSTRAINT tenant_sales_config_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: transactions transactions_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: transactions transactions_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: twilio_call_logs twilio_call_logs_call_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.twilio_call_logs
    ADD CONSTRAINT twilio_call_logs_call_history_id_fkey FOREIGN KEY (call_history_id) REFERENCES public.call_history(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: twilio_call_logs twilio_call_logs_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.twilio_call_logs
    ADD CONSTRAINT twilio_call_logs_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_communities wa_communities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_communities
    ADD CONSTRAINT wa_communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_communities wa_communities_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_communities
    ADD CONSTRAINT wa_communities_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE RESTRICT;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaign_items wa_community_campaign_items_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaign_items
    ADD CONSTRAINT wa_community_campaign_items_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.wa_community_campaigns(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaign_items wa_community_campaign_items_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaign_items
    ADD CONSTRAINT wa_community_campaign_items_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.wa_communities(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_campaigns wa_community_campaigns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_campaigns
    ADD CONSTRAINT wa_community_campaigns_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_community_groups wa_community_groups_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_community_groups
    ADD CONSTRAINT wa_community_groups_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.wa_communities(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_message_sequences wa_message_sequences_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_message_sequences
    ADD CONSTRAINT wa_message_sequences_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.wa_communities(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_message_sequences wa_message_sequences_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_message_sequences
    ADD CONSTRAINT wa_message_sequences_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.wa_communities(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES public.wa_sequence_enrollments(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.wa_message_sequences(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_sequence_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_sequence_step_id_fkey FOREIGN KEY (sequence_step_id) REFERENCES public.wa_sequence_steps(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_scheduled_messages wa_scheduled_messages_target_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_scheduled_messages
    ADD CONSTRAINT wa_scheduled_messages_target_group_id_fkey FOREIGN KEY (target_group_id) REFERENCES public.wa_community_groups(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_sequence_enrollments wa_sequence_enrollments_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_sequence_enrollments
    ADD CONSTRAINT wa_sequence_enrollments_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.wa_message_sequences(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_sequence_steps wa_sequence_steps_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_sequence_steps
    ADD CONSTRAINT wa_sequence_steps_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.wa_message_sequences(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wa_sequence_steps wa_sequence_steps_target_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wa_sequence_steps
    ADD CONSTRAINT wa_sequence_steps_target_group_id_fkey FOREIGN KEY (target_group_id) REFERENCES public.wa_community_groups(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wavoip_devices wavoip_devices_team_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wavoip_devices
    ADD CONSTRAINT wavoip_devices_team_member_id_fkey FOREIGN KEY (team_member_id) REFERENCES public.team_members(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: wavoip_devices wavoip_devices_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.wavoip_devices
    ADD CONSTRAINT wavoip_devices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_cloud_templates whatsapp_cloud_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_cloud_templates
    ADD CONSTRAINT whatsapp_cloud_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_cloud_templates whatsapp_cloud_templates_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_cloud_templates
    ADD CONSTRAINT whatsapp_cloud_templates_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_cloud_templates whatsapp_cloud_templates_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_cloud_templates
    ADD CONSTRAINT whatsapp_cloud_templates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_group_members whatsapp_group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_group_members
    ADD CONSTRAINT whatsapp_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.whatsapp_groups(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_group_members whatsapp_group_members_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_group_members
    ADD CONSTRAINT whatsapp_group_members_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_group_members whatsapp_group_members_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_group_members
    ADD CONSTRAINT whatsapp_group_members_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_groups whatsapp_groups_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_groups
    ADD CONSTRAINT whatsapp_groups_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_groups whatsapp_groups_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_groups
    ADD CONSTRAINT whatsapp_groups_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_instances whatsapp_instances_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_instances
    ADD CONSTRAINT whatsapp_instances_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_messages whatsapp_messages_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.whatsapp_groups(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_messages whatsapp_messages_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_messages whatsapp_messages_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_messages whatsapp_messages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_messages
    ADD CONSTRAINT whatsapp_messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_config whatsapp_task_bot_config_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_config
    ADD CONSTRAINT whatsapp_task_bot_config_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.whatsapp_instances(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_config whatsapp_task_bot_config_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_config
    ADD CONSTRAINT whatsapp_task_bot_config_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_logs whatsapp_task_bot_logs_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_logs
    ADD CONSTRAINT whatsapp_task_bot_logs_config_id_fkey FOREIGN KEY (config_id) REFERENCES public.whatsapp_task_bot_config(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_logs whatsapp_task_bot_logs_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_logs
    ADD CONSTRAINT whatsapp_task_bot_logs_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.whatsapp_groups(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_task_bot_logs whatsapp_task_bot_logs_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_task_bot_logs
    ADD CONSTRAINT whatsapp_task_bot_logs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_template_tags whatsapp_template_tags_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_template_tags
    ADD CONSTRAINT whatsapp_template_tags_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.whatsapp_cloud_templates(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: whatsapp_template_tags whatsapp_template_tags_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

DO $idem$ BEGIN
  ALTER TABLE ONLY public.whatsapp_template_tags
    ADD CONSTRAINT whatsapp_template_tags_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; WHEN duplicate_table THEN null; END $idem$;


--
-- Name: cs_events CS Events podem ser modificados por autenticados; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "CS Events podem ser modificados por autenticados" ON public.cs_events;
CREATE POLICY "CS Events podem ser modificados por autenticados" ON public.cs_events USING ((auth.role() = 'authenticated'::text));


--
-- Name: cs_events CS Events são visíveis para todos; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "CS Events são visíveis para todos" ON public.cs_events;
CREATE POLICY "CS Events são visíveis para todos" ON public.cs_events FOR SELECT USING (true);


--
-- Name: cs_event_rsvps CS RSVPs podem ser criados por qualquer um; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "CS RSVPs podem ser criados por qualquer um" ON public.cs_event_rsvps;
CREATE POLICY "CS RSVPs podem ser criados por qualquer um" ON public.cs_event_rsvps FOR INSERT WITH CHECK (true);


--
-- Name: cs_event_rsvps CS RSVPs podem ser deletados por autenticados; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "CS RSVPs podem ser deletados por autenticados" ON public.cs_event_rsvps;
CREATE POLICY "CS RSVPs podem ser deletados por autenticados" ON public.cs_event_rsvps FOR DELETE USING ((auth.role() = 'authenticated'::text));


--
-- Name: cs_event_rsvps CS RSVPs podem ser modificados por autenticados; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "CS RSVPs podem ser modificados por autenticados" ON public.cs_event_rsvps;
CREATE POLICY "CS RSVPs podem ser modificados por autenticados" ON public.cs_event_rsvps FOR UPDATE USING ((auth.role() = 'authenticated'::text));


--
-- Name: cs_event_rsvps CS RSVPs são visíveis para autenticados; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "CS RSVPs são visíveis para autenticados" ON public.cs_event_rsvps;
CREATE POLICY "CS RSVPs são visíveis para autenticados" ON public.cs_event_rsvps FOR SELECT USING (true);


--
-- Name: nps_survey_schedule Service role full access; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "Service role full access" ON public.nps_survey_schedule;
CREATE POLICY "Service role full access" ON public.nps_survey_schedule USING (true);


--
-- Name: call_history Users can insert call history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "Users can insert call history" ON public.call_history;
CREATE POLICY "Users can insert call history" ON public.call_history FOR INSERT WITH CHECK (true);


--
-- Name: wavoip_devices Users can manage their own devices; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "Users can manage their own devices" ON public.wavoip_devices;
CREATE POLICY "Users can manage their own devices" ON public.wavoip_devices USING (true);


--
-- Name: call_history Users can update call history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "Users can update call history" ON public.call_history;
CREATE POLICY "Users can update call history" ON public.call_history FOR UPDATE USING (true);


--
-- Name: call_history Users can view call history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "Users can view call history" ON public.call_history;
CREATE POLICY "Users can view call history" ON public.call_history FOR SELECT USING (true);


--
-- Name: wavoip_devices Users can view their own devices; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "Users can view their own devices" ON public.wavoip_devices;
CREATE POLICY "Users can view their own devices" ON public.wavoip_devices FOR SELECT USING (true);


--
-- Name: ai_agent_cadence_enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_cadence_enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_chat_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_chat_events ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_message_queue; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_message_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_scheduled_followups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_scheduled_followups ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_send_counts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_send_counts ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_tools; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_agent_tools ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_sales_agents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_sales_agents ENABLE ROW LEVEL SECURITY;

--
-- Name: analysis_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.analysis_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_buscas anon read by id; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "anon read by id" ON public.prospeccao_buscas;
CREATE POLICY "anon read by id" ON public.prospeccao_buscas FOR SELECT TO anon USING (true);


--
-- Name: prospeccao_diagnosticos anon read by id; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "anon read by id" ON public.prospeccao_diagnosticos;
CREATE POLICY "anon read by id" ON public.prospeccao_diagnosticos FOR SELECT TO anon USING (true);


--
-- Name: prospeccao_leads_descobertos anon read by id; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "anon read by id" ON public.prospeccao_leads_descobertos;
CREATE POLICY "anon read by id" ON public.prospeccao_leads_descobertos FOR SELECT TO anon USING (true);


--
-- Name: asaas_customers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.asaas_customers ENABLE ROW LEVEL SECURITY;

--
-- Name: asaas_webhooks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.asaas_webhooks ENABLE ROW LEVEL SECURITY;

--
-- Name: twilio_call_logs authenticated_access; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS authenticated_access ON public.twilio_call_logs;
CREATE POLICY authenticated_access ON public.twilio_call_logs TO authenticated USING (true);


--
-- Name: calendar_blocks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_blocks ENABLE ROW LEVEL SECURITY;

--
-- Name: calendar_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

--
-- Name: call_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.call_history ENABLE ROW LEVEL SECURITY;

--
-- Name: campaign_instance_stats; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.campaign_instance_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: campaign_leads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.campaign_leads ENABLE ROW LEVEL SECURITY;

--
-- Name: campaign_leads campaign_leads_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS campaign_leads_tenant ON public.campaign_leads;
CREATE POLICY campaign_leads_tenant ON public.campaign_leads USING ((tenant_id = ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE (team_members.auth_user_id = auth.uid()))));


--
-- Name: campaign_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.campaign_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: campaign_templates campaign_templates_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS campaign_templates_tenant ON public.campaign_templates;
CREATE POLICY campaign_templates_tenant ON public.campaign_templates USING ((tenant_id = ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE (team_members.auth_user_id = auth.uid()))));


--
-- Name: campaigns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

--
-- Name: campaigns campaigns_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS campaigns_tenant ON public.campaigns;
CREATE POLICY campaigns_tenant ON public.campaigns USING ((tenant_id = ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE (team_members.auth_user_id = auth.uid()))));


--
-- Name: chat_configs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chat_configs ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: campaign_instance_stats cis_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS cis_tenant ON public.campaign_instance_stats;
CREATE POLICY cis_tenant ON public.campaign_instance_stats USING ((tenant_id = ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE (team_members.auth_user_id = auth.uid()))));


--
-- Name: client_onboarding_data; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_onboarding_data ENABLE ROW LEVEL SECURITY;

--
-- Name: client_onboarding_data client_onboarding_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS client_onboarding_insert ON public.client_onboarding_data;
CREATE POLICY client_onboarding_insert ON public.client_onboarding_data FOR INSERT WITH CHECK (((tenant_id = public.get_tenant_id()) OR public.is_superadmin()));


--
-- Name: client_onboarding_data client_onboarding_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS client_onboarding_select ON public.client_onboarding_data;
CREATE POLICY client_onboarding_select ON public.client_onboarding_data FOR SELECT USING (((tenant_id = public.get_tenant_id()) OR public.is_superadmin()));


--
-- Name: client_onboarding_data client_onboarding_update; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS client_onboarding_update ON public.client_onboarding_data;
CREATE POLICY client_onboarding_update ON public.client_onboarding_data FOR UPDATE USING (((tenant_id = public.get_tenant_id()) OR public.is_superadmin()));


--
-- Name: coach_playbooks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coach_playbooks ENABLE ROW LEVEL SECURITY;

--
-- Name: coach_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coach_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: commission_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.commission_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: commissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;

--
-- Name: company_activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.company_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.config ENABLE ROW LEVEL SECURITY;

--
-- Name: config config_all_authenticated; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS config_all_authenticated ON public.config;
CREATE POLICY config_all_authenticated ON public.config TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_connections connections_anon_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS connections_anon_insert ON public.cs_event_connections;
CREATE POLICY connections_anon_insert ON public.cs_event_connections FOR INSERT TO anon WITH CHECK (true);


--
-- Name: cs_event_connections connections_anon_update; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS connections_anon_update ON public.cs_event_connections;
CREATE POLICY connections_anon_update ON public.cs_event_connections FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: cs_event_connections connections_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS connections_auth_all ON public.cs_event_connections;
CREATE POLICY connections_auth_all ON public.cs_event_connections TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_connections connections_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS connections_select_all ON public.cs_event_connections;
CREATE POLICY connections_select_all ON public.cs_event_connections FOR SELECT USING (true);


--
-- Name: cs_event_connections connections_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS connections_service_all ON public.cs_event_connections;
CREATE POLICY connections_service_all ON public.cs_event_connections TO service_role USING (true) WITH CHECK (true);


--
-- Name: cs_conversation_handled; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_conversation_handled ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_conversation_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_conversation_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_engagement_metrics; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_engagement_metrics ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_connections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_connections ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_feed_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_feed_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_feed_posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_feed_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_materials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_participant_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_participant_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_participant_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_participant_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_rsvps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_rsvps ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_schedule_bookmarks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_schedule_bookmarks ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_schedule_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_event_schedule_items ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_events ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_health_current; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_health_current ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_health_scores_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_health_scores_history ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_inbox_metrics; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_inbox_metrics ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_interactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_interactions ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_objectives; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_objectives ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_response_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_response_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_success_metrics; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_success_metrics ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_touchpoints; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cs_touchpoints ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_loss_reasons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_loss_reasons ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_payment_installments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_payment_installments ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: deals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;

--
-- Name: dropdown_options; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dropdown_options ENABLE ROW LEVEL SECURITY;

--
-- Name: dropdown_options dropdown_options_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS dropdown_options_all ON public.dropdown_options;
CREATE POLICY dropdown_options_all ON public.dropdown_options TO authenticated USING (true) WITH CHECK (true);


--
-- Name: dropdown_options dropdown_options_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS dropdown_options_select ON public.dropdown_options;
CREATE POLICY dropdown_options_select ON public.dropdown_options FOR SELECT TO authenticated USING (true);


--
-- Name: email_automation_runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_automation_runs ENABLE ROW LEVEL SECURITY;

--
-- Name: email_automation_runs email_automation_runs_authenticated_read; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_automation_runs_authenticated_read ON public.email_automation_runs;
CREATE POLICY email_automation_runs_authenticated_read ON public.email_automation_runs FOR SELECT TO authenticated USING (true);


--
-- Name: email_automation_runs email_automation_runs_service_write; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_automation_runs_service_write ON public.email_automation_runs;
CREATE POLICY email_automation_runs_service_write ON public.email_automation_runs FOR INSERT TO service_role WITH CHECK (true);


--
-- Name: email_automations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_automations ENABLE ROW LEVEL SECURITY;

--
-- Name: email_campaign_leads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_campaign_leads ENABLE ROW LEVEL SECURITY;

--
-- Name: email_campaign_leads email_campaign_leads_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_campaign_leads_tenant ON public.email_campaign_leads;
CREATE POLICY email_campaign_leads_tenant ON public.email_campaign_leads USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_campaigns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_campaigns ENABLE ROW LEVEL SECURITY;

--
-- Name: email_campaigns email_campaigns_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_campaigns_tenant ON public.email_campaigns;
CREATE POLICY email_campaigns_tenant ON public.email_campaigns USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_events ENABLE ROW LEVEL SECURITY;

--
-- Name: email_lists; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_lists ENABLE ROW LEVEL SECURITY;

--
-- Name: email_sends; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_sends ENABLE ROW LEVEL SECURITY;

--
-- Name: email_sequence_enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_sequence_enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: email_sequence_enrollments email_sequence_enrollments_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_sequence_enrollments_tenant ON public.email_sequence_enrollments;
CREATE POLICY email_sequence_enrollments_tenant ON public.email_sequence_enrollments USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_sequence_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_sequence_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: email_sequence_logs email_sequence_logs_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_sequence_logs_tenant ON public.email_sequence_logs;
CREATE POLICY email_sequence_logs_tenant ON public.email_sequence_logs USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_sequence_steps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_sequence_steps ENABLE ROW LEVEL SECURITY;

--
-- Name: email_sequence_steps email_sequence_steps_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_sequence_steps_tenant ON public.email_sequence_steps;
CREATE POLICY email_sequence_steps_tenant ON public.email_sequence_steps USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_sequences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_sequences ENABLE ROW LEVEL SECURITY;

--
-- Name: email_sequences email_sequences_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_sequences_tenant ON public.email_sequences;
CREATE POLICY email_sequences_tenant ON public.email_sequences USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_subscribers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_subscribers ENABLE ROW LEVEL SECURITY;

--
-- Name: email_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: email_templates email_templates_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_templates_authenticated_all ON public.email_templates;
CREATE POLICY email_templates_authenticated_all ON public.email_templates TO authenticated USING (true) WITH CHECK (true);


--
-- Name: email_templates email_templates_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_templates_tenant ON public.email_templates;
CREATE POLICY email_templates_tenant ON public.email_templates USING ((tenant_id = public.get_tenant_id()));


--
-- Name: email_unsubscribes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_unsubscribes ENABLE ROW LEVEL SECURITY;

--
-- Name: email_unsubscribes email_unsubscribes_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS email_unsubscribes_tenant ON public.email_unsubscribes;
CREATE POLICY email_unsubscribes_tenant ON public.email_unsubscribes USING ((tenant_id = public.get_tenant_id()));


--
-- Name: cs_event_feed_likes feed_likes_anon_delete; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_likes_anon_delete ON public.cs_event_feed_likes;
CREATE POLICY feed_likes_anon_delete ON public.cs_event_feed_likes FOR DELETE TO anon USING (true);


--
-- Name: cs_event_feed_likes feed_likes_anon_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_likes_anon_insert ON public.cs_event_feed_likes;
CREATE POLICY feed_likes_anon_insert ON public.cs_event_feed_likes FOR INSERT TO anon WITH CHECK (true);


--
-- Name: cs_event_feed_likes feed_likes_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_likes_auth_all ON public.cs_event_feed_likes;
CREATE POLICY feed_likes_auth_all ON public.cs_event_feed_likes TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_feed_likes feed_likes_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_likes_select_all ON public.cs_event_feed_likes;
CREATE POLICY feed_likes_select_all ON public.cs_event_feed_likes FOR SELECT USING (true);


--
-- Name: cs_event_feed_likes feed_likes_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_likes_service_all ON public.cs_event_feed_likes;
CREATE POLICY feed_likes_service_all ON public.cs_event_feed_likes TO service_role USING (true) WITH CHECK (true);


--
-- Name: cs_event_feed_posts feed_posts_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_posts_auth_all ON public.cs_event_feed_posts;
CREATE POLICY feed_posts_auth_all ON public.cs_event_feed_posts TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_feed_posts feed_posts_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_posts_select_all ON public.cs_event_feed_posts;
CREATE POLICY feed_posts_select_all ON public.cs_event_feed_posts FOR SELECT USING (true);


--
-- Name: cs_event_feed_posts feed_posts_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS feed_posts_service_all ON public.cs_event_feed_posts;
CREATE POLICY feed_posts_service_all ON public.cs_event_feed_posts TO service_role USING (true) WITH CHECK (true);


--
-- Name: financial_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.financial_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: financial_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.financial_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: financial_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.financial_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: franchise_campaigns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.franchise_campaigns ENABLE ROW LEVEL SECURITY;

--
-- Name: franchise_campaigns franchise_campaigns_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS franchise_campaigns_tenant ON public.franchise_campaigns;
CREATE POLICY franchise_campaigns_tenant ON public.franchise_campaigns USING ((tenant_id = public.get_tenant_id()));


--
-- Name: franchise_distribution_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.franchise_distribution_log ENABLE ROW LEVEL SECURITY;

--
-- Name: franchise_distribution_log franchise_distribution_log_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS franchise_distribution_log_tenant ON public.franchise_distribution_log;
CREATE POLICY franchise_distribution_log_tenant ON public.franchise_distribution_log USING ((tenant_id = public.get_tenant_id()));


--
-- Name: franchise_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.franchise_members ENABLE ROW LEVEL SECURITY;

--
-- Name: franchise_members franchise_members_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS franchise_members_tenant ON public.franchise_members;
CREATE POLICY franchise_members_tenant ON public.franchise_members USING ((tenant_id = public.get_tenant_id()));


--
-- Name: google_ads_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_ads_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: google_ads_campaign_data; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_ads_campaign_data ENABLE ROW LEVEL SECURITY;

--
-- Name: google_ads_daily_data; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_ads_daily_data ENABLE ROW LEVEL SECURITY;

--
-- Name: import_jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.import_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_business_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_business_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_engagement; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_engagement ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_feed_posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_feed_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: instagram_stories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.instagram_stories ENABLE ROW LEVEL SECURITY;

--
-- Name: integration_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.integration_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_conversions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_conversions ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_diagnostics_v2; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_diagnostics_v2 ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_distribution_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_distribution_config ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_distribution_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_distribution_log ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_distribution_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_distribution_members ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_interactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lead_interactions ENABLE ROW LEVEL SECURITY;

--
-- Name: lead_interactions lead_interactions_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS lead_interactions_all ON public.lead_interactions;
CREATE POLICY lead_interactions_all ON public.lead_interactions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: leads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

--
-- Name: llm_provider_configs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.llm_provider_configs ENABLE ROW LEVEL SECURITY;

--
-- Name: marketing_forms; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.marketing_forms ENABLE ROW LEVEL SECURITY;

--
-- Name: marketing_forms marketing_forms_anon_update_stats; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_forms_anon_update_stats ON public.marketing_forms;
CREATE POLICY marketing_forms_anon_update_stats ON public.marketing_forms FOR UPDATE USING ((is_active = true)) WITH CHECK ((is_active = true));


--
-- Name: marketing_forms marketing_forms_public_read; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_forms_public_read ON public.marketing_forms;
CREATE POLICY marketing_forms_public_read ON public.marketing_forms FOR SELECT USING ((is_active = true));


--
-- Name: marketing_forms marketing_forms_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_forms_tenant ON public.marketing_forms;
CREATE POLICY marketing_forms_tenant ON public.marketing_forms USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: email_automations marketing_manage; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_manage ON public.email_automations;
CREATE POLICY marketing_manage ON public.email_automations TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_campaigns marketing_manage; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_manage ON public.email_campaigns;
CREATE POLICY marketing_manage ON public.email_campaigns TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_lists marketing_manage; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_manage ON public.email_lists;
CREATE POLICY marketing_manage ON public.email_lists TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_templates marketing_manage; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_manage ON public.email_templates;
CREATE POLICY marketing_manage ON public.email_templates TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: whatsapp_cloud_templates marketing_manage; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_manage ON public.whatsapp_cloud_templates;
CREATE POLICY marketing_manage ON public.whatsapp_cloud_templates TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: whatsapp_template_tags marketing_manage; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_manage ON public.whatsapp_template_tags;
CREATE POLICY marketing_manage ON public.whatsapp_template_tags TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_automation_runs marketing_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_tenant ON public.email_automation_runs;
CREATE POLICY marketing_tenant ON public.email_automation_runs TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_events marketing_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_tenant ON public.email_events;
CREATE POLICY marketing_tenant ON public.email_events TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_sends marketing_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_tenant ON public.email_sends;
CREATE POLICY marketing_tenant ON public.email_sends TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: email_subscribers marketing_tenant; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS marketing_tenant ON public.email_subscribers;
CREATE POLICY marketing_tenant ON public.email_subscribers TO authenticated USING ((tenant_id = public.get_tenant_id())) WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: cs_event_materials materials_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS materials_auth_all ON public.cs_event_materials;
CREATE POLICY materials_auth_all ON public.cs_event_materials TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_materials materials_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS materials_select_all ON public.cs_event_materials;
CREATE POLICY materials_select_all ON public.cs_event_materials FOR SELECT USING (true);


--
-- Name: cs_event_materials materials_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS materials_service_all ON public.cs_event_materials;
CREATE POLICY materials_service_all ON public.cs_event_materials TO service_role USING (true) WITH CHECK (true);


--
-- Name: meetings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;

--
-- Name: member_calls_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.member_calls_history ENABLE ROW LEVEL SECURITY;

--
-- Name: member_daily_activity; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.member_daily_activity ENABLE ROW LEVEL SECURITY;

--
-- Name: member_engagement_snapshots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.member_engagement_snapshots ENABLE ROW LEVEL SECURITY;

--
-- Name: member_lessons_progress; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.member_lessons_progress ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_ads_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_ads_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_ads_ad_data; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_ads_ad_data ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_ads_conversions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_ads_conversions ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_ads_daily_data; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_ads_daily_data ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_ads_sync_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_ads_sync_log ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_lead_ads_forms; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_lead_ads_forms ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_lead_ads_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_lead_ads_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: meta_lead_ads_pages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meta_lead_ads_pages ENABLE ROW LEVEL SECURITY;

--
-- Name: noshow_followups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.noshow_followups ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: nps_survey_schedule; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nps_survey_schedule ENABLE ROW LEVEL SECURITY;

--
-- Name: onboarding_stages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.onboarding_stages ENABLE ROW LEVEL SECURITY;

--
-- Name: onboarding_stages onboarding_stages_admin; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS onboarding_stages_admin ON public.onboarding_stages;
CREATE POLICY onboarding_stages_admin ON public.onboarding_stages USING (public.is_superadmin());


--
-- Name: onboarding_stages onboarding_stages_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS onboarding_stages_select ON public.onboarding_stages;
CREATE POLICY onboarding_stages_select ON public.onboarding_stages FOR SELECT USING (((tenant_id = public.get_tenant_id()) OR public.is_superadmin()));


--
-- Name: onboardings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.onboardings ENABLE ROW LEVEL SECURITY;

--
-- Name: organization_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;

--
-- Name: organization_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organization_products ENABLE ROW LEVEL SECURITY;

--
-- Name: organizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

--
-- Name: pain_registrations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pain_registrations ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_gateway_fees; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_gateway_fees ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_gateways; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_gateways ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_buscas pb_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS pb_authenticated_all ON public.prospeccao_buscas;
CREATE POLICY pb_authenticated_all ON public.prospeccao_buscas TO authenticated USING (true) WITH CHECK (true);


--
-- Name: prospeccao_diagnosticos pd_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS pd_authenticated_all ON public.prospeccao_diagnosticos;
CREATE POLICY pd_authenticated_all ON public.prospeccao_diagnosticos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: prospeccao_leads_descobertos pld_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS pld_authenticated_all ON public.prospeccao_leads_descobertos;
CREATE POLICY pld_authenticated_all ON public.prospeccao_leads_descobertos TO authenticated USING (true) WITH CHECK (true);


--
-- Name: prospeccao_prompts_config ppc_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS ppc_authenticated_all ON public.prospeccao_prompts_config;
CREATE POLICY ppc_authenticated_all ON public.prospeccao_prompts_config TO authenticated USING (true) WITH CHECK (true);


--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: cs_event_participant_profiles profiles_anon_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS profiles_anon_insert ON public.cs_event_participant_profiles;
CREATE POLICY profiles_anon_insert ON public.cs_event_participant_profiles FOR INSERT TO anon WITH CHECK (true);


--
-- Name: cs_event_participant_profiles profiles_anon_update; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS profiles_anon_update ON public.cs_event_participant_profiles;
CREATE POLICY profiles_anon_update ON public.cs_event_participant_profiles FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: cs_event_participant_profiles profiles_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS profiles_auth_all ON public.cs_event_participant_profiles;
CREATE POLICY profiles_auth_all ON public.cs_event_participant_profiles TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_participant_profiles profiles_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS profiles_select_all ON public.cs_event_participant_profiles;
CREATE POLICY profiles_select_all ON public.cs_event_participant_profiles FOR SELECT USING (true);


--
-- Name: cs_event_participant_profiles profiles_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS profiles_service_all ON public.cs_event_participant_profiles;
CREATE POLICY profiles_service_all ON public.cs_event_participant_profiles TO service_role USING (true) WITH CHECK (true);


--
-- Name: prospeccao_buscas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prospeccao_buscas ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_diagnosticos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prospeccao_diagnosticos ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_leads_descobertos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prospeccao_leads_descobertos ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_prompts_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prospeccao_prompts_config ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_templates_nicho; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prospeccao_templates_nicho ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_uso_api; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prospeccao_uso_api ENABLE ROW LEVEL SECURITY;

--
-- Name: prospeccao_templates_nicho ptn_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS ptn_authenticated_all ON public.prospeccao_templates_nicho;
CREATE POLICY ptn_authenticated_all ON public.prospeccao_templates_nicho TO authenticated USING (true) WITH CHECK (true);


--
-- Name: prospeccao_uso_api pua_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS pua_authenticated_all ON public.prospeccao_uso_api;
CREATE POLICY pua_authenticated_all ON public.prospeccao_uso_api TO authenticated USING (true) WITH CHECK (true);


--
-- Name: receive_lead_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receive_lead_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_alerts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_alerts ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_automation_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_automation_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_materials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_pipeline_stages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_pipeline_stages ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_pipeline_transitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_pipeline_transitions ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_pipelines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_pipelines ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_playbook; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sales_playbook ENABLE ROW LEVEL SECURITY;

--
-- Name: sales_playbook sales_playbook_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sales_playbook_all ON public.sales_playbook;
CREATE POLICY sales_playbook_all ON public.sales_playbook TO authenticated USING (true) WITH CHECK (true);


--
-- Name: sales_playbook sales_playbook_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sales_playbook_select ON public.sales_playbook;
CREATE POLICY sales_playbook_select ON public.sales_playbook FOR SELECT TO authenticated USING (true);


--
-- Name: cs_event_schedule_bookmarks schedule_bookmarks_anon_delete; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_bookmarks_anon_delete ON public.cs_event_schedule_bookmarks;
CREATE POLICY schedule_bookmarks_anon_delete ON public.cs_event_schedule_bookmarks FOR DELETE TO anon USING (true);


--
-- Name: cs_event_schedule_bookmarks schedule_bookmarks_anon_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_bookmarks_anon_insert ON public.cs_event_schedule_bookmarks;
CREATE POLICY schedule_bookmarks_anon_insert ON public.cs_event_schedule_bookmarks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: cs_event_schedule_bookmarks schedule_bookmarks_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_bookmarks_auth_all ON public.cs_event_schedule_bookmarks;
CREATE POLICY schedule_bookmarks_auth_all ON public.cs_event_schedule_bookmarks TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_schedule_bookmarks schedule_bookmarks_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_bookmarks_select_all ON public.cs_event_schedule_bookmarks;
CREATE POLICY schedule_bookmarks_select_all ON public.cs_event_schedule_bookmarks FOR SELECT USING (true);


--
-- Name: cs_event_schedule_bookmarks schedule_bookmarks_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_bookmarks_service_all ON public.cs_event_schedule_bookmarks;
CREATE POLICY schedule_bookmarks_service_all ON public.cs_event_schedule_bookmarks TO service_role USING (true) WITH CHECK (true);


--
-- Name: cs_event_schedule_items schedule_items_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_items_auth_all ON public.cs_event_schedule_items;
CREATE POLICY schedule_items_auth_all ON public.cs_event_schedule_items TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_schedule_items schedule_items_select_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_items_select_all ON public.cs_event_schedule_items;
CREATE POLICY schedule_items_select_all ON public.cs_event_schedule_items FOR SELECT USING (true);


--
-- Name: cs_event_schedule_items schedule_items_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS schedule_items_service_all ON public.cs_event_schedule_items;
CREATE POLICY schedule_items_service_all ON public.cs_event_schedule_items TO service_role USING (true) WITH CHECK (true);


--
-- Name: scheduled_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.scheduled_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: scheduled_messages scheduled_messages_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS scheduled_messages_all ON public.scheduled_messages;
CREATE POLICY scheduled_messages_all ON public.scheduled_messages TO authenticated USING (true) WITH CHECK (true);


--
-- Name: sdr_closer_transfers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sdr_closer_transfers ENABLE ROW LEVEL SECURITY;

--
-- Name: sdr_closer_transfers sdr_closer_transfers_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sdr_closer_transfers_insert ON public.sdr_closer_transfers;
CREATE POLICY sdr_closer_transfers_insert ON public.sdr_closer_transfers FOR INSERT TO authenticated WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: sdr_closer_transfers sdr_closer_transfers_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sdr_closer_transfers_select ON public.sdr_closer_transfers;
CREATE POLICY sdr_closer_transfers_select ON public.sdr_closer_transfers FOR SELECT TO authenticated USING ((tenant_id = public.get_tenant_id()));


--
-- Name: sdr_closer_transfers sdr_closer_transfers_update; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sdr_closer_transfers_update ON public.sdr_closer_transfers;
CREATE POLICY sdr_closer_transfers_update ON public.sdr_closer_transfers FOR UPDATE TO authenticated USING ((tenant_id = public.get_tenant_id()));


--
-- Name: cs_event_participant_sessions sessions_anon_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sessions_anon_select ON public.cs_event_participant_sessions;
CREATE POLICY sessions_anon_select ON public.cs_event_participant_sessions FOR SELECT TO anon USING (true);


--
-- Name: cs_event_participant_sessions sessions_auth_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sessions_auth_all ON public.cs_event_participant_sessions;
CREATE POLICY sessions_auth_all ON public.cs_event_participant_sessions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: cs_event_participant_sessions sessions_service_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS sessions_service_all ON public.cs_event_participant_sessions;
CREATE POLICY sessions_service_all ON public.cs_event_participant_sessions TO service_role USING (true) WITH CHECK (true);


--
-- Name: social_seller_alerts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_seller_alerts ENABLE ROW LEVEL SECURITY;

--
-- Name: social_seller_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_seller_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: social_seller_stages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_seller_stages ENABLE ROW LEVEL SECURITY;

--
-- Name: social_selling_automations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_selling_automations ENABLE ROW LEVEL SECURITY;

--
-- Name: social_selling_enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_selling_enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: social_selling_interactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_selling_interactions ENABLE ROW LEVEL SECURITY;

--
-- Name: social_selling_known_followers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_selling_known_followers ENABLE ROW LEVEL SECURITY;

--
-- Name: social_selling_qualification_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_selling_qualification_log ENABLE ROW LEVEL SECURITY;

--
-- Name: team_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_agent_cadence_enrollments tenant_access; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_access ON public.ai_agent_cadence_enrollments;
CREATE POLICY tenant_access ON public.ai_agent_cadence_enrollments USING ((tenant_id = public.get_tenant_id()));


--
-- Name: ai_agent_scheduled_followups tenant_access; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_access ON public.ai_agent_scheduled_followups;
CREATE POLICY tenant_access ON public.ai_agent_scheduled_followups USING ((tenant_id = public.get_tenant_id()));


--
-- Name: ai_agent_send_counts tenant_access; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_access ON public.ai_agent_send_counts;
CREATE POLICY tenant_access ON public.ai_agent_send_counts USING ((tenant_id = public.get_tenant_id()));


--
-- Name: profiles tenant_admin_delete_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_admin_delete_profiles ON public.profiles;
CREATE POLICY tenant_admin_delete_profiles ON public.profiles FOR DELETE TO authenticated USING (((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)) AND (EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND (p.role = 'admin'::text) AND (p.tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)))))));


--
-- Name: team_members tenant_admin_delete_team_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_admin_delete_team_members ON public.team_members;
CREATE POLICY tenant_admin_delete_team_members ON public.team_members FOR DELETE USING (((tenant_id = public.get_tenant_id()) AND public.is_tenant_admin()));


--
-- Name: profiles tenant_admin_update_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_admin_update_profiles ON public.profiles;
CREATE POLICY tenant_admin_update_profiles ON public.profiles FOR UPDATE TO authenticated USING (((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)) AND (EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND (p.role = 'admin'::text) AND (p.tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)))))));


--
-- Name: team_members tenant_admin_update_team_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_admin_update_team_members ON public.team_members;
CREATE POLICY tenant_admin_update_team_members ON public.team_members FOR UPDATE USING (((tenant_id = public.get_tenant_id()) AND public.is_tenant_admin())) WITH CHECK (((tenant_id = public.get_tenant_id()) AND public.is_tenant_admin()));


--
-- Name: social_selling_qualification_log tenant_all_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_all_log ON public.social_selling_qualification_log;
CREATE POLICY tenant_all_log ON public.social_selling_qualification_log USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_automations tenant_all_ssa; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_all_ssa ON public.social_selling_automations;
CREATE POLICY tenant_all_ssa ON public.social_selling_automations USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: tenant_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_config ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_config tenant_config_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_config_insert ON public.tenant_config;
CREATE POLICY tenant_config_insert ON public.tenant_config FOR INSERT WITH CHECK (public.is_superadmin());


--
-- Name: tenant_config tenant_config_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_config_select ON public.tenant_config;
CREATE POLICY tenant_config_select ON public.tenant_config FOR SELECT USING (((tenant_id = public.get_tenant_id()) OR public.is_superadmin()));


--
-- Name: tenant_config tenant_config_update; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_config_update ON public.tenant_config;
CREATE POLICY tenant_config_update ON public.tenant_config FOR UPDATE USING (public.is_superadmin());


--
-- Name: ai_agent_conversations tenant_delete_ai_agent_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_ai_agent_conversations ON public.ai_agent_conversations;
CREATE POLICY tenant_delete_ai_agent_conversations ON public.ai_agent_conversations FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_logs tenant_delete_ai_agent_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_ai_agent_logs ON public.ai_agent_logs;
CREATE POLICY tenant_delete_ai_agent_logs ON public.ai_agent_logs FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_message_queue tenant_delete_ai_agent_message_queue; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_ai_agent_message_queue ON public.ai_agent_message_queue;
CREATE POLICY tenant_delete_ai_agent_message_queue ON public.ai_agent_message_queue FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_tools tenant_delete_ai_agent_tools; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_ai_agent_tools ON public.ai_agent_tools;
CREATE POLICY tenant_delete_ai_agent_tools ON public.ai_agent_tools FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_sales_agents tenant_delete_ai_sales_agents; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_ai_sales_agents ON public.ai_sales_agents;
CREATE POLICY tenant_delete_ai_sales_agents ON public.ai_sales_agents FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: analysis_templates tenant_delete_analysis_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_analysis_templates ON public.analysis_templates;
CREATE POLICY tenant_delete_analysis_templates ON public.analysis_templates FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_customers tenant_delete_asaas_customers; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_asaas_customers ON public.asaas_customers;
CREATE POLICY tenant_delete_asaas_customers ON public.asaas_customers FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_webhooks tenant_delete_asaas_webhooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_asaas_webhooks ON public.asaas_webhooks;
CREATE POLICY tenant_delete_asaas_webhooks ON public.asaas_webhooks FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: calendar_events tenant_delete_calendar_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_calendar_events ON public.calendar_events;
CREATE POLICY tenant_delete_calendar_events ON public.calendar_events FOR DELETE TO authenticated USING (((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)) AND (team_member_id = auth.uid())));


--
-- Name: call_history tenant_delete_call_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_call_history ON public.call_history;
CREATE POLICY tenant_delete_call_history ON public.call_history FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_configs tenant_delete_chat_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_chat_configs ON public.chat_configs;
CREATE POLICY tenant_delete_chat_configs ON public.chat_configs FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_messages tenant_delete_chat_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_chat_messages ON public.chat_messages;
CREATE POLICY tenant_delete_chat_messages ON public.chat_messages FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_sessions tenant_delete_chat_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_chat_sessions ON public.chat_sessions;
CREATE POLICY tenant_delete_chat_sessions ON public.chat_sessions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_playbooks tenant_delete_coach_playbooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_coach_playbooks ON public.coach_playbooks;
CREATE POLICY tenant_delete_coach_playbooks ON public.coach_playbooks FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_sessions tenant_delete_coach_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_coach_sessions ON public.coach_sessions;
CREATE POLICY tenant_delete_coach_sessions ON public.coach_sessions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commission_rules tenant_delete_commission_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_commission_rules ON public.commission_rules;
CREATE POLICY tenant_delete_commission_rules ON public.commission_rules FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commissions tenant_delete_commissions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_commissions ON public.commissions;
CREATE POLICY tenant_delete_commissions ON public.commissions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: company_activities tenant_delete_company_activities; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_company_activities ON public.company_activities;
CREATE POLICY tenant_delete_company_activities ON public.company_activities FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_handled tenant_delete_cs_conversation_handled; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_conversation_handled ON public.cs_conversation_handled;
CREATE POLICY tenant_delete_cs_conversation_handled ON public.cs_conversation_handled FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_notes tenant_delete_cs_conversation_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_conversation_notes ON public.cs_conversation_notes;
CREATE POLICY tenant_delete_cs_conversation_notes ON public.cs_conversation_notes FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_engagement_metrics tenant_delete_cs_engagement_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_engagement_metrics ON public.cs_engagement_metrics;
CREATE POLICY tenant_delete_cs_engagement_metrics ON public.cs_engagement_metrics FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_event_rsvps tenant_delete_cs_event_rsvps; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_event_rsvps ON public.cs_event_rsvps;
CREATE POLICY tenant_delete_cs_event_rsvps ON public.cs_event_rsvps FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_events tenant_delete_cs_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_events ON public.cs_events;
CREATE POLICY tenant_delete_cs_events ON public.cs_events FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_current tenant_delete_cs_health_current; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_health_current ON public.cs_health_current;
CREATE POLICY tenant_delete_cs_health_current ON public.cs_health_current FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_scores_history tenant_delete_cs_health_scores_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_health_scores_history ON public.cs_health_scores_history;
CREATE POLICY tenant_delete_cs_health_scores_history ON public.cs_health_scores_history FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_inbox_metrics tenant_delete_cs_inbox_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_inbox_metrics ON public.cs_inbox_metrics;
CREATE POLICY tenant_delete_cs_inbox_metrics ON public.cs_inbox_metrics FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_interactions tenant_delete_cs_interactions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_interactions ON public.cs_interactions;
CREATE POLICY tenant_delete_cs_interactions ON public.cs_interactions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_objectives tenant_delete_cs_objectives; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_objectives ON public.cs_objectives;
CREATE POLICY tenant_delete_cs_objectives ON public.cs_objectives FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_response_templates tenant_delete_cs_response_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_response_templates ON public.cs_response_templates;
CREATE POLICY tenant_delete_cs_response_templates ON public.cs_response_templates FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_success_metrics tenant_delete_cs_success_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_success_metrics ON public.cs_success_metrics;
CREATE POLICY tenant_delete_cs_success_metrics ON public.cs_success_metrics FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_touchpoints tenant_delete_cs_touchpoints; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_cs_touchpoints ON public.cs_touchpoints;
CREATE POLICY tenant_delete_cs_touchpoints ON public.cs_touchpoints FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_contacts tenant_delete_deal_contacts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_deal_contacts ON public.deal_contacts;
CREATE POLICY tenant_delete_deal_contacts ON public.deal_contacts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_loss_reasons tenant_delete_deal_loss_reasons; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_deal_loss_reasons ON public.deal_loss_reasons;
CREATE POLICY tenant_delete_deal_loss_reasons ON public.deal_loss_reasons FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payment_installments tenant_delete_deal_payment_installments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_deal_payment_installments ON public.deal_payment_installments;
CREATE POLICY tenant_delete_deal_payment_installments ON public.deal_payment_installments FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payments tenant_delete_deal_payments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_deal_payments ON public.deal_payments;
CREATE POLICY tenant_delete_deal_payments ON public.deal_payments FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deals tenant_delete_deals; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_deals ON public.deals;
CREATE POLICY tenant_delete_deals ON public.deals FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_accounts tenant_delete_financial_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_financial_accounts ON public.financial_accounts;
CREATE POLICY tenant_delete_financial_accounts ON public.financial_accounts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_categories tenant_delete_financial_categories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_financial_categories ON public.financial_categories;
CREATE POLICY tenant_delete_financial_categories ON public.financial_categories FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_entries tenant_delete_financial_entries; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_financial_entries ON public.financial_entries;
CREATE POLICY tenant_delete_financial_entries ON public.financial_entries FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_accounts tenant_delete_google_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_google_ads_accounts ON public.google_ads_accounts;
CREATE POLICY tenant_delete_google_ads_accounts ON public.google_ads_accounts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_campaign_data tenant_delete_google_ads_campaign_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_google_ads_campaign_data ON public.google_ads_campaign_data;
CREATE POLICY tenant_delete_google_ads_campaign_data ON public.google_ads_campaign_data FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_daily_data tenant_delete_google_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_google_ads_daily_data ON public.google_ads_daily_data;
CREATE POLICY tenant_delete_google_ads_daily_data ON public.google_ads_daily_data FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_business_accounts tenant_delete_instagram_business_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_business_accounts ON public.instagram_business_accounts;
CREATE POLICY tenant_delete_instagram_business_accounts ON public.instagram_business_accounts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_comments tenant_delete_instagram_comments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_comments ON public.instagram_comments;
CREATE POLICY tenant_delete_instagram_comments ON public.instagram_comments FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_conversations tenant_delete_instagram_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_conversations ON public.instagram_conversations;
CREATE POLICY tenant_delete_instagram_conversations ON public.instagram_conversations FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_engagement tenant_delete_instagram_engagement; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_engagement ON public.instagram_engagement;
CREATE POLICY tenant_delete_instagram_engagement ON public.instagram_engagement FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_feed_posts tenant_delete_instagram_feed_posts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_feed_posts ON public.instagram_feed_posts;
CREATE POLICY tenant_delete_instagram_feed_posts ON public.instagram_feed_posts FOR DELETE USING ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_messages tenant_delete_instagram_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_messages ON public.instagram_messages;
CREATE POLICY tenant_delete_instagram_messages ON public.instagram_messages FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_profiles tenant_delete_instagram_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_profiles ON public.instagram_profiles;
CREATE POLICY tenant_delete_instagram_profiles ON public.instagram_profiles FOR DELETE USING ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_stories tenant_delete_instagram_stories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_instagram_stories ON public.instagram_stories;
CREATE POLICY tenant_delete_instagram_stories ON public.instagram_stories FOR DELETE USING ((tenant_id = public.get_tenant_id()));


--
-- Name: integration_settings tenant_delete_integration_settings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_integration_settings ON public.integration_settings;
CREATE POLICY tenant_delete_integration_settings ON public.integration_settings FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_conversions tenant_delete_lead_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_lead_conversions ON public.lead_conversions;
CREATE POLICY tenant_delete_lead_conversions ON public.lead_conversions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_diagnostics_v2 tenant_delete_lead_diagnostics_v2; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_lead_diagnostics_v2 ON public.lead_diagnostics_v2;
CREATE POLICY tenant_delete_lead_diagnostics_v2 ON public.lead_diagnostics_v2 FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_config tenant_delete_lead_distribution_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_lead_distribution_config ON public.lead_distribution_config;
CREATE POLICY tenant_delete_lead_distribution_config ON public.lead_distribution_config FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_log tenant_delete_lead_distribution_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_lead_distribution_log ON public.lead_distribution_log;
CREATE POLICY tenant_delete_lead_distribution_log ON public.lead_distribution_log FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_members tenant_delete_lead_distribution_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_lead_distribution_members ON public.lead_distribution_members;
CREATE POLICY tenant_delete_lead_distribution_members ON public.lead_distribution_members FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: leads tenant_delete_leads; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_leads ON public.leads;
CREATE POLICY tenant_delete_leads ON public.leads FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: llm_provider_configs tenant_delete_llm_provider_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_llm_provider_configs ON public.llm_provider_configs;
CREATE POLICY tenant_delete_llm_provider_configs ON public.llm_provider_configs FOR DELETE USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meetings tenant_delete_meetings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_meetings ON public.meetings;
CREATE POLICY tenant_delete_meetings ON public.meetings FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_calls_history tenant_delete_member_calls_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_member_calls_history ON public.member_calls_history;
CREATE POLICY tenant_delete_member_calls_history ON public.member_calls_history FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_daily_activity tenant_delete_member_daily_activity; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_member_daily_activity ON public.member_daily_activity;
CREATE POLICY tenant_delete_member_daily_activity ON public.member_daily_activity FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_engagement_snapshots tenant_delete_member_engagement_snapshots; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_member_engagement_snapshots ON public.member_engagement_snapshots;
CREATE POLICY tenant_delete_member_engagement_snapshots ON public.member_engagement_snapshots FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_lessons_progress tenant_delete_member_lessons_progress; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_member_lessons_progress ON public.member_lessons_progress;
CREATE POLICY tenant_delete_member_lessons_progress ON public.member_lessons_progress FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_accounts tenant_delete_meta_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_meta_ads_accounts ON public.meta_ads_accounts;
CREATE POLICY tenant_delete_meta_ads_accounts ON public.meta_ads_accounts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_ad_data tenant_delete_meta_ads_ad_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_meta_ads_ad_data ON public.meta_ads_ad_data;
CREATE POLICY tenant_delete_meta_ads_ad_data ON public.meta_ads_ad_data FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_conversions tenant_delete_meta_ads_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_meta_ads_conversions ON public.meta_ads_conversions;
CREATE POLICY tenant_delete_meta_ads_conversions ON public.meta_ads_conversions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_daily_data tenant_delete_meta_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_meta_ads_daily_data ON public.meta_ads_daily_data;
CREATE POLICY tenant_delete_meta_ads_daily_data ON public.meta_ads_daily_data FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_sync_log tenant_delete_meta_ads_sync_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_meta_ads_sync_log ON public.meta_ads_sync_log;
CREATE POLICY tenant_delete_meta_ads_sync_log ON public.meta_ads_sync_log FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_logs tenant_delete_notification_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_notification_logs ON public.notification_logs;
CREATE POLICY tenant_delete_notification_logs ON public.notification_logs FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_rules tenant_delete_notification_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_notification_rules ON public.notification_rules;
CREATE POLICY tenant_delete_notification_rules ON public.notification_rules FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: onboardings tenant_delete_onboardings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_onboardings ON public.onboardings;
CREATE POLICY tenant_delete_onboardings ON public.onboardings FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_members tenant_delete_organization_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_organization_members ON public.organization_members;
CREATE POLICY tenant_delete_organization_members ON public.organization_members FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_products tenant_delete_organization_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_organization_products ON public.organization_products;
CREATE POLICY tenant_delete_organization_products ON public.organization_products FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organizations tenant_delete_organizations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_organizations ON public.organizations;
CREATE POLICY tenant_delete_organizations ON public.organizations FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: pain_registrations tenant_delete_pain_registrations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_pain_registrations ON public.pain_registrations;
CREATE POLICY tenant_delete_pain_registrations ON public.pain_registrations FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateway_fees tenant_delete_payment_gateway_fees; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_payment_gateway_fees ON public.payment_gateway_fees;
CREATE POLICY tenant_delete_payment_gateway_fees ON public.payment_gateway_fees FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateways tenant_delete_payment_gateways; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_payment_gateways ON public.payment_gateways;
CREATE POLICY tenant_delete_payment_gateways ON public.payment_gateways FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: products tenant_delete_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_products ON public.products;
CREATE POLICY tenant_delete_products ON public.products FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: receive_lead_logs tenant_delete_receive_lead_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_receive_lead_logs ON public.receive_lead_logs;
CREATE POLICY tenant_delete_receive_lead_logs ON public.receive_lead_logs FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_alerts tenant_delete_sales_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_alerts ON public.sales_alerts;
CREATE POLICY tenant_delete_sales_alerts ON public.sales_alerts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_automation_rules tenant_delete_sales_automation_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_automation_rules ON public.sales_automation_rules;
CREATE POLICY tenant_delete_sales_automation_rules ON public.sales_automation_rules FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_materials tenant_delete_sales_materials; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_materials ON public.sales_materials;
CREATE POLICY tenant_delete_sales_materials ON public.sales_materials FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_notes tenant_delete_sales_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_notes ON public.sales_notes;
CREATE POLICY tenant_delete_sales_notes ON public.sales_notes FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_stages tenant_delete_sales_pipeline_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_pipeline_stages ON public.sales_pipeline_stages;
CREATE POLICY tenant_delete_sales_pipeline_stages ON public.sales_pipeline_stages FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_transitions tenant_delete_sales_pipeline_transitions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_pipeline_transitions ON public.sales_pipeline_transitions;
CREATE POLICY tenant_delete_sales_pipeline_transitions ON public.sales_pipeline_transitions FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipelines tenant_delete_sales_pipelines; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sales_pipelines ON public.sales_pipelines;
CREATE POLICY tenant_delete_sales_pipelines ON public.sales_pipelines FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_alerts tenant_delete_social_seller_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_social_seller_alerts ON public.social_seller_alerts;
CREATE POLICY tenant_delete_social_seller_alerts ON public.social_seller_alerts FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_rules tenant_delete_social_seller_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_social_seller_rules ON public.social_seller_rules;
CREATE POLICY tenant_delete_social_seller_rules ON public.social_seller_rules FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_stages tenant_delete_social_seller_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_social_seller_stages ON public.social_seller_stages;
CREATE POLICY tenant_delete_social_seller_stages ON public.social_seller_stages FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_enrollments tenant_delete_sse; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_sse ON public.social_selling_enrollments;
CREATE POLICY tenant_delete_sse ON public.social_selling_enrollments FOR DELETE USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_known_followers tenant_delete_ssn; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_ssn ON public.social_selling_known_followers;
CREATE POLICY tenant_delete_ssn ON public.social_selling_known_followers FOR DELETE USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: wavoip_devices tenant_delete_wavoip_devices; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_wavoip_devices ON public.wavoip_devices;
CREATE POLICY tenant_delete_wavoip_devices ON public.wavoip_devices FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_group_members tenant_delete_whatsapp_group_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_whatsapp_group_members ON public.whatsapp_group_members;
CREATE POLICY tenant_delete_whatsapp_group_members ON public.whatsapp_group_members FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_groups tenant_delete_whatsapp_groups; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_whatsapp_groups ON public.whatsapp_groups;
CREATE POLICY tenant_delete_whatsapp_groups ON public.whatsapp_groups FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_instances tenant_delete_whatsapp_instances; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_whatsapp_instances ON public.whatsapp_instances;
CREATE POLICY tenant_delete_whatsapp_instances ON public.whatsapp_instances FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_messages tenant_delete_whatsapp_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_whatsapp_messages ON public.whatsapp_messages;
CREATE POLICY tenant_delete_whatsapp_messages ON public.whatsapp_messages FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_config tenant_delete_whatsapp_task_bot_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_whatsapp_task_bot_config ON public.whatsapp_task_bot_config;
CREATE POLICY tenant_delete_whatsapp_task_bot_config ON public.whatsapp_task_bot_config FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_logs tenant_delete_whatsapp_task_bot_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_delete_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs;
CREATE POLICY tenant_delete_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs FOR DELETE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_conversations tenant_insert_ai_agent_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ai_agent_conversations ON public.ai_agent_conversations;
CREATE POLICY tenant_insert_ai_agent_conversations ON public.ai_agent_conversations FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_logs tenant_insert_ai_agent_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ai_agent_logs ON public.ai_agent_logs;
CREATE POLICY tenant_insert_ai_agent_logs ON public.ai_agent_logs FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_message_queue tenant_insert_ai_agent_message_queue; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ai_agent_message_queue ON public.ai_agent_message_queue;
CREATE POLICY tenant_insert_ai_agent_message_queue ON public.ai_agent_message_queue FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_tools tenant_insert_ai_agent_tools; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ai_agent_tools ON public.ai_agent_tools;
CREATE POLICY tenant_insert_ai_agent_tools ON public.ai_agent_tools FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_sales_agents tenant_insert_ai_sales_agents; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ai_sales_agents ON public.ai_sales_agents;
CREATE POLICY tenant_insert_ai_sales_agents ON public.ai_sales_agents FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: analysis_templates tenant_insert_analysis_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_analysis_templates ON public.analysis_templates;
CREATE POLICY tenant_insert_analysis_templates ON public.analysis_templates FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_customers tenant_insert_asaas_customers; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_asaas_customers ON public.asaas_customers;
CREATE POLICY tenant_insert_asaas_customers ON public.asaas_customers FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_webhooks tenant_insert_asaas_webhooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_asaas_webhooks ON public.asaas_webhooks;
CREATE POLICY tenant_insert_asaas_webhooks ON public.asaas_webhooks FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: calendar_events tenant_insert_calendar_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_calendar_events ON public.calendar_events;
CREATE POLICY tenant_insert_calendar_events ON public.calendar_events FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: call_history tenant_insert_call_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_call_history ON public.call_history;
CREATE POLICY tenant_insert_call_history ON public.call_history FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_configs tenant_insert_chat_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_chat_configs ON public.chat_configs;
CREATE POLICY tenant_insert_chat_configs ON public.chat_configs FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_messages tenant_insert_chat_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_chat_messages ON public.chat_messages;
CREATE POLICY tenant_insert_chat_messages ON public.chat_messages FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_sessions tenant_insert_chat_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_chat_sessions ON public.chat_sessions;
CREATE POLICY tenant_insert_chat_sessions ON public.chat_sessions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_playbooks tenant_insert_coach_playbooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_coach_playbooks ON public.coach_playbooks;
CREATE POLICY tenant_insert_coach_playbooks ON public.coach_playbooks FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_sessions tenant_insert_coach_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_coach_sessions ON public.coach_sessions;
CREATE POLICY tenant_insert_coach_sessions ON public.coach_sessions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commission_rules tenant_insert_commission_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_commission_rules ON public.commission_rules;
CREATE POLICY tenant_insert_commission_rules ON public.commission_rules FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commissions tenant_insert_commissions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_commissions ON public.commissions;
CREATE POLICY tenant_insert_commissions ON public.commissions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: company_activities tenant_insert_company_activities; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_company_activities ON public.company_activities;
CREATE POLICY tenant_insert_company_activities ON public.company_activities FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_handled tenant_insert_cs_conversation_handled; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_conversation_handled ON public.cs_conversation_handled;
CREATE POLICY tenant_insert_cs_conversation_handled ON public.cs_conversation_handled FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_notes tenant_insert_cs_conversation_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_conversation_notes ON public.cs_conversation_notes;
CREATE POLICY tenant_insert_cs_conversation_notes ON public.cs_conversation_notes FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_engagement_metrics tenant_insert_cs_engagement_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_engagement_metrics ON public.cs_engagement_metrics;
CREATE POLICY tenant_insert_cs_engagement_metrics ON public.cs_engagement_metrics FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_event_rsvps tenant_insert_cs_event_rsvps; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_event_rsvps ON public.cs_event_rsvps;
CREATE POLICY tenant_insert_cs_event_rsvps ON public.cs_event_rsvps FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_events tenant_insert_cs_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_events ON public.cs_events;
CREATE POLICY tenant_insert_cs_events ON public.cs_events FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_current tenant_insert_cs_health_current; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_health_current ON public.cs_health_current;
CREATE POLICY tenant_insert_cs_health_current ON public.cs_health_current FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_scores_history tenant_insert_cs_health_scores_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_health_scores_history ON public.cs_health_scores_history;
CREATE POLICY tenant_insert_cs_health_scores_history ON public.cs_health_scores_history FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_inbox_metrics tenant_insert_cs_inbox_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_inbox_metrics ON public.cs_inbox_metrics;
CREATE POLICY tenant_insert_cs_inbox_metrics ON public.cs_inbox_metrics FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_interactions tenant_insert_cs_interactions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_interactions ON public.cs_interactions;
CREATE POLICY tenant_insert_cs_interactions ON public.cs_interactions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_objectives tenant_insert_cs_objectives; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_objectives ON public.cs_objectives;
CREATE POLICY tenant_insert_cs_objectives ON public.cs_objectives FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_response_templates tenant_insert_cs_response_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_response_templates ON public.cs_response_templates;
CREATE POLICY tenant_insert_cs_response_templates ON public.cs_response_templates FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_success_metrics tenant_insert_cs_success_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_success_metrics ON public.cs_success_metrics;
CREATE POLICY tenant_insert_cs_success_metrics ON public.cs_success_metrics FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_touchpoints tenant_insert_cs_touchpoints; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_cs_touchpoints ON public.cs_touchpoints;
CREATE POLICY tenant_insert_cs_touchpoints ON public.cs_touchpoints FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_contacts tenant_insert_deal_contacts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_deal_contacts ON public.deal_contacts;
CREATE POLICY tenant_insert_deal_contacts ON public.deal_contacts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_loss_reasons tenant_insert_deal_loss_reasons; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_deal_loss_reasons ON public.deal_loss_reasons;
CREATE POLICY tenant_insert_deal_loss_reasons ON public.deal_loss_reasons FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payment_installments tenant_insert_deal_payment_installments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_deal_payment_installments ON public.deal_payment_installments;
CREATE POLICY tenant_insert_deal_payment_installments ON public.deal_payment_installments FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payments tenant_insert_deal_payments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_deal_payments ON public.deal_payments;
CREATE POLICY tenant_insert_deal_payments ON public.deal_payments FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deals tenant_insert_deals; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_deals ON public.deals;
CREATE POLICY tenant_insert_deals ON public.deals FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_accounts tenant_insert_financial_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_financial_accounts ON public.financial_accounts;
CREATE POLICY tenant_insert_financial_accounts ON public.financial_accounts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_categories tenant_insert_financial_categories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_financial_categories ON public.financial_categories;
CREATE POLICY tenant_insert_financial_categories ON public.financial_categories FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_entries tenant_insert_financial_entries; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_financial_entries ON public.financial_entries;
CREATE POLICY tenant_insert_financial_entries ON public.financial_entries FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_accounts tenant_insert_google_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_google_ads_accounts ON public.google_ads_accounts;
CREATE POLICY tenant_insert_google_ads_accounts ON public.google_ads_accounts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_campaign_data tenant_insert_google_ads_campaign_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_google_ads_campaign_data ON public.google_ads_campaign_data;
CREATE POLICY tenant_insert_google_ads_campaign_data ON public.google_ads_campaign_data FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_daily_data tenant_insert_google_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_google_ads_daily_data ON public.google_ads_daily_data;
CREATE POLICY tenant_insert_google_ads_daily_data ON public.google_ads_daily_data FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_business_accounts tenant_insert_instagram_business_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_business_accounts ON public.instagram_business_accounts;
CREATE POLICY tenant_insert_instagram_business_accounts ON public.instagram_business_accounts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_comments tenant_insert_instagram_comments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_comments ON public.instagram_comments;
CREATE POLICY tenant_insert_instagram_comments ON public.instagram_comments FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_conversations tenant_insert_instagram_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_conversations ON public.instagram_conversations;
CREATE POLICY tenant_insert_instagram_conversations ON public.instagram_conversations FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_engagement tenant_insert_instagram_engagement; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_engagement ON public.instagram_engagement;
CREATE POLICY tenant_insert_instagram_engagement ON public.instagram_engagement FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_feed_posts tenant_insert_instagram_feed_posts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_feed_posts ON public.instagram_feed_posts;
CREATE POLICY tenant_insert_instagram_feed_posts ON public.instagram_feed_posts FOR INSERT WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_messages tenant_insert_instagram_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_messages ON public.instagram_messages;
CREATE POLICY tenant_insert_instagram_messages ON public.instagram_messages FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_profiles tenant_insert_instagram_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_profiles ON public.instagram_profiles;
CREATE POLICY tenant_insert_instagram_profiles ON public.instagram_profiles FOR INSERT WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_stories tenant_insert_instagram_stories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_instagram_stories ON public.instagram_stories;
CREATE POLICY tenant_insert_instagram_stories ON public.instagram_stories FOR INSERT WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: integration_settings tenant_insert_integration_settings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_integration_settings ON public.integration_settings;
CREATE POLICY tenant_insert_integration_settings ON public.integration_settings FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_conversions tenant_insert_lead_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_lead_conversions ON public.lead_conversions;
CREATE POLICY tenant_insert_lead_conversions ON public.lead_conversions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_diagnostics_v2 tenant_insert_lead_diagnostics_v2; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_lead_diagnostics_v2 ON public.lead_diagnostics_v2;
CREATE POLICY tenant_insert_lead_diagnostics_v2 ON public.lead_diagnostics_v2 FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_config tenant_insert_lead_distribution_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_lead_distribution_config ON public.lead_distribution_config;
CREATE POLICY tenant_insert_lead_distribution_config ON public.lead_distribution_config FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_log tenant_insert_lead_distribution_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_lead_distribution_log ON public.lead_distribution_log;
CREATE POLICY tenant_insert_lead_distribution_log ON public.lead_distribution_log FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_members tenant_insert_lead_distribution_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_lead_distribution_members ON public.lead_distribution_members;
CREATE POLICY tenant_insert_lead_distribution_members ON public.lead_distribution_members FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: leads tenant_insert_leads; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_leads ON public.leads;
CREATE POLICY tenant_insert_leads ON public.leads FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: llm_provider_configs tenant_insert_llm_provider_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_llm_provider_configs ON public.llm_provider_configs;
CREATE POLICY tenant_insert_llm_provider_configs ON public.llm_provider_configs FOR INSERT WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meetings tenant_insert_meetings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_meetings ON public.meetings;
CREATE POLICY tenant_insert_meetings ON public.meetings FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_calls_history tenant_insert_member_calls_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_member_calls_history ON public.member_calls_history;
CREATE POLICY tenant_insert_member_calls_history ON public.member_calls_history FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_daily_activity tenant_insert_member_daily_activity; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_member_daily_activity ON public.member_daily_activity;
CREATE POLICY tenant_insert_member_daily_activity ON public.member_daily_activity FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_engagement_snapshots tenant_insert_member_engagement_snapshots; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_member_engagement_snapshots ON public.member_engagement_snapshots;
CREATE POLICY tenant_insert_member_engagement_snapshots ON public.member_engagement_snapshots FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_lessons_progress tenant_insert_member_lessons_progress; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_member_lessons_progress ON public.member_lessons_progress;
CREATE POLICY tenant_insert_member_lessons_progress ON public.member_lessons_progress FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_accounts tenant_insert_meta_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_meta_ads_accounts ON public.meta_ads_accounts;
CREATE POLICY tenant_insert_meta_ads_accounts ON public.meta_ads_accounts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_ad_data tenant_insert_meta_ads_ad_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_meta_ads_ad_data ON public.meta_ads_ad_data;
CREATE POLICY tenant_insert_meta_ads_ad_data ON public.meta_ads_ad_data FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_conversions tenant_insert_meta_ads_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_meta_ads_conversions ON public.meta_ads_conversions;
CREATE POLICY tenant_insert_meta_ads_conversions ON public.meta_ads_conversions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_daily_data tenant_insert_meta_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_meta_ads_daily_data ON public.meta_ads_daily_data;
CREATE POLICY tenant_insert_meta_ads_daily_data ON public.meta_ads_daily_data FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_sync_log tenant_insert_meta_ads_sync_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_meta_ads_sync_log ON public.meta_ads_sync_log;
CREATE POLICY tenant_insert_meta_ads_sync_log ON public.meta_ads_sync_log FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_logs tenant_insert_notification_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_notification_logs ON public.notification_logs;
CREATE POLICY tenant_insert_notification_logs ON public.notification_logs FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_rules tenant_insert_notification_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_notification_rules ON public.notification_rules;
CREATE POLICY tenant_insert_notification_rules ON public.notification_rules FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: onboardings tenant_insert_onboardings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_onboardings ON public.onboardings;
CREATE POLICY tenant_insert_onboardings ON public.onboardings FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_members tenant_insert_organization_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_organization_members ON public.organization_members;
CREATE POLICY tenant_insert_organization_members ON public.organization_members FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_products tenant_insert_organization_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_organization_products ON public.organization_products;
CREATE POLICY tenant_insert_organization_products ON public.organization_products FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organizations tenant_insert_organizations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_organizations ON public.organizations;
CREATE POLICY tenant_insert_organizations ON public.organizations FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: pain_registrations tenant_insert_pain_registrations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_pain_registrations ON public.pain_registrations;
CREATE POLICY tenant_insert_pain_registrations ON public.pain_registrations FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateway_fees tenant_insert_payment_gateway_fees; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_payment_gateway_fees ON public.payment_gateway_fees;
CREATE POLICY tenant_insert_payment_gateway_fees ON public.payment_gateway_fees FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateways tenant_insert_payment_gateways; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_payment_gateways ON public.payment_gateways;
CREATE POLICY tenant_insert_payment_gateways ON public.payment_gateways FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: products tenant_insert_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_products ON public.products;
CREATE POLICY tenant_insert_products ON public.products FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: profiles tenant_insert_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_profiles ON public.profiles;
CREATE POLICY tenant_insert_profiles ON public.profiles FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: receive_lead_logs tenant_insert_receive_lead_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_receive_lead_logs ON public.receive_lead_logs;
CREATE POLICY tenant_insert_receive_lead_logs ON public.receive_lead_logs FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_alerts tenant_insert_sales_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_alerts ON public.sales_alerts;
CREATE POLICY tenant_insert_sales_alerts ON public.sales_alerts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_automation_rules tenant_insert_sales_automation_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_automation_rules ON public.sales_automation_rules;
CREATE POLICY tenant_insert_sales_automation_rules ON public.sales_automation_rules FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_materials tenant_insert_sales_materials; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_materials ON public.sales_materials;
CREATE POLICY tenant_insert_sales_materials ON public.sales_materials FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_notes tenant_insert_sales_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_notes ON public.sales_notes;
CREATE POLICY tenant_insert_sales_notes ON public.sales_notes FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_stages tenant_insert_sales_pipeline_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_pipeline_stages ON public.sales_pipeline_stages;
CREATE POLICY tenant_insert_sales_pipeline_stages ON public.sales_pipeline_stages FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_transitions tenant_insert_sales_pipeline_transitions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_pipeline_transitions ON public.sales_pipeline_transitions;
CREATE POLICY tenant_insert_sales_pipeline_transitions ON public.sales_pipeline_transitions FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipelines tenant_insert_sales_pipelines; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sales_pipelines ON public.sales_pipelines;
CREATE POLICY tenant_insert_sales_pipelines ON public.sales_pipelines FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_alerts tenant_insert_social_seller_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_social_seller_alerts ON public.social_seller_alerts;
CREATE POLICY tenant_insert_social_seller_alerts ON public.social_seller_alerts FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_rules tenant_insert_social_seller_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_social_seller_rules ON public.social_seller_rules;
CREATE POLICY tenant_insert_social_seller_rules ON public.social_seller_rules FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_stages tenant_insert_social_seller_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_social_seller_stages ON public.social_seller_stages;
CREATE POLICY tenant_insert_social_seller_stages ON public.social_seller_stages FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_enrollments tenant_insert_sse; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_sse ON public.social_selling_enrollments;
CREATE POLICY tenant_insert_sse ON public.social_selling_enrollments FOR INSERT WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_interactions tenant_insert_ssi; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ssi ON public.social_selling_interactions;
CREATE POLICY tenant_insert_ssi ON public.social_selling_interactions FOR INSERT WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_known_followers tenant_insert_ssn; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_ssn ON public.social_selling_known_followers;
CREATE POLICY tenant_insert_ssn ON public.social_selling_known_followers FOR INSERT WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: team_members tenant_insert_team_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_team_members ON public.team_members;
CREATE POLICY tenant_insert_team_members ON public.team_members FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: wavoip_devices tenant_insert_wavoip_devices; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_wavoip_devices ON public.wavoip_devices;
CREATE POLICY tenant_insert_wavoip_devices ON public.wavoip_devices FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_group_members tenant_insert_whatsapp_group_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_whatsapp_group_members ON public.whatsapp_group_members;
CREATE POLICY tenant_insert_whatsapp_group_members ON public.whatsapp_group_members FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_groups tenant_insert_whatsapp_groups; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_whatsapp_groups ON public.whatsapp_groups;
CREATE POLICY tenant_insert_whatsapp_groups ON public.whatsapp_groups FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_instances tenant_insert_whatsapp_instances; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_whatsapp_instances ON public.whatsapp_instances;
CREATE POLICY tenant_insert_whatsapp_instances ON public.whatsapp_instances FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_messages tenant_insert_whatsapp_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_whatsapp_messages ON public.whatsapp_messages;
CREATE POLICY tenant_insert_whatsapp_messages ON public.whatsapp_messages FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_config tenant_insert_whatsapp_task_bot_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_whatsapp_task_bot_config ON public.whatsapp_task_bot_config;
CREATE POLICY tenant_insert_whatsapp_task_bot_config ON public.whatsapp_task_bot_config FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_logs tenant_insert_whatsapp_task_bot_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_insert_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs;
CREATE POLICY tenant_insert_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs FOR INSERT TO authenticated WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: calendar_blocks tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_isolation ON public.calendar_blocks;
CREATE POLICY tenant_isolation ON public.calendar_blocks USING ((tenant_id = public.get_tenant_id()));


--
-- Name: import_jobs tenant_isolation_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_isolation_insert ON public.import_jobs;
CREATE POLICY tenant_isolation_insert ON public.import_jobs FOR INSERT WITH CHECK ((tenant_id = public.get_tenant_id()));


--
-- Name: import_jobs tenant_isolation_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_isolation_select ON public.import_jobs;
CREATE POLICY tenant_isolation_select ON public.import_jobs FOR SELECT USING ((tenant_id = public.get_tenant_id()));


--
-- Name: meta_lead_ads_forms tenant_meta_forms; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_meta_forms ON public.meta_lead_ads_forms;
CREATE POLICY tenant_meta_forms ON public.meta_lead_ads_forms USING ((tenant_id = public.get_tenant_id()));


--
-- Name: meta_lead_ads_logs tenant_meta_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_meta_logs ON public.meta_lead_ads_logs;
CREATE POLICY tenant_meta_logs ON public.meta_lead_ads_logs USING ((tenant_id = public.get_tenant_id()));


--
-- Name: meta_lead_ads_pages tenant_meta_pages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_meta_pages ON public.meta_lead_ads_pages;
CREATE POLICY tenant_meta_pages ON public.meta_lead_ads_pages USING ((tenant_id = public.get_tenant_id()));


--
-- Name: tenant_sales_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_sales_config ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_sales_config tenant_sales_config_insert; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_sales_config_insert ON public.tenant_sales_config;
CREATE POLICY tenant_sales_config_insert ON public.tenant_sales_config FOR INSERT WITH CHECK (((tenant_id IN ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE ((team_members.auth_user_id = auth.uid()) AND (team_members.role = 'admin'::text)))) OR (current_setting('role'::text, true) = 'service_role'::text)));


--
-- Name: tenant_sales_config tenant_sales_config_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_sales_config_select ON public.tenant_sales_config;
CREATE POLICY tenant_sales_config_select ON public.tenant_sales_config FOR SELECT USING (((tenant_id IN ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE (team_members.auth_user_id = auth.uid()))) OR (current_setting('role'::text, true) = 'service_role'::text)));


--
-- Name: tenant_sales_config tenant_sales_config_update; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_sales_config_update ON public.tenant_sales_config;
CREATE POLICY tenant_sales_config_update ON public.tenant_sales_config FOR UPDATE USING (((tenant_id IN ( SELECT team_members.tenant_id
   FROM public.team_members
  WHERE ((team_members.auth_user_id = auth.uid()) AND (team_members.role = 'admin'::text)))) OR (current_setting('role'::text, true) = 'service_role'::text)));


--
-- Name: tenants tenant_select; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select ON public.tenants;
CREATE POLICY tenant_select ON public.tenants FOR SELECT TO authenticated USING (true);


--
-- Name: ai_agent_conversations tenant_select_ai_agent_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ai_agent_conversations ON public.ai_agent_conversations;
CREATE POLICY tenant_select_ai_agent_conversations ON public.ai_agent_conversations FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_logs tenant_select_ai_agent_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ai_agent_logs ON public.ai_agent_logs;
CREATE POLICY tenant_select_ai_agent_logs ON public.ai_agent_logs FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_message_queue tenant_select_ai_agent_message_queue; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ai_agent_message_queue ON public.ai_agent_message_queue;
CREATE POLICY tenant_select_ai_agent_message_queue ON public.ai_agent_message_queue FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_tools tenant_select_ai_agent_tools; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ai_agent_tools ON public.ai_agent_tools;
CREATE POLICY tenant_select_ai_agent_tools ON public.ai_agent_tools FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_sales_agents tenant_select_ai_sales_agents; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ai_sales_agents ON public.ai_sales_agents;
CREATE POLICY tenant_select_ai_sales_agents ON public.ai_sales_agents FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: analysis_templates tenant_select_analysis_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_analysis_templates ON public.analysis_templates;
CREATE POLICY tenant_select_analysis_templates ON public.analysis_templates FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_customers tenant_select_asaas_customers; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_asaas_customers ON public.asaas_customers;
CREATE POLICY tenant_select_asaas_customers ON public.asaas_customers FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_webhooks tenant_select_asaas_webhooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_asaas_webhooks ON public.asaas_webhooks;
CREATE POLICY tenant_select_asaas_webhooks ON public.asaas_webhooks FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: calendar_events tenant_select_calendar_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_calendar_events ON public.calendar_events;
CREATE POLICY tenant_select_calendar_events ON public.calendar_events FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: call_history tenant_select_call_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_call_history ON public.call_history;
CREATE POLICY tenant_select_call_history ON public.call_history FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_configs tenant_select_chat_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_chat_configs ON public.chat_configs;
CREATE POLICY tenant_select_chat_configs ON public.chat_configs FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_messages tenant_select_chat_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_chat_messages ON public.chat_messages;
CREATE POLICY tenant_select_chat_messages ON public.chat_messages FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_sessions tenant_select_chat_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_chat_sessions ON public.chat_sessions;
CREATE POLICY tenant_select_chat_sessions ON public.chat_sessions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_playbooks tenant_select_coach_playbooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_coach_playbooks ON public.coach_playbooks;
CREATE POLICY tenant_select_coach_playbooks ON public.coach_playbooks FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_sessions tenant_select_coach_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_coach_sessions ON public.coach_sessions;
CREATE POLICY tenant_select_coach_sessions ON public.coach_sessions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commission_rules tenant_select_commission_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_commission_rules ON public.commission_rules;
CREATE POLICY tenant_select_commission_rules ON public.commission_rules FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commissions tenant_select_commissions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_commissions ON public.commissions;
CREATE POLICY tenant_select_commissions ON public.commissions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: company_activities tenant_select_company_activities; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_company_activities ON public.company_activities;
CREATE POLICY tenant_select_company_activities ON public.company_activities FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_handled tenant_select_cs_conversation_handled; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_conversation_handled ON public.cs_conversation_handled;
CREATE POLICY tenant_select_cs_conversation_handled ON public.cs_conversation_handled FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_notes tenant_select_cs_conversation_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_conversation_notes ON public.cs_conversation_notes;
CREATE POLICY tenant_select_cs_conversation_notes ON public.cs_conversation_notes FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_engagement_metrics tenant_select_cs_engagement_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_engagement_metrics ON public.cs_engagement_metrics;
CREATE POLICY tenant_select_cs_engagement_metrics ON public.cs_engagement_metrics FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_event_rsvps tenant_select_cs_event_rsvps; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_event_rsvps ON public.cs_event_rsvps;
CREATE POLICY tenant_select_cs_event_rsvps ON public.cs_event_rsvps FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_events tenant_select_cs_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_events ON public.cs_events;
CREATE POLICY tenant_select_cs_events ON public.cs_events FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_current tenant_select_cs_health_current; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_health_current ON public.cs_health_current;
CREATE POLICY tenant_select_cs_health_current ON public.cs_health_current FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_scores_history tenant_select_cs_health_scores_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_health_scores_history ON public.cs_health_scores_history;
CREATE POLICY tenant_select_cs_health_scores_history ON public.cs_health_scores_history FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_inbox_metrics tenant_select_cs_inbox_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_inbox_metrics ON public.cs_inbox_metrics;
CREATE POLICY tenant_select_cs_inbox_metrics ON public.cs_inbox_metrics FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_interactions tenant_select_cs_interactions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_interactions ON public.cs_interactions;
CREATE POLICY tenant_select_cs_interactions ON public.cs_interactions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_objectives tenant_select_cs_objectives; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_objectives ON public.cs_objectives;
CREATE POLICY tenant_select_cs_objectives ON public.cs_objectives FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_response_templates tenant_select_cs_response_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_response_templates ON public.cs_response_templates;
CREATE POLICY tenant_select_cs_response_templates ON public.cs_response_templates FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_success_metrics tenant_select_cs_success_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_success_metrics ON public.cs_success_metrics;
CREATE POLICY tenant_select_cs_success_metrics ON public.cs_success_metrics FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_touchpoints tenant_select_cs_touchpoints; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_cs_touchpoints ON public.cs_touchpoints;
CREATE POLICY tenant_select_cs_touchpoints ON public.cs_touchpoints FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_contacts tenant_select_deal_contacts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_deal_contacts ON public.deal_contacts;
CREATE POLICY tenant_select_deal_contacts ON public.deal_contacts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_loss_reasons tenant_select_deal_loss_reasons; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_deal_loss_reasons ON public.deal_loss_reasons;
CREATE POLICY tenant_select_deal_loss_reasons ON public.deal_loss_reasons FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payment_installments tenant_select_deal_payment_installments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_deal_payment_installments ON public.deal_payment_installments;
CREATE POLICY tenant_select_deal_payment_installments ON public.deal_payment_installments FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payments tenant_select_deal_payments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_deal_payments ON public.deal_payments;
CREATE POLICY tenant_select_deal_payments ON public.deal_payments FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deals tenant_select_deals; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_deals ON public.deals;
CREATE POLICY tenant_select_deals ON public.deals FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_accounts tenant_select_financial_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_financial_accounts ON public.financial_accounts;
CREATE POLICY tenant_select_financial_accounts ON public.financial_accounts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_categories tenant_select_financial_categories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_financial_categories ON public.financial_categories;
CREATE POLICY tenant_select_financial_categories ON public.financial_categories FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_entries tenant_select_financial_entries; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_financial_entries ON public.financial_entries;
CREATE POLICY tenant_select_financial_entries ON public.financial_entries FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_accounts tenant_select_google_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_google_ads_accounts ON public.google_ads_accounts;
CREATE POLICY tenant_select_google_ads_accounts ON public.google_ads_accounts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_campaign_data tenant_select_google_ads_campaign_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_google_ads_campaign_data ON public.google_ads_campaign_data;
CREATE POLICY tenant_select_google_ads_campaign_data ON public.google_ads_campaign_data FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_daily_data tenant_select_google_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_google_ads_daily_data ON public.google_ads_daily_data;
CREATE POLICY tenant_select_google_ads_daily_data ON public.google_ads_daily_data FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_business_accounts tenant_select_instagram_business_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_business_accounts ON public.instagram_business_accounts;
CREATE POLICY tenant_select_instagram_business_accounts ON public.instagram_business_accounts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_comments tenant_select_instagram_comments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_comments ON public.instagram_comments;
CREATE POLICY tenant_select_instagram_comments ON public.instagram_comments FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_conversations tenant_select_instagram_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_conversations ON public.instagram_conversations;
CREATE POLICY tenant_select_instagram_conversations ON public.instagram_conversations FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_engagement tenant_select_instagram_engagement; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_engagement ON public.instagram_engagement;
CREATE POLICY tenant_select_instagram_engagement ON public.instagram_engagement FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_feed_posts tenant_select_instagram_feed_posts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_feed_posts ON public.instagram_feed_posts;
CREATE POLICY tenant_select_instagram_feed_posts ON public.instagram_feed_posts FOR SELECT USING ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_messages tenant_select_instagram_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_messages ON public.instagram_messages;
CREATE POLICY tenant_select_instagram_messages ON public.instagram_messages FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_profiles tenant_select_instagram_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_profiles ON public.instagram_profiles;
CREATE POLICY tenant_select_instagram_profiles ON public.instagram_profiles FOR SELECT USING ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_stories tenant_select_instagram_stories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_instagram_stories ON public.instagram_stories;
CREATE POLICY tenant_select_instagram_stories ON public.instagram_stories FOR SELECT USING ((tenant_id = public.get_tenant_id()));


--
-- Name: integration_settings tenant_select_integration_settings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_integration_settings ON public.integration_settings;
CREATE POLICY tenant_select_integration_settings ON public.integration_settings FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_conversions tenant_select_lead_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_lead_conversions ON public.lead_conversions;
CREATE POLICY tenant_select_lead_conversions ON public.lead_conversions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_diagnostics_v2 tenant_select_lead_diagnostics_v2; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_lead_diagnostics_v2 ON public.lead_diagnostics_v2;
CREATE POLICY tenant_select_lead_diagnostics_v2 ON public.lead_diagnostics_v2 FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_config tenant_select_lead_distribution_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_lead_distribution_config ON public.lead_distribution_config;
CREATE POLICY tenant_select_lead_distribution_config ON public.lead_distribution_config FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_log tenant_select_lead_distribution_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_lead_distribution_log ON public.lead_distribution_log;
CREATE POLICY tenant_select_lead_distribution_log ON public.lead_distribution_log FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_members tenant_select_lead_distribution_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_lead_distribution_members ON public.lead_distribution_members;
CREATE POLICY tenant_select_lead_distribution_members ON public.lead_distribution_members FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: leads tenant_select_leads; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_leads ON public.leads;
CREATE POLICY tenant_select_leads ON public.leads FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: llm_provider_configs tenant_select_llm_provider_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_llm_provider_configs ON public.llm_provider_configs;
CREATE POLICY tenant_select_llm_provider_configs ON public.llm_provider_configs FOR SELECT USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meetings tenant_select_meetings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_meetings ON public.meetings;
CREATE POLICY tenant_select_meetings ON public.meetings FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_calls_history tenant_select_member_calls_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_member_calls_history ON public.member_calls_history;
CREATE POLICY tenant_select_member_calls_history ON public.member_calls_history FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_daily_activity tenant_select_member_daily_activity; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_member_daily_activity ON public.member_daily_activity;
CREATE POLICY tenant_select_member_daily_activity ON public.member_daily_activity FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_engagement_snapshots tenant_select_member_engagement_snapshots; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_member_engagement_snapshots ON public.member_engagement_snapshots;
CREATE POLICY tenant_select_member_engagement_snapshots ON public.member_engagement_snapshots FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_lessons_progress tenant_select_member_lessons_progress; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_member_lessons_progress ON public.member_lessons_progress;
CREATE POLICY tenant_select_member_lessons_progress ON public.member_lessons_progress FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_accounts tenant_select_meta_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_meta_ads_accounts ON public.meta_ads_accounts;
CREATE POLICY tenant_select_meta_ads_accounts ON public.meta_ads_accounts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_ad_data tenant_select_meta_ads_ad_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_meta_ads_ad_data ON public.meta_ads_ad_data;
CREATE POLICY tenant_select_meta_ads_ad_data ON public.meta_ads_ad_data FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_conversions tenant_select_meta_ads_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_meta_ads_conversions ON public.meta_ads_conversions;
CREATE POLICY tenant_select_meta_ads_conversions ON public.meta_ads_conversions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_daily_data tenant_select_meta_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_meta_ads_daily_data ON public.meta_ads_daily_data;
CREATE POLICY tenant_select_meta_ads_daily_data ON public.meta_ads_daily_data FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_sync_log tenant_select_meta_ads_sync_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_meta_ads_sync_log ON public.meta_ads_sync_log;
CREATE POLICY tenant_select_meta_ads_sync_log ON public.meta_ads_sync_log FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_logs tenant_select_notification_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_notification_logs ON public.notification_logs;
CREATE POLICY tenant_select_notification_logs ON public.notification_logs FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_rules tenant_select_notification_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_notification_rules ON public.notification_rules;
CREATE POLICY tenant_select_notification_rules ON public.notification_rules FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: onboardings tenant_select_onboardings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_onboardings ON public.onboardings;
CREATE POLICY tenant_select_onboardings ON public.onboardings FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_members tenant_select_organization_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_organization_members ON public.organization_members;
CREATE POLICY tenant_select_organization_members ON public.organization_members FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_products tenant_select_organization_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_organization_products ON public.organization_products;
CREATE POLICY tenant_select_organization_products ON public.organization_products FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organizations tenant_select_organizations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_organizations ON public.organizations;
CREATE POLICY tenant_select_organizations ON public.organizations FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: pain_registrations tenant_select_pain_registrations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_pain_registrations ON public.pain_registrations;
CREATE POLICY tenant_select_pain_registrations ON public.pain_registrations FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateway_fees tenant_select_payment_gateway_fees; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_payment_gateway_fees ON public.payment_gateway_fees;
CREATE POLICY tenant_select_payment_gateway_fees ON public.payment_gateway_fees FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateways tenant_select_payment_gateways; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_payment_gateways ON public.payment_gateways;
CREATE POLICY tenant_select_payment_gateways ON public.payment_gateways FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: products tenant_select_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_products ON public.products;
CREATE POLICY tenant_select_products ON public.products FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: profiles tenant_select_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_profiles ON public.profiles;
CREATE POLICY tenant_select_profiles ON public.profiles FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: receive_lead_logs tenant_select_receive_lead_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_receive_lead_logs ON public.receive_lead_logs;
CREATE POLICY tenant_select_receive_lead_logs ON public.receive_lead_logs FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_alerts tenant_select_sales_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_alerts ON public.sales_alerts;
CREATE POLICY tenant_select_sales_alerts ON public.sales_alerts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_automation_rules tenant_select_sales_automation_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_automation_rules ON public.sales_automation_rules;
CREATE POLICY tenant_select_sales_automation_rules ON public.sales_automation_rules FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_materials tenant_select_sales_materials; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_materials ON public.sales_materials;
CREATE POLICY tenant_select_sales_materials ON public.sales_materials FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_notes tenant_select_sales_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_notes ON public.sales_notes;
CREATE POLICY tenant_select_sales_notes ON public.sales_notes FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_stages tenant_select_sales_pipeline_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_pipeline_stages ON public.sales_pipeline_stages;
CREATE POLICY tenant_select_sales_pipeline_stages ON public.sales_pipeline_stages FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_transitions tenant_select_sales_pipeline_transitions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_pipeline_transitions ON public.sales_pipeline_transitions;
CREATE POLICY tenant_select_sales_pipeline_transitions ON public.sales_pipeline_transitions FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipelines tenant_select_sales_pipelines; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sales_pipelines ON public.sales_pipelines;
CREATE POLICY tenant_select_sales_pipelines ON public.sales_pipelines FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_alerts tenant_select_social_seller_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_social_seller_alerts ON public.social_seller_alerts;
CREATE POLICY tenant_select_social_seller_alerts ON public.social_seller_alerts FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_rules tenant_select_social_seller_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_social_seller_rules ON public.social_seller_rules;
CREATE POLICY tenant_select_social_seller_rules ON public.social_seller_rules FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_stages tenant_select_social_seller_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_social_seller_stages ON public.social_seller_stages;
CREATE POLICY tenant_select_social_seller_stages ON public.social_seller_stages FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_enrollments tenant_select_sse; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_sse ON public.social_selling_enrollments;
CREATE POLICY tenant_select_sse ON public.social_selling_enrollments FOR SELECT USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_interactions tenant_select_ssi; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ssi ON public.social_selling_interactions;
CREATE POLICY tenant_select_ssi ON public.social_selling_interactions FOR SELECT USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_known_followers tenant_select_ssn; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_ssn ON public.social_selling_known_followers;
CREATE POLICY tenant_select_ssn ON public.social_selling_known_followers FOR SELECT USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: team_members tenant_select_team_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_team_members ON public.team_members;
CREATE POLICY tenant_select_team_members ON public.team_members FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: wavoip_devices tenant_select_wavoip_devices; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_wavoip_devices ON public.wavoip_devices;
CREATE POLICY tenant_select_wavoip_devices ON public.wavoip_devices FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_group_members tenant_select_whatsapp_group_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_whatsapp_group_members ON public.whatsapp_group_members;
CREATE POLICY tenant_select_whatsapp_group_members ON public.whatsapp_group_members FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_groups tenant_select_whatsapp_groups; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_whatsapp_groups ON public.whatsapp_groups;
CREATE POLICY tenant_select_whatsapp_groups ON public.whatsapp_groups FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_instances tenant_select_whatsapp_instances; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_whatsapp_instances ON public.whatsapp_instances;
CREATE POLICY tenant_select_whatsapp_instances ON public.whatsapp_instances FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_messages tenant_select_whatsapp_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_whatsapp_messages ON public.whatsapp_messages;
CREATE POLICY tenant_select_whatsapp_messages ON public.whatsapp_messages FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_config tenant_select_whatsapp_task_bot_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_whatsapp_task_bot_config ON public.whatsapp_task_bot_config;
CREATE POLICY tenant_select_whatsapp_task_bot_config ON public.whatsapp_task_bot_config FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_logs tenant_select_whatsapp_task_bot_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_select_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs;
CREATE POLICY tenant_select_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs FOR SELECT TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: team_members tenant_self_update_team_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_self_update_team_members ON public.team_members;
CREATE POLICY tenant_self_update_team_members ON public.team_members FOR UPDATE USING (((tenant_id = public.get_tenant_id()) AND (auth_user_id = auth.uid()))) WITH CHECK (((tenant_id = public.get_tenant_id()) AND (auth_user_id = auth.uid())));


--
-- Name: ai_agent_conversations tenant_update_ai_agent_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_ai_agent_conversations ON public.ai_agent_conversations;
CREATE POLICY tenant_update_ai_agent_conversations ON public.ai_agent_conversations FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_logs tenant_update_ai_agent_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_ai_agent_logs ON public.ai_agent_logs;
CREATE POLICY tenant_update_ai_agent_logs ON public.ai_agent_logs FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_message_queue tenant_update_ai_agent_message_queue; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_ai_agent_message_queue ON public.ai_agent_message_queue;
CREATE POLICY tenant_update_ai_agent_message_queue ON public.ai_agent_message_queue FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_agent_tools tenant_update_ai_agent_tools; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_ai_agent_tools ON public.ai_agent_tools;
CREATE POLICY tenant_update_ai_agent_tools ON public.ai_agent_tools FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: ai_sales_agents tenant_update_ai_sales_agents; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_ai_sales_agents ON public.ai_sales_agents;
CREATE POLICY tenant_update_ai_sales_agents ON public.ai_sales_agents FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: analysis_templates tenant_update_analysis_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_analysis_templates ON public.analysis_templates;
CREATE POLICY tenant_update_analysis_templates ON public.analysis_templates FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_customers tenant_update_asaas_customers; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_asaas_customers ON public.asaas_customers;
CREATE POLICY tenant_update_asaas_customers ON public.asaas_customers FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: asaas_webhooks tenant_update_asaas_webhooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_asaas_webhooks ON public.asaas_webhooks;
CREATE POLICY tenant_update_asaas_webhooks ON public.asaas_webhooks FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: calendar_events tenant_update_calendar_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_calendar_events ON public.calendar_events;
CREATE POLICY tenant_update_calendar_events ON public.calendar_events FOR UPDATE TO authenticated USING (((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)) AND (team_member_id = auth.uid())));


--
-- Name: call_history tenant_update_call_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_call_history ON public.call_history;
CREATE POLICY tenant_update_call_history ON public.call_history FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_configs tenant_update_chat_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_chat_configs ON public.chat_configs;
CREATE POLICY tenant_update_chat_configs ON public.chat_configs FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_messages tenant_update_chat_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_chat_messages ON public.chat_messages;
CREATE POLICY tenant_update_chat_messages ON public.chat_messages FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: chat_sessions tenant_update_chat_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_chat_sessions ON public.chat_sessions;
CREATE POLICY tenant_update_chat_sessions ON public.chat_sessions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_playbooks tenant_update_coach_playbooks; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_coach_playbooks ON public.coach_playbooks;
CREATE POLICY tenant_update_coach_playbooks ON public.coach_playbooks FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: coach_sessions tenant_update_coach_sessions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_coach_sessions ON public.coach_sessions;
CREATE POLICY tenant_update_coach_sessions ON public.coach_sessions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commission_rules tenant_update_commission_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_commission_rules ON public.commission_rules;
CREATE POLICY tenant_update_commission_rules ON public.commission_rules FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: commissions tenant_update_commissions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_commissions ON public.commissions;
CREATE POLICY tenant_update_commissions ON public.commissions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: company_activities tenant_update_company_activities; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_company_activities ON public.company_activities;
CREATE POLICY tenant_update_company_activities ON public.company_activities FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_handled tenant_update_cs_conversation_handled; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_conversation_handled ON public.cs_conversation_handled;
CREATE POLICY tenant_update_cs_conversation_handled ON public.cs_conversation_handled FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_conversation_notes tenant_update_cs_conversation_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_conversation_notes ON public.cs_conversation_notes;
CREATE POLICY tenant_update_cs_conversation_notes ON public.cs_conversation_notes FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_engagement_metrics tenant_update_cs_engagement_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_engagement_metrics ON public.cs_engagement_metrics;
CREATE POLICY tenant_update_cs_engagement_metrics ON public.cs_engagement_metrics FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_event_rsvps tenant_update_cs_event_rsvps; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_event_rsvps ON public.cs_event_rsvps;
CREATE POLICY tenant_update_cs_event_rsvps ON public.cs_event_rsvps FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_events tenant_update_cs_events; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_events ON public.cs_events;
CREATE POLICY tenant_update_cs_events ON public.cs_events FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_current tenant_update_cs_health_current; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_health_current ON public.cs_health_current;
CREATE POLICY tenant_update_cs_health_current ON public.cs_health_current FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_health_scores_history tenant_update_cs_health_scores_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_health_scores_history ON public.cs_health_scores_history;
CREATE POLICY tenant_update_cs_health_scores_history ON public.cs_health_scores_history FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_inbox_metrics tenant_update_cs_inbox_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_inbox_metrics ON public.cs_inbox_metrics;
CREATE POLICY tenant_update_cs_inbox_metrics ON public.cs_inbox_metrics FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_interactions tenant_update_cs_interactions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_interactions ON public.cs_interactions;
CREATE POLICY tenant_update_cs_interactions ON public.cs_interactions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_objectives tenant_update_cs_objectives; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_objectives ON public.cs_objectives;
CREATE POLICY tenant_update_cs_objectives ON public.cs_objectives FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_response_templates tenant_update_cs_response_templates; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_response_templates ON public.cs_response_templates;
CREATE POLICY tenant_update_cs_response_templates ON public.cs_response_templates FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_success_metrics tenant_update_cs_success_metrics; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_success_metrics ON public.cs_success_metrics;
CREATE POLICY tenant_update_cs_success_metrics ON public.cs_success_metrics FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: cs_touchpoints tenant_update_cs_touchpoints; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_cs_touchpoints ON public.cs_touchpoints;
CREATE POLICY tenant_update_cs_touchpoints ON public.cs_touchpoints FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_contacts tenant_update_deal_contacts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_deal_contacts ON public.deal_contacts;
CREATE POLICY tenant_update_deal_contacts ON public.deal_contacts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_loss_reasons tenant_update_deal_loss_reasons; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_deal_loss_reasons ON public.deal_loss_reasons;
CREATE POLICY tenant_update_deal_loss_reasons ON public.deal_loss_reasons FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payment_installments tenant_update_deal_payment_installments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_deal_payment_installments ON public.deal_payment_installments;
CREATE POLICY tenant_update_deal_payment_installments ON public.deal_payment_installments FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deal_payments tenant_update_deal_payments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_deal_payments ON public.deal_payments;
CREATE POLICY tenant_update_deal_payments ON public.deal_payments FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: deals tenant_update_deals; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_deals ON public.deals;
CREATE POLICY tenant_update_deals ON public.deals FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_accounts tenant_update_financial_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_financial_accounts ON public.financial_accounts;
CREATE POLICY tenant_update_financial_accounts ON public.financial_accounts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_categories tenant_update_financial_categories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_financial_categories ON public.financial_categories;
CREATE POLICY tenant_update_financial_categories ON public.financial_categories FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: financial_entries tenant_update_financial_entries; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_financial_entries ON public.financial_entries;
CREATE POLICY tenant_update_financial_entries ON public.financial_entries FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_accounts tenant_update_google_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_google_ads_accounts ON public.google_ads_accounts;
CREATE POLICY tenant_update_google_ads_accounts ON public.google_ads_accounts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_campaign_data tenant_update_google_ads_campaign_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_google_ads_campaign_data ON public.google_ads_campaign_data;
CREATE POLICY tenant_update_google_ads_campaign_data ON public.google_ads_campaign_data FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: google_ads_daily_data tenant_update_google_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_google_ads_daily_data ON public.google_ads_daily_data;
CREATE POLICY tenant_update_google_ads_daily_data ON public.google_ads_daily_data FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_business_accounts tenant_update_instagram_business_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_business_accounts ON public.instagram_business_accounts;
CREATE POLICY tenant_update_instagram_business_accounts ON public.instagram_business_accounts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_comments tenant_update_instagram_comments; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_comments ON public.instagram_comments;
CREATE POLICY tenant_update_instagram_comments ON public.instagram_comments FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_conversations tenant_update_instagram_conversations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_conversations ON public.instagram_conversations;
CREATE POLICY tenant_update_instagram_conversations ON public.instagram_conversations FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_engagement tenant_update_instagram_engagement; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_engagement ON public.instagram_engagement;
CREATE POLICY tenant_update_instagram_engagement ON public.instagram_engagement FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_feed_posts tenant_update_instagram_feed_posts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_feed_posts ON public.instagram_feed_posts;
CREATE POLICY tenant_update_instagram_feed_posts ON public.instagram_feed_posts FOR UPDATE USING ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_messages tenant_update_instagram_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_messages ON public.instagram_messages;
CREATE POLICY tenant_update_instagram_messages ON public.instagram_messages FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: instagram_profiles tenant_update_instagram_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_profiles ON public.instagram_profiles;
CREATE POLICY tenant_update_instagram_profiles ON public.instagram_profiles FOR UPDATE USING ((tenant_id = public.get_tenant_id()));


--
-- Name: instagram_stories tenant_update_instagram_stories; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_instagram_stories ON public.instagram_stories;
CREATE POLICY tenant_update_instagram_stories ON public.instagram_stories FOR UPDATE USING ((tenant_id = public.get_tenant_id()));


--
-- Name: integration_settings tenant_update_integration_settings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_integration_settings ON public.integration_settings;
CREATE POLICY tenant_update_integration_settings ON public.integration_settings FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_conversions tenant_update_lead_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_lead_conversions ON public.lead_conversions;
CREATE POLICY tenant_update_lead_conversions ON public.lead_conversions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_diagnostics_v2 tenant_update_lead_diagnostics_v2; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_lead_diagnostics_v2 ON public.lead_diagnostics_v2;
CREATE POLICY tenant_update_lead_diagnostics_v2 ON public.lead_diagnostics_v2 FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_config tenant_update_lead_distribution_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_lead_distribution_config ON public.lead_distribution_config;
CREATE POLICY tenant_update_lead_distribution_config ON public.lead_distribution_config FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_log tenant_update_lead_distribution_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_lead_distribution_log ON public.lead_distribution_log;
CREATE POLICY tenant_update_lead_distribution_log ON public.lead_distribution_log FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: lead_distribution_members tenant_update_lead_distribution_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_lead_distribution_members ON public.lead_distribution_members;
CREATE POLICY tenant_update_lead_distribution_members ON public.lead_distribution_members FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: leads tenant_update_leads; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_leads ON public.leads;
CREATE POLICY tenant_update_leads ON public.leads FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: llm_provider_configs tenant_update_llm_provider_configs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_llm_provider_configs ON public.llm_provider_configs;
CREATE POLICY tenant_update_llm_provider_configs ON public.llm_provider_configs FOR UPDATE USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meetings tenant_update_meetings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_meetings ON public.meetings;
CREATE POLICY tenant_update_meetings ON public.meetings FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_calls_history tenant_update_member_calls_history; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_member_calls_history ON public.member_calls_history;
CREATE POLICY tenant_update_member_calls_history ON public.member_calls_history FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_daily_activity tenant_update_member_daily_activity; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_member_daily_activity ON public.member_daily_activity;
CREATE POLICY tenant_update_member_daily_activity ON public.member_daily_activity FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_engagement_snapshots tenant_update_member_engagement_snapshots; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_member_engagement_snapshots ON public.member_engagement_snapshots;
CREATE POLICY tenant_update_member_engagement_snapshots ON public.member_engagement_snapshots FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: member_lessons_progress tenant_update_member_lessons_progress; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_member_lessons_progress ON public.member_lessons_progress;
CREATE POLICY tenant_update_member_lessons_progress ON public.member_lessons_progress FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_accounts tenant_update_meta_ads_accounts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_meta_ads_accounts ON public.meta_ads_accounts;
CREATE POLICY tenant_update_meta_ads_accounts ON public.meta_ads_accounts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_ad_data tenant_update_meta_ads_ad_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_meta_ads_ad_data ON public.meta_ads_ad_data;
CREATE POLICY tenant_update_meta_ads_ad_data ON public.meta_ads_ad_data FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_conversions tenant_update_meta_ads_conversions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_meta_ads_conversions ON public.meta_ads_conversions;
CREATE POLICY tenant_update_meta_ads_conversions ON public.meta_ads_conversions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_daily_data tenant_update_meta_ads_daily_data; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_meta_ads_daily_data ON public.meta_ads_daily_data;
CREATE POLICY tenant_update_meta_ads_daily_data ON public.meta_ads_daily_data FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: meta_ads_sync_log tenant_update_meta_ads_sync_log; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_meta_ads_sync_log ON public.meta_ads_sync_log;
CREATE POLICY tenant_update_meta_ads_sync_log ON public.meta_ads_sync_log FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_logs tenant_update_notification_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_notification_logs ON public.notification_logs;
CREATE POLICY tenant_update_notification_logs ON public.notification_logs FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: notification_rules tenant_update_notification_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_notification_rules ON public.notification_rules;
CREATE POLICY tenant_update_notification_rules ON public.notification_rules FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: onboardings tenant_update_onboardings; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_onboardings ON public.onboardings;
CREATE POLICY tenant_update_onboardings ON public.onboardings FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_members tenant_update_organization_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_organization_members ON public.organization_members;
CREATE POLICY tenant_update_organization_members ON public.organization_members FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organization_products tenant_update_organization_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_organization_products ON public.organization_products;
CREATE POLICY tenant_update_organization_products ON public.organization_products FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: organizations tenant_update_organizations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_organizations ON public.organizations;
CREATE POLICY tenant_update_organizations ON public.organizations FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: pain_registrations tenant_update_pain_registrations; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_pain_registrations ON public.pain_registrations;
CREATE POLICY tenant_update_pain_registrations ON public.pain_registrations FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateway_fees tenant_update_payment_gateway_fees; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_payment_gateway_fees ON public.payment_gateway_fees;
CREATE POLICY tenant_update_payment_gateway_fees ON public.payment_gateway_fees FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: payment_gateways tenant_update_payment_gateways; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_payment_gateways ON public.payment_gateways;
CREATE POLICY tenant_update_payment_gateways ON public.payment_gateways FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: products tenant_update_products; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_products ON public.products;
CREATE POLICY tenant_update_products ON public.products FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: receive_lead_logs tenant_update_receive_lead_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_receive_lead_logs ON public.receive_lead_logs;
CREATE POLICY tenant_update_receive_lead_logs ON public.receive_lead_logs FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_alerts tenant_update_sales_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_alerts ON public.sales_alerts;
CREATE POLICY tenant_update_sales_alerts ON public.sales_alerts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_automation_rules tenant_update_sales_automation_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_automation_rules ON public.sales_automation_rules;
CREATE POLICY tenant_update_sales_automation_rules ON public.sales_automation_rules FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_materials tenant_update_sales_materials; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_materials ON public.sales_materials;
CREATE POLICY tenant_update_sales_materials ON public.sales_materials FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_notes tenant_update_sales_notes; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_notes ON public.sales_notes;
CREATE POLICY tenant_update_sales_notes ON public.sales_notes FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_stages tenant_update_sales_pipeline_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_pipeline_stages ON public.sales_pipeline_stages;
CREATE POLICY tenant_update_sales_pipeline_stages ON public.sales_pipeline_stages FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipeline_transitions tenant_update_sales_pipeline_transitions; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_pipeline_transitions ON public.sales_pipeline_transitions;
CREATE POLICY tenant_update_sales_pipeline_transitions ON public.sales_pipeline_transitions FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: sales_pipelines tenant_update_sales_pipelines; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sales_pipelines ON public.sales_pipelines;
CREATE POLICY tenant_update_sales_pipelines ON public.sales_pipelines FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: profiles tenant_update_self_profiles; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_self_profiles ON public.profiles;
CREATE POLICY tenant_update_self_profiles ON public.profiles FOR UPDATE TO authenticated USING (((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)) AND (id = auth.uid())));


--
-- Name: social_seller_alerts tenant_update_social_seller_alerts; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_social_seller_alerts ON public.social_seller_alerts;
CREATE POLICY tenant_update_social_seller_alerts ON public.social_seller_alerts FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_rules tenant_update_social_seller_rules; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_social_seller_rules ON public.social_seller_rules;
CREATE POLICY tenant_update_social_seller_rules ON public.social_seller_rules FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_seller_stages tenant_update_social_seller_stages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_social_seller_stages ON public.social_seller_stages;
CREATE POLICY tenant_update_social_seller_stages ON public.social_seller_stages FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_enrollments tenant_update_sse; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_sse ON public.social_selling_enrollments;
CREATE POLICY tenant_update_sse ON public.social_selling_enrollments FOR UPDATE USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: social_selling_known_followers tenant_update_ssn; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_ssn ON public.social_selling_known_followers;
CREATE POLICY tenant_update_ssn ON public.social_selling_known_followers FOR UPDATE USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: wavoip_devices tenant_update_wavoip_devices; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_wavoip_devices ON public.wavoip_devices;
CREATE POLICY tenant_update_wavoip_devices ON public.wavoip_devices FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_group_members tenant_update_whatsapp_group_members; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_whatsapp_group_members ON public.whatsapp_group_members;
CREATE POLICY tenant_update_whatsapp_group_members ON public.whatsapp_group_members FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_groups tenant_update_whatsapp_groups; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_whatsapp_groups ON public.whatsapp_groups;
CREATE POLICY tenant_update_whatsapp_groups ON public.whatsapp_groups FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_instances tenant_update_whatsapp_instances; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_whatsapp_instances ON public.whatsapp_instances;
CREATE POLICY tenant_update_whatsapp_instances ON public.whatsapp_instances FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_messages tenant_update_whatsapp_messages; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_whatsapp_messages ON public.whatsapp_messages;
CREATE POLICY tenant_update_whatsapp_messages ON public.whatsapp_messages FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_config tenant_update_whatsapp_task_bot_config; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_whatsapp_task_bot_config ON public.whatsapp_task_bot_config;
CREATE POLICY tenant_update_whatsapp_task_bot_config ON public.whatsapp_task_bot_config FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: whatsapp_task_bot_logs tenant_update_whatsapp_task_bot_logs; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenant_update_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs;
CREATE POLICY tenant_update_whatsapp_task_bot_logs ON public.whatsapp_task_bot_logs FOR UPDATE TO authenticated USING ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id))) WITH CHECK ((tenant_id = ( SELECT public.get_tenant_id() AS get_tenant_id)));


--
-- Name: tenants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

--
-- Name: tenants tenants_insert_superadmin; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenants_insert_superadmin ON public.tenants;
CREATE POLICY tenants_insert_superadmin ON public.tenants FOR INSERT WITH CHECK (public.is_superadmin());


--
-- Name: tenants tenants_select_superadmin; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS tenants_select_superadmin ON public.tenants;
CREATE POLICY tenants_select_superadmin ON public.tenants FOR SELECT USING (true);


--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions transactions_all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS transactions_all ON public.transactions;
CREATE POLICY transactions_all ON public.transactions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: twilio_call_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.twilio_call_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_community_campaign_items wa_campaign_items authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_campaign_items authenticated all" ON public.wa_community_campaign_items;
CREATE POLICY "wa_campaign_items authenticated all" ON public.wa_community_campaign_items USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_community_campaigns wa_campaigns authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_campaigns authenticated all" ON public.wa_community_campaigns;
CREATE POLICY "wa_campaigns authenticated all" ON public.wa_community_campaigns USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_communities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_communities ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_communities wa_communities authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_communities authenticated all" ON public.wa_communities;
CREATE POLICY "wa_communities authenticated all" ON public.wa_communities USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_community_campaign_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_community_campaign_items ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_community_campaigns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_community_campaigns ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_community_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_community_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_community_groups wa_community_groups authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_community_groups authenticated all" ON public.wa_community_groups;
CREATE POLICY "wa_community_groups authenticated all" ON public.wa_community_groups USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_message_sequences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_message_sequences ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_message_sequences wa_message_sequences authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_message_sequences authenticated all" ON public.wa_message_sequences;
CREATE POLICY "wa_message_sequences authenticated all" ON public.wa_message_sequences USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_scheduled_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_scheduled_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_scheduled_messages wa_scheduled_messages authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_scheduled_messages authenticated all" ON public.wa_scheduled_messages;
CREATE POLICY "wa_scheduled_messages authenticated all" ON public.wa_scheduled_messages USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_sequence_enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_sequence_enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_sequence_enrollments wa_sequence_enrollments authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_sequence_enrollments authenticated all" ON public.wa_sequence_enrollments;
CREATE POLICY "wa_sequence_enrollments authenticated all" ON public.wa_sequence_enrollments USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wa_sequence_steps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_sequence_steps ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_sequence_steps wa_sequence_steps authenticated all; Type: POLICY; Schema: public; Owner: -
--

DROP POLICY IF EXISTS "wa_sequence_steps authenticated all" ON public.wa_sequence_steps;
CREATE POLICY "wa_sequence_steps authenticated all" ON public.wa_sequence_steps USING ((auth.role() = 'authenticated'::text)) WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: wavoip_devices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wavoip_devices ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_cloud_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_cloud_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_group_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_group_members ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_instances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_instances ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_task_bot_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_task_bot_config ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_task_bot_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_task_bot_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_template_tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_template_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: supabase_realtime_messages_publication; Type: PUBLICATION; Schema: -; Owner: -
--

DROP PUBLICATION IF EXISTS supabase_realtime_messages_publication;
CREATE PUBLICATION supabase_realtime_messages_publication WITH (publish = 'insert, update, delete, truncate');


--
-- Name: supabase_realtime ai_agent_chat_events; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.ai_agent_chat_events;


--
-- Name: supabase_realtime ai_agent_conversations; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.ai_agent_conversations;


--
-- Name: supabase_realtime cs_event_connections; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.cs_event_connections;


--
-- Name: supabase_realtime cs_event_feed_posts; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.cs_event_feed_posts;


--
-- Name: supabase_realtime cs_event_schedule_items; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.cs_event_schedule_items;


--
-- Name: supabase_realtime social_selling_enrollments; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.social_selling_enrollments;


--
-- Name: supabase_realtime social_selling_interactions; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.social_selling_interactions;


--
-- Name: supabase_realtime social_selling_known_followers; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.social_selling_known_followers;


--
-- Name: supabase_realtime whatsapp_instances; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.whatsapp_instances;


--
-- Name: supabase_realtime whatsapp_messages; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.whatsapp_messages;


--
-- Name: ensure_rls; Type: EVENT TRIGGER; Schema: -; Owner: -
--

DROP EVENT TRIGGER IF EXISTS ensure_rls;
CREATE EVENT TRIGGER ensure_rls ON ddl_command_end
         WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
   EXECUTE FUNCTION public.rls_auto_enable();


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

-- removed: system event trigger issue_graphql_placeholder (managed by Supabase)


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

-- removed: system event trigger issue_pg_cron_access (managed by Supabase)


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

-- removed: system event trigger issue_pg_graphql_access (managed by Supabase)


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

-- removed: system event trigger issue_pg_net_access (managed by Supabase)


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

-- removed: system event trigger pgrst_ddl_watch (managed by Supabase)


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

-- removed: system event trigger pgrst_drop_watch (managed by Supabase)


--
-- PostgreSQL database dump complete
--


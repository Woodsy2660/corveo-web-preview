-- Migration: Create consent_event table
-- Purpose: Append-only consent event log
-- Ref: docs/02-data-model-and-api.md §1.4, §3.3; docs/migration-plan-v0.2.md §06
--
-- Never updated. Current state is the latest row (see has_active_consent()).
-- Append-only is enforced by trigger in 20260729100900_create_append_only_guards.sql.

create table public.consent_event (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(id),
  event_type text not null,
  version text not null,
  document_hash text not null,
  method text not null default 'in_app_checkbox',
  occurred_at timestamptz not null default now(),

  constraint consent_event_type_check check (event_type in ('granted', 'withdrawn'))
);

comment on table public.consent_event is
  'Append-only consent log. Never updated. Current state is computed from the latest event.
   @omit';
comment on column public.consent_event.event_type is
  'granted or withdrawn. Re-granting after withdrawal is a new granted row.';
comment on column public.consent_event.document_hash is
  'SHA-256 of the exact consent text shown. Proves which words were displayed.';
comment on column public.consent_event.method is
  'How consent was captured. Default in_app_checkbox for V1.';

-- has_active_consent() sorts on every call, including from RLS-adjacent paths.
create index consent_event_user_time_idx
  on public.consent_event (user_id, occurred_at desc);

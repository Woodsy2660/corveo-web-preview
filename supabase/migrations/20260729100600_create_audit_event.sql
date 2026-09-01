-- Migration: Create audit_event table
-- Purpose: Append-only audit log for all state changes (A.12.6, D.4)
-- Ref: docs/02-data-model-and-api.md §1.4; docs/migration-plan-v0.2.md §07
--
-- Written inside the same transaction as the change it records, from
-- security-definer functions only. Patients have no policy on this table.

create table public.audit_event (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.app_user(id),
  actor_type text not null,
  actor_id uuid,
  event_type text not null,
  target_table text,
  target_id uuid,
  detail jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),

  constraint audit_event_actor_type_check
    check (actor_type in ('patient', 'system', 'corveo_admin')),
  constraint audit_event_event_type_check
    check (event_type in (
      'observation_ingested',
      'observation_soft_deleted',
      'consent_granted',
      'consent_withdrawn',
      'export_generated',
      'identity_deleted',
      'patient_enrolled'
    ))
);

comment on table public.audit_event is
  'Append-only audit log. Single source for who did what. Satisfies A.12.6 and D.4.
   @omit';
comment on column public.audit_event.user_id is 'Nullable for system-level events.';
comment on column public.audit_event.actor_type is 'patient, system, or corveo_admin.';
comment on column public.audit_event.event_type is
  'patient_enrolled, observation_ingested, observation_soft_deleted, consent_granted, consent_withdrawn, export_generated, identity_deleted.';
comment on column public.audit_event.detail is 'Counts, rejection reasons, source system.';

create index audit_event_user_time_idx
  on public.audit_event (user_id, occurred_at desc);
create index audit_event_type_time_idx
  on public.audit_event (event_type, occurred_at desc);

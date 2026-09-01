-- Migration: Enable RLS and create patient-facing policies
-- Purpose: Row-level isolation for all patient data
-- Ref: docs/02-data-model-and-api.md §3.5; docs/migration-plan-v0.2.md §11
--
-- No INSERT / UPDATE / DELETE policy on observation or observation_component.
-- All clinical writes go through security-definer RPCs.
-- consent_event has no INSERT policy — writes go through record_consent().

alter table public.app_user enable row level security;
alter table public.observation enable row level security;
alter table public.observation_component enable row level security;
alter table public.consent_event enable row level security;
alter table public.audit_event enable row level security;
alter table public.program_progress enable row level security;

-- observation_definition is reference data (no patient rows). Ungranted to
-- clients; security-definer RPCs read it as owner.

--------------------------------------------------------------------------------
-- app_user
--------------------------------------------------------------------------------

create policy app_user_select_own on public.app_user
  for select
  using (id = public.get_app_user_id());

--------------------------------------------------------------------------------
-- observation
--------------------------------------------------------------------------------

create policy observation_select_own on public.observation
  for select
  using (
    user_id = public.get_app_user_id()
    and deleted_at is null
  );

--------------------------------------------------------------------------------
-- observation_component
--------------------------------------------------------------------------------

create policy observation_component_select_own on public.observation_component
  for select
  using (
    exists (
      select 1
        from public.observation o
       where o.id = observation_component.observation_id
         and o.user_id = public.get_app_user_id()
         and o.deleted_at is null
    )
  );

--------------------------------------------------------------------------------
-- consent_event — read own; writes via record_consent()
--------------------------------------------------------------------------------

create policy consent_event_select_own on public.consent_event
  for select
  using (user_id = public.get_app_user_id());

--------------------------------------------------------------------------------
-- audit_event — RLS enabled, no policy: patients cannot read
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- program_progress
--------------------------------------------------------------------------------

create policy program_progress_select_own on public.program_progress
  for select
  using (user_id = public.get_app_user_id());

create policy program_progress_insert_own on public.program_progress
  for insert
  with check (user_id = public.get_app_user_id());

create policy program_progress_update_own on public.program_progress
  for update
  using (user_id = public.get_app_user_id())
  with check (user_id = public.get_app_user_id());

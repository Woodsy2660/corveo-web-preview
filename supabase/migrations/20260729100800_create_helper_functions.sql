-- Migration: Helper functions for RLS and RPCs
-- Purpose: Auth resolution, consent check, append-only guard
-- Ref: docs/02-data-model-and-api.md §3.3; docs/migration-plan-v0.2.md §09
--
-- Every security definer function pins search_path and fully qualifies names.
-- An unpinned security definer function is a privilege-escalation vector.

create or replace function public.get_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select au.id
    from public.app_user au
   where au.auth_user_id = auth.uid()
     and au.identity_deleted_at is null
$$;

comment on function public.get_app_user_id() is
  'Resolves auth.uid() to app_user.id, ignoring identity-deleted rows. Used in RLS policies.';

create or replace function public.has_active_consent(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select ce.event_type = 'granted'
       from public.consent_event ce
      where ce.user_id = p_user_id
      order by ce.occurred_at desc, ce.id desc
      limit 1),
    false
  )
$$;

comment on function public.has_active_consent(uuid) is
  'True if the latest consent_event for the user is granted. Security definer so the result does not depend on the caller''s RLS.';

create or replace function public.prevent_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '%.% is append-only', tg_table_schema, tg_table_name
    using errcode = 'P0001';
end;
$$;

comment on function public.prevent_mutation() is
  'BEFORE UPDATE OR DELETE trigger function. Enforces append-only on consent_event and audit_event.';

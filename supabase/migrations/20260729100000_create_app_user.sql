-- Migration: Create app_user table
-- Purpose: Durable patient identifier that outlives auth identity deletion
-- Ref: docs/02-data-model-and-api.md §1.4, docs/migration-plan-v0.2.md §01
--
-- Enrolment is explicit via enrol_patient() — there is no trigger on
-- auth.users. An anonymous session at launch must not create a patient row.

create table public.app_user (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text,
  adult_attested boolean not null default false,
  adult_attested_at timestamptz,
  identity_deleted_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.app_user is
  'Durable patient identifier. Survives auth identity deletion per App Store 5.1.1(v) and the health-records retention floor.
   @omit';
comment on column public.app_user.auth_user_id is
  'Nullable unique FK to auth.users. Nulled on identity deletion; this row survives. Unique so get_app_user_id() is a scalar.';
comment on column public.app_user.adult_attested is
  '18+ attestation gate. Required for the adults-only retention position.';
comment on column public.app_user.adult_attested_at is
  'Evidentiary: proves when the attestation was made.';
comment on column public.app_user.identity_deleted_at is
  'Set when the auth identity is deleted. Distinguishes retained-under-law from active.';
comment on column public.app_user.created_at is
  'Start of the retention clock.';

-- Unique on auth_user_id already covers the get_app_user_id() lookup.
-- Multiple NULLs are permitted, which is required after identity deletion.

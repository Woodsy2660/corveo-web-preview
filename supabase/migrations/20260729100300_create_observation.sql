-- Migration: Create observation table
-- Purpose: Parent observation record — one row per clinical event
-- Ref: docs/02-data-model-and-api.md §1.4; docs/migration-plan-v0.2.md §04
--
-- is_panel is denormalised from observation_definition on write so the
-- value-shape CHECK is local (a CHECK cannot reference another table).
-- PROHIBITED: DELETE on this table. PROHIBITED: category / severity / band /
-- is_high / risk_score / heart_age / normal_range.

create table public.observation (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_user(id),

  status text not null default 'final',

  code_system text not null,
  code text not null references public.observation_definition(code),
  code_display text not null,
  code_system_snomed text not null,
  code_snomed text not null,

  -- Copied from observation_definition on ingest so the CHECK is implementable.
  is_panel boolean not null default false,

  value_quantity numeric,
  value_unit text,
  value_code text,
  value_string text,
  value_boolean boolean,
  data_absent_reason text,

  body_site_system text,
  body_site_code text,
  context jsonb not null default '{}'::jsonb,

  effective_time timestamptz not null,
  -- Australian users first; ingest always supplies the IANA name when known.
  effective_tz text not null default 'Australia/Sydney',
  effective_offset_minutes integer,
  recorded_at timestamptz not null default now(),

  source_type text not null,
  source_uuid text not null,
  source_system text not null,
  source_name text,
  source_device_model text,
  source_user_entered boolean not null default false,

  deleted_at timestamptz,
  deleted_reason text,

  created_at timestamptz not null default now(),

  constraint observation_status_check
    check (status in (
      'registered','preliminary','final','amended','corrected',
      'entered-in-error','cancelled','unknown'
    )),
  constraint observation_source_type_check
    check (source_type in ('healthkit','manual')),
  constraint observation_deleted_reason_check
    check (deleted_reason is null or deleted_reason in (
      'deleted_in_source','patient_removed','entered_in_error'
    )),
  constraint observation_deleted_pair_check
    check ((deleted_at is null) = (deleted_reason is null)),
  constraint observation_value_shape check (
    (is_panel
       and num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 0
       and data_absent_reason is null)
    or (not is_panel
       and num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 1
       and data_absent_reason is null)
    or (not is_panel
       and num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 0
       and data_absent_reason is not null)
  ),
  constraint observation_unit_with_quantity check (
    value_quantity is null or value_unit is not null
  ),
  constraint observation_dedup_key unique (user_id, source_system, source_uuid)
);

comment on table public.observation is
  'Parent observation record. BP, heart rate, and future modules land here identically.
   @omit';
comment on column public.observation.is_panel is
  'Structural copy of observation_definition.is_panel. Not a clinical interpretation.';
comment on column public.observation.body_site_code is
  'Always null for HealthKit readings. No standard metadata key for cuff arm.';
comment on column public.observation.effective_tz is
  'IANA timezone name. Derive local time from this, never from UTC.';
comment on column public.observation.source_user_entered is
  'HKMetadataKeyWasUserEntered. Distinguishes device-measured from typed-into-Health.';
comment on column public.observation.deleted_at is
  'Soft delete. Hard DELETE is prohibited by A.12.6.';

create index observation_user_time_idx
  on public.observation (user_id, effective_time desc)
  where deleted_at is null;

create index observation_code_idx
  on public.observation (code);

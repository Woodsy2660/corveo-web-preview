-- Migration: Create observation_component table
-- Purpose: Child records for panel components (systolic / diastolic)
-- Ref: docs/02-data-model-and-api.md §1.4; docs/migration-plan-v0.2.md §05
--
-- source_uuid is NOT NULL: HKDeletedObject carries only a UUID, and which
-- UUID arrives depends on the type the deletion was observed against.
-- Store the correlation UUID on the parent and each sample UUID here.

create table public.observation_component (
  id uuid primary key default gen_random_uuid(),
  observation_id uuid not null references public.observation(id) on delete cascade,

  code_system text not null,
  code text not null references public.observation_definition(code),
  code_display text not null,
  code_system_snomed text not null,
  code_snomed text not null,

  value_quantity numeric,
  value_unit text,
  value_code text,
  value_string text,
  value_boolean boolean,
  data_absent_reason text,

  source_uuid text not null,

  constraint observation_component_unique_code unique (observation_id, code),
  constraint observation_component_value_shape check (
    (num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 1
       and data_absent_reason is null)
    or (num_nonnulls(value_quantity, value_code, value_string, value_boolean) = 0
       and data_absent_reason is not null)
  ),
  constraint observation_component_unit_with_quantity check (
    value_quantity is null or value_unit is not null
  )
);

comment on table public.observation_component is
  'Child records for panel observations. BP has two: systolic and diastolic. No independent deleted_at; parent soft-delete suffices.
   @omit';
comment on column public.observation_component.source_uuid is
  'HKQuantitySample.uuid. Required for deletion matching (docs/03 §5.3).';

-- Postgres does not auto-index FKs. This is the join behind every read
-- and the RLS subquery on top of it.
create index observation_component_observation_id_idx
  on public.observation_component (observation_id);

-- Deletion matching; otherwise every deletion batch is a sequential scan.
create index observation_component_source_uuid_idx
  on public.observation_component (source_uuid);

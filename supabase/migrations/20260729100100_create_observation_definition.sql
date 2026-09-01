-- Migration: Create observation_definition table
-- Purpose: Reference data for observation types with data-quality bounds
-- Ref: docs/02-data-model-and-api.md §1.3, §1.4; docs/migration-plan-v0.2.md §02
--
-- Adding Weight or Cholesterol is a row insert, not a schema change.
-- PROHIBITED: category, severity, band, normal_range, or any interpretation column.

create table public.observation_definition (
  code text primary key,
  code_system text not null default 'http://loinc.org',
  code_display text not null,
  code_system_snomed text not null default 'http://snomed.info/sct',
  code_snomed text not null,
  parent_code text references public.observation_definition(code),
  expected_unit text,
  min_value numeric,
  max_value numeric,
  is_panel boolean not null default false,
  display_in_v1 boolean not null default true,
  sort_order integer not null default 0,
  constraint observation_definition_unit_or_panel
    check (expected_unit is not null or is_panel)
);

comment on table public.observation_definition is
  'Reference data for observation types. Adding a module is a row insert.
   @omit';
comment on column public.observation_definition.code is 'LOINC code (primary key).';
comment on column public.observation_definition.code_snomed is
  'SNOMED CT code. Mandatory per AU Core dual-coding.';
comment on column public.observation_definition.parent_code is
  'Panel membership. Lets ingest reject an orphan component.';
comment on column public.observation_definition.expected_unit is
  'UCUM unit. Ingest rejects any other; V1 performs no conversion.';
comment on column public.observation_definition.min_value is
  'Data-quality floor. Not clinical interpretation.';
comment on column public.observation_definition.max_value is
  'Data-quality ceiling. Not clinical interpretation.';
comment on column public.observation_definition.is_panel is
  'Structural: whether components are expected. Carries no clinical meaning.';
comment on column public.observation_definition.display_in_v1 is
  'False for types captured but not shown (heart rate, once seeded).';

create index observation_definition_parent_code_idx
  on public.observation_definition (parent_code);

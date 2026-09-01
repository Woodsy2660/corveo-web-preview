-- Migration: Seed BP observation types
-- Purpose: Blood pressure panel, systolic, diastolic
-- Ref: docs/02-data-model-and-api.md §1.3; docs/migration-plan-v0.2.md §03
--
-- Heart rate (8867-4) is deliberately not seeded. Open item D-01: the AU Core
-- Heart Rate SNOMED code is unconfirmed. A TBD in a NOT NULL column would
-- ship. Until its own migration lands, ingest_observations rejects 8867-4
-- with UNKNOWN_CODE — the plugin still requests the HealthKit permission.

insert into public.observation_definition (
  code, code_display, code_snomed, parent_code,
  expected_unit, min_value, max_value, is_panel, display_in_v1, sort_order
) values
  ('85354-9', 'Blood pressure panel', '75367002', null,
    null, null, null, true, true, 10),
  ('8480-6', 'Systolic blood pressure', '271649006', '85354-9',
    'mm[Hg]', 60, 260, false, true, 11),
  ('8462-4', 'Diastolic blood pressure', '271650006', '85354-9',
    'mm[Hg]', 30, 160, false, true, 12);

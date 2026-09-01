# BP Reset V1 — Migration Plan

| | |
|---|---|
| **Status** | Superseded by `migration-plan-v0.2.md` |
| **Owner** | Ben (platform) |
| **Date** | 20 August 2026 |
| **Source** | Derived from `02-data-model-and-api.md` |

> **Implemented SQL follows v0.2.** This v0.1 draft transcribed the tables accurately but omitted write paths and carried two security defects. The files in `supabase/migrations/` match `docs/migration-plan-v0.2.md`. Keep this document as the historical sequence; do not apply it.

---

## Overview

This document lists all planned Supabase migrations for BP Reset V1. Migrations are forward-only, one concern per file, and applied through CI using Corveo-held credentials.

**Naming convention:** `YYYYMMDDHHMMSS_description.sql`

---

## Migration Sequence

| # | File | Description | Dependencies |
|---|---|---|---|
| 01 | `20260729100000_create_app_user.sql` | Create `app_user` table linking to `auth.users` | None |
| 02 | `20260729100100_create_observation_definition.sql` | Create `observation_definition` reference table | None |
| 03 | `20260729100200_seed_observation_definitions.sql` | Seed BP panel, systolic, diastolic, heart rate codes | 02 |
| 04 | `20260729100300_create_observation.sql` | Create `observation` parent table | 01, 02 |
| 05 | `20260729100400_create_observation_component.sql` | Create `observation_component` child table | 04 |
| 06 | `20260729100500_create_consent_event.sql` | Create append-only `consent_event` table | 01 |
| 07 | `20260729100600_create_audit_event.sql` | Create append-only `audit_event` table | 01 |
| 08 | `20260729100700_create_program_progress.sql` | Create `program_progress` table | 01 |
| 09 | `20260729100800_create_helper_functions.sql` | Create `get_app_user_id()`, `has_active_consent()` | 01, 06 |
| 10 | `20260729100900_create_rls_policies.sql` | Enable RLS and create all policies | 01-08 |
| 11 | `20260729101000_create_views.sql` | Create `v_bp_readings`, `v_bp_trend`, `v_consent_status` | 04, 05, 06 |
| 12 | `20260729101100_create_ingest_rpc.sql` | Create `ingest_observations` security-definer RPC | 04, 05, 09 |
| 13 | `20260729101200_create_export_rpc.sql` | Create `export_patient_data` RPC (Deliverable 12) | 04, 05 |

---

## Migration Details

### 01: `create_app_user.sql`

Creates the durable patient identifier that outlives auth identity deletion.

**Table: `app_user`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Never reused, never deleted |
| `auth_user_id` | `uuid` | `REFERENCES auth.users(id) ON DELETE SET NULL` | Nullable for identity deletion |
| `display_name` | `text` | | Cleared on identity deletion |
| `adult_attested` | `boolean` | `NOT NULL DEFAULT false` | 18+ gate |
| `adult_attested_at` | `timestamptz` | | Evidentiary timestamp |
| `identity_deleted_at` | `timestamptz` | | Set when auth identity deleted |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Retention clock start |

**Trigger:** Auto-create `app_user` row on `auth.users` insert.

---

### 02: `create_observation_definition.sql`

Reference table for observation types with validation bounds.

**Table: `observation_definition`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `code` | `text` | `PRIMARY KEY` | LOINC code |
| `code_system` | `text` | `NOT NULL DEFAULT 'http://loinc.org'` | |
| `code_display` | `text` | `NOT NULL` | Human label |
| `code_system_snomed` | `text` | `NOT NULL DEFAULT 'http://snomed.info/sct'` | |
| `code_snomed` | `text` | `NOT NULL` | SNOMED CT code |
| `parent_code` | `text` | `REFERENCES observation_definition(code)` | Panel membership |
| `expected_unit` | `text` | | UCUM code |
| `min_value` | `numeric` | | Data quality floor |
| `max_value` | `numeric` | | Data quality ceiling |
| `is_panel` | `boolean` | `NOT NULL DEFAULT false` | Expects components |
| `display_in_v1` | `boolean` | `NOT NULL DEFAULT true` | UI visibility |
| `sort_order` | `integer` | `NOT NULL DEFAULT 0` | Deterministic ordering |

---

### 03: `seed_observation_definitions.sql`

Seeds the four observation types for V1.

| code | display | snomed | parent | unit | min | max | panel | display_v1 | sort |
|---|---|---|---|---|---|---|---|---|---|
| `85354-9` | Blood pressure panel | `75367002` | — | — | — | — | yes | yes | 10 |
| `8480-6` | Systolic BP | `271649006` | `85354-9` | `mm[Hg]` | 60 | 260 | no | yes | 11 |
| `8462-4` | Diastolic BP | `271650006` | `85354-9` | `mm[Hg]` | 30 | 160 | no | yes | 12 |
| `8867-4` | Heart rate | `TBD` | — | `/min` | 30 | 220 | no | **no** | 20 |

**Open item:** Heart rate SNOMED code needs verification against AU Core Heart Rate profile.

---

### 04: `create_observation.sql`

Parent observation table — one row per clinical event.

**Table: `observation`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `user_id` | `uuid` | `NOT NULL REFERENCES app_user(id)` | Subject |
| `status` | `text` | `NOT NULL DEFAULT 'final'` | FHIR status |
| `code_system` | `text` | `NOT NULL` | `http://loinc.org` |
| `code` | `text` | `NOT NULL` | LOINC code |
| `code_display` | `text` | `NOT NULL` | |
| `code_system_snomed` | `text` | `NOT NULL` | `http://snomed.info/sct` |
| `code_snomed` | `text` | `NOT NULL` | SNOMED code |
| `value_quantity` | `numeric` | | Numeric value |
| `value_unit` | `text` | | UCUM unit |
| `value_code` | `text` | | Coded value |
| `value_string` | `text` | | Free-text value |
| `value_boolean` | `boolean` | | Boolean value |
| `data_absent_reason` | `text` | | Why value missing |
| `body_site_system` | `text` | | NCTS body-site-1 |
| `body_site_code` | `text` | | Body site code |
| `context` | `jsonb` | `DEFAULT '{}'::jsonb` | Posture, cuff size |
| `effective_time` | `timestamptz` | `NOT NULL` | Measurement UTC |
| `effective_tz` | `text` | | IANA timezone |
| `effective_offset_minutes` | `integer` | | UTC offset |
| `recorded_at` | `timestamptz` | `NOT NULL DEFAULT now()` | System entry time |
| `source_type` | `text` | `NOT NULL` | `healthkit` or `manual` |
| `source_uuid` | `text` | `NOT NULL` | Dedup key |
| `source_system` | `text` | `NOT NULL` | Bundle identifier |
| `source_name` | `text` | | Display name |
| `source_device_model` | `text` | | Device model |
| `source_user_entered` | `boolean` | `DEFAULT false` | Manual in HealthKit |
| `deleted_at` | `timestamptz` | | Soft delete |
| `deleted_reason` | `text` | | Why deleted |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Row creation |

**Constraints:**
- `UNIQUE (user_id, source_system, source_uuid)` — dedup key
- `CHECK` — exactly one of: value column populated, `data_absent_reason` set, or `is_panel` code

**Indexes:**
- `(user_id, effective_time DESC) WHERE deleted_at IS NULL` — keyset pagination

---

### 05: `create_observation_component.sql`

Child table for panel components (systolic/diastolic).

**Table: `observation_component`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `observation_id` | `uuid` | `NOT NULL REFERENCES observation(id) ON DELETE CASCADE` | Parent |
| `code_system` | `text` | `NOT NULL` | |
| `code` | `text` | `NOT NULL` | |
| `code_display` | `text` | `NOT NULL` | |
| `code_system_snomed` | `text` | `NOT NULL` | |
| `code_snomed` | `text` | `NOT NULL` | |
| `value_quantity` | `numeric` | | |
| `value_unit` | `text` | | |
| `value_code` | `text` | | |
| `value_string` | `text` | | |
| `value_boolean` | `boolean` | | |
| `data_absent_reason` | `text` | | |
| `source_uuid` | `text` | | Component dedup key |

**Constraints:**
- `UNIQUE (observation_id, code)` — one systolic, one diastolic per reading

---

### 06: `create_consent_event.sql`

Append-only consent event log.

**Table: `consent_event`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `user_id` | `uuid` | `NOT NULL REFERENCES app_user(id)` | |
| `event_type` | `text` | `NOT NULL CHECK (event_type IN ('granted', 'withdrawn'))` | |
| `version` | `text` | `NOT NULL` | Consent version |
| `document_hash` | `text` | `NOT NULL` | SHA-256 of consent text |
| `method` | `text` | `NOT NULL DEFAULT 'in_app_checkbox'` | |
| `occurred_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

**No UPDATE or DELETE** — append-only by design.

---

### 07: `create_audit_event.sql`

Append-only audit log for all state changes.

**Table: `audit_event`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `user_id` | `uuid` | `REFERENCES app_user(id)` | Nullable for system events |
| `actor_type` | `text` | `NOT NULL` | `patient`, `system`, `corveo_admin` |
| `actor_id` | `uuid` | | Which actor |
| `event_type` | `text` | `NOT NULL` | Event category |
| `target_table` | `text` | | Affected table |
| `target_id` | `uuid` | | Affected row |
| `detail` | `jsonb` | `DEFAULT '{}'::jsonb` | Counts, reasons |
| `occurred_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

**Event types:** `observation_ingested`, `observation_soft_deleted`, `consent_granted`, `consent_withdrawn`, `export_generated`, `identity_deleted`

---

### 08: `create_program_progress.sql`

Journey state persisted server-side.

**Table: `program_progress`**

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `user_id` | `uuid` | `PRIMARY KEY REFERENCES app_user(id)` | |
| `current_week` | `integer` | `NOT NULL DEFAULT 1` | 1-6 |
| `completed_steps` | `jsonb` | `DEFAULT '{}'::jsonb` | Step completion |
| `updated_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

---

### 09: `create_helper_functions.sql`

Shared helper functions for RLS and RPCs.

**Function: `get_app_user_id()`**
```sql
create function get_app_user_id()
returns uuid language sql stable security definer as $$
  select id from app_user where auth_user_id = auth.uid()
$$;
```

**Function: `has_active_consent(uuid)`**
```sql
create function has_active_consent(p_user_id uuid)
returns boolean language sql stable as $$
  select coalesce(
    (select event_type = 'granted'
       from consent_event
      where user_id = p_user_id
      order by occurred_at desc, id desc
      limit 1),
    false
  );
$$;
```

---

### 10: `create_rls_policies.sql`

Row-level security for all patient data tables.

**Policies:**

| Table | Policy | Rule |
|---|---|---|
| `app_user` | `select_own` | `id = get_app_user_id()` |
| `observation` | `select_own` | `user_id = get_app_user_id() AND deleted_at IS NULL` |
| `observation_component` | `select_own` | Via parent join |
| `consent_event` | `select_own` | `user_id = get_app_user_id()` |
| `consent_event` | `insert_own` | `user_id = get_app_user_id()` |
| `audit_event` | None | Patients cannot read audit log |
| `program_progress` | `select_own` | `user_id = get_app_user_id()` |
| `program_progress` | `upsert_own` | `user_id = get_app_user_id()` |

**No direct INSERT/UPDATE/DELETE** on `observation` — all writes via `ingest_observations` RPC.

---

### 11: `create_views.sql`

Read views that flatten the parent/child model.

**View: `v_bp_readings`**
```sql
create view v_bp_readings as
select
  o.id,
  o.effective_time,
  o.effective_tz,
  (select value_quantity from observation_component where observation_id = o.id and code = '8480-6') as systolic,
  (select value_quantity from observation_component where observation_id = o.id and code = '8462-4') as diastolic,
  o.source_type,
  o.source_name,
  o.body_site_code
from observation o
where o.code = '85354-9'
  and o.deleted_at is null
  and o.user_id = get_app_user_id();
```

**View: `v_bp_trend`**
Daily aggregates for chart rendering.

**View: `v_consent_status`**
```sql
create view v_consent_status as
select
  has_active_consent(get_app_user_id()) as has_active_consent,
  (select version from consent_event where user_id = get_app_user_id() order by occurred_at desc limit 1) as version,
  (select occurred_at from consent_event where user_id = get_app_user_id() order by occurred_at desc limit 1) as last_event_at;
```

---

### 12: `create_ingest_rpc.sql`

The single write path for observations.

**Function: `ingest_observations(jsonb)`**

- Security definer (bypasses RLS for insert)
- Validates consent via `has_active_consent()`
- Validates bounds from `observation_definition`
- Upserts on `(user_id, source_system, source_uuid)`
- Soft-deletes by `deleted_source_uuids`
- Writes `audit_event` rows in same transaction
- Returns `{inserted, duplicates, soft_deleted, rejected[]}`

**Rejection reasons:** `VALUE_OUT_OF_BOUNDS`, `UNIT_MISMATCH`, `UNKNOWN_CODE`, `SYSTOLIC_NOT_GREATER`, `MALFORMED_TIMESTAMP`, `MISSING_COMPONENT`

---

### 13: `create_export_rpc.sql`

Patient data export for Deliverable 12.

**Function: `export_patient_data()`**

- Returns FHIR R4 Bundle JSON + CSV
- Uses AU Core mapping from `02-data-model-and-api.md` §2
- Writes `audit_event` with `event_type = 'export_generated'`

---

## Constraints Summary

### Prohibited Columns (A.3.3 compliance)

These columns **must never be added**:
- `category` / `severity` / `band`
- `is_high` / `is_low` / `is_normal`
- `risk_score` / `heart_age`
- `normal_range` / `reference_range`
- Any column that interprets a clinical value

### Required Audit Trail (A.12.6 compliance)

All state changes must write to `audit_event`:
- Observation insert → `observation_ingested`
- Observation soft delete → `observation_soft_deleted`
- Consent granted → `consent_granted`
- Consent withdrawn → `consent_withdrawn`
- Export generated → `export_generated`
- Identity deleted → `identity_deleted`

---

## Open Items

| # | Item | Blocks |
|---|---|---|
| D-01 | AU Core Heart Rate SNOMED code | Migration 03 |
| D-03 | NCTS body-site codes for left/right upper arm | Manual entry validation |

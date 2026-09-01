# Database Migrations

Implemented against `docs/migration-plan-v0.2.md`, which supersedes the v0.1 draft in `docs/05-migration-plan.md`.

## Rules

1. **Forward-only** — Never rolled back in production. Write a compensating migration instead.
2. **One concern per file** — Do not bundle unrelated changes.
3. **Never edited after merge** — Once merged to `main`, a file is immutable.
4. **Applied to production only through CI** — Corveo-held credential. Never apply to `staging` or `prod` from a local terminal. The `dev` project may be pushed from a local machine during platform work.

## Sequence (v0.2)

| # | File | Notes |
|---|---|---|
| 01 | `create_app_user` | Unique `auth_user_id`. No trigger on `auth.users`. |
| 02 | `create_observation_definition` | Unit-or-panel CHECK. |
| 03 | `seed_observation_definitions_bp` | BP panel only. Heart rate blocked on D-01. |
| 04 | `create_observation` | Denormalised `is_panel`, enum CHECKs, FK to definition. |
| 05 | `create_observation_component` | `source_uuid NOT NULL`, join and deletion indexes. |
| 06 | `create_consent_event` | Append-only log. |
| 07 | `create_audit_event` | Actor and event-type CHECKs. |
| 08 | `create_program_progress` | `updated_at` trigger, week 1–6. |
| 09 | `create_helper_functions` | Pinned `search_path` on security definers. |
| 10 | `create_append_only_guards` | Trigger + revoke, not a comment. |
| 11 | `create_rls_policies` | No patient INSERT on consent or observations. |
| 12 | `create_views` | `security_invoker = true`. |
| 13 | `create_ingest_rpc` | Consent-gated; parent-or-component deletion match. |
| 14 | `create_patient_rpcs` | `enrol_patient`, `record_consent`, `withdraw_consent`, `soft_delete_observation`, `delete_account`. |
| 15 | `create_export_rpc` | FHIR Bundle + CSV (Deliverable 12). |
| 16 | `grants` | Explicit GRANT/REVOKE. |

Heart rate seed is **not** in this series (D-01).

## Naming

`YYYYMMDDHHMMSS_description.sql`

## Review

PRs touching this directory require Ben's review before merge.

# Architectural Decision Records

This file records decisions made during the BP Reset V1 build. Each entry follows the format:

- **Context**: The situation or problem
- **Decision**: What we chose
- **Consequences**: What follows from the choice

Add new decisions at the end. Do not edit or remove existing entries.

---

## A-01: Native iOS app as sole data gateway

**Context**: Apple Health has no cloud API. Its data is on-device and reachable only through a native iOS app.

**Decision**: The app is the only possible gateway; there is no server-to-server route.

**Consequences**: All HealthKit data must flow through the native plugin. No alternative ingest path exists.

---

## A-02: HealthKit is the durable queue; anchor advances only on 2xx

**Context**: We need to guarantee no readings are lost during sync, without storing health data on device.

**Decision**: The plugin advances its `HKQueryAnchor` only after Supabase confirms the write with a 2xx response. Failed uploads leave samples unread for redelivery.

**Consequences**: Removes on-device health data storage entirely. No local SQLite outbox needed. Avoids iCloud backup risk of a shadow health record.

---

## A-03: Native uploads directly to Supabase in background

**Context**: Background delivery wakes the native app while the WebView and JS runtime may be suspended or absent.

**Decision**: The native plugin uploads directly to Supabase during background wakes, not via JS.

**Consequences**: Background readings are never silently dropped. The plugin must handle auth token refresh autonomously.

---

## A-04: PostgREST + RLS for reads; single RPC for ingest

**Context**: We need an API surface without introducing unnecessary deployment complexity.

**Decision**: Use PostgREST for reads and a single Postgres RPC (`ingest_observations`) for writes. No Edge Functions in V1.

**Consequences**: No extra deploy target, no cold starts. Validation lives beside the constraints that enforce it. Edge Functions become necessary only when a client-inaccessible secret is required.

---

## A-05: Parent/child observation model

**Context**: SOW A.3.4 requires a generic observation model that is migration-safe for later result types. Blood pressure is structurally a panel with components.

**Decision**: Use `observation` (parent) and `observation_component` (child) tables. A BP reading is one parent with two components.

**Consequences**: Matches AU Core structure (which mandates `component` at 2..* for BP) and HealthKit structure (correlation with child samples). Future modules (cholesterol, weight) add rows, not schema changes.

---

## A-06: Soft delete only, with audit log

**Context**: SOW A.12.6 requires retention against the health-records floor by deletion-with-logging.

**Decision**: No `DELETE` on `observation`. Soft delete via `deleted_at` column. All deletions logged to `audit_event`.

**Consequences**: RLS excludes soft-deleted rows from patient-facing reads. Hard deletion is a privileged operation Corveo performs directly. Full audit trail preserved.

---

## A-07: No third-party SDKs

**Context**: The Engagement Data Schedule records zero sub-processors. Adding any SDK that transmits data off-device requires prior disclosure under Annexure D clause D.5.

**Decision**: No Sentry, Firebase, or equivalent analytics/crash-reporting SDKs.

**Consequences**: Crash and error reporting must use native mechanisms or be deferred. Any future SDK addition requires Andrew's sign-off before the PR is opened.

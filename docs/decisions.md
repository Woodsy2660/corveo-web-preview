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

---

## F-01: Front-end stack pinned at kickoff (React 19, Vite 8, TS 5.9, react-router 8, TanStack Query 5, Tailwind 4)

**Context**: The July docs named React 18 + Capacitor 6; both ecosystems had moved a major version by build kickoff (14 Aug 2026). TypeScript 7 (the native compiler) shipped weeks ago and is not yet battle-tested across the toolchain.

**Decision**: Build on current stable majors — React 19, Vite 8, react-router 8, TanStack Query 5, Tailwind 4 — with TypeScript held at 5.9. React Query is the formal data-fetching layer (it was implied but undocumented). Dev server port is pinned to 5184 (strictPort).

**Consequences**: No mid-build major upgrades. TS 7 migration is a deliberate later decision. The Capacitor major remains the native lane's choice (see F-02).

---

## F-02: Web app stays Capacitor-agnostic until the shell lands

**Context**: The Capacitor shell, Xcode project and TestFlight pipeline are the native lane's scope, and Capacitor has moved to 8.x since the docs were written.

**Decision**: `src/` has no Capacitor dependency. The plugin bridge is consumed through `src/lib/health/index.ts`, a factory returning the web mock; the native lane swaps in `registerPlugin` when the shell exists and picks the Capacitor version.

**Consequences**: Front end builds, tests and deploys as a plain web app; the Vercel preview needs no native toolchain. Integration is a one-file change. The frozen interface in `03-plugin-bridge-spec.md` §3 is the compatibility contract (copied verbatim into `src/lib/health/types.ts`).

---

## F-03: Hand-written typed mock instead of OpenAPI-generated mock

**Context**: The README describes a mock generated from `docs/api/openapi.yaml`, but that spec is stubs (schemas TODO) and no generator exists. Waiting on it blocked the entire front-end lane.

**Decision**: Code against a `CorveoApi` TypeScript interface (`src/lib/api/types.ts`) whose shapes mirror `02-data-model-and-api.md` Part 4 verbatim, with a hand-written in-memory mock (`src/lib/api/mock.ts`) over deterministic synthetic fixtures.

**Consequences**: The interface, not the YAML, is the working contract; the OpenAPI spec can be completed later as confirmation. One gap surfaced: Part 4 defines no consent write path — the mock invented `recordConsentEvent`, which the real API must specify (open item F-B in `04-front-end.md`).

---

## F-04: Settings is a stack screen, not a fourth tab

**Context**: The repo defines three tabs (Readings, Trend, Program). Deliverable 12 (export, deletion, safety copy) and the Apple Health status need a home.

**Decision**: Settings lives at `/app/settings`, reached from a header link on each tab, with the validated-cuff list at `/app/cuffs` beneath it. The tab bar stays three tabs.

**Consequences**: Deliverables 8 and 12 have surfaces without changing the agreed information architecture.

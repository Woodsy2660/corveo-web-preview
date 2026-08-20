# Deviations log

Every departure from `BP-Reset-HealthKit-Implementation-Guide-v1.3.md`, logged as it happens,
for the as-built republish at P5 (§12 Phase 5, §17.1).

**Rule (guide §1):** the guide is not silently deviated from. Where device reality contradicts
the document, the device wins — the spike result is recorded in an ADR, the guide section is
amended, and the change is logged here. Where I merely *believe* a section is wrong, I say so
explicitly, propose the smallest on-device experiment that settles it, and nothing changes
until it is settled.

## Status: 20 August 2026

**Deviations: one — D-001, below.**

The §13 migration was extracted verbatim (sha256-verified against guide lines 797–997) with
nothing corrected in transit. No plugin code has been written yet.

**Phase 0 gates cleared, 20 Aug 2026.** Dev iPhone on the frozen acceptance OS (iOS 26.6+;
exact build still to be recorded into ADR-0006), and the §9.4 Omron chain proven — cuff
readings are landing in Apple Health on the device. The spike is unblocked and SPK-1 is the
next action.

## Raised but not deviations

Open items that are questions or additions, not departures. Listed here so the as-built
republish has one place to look.

| # | Item | Kind | Where | Status |
|---|---|---|---|---|
| Q1 | §13 issues no table-level `GRANT` on `public.observations`; ingest depends on the project's default privileges for `authenticated` | Question → backend | `db/migrations/README.md` | Open — awaiting Ben |
| Q2 | §13's `001` FK-references `public.patients(id)`, a table no section specifies (D3 covers `enrolments` only) | Question → backend | `db/migrations/README.md` | Open — awaiting Ben |
| Q3 | T8b's expected outcome depends on arrival order; the preference order carries no `taken_at` term | Question → backend/spec | `db/migrations/README.md`, test 11 | Open — believed intended, needs confirming for the as-built §8.2 |
| Q4 | Migrations `000`/`001` are not re-runnable (`create policy` has no `IF NOT EXISTS`) | Question → backend | `db/migrations/README.md` | Open — greenfield-only as written, per §13's own note |
| Q5 | Wrong-*type* input raises a cast error rather than `STRUCTURAL_VALIDATION_FAILED`; still all-or-nothing | Question → backend | `db/migrations/README.md`, test 09 | Open — believed acceptable |
| S1 | Bundle-ID collision: §11 gives the spike reader `dev.lucab.bpspike`, §9.2 gives the Capacitor harness the same ID, while T2 requires a first-run sheet | Risk → settled on device | `docs/adr/ADR-0006-spike-outcome.md` (SPK-extra) | Open — on-device check added to the spike run sheet |
| E1 | §18's estimate (15–19 dev-days, planning number 15–18) is challenged by the developer as too high for the cadence now being worked | Amendment → needs a number | §18, open decision D4 | **Closed 20 Aug — figure supplied, amended as D-001 below.** Original note retained: Not amended unilaterally: §18 is part of the frozen spec and its arithmetic is the subject of registered open decision D4, owned by the engagement lead. Two things are separable and were conflated in the original: **effort** in developer-days, and **elapsed** calendar time. Working full consecutive days compresses the calendar without changing the effort. The one genuinely incompressible element is the **48-hour soak** (T6: T5a ×5 across 48 h including a reboot and a locked-store deferral), which is wall-clock and runs in parallel from P3 — no amount of concentration shortens it, and Stage 2 evidence depends on it. |

## Contract conflicts with the front-end foundation (19 August 2026)

Full analysis: [`integration-review-frontend-foundation.md`](integration-review-frontend-foundation.md).

`Demo/Corveo-IOS-App-frontend-foundation` is built against `docs/03-plugin-bridge-spec.md`
**v0.1 DRAFT (29 July 2026)** and `docs/02-data-model-and-api.md`. Guide v1.3 (18 August)
disagrees with both in load-bearing ways. **These are not deviations** — a deviation is
building something different from the frozen spec. This is two specifications disagreeing,
which is a decision, and every one of these decisions is owned above this lane.

Their own open item **P-01** — *"Freeze this interface with Luca before implementation
hardens · Blocks: Everything"* — is the agreed mechanism for resolving them.

| # | Conflict | Owner | Blocks |
|---|---|---|---|
| C1 | **Who uploads:** JS foreground drain (v1.3) vs native background upload with Keychain token custody (theirs, A-03) | Engagement lead + client | The whole engine design |
| C2 | **Durability:** durable two-generation on-device queue (v1.3) vs "HealthKit is the queue", anchor advances only on 2xx (theirs, A-02) | Follows C1 | P2 |
| C3 | Configuration/binding: `configure(enrolmentRef, importStart)` vs `setCredentials(tokens)` | Follows C1 | P1 |
| C4 | Backfill bound: `importStart` vs rolling 30 days | Backend + lead | P1 — recommend v1.3 |
| C5 | Timezone: metadata-or-null vs device-TZ fallback | Native — **believed a defect in theirs** | P1 |
| C6 | Read set includes `heartRate` in theirs; outside the sixteen deliverables | Lead | SPK-3 |
| C7 | Observers on both quantity types vs systolic only | Native — low impact | P2 |
| C8 | Deletions out of V1 (v1.3 §8.3) vs in scope with soft delete + audit (theirs) | Client + lead | Scope |
| C9 | Snapshot/itemId acknowledgement has no counterpart in theirs | Follows C1 | P4 |
| C10 | Permission states `notRequested\|requested` vs `notDetermined\|requested\|unknown` | Native — recommend adopting theirs | P1 |
| C11 | Error-code vocabularies differ; their `types.ts` has already drifted from their own §8 table | Native + front end | P1 |
| C12 | Toolchain: Xcode 26 / Node 22 / iOS 26.6+ frozen vs `.xcode-version` 16, `.nvmrc` 20 | Native | P0 |
| C13 | Schema: flat `observations` vs parent/child `observation` + `observation_component` (FHIR AU Core) | Backend | §13 as committed |
| C14 | RPC: `ingest_bp_batch` vs `ingest_observations` | Backend | §13 as committed |
| C15 | **Batch semantics:** all-or-nothing (v1.3) vs per-item rejection "never fatal to the batch" (theirs) | Backend + lead | Whole-snapshot ack correctness |
| C16 | **D3 answered:** their schema has no `enrolments` table, so `enrolmentRef`/`importStart` have no home | Backend | §13, §6 identity model |
| C17 | Dedup key `(patient_id, client_uuid)` vs `(user_id, source_system, source_uuid)` | Backend — recommend theirs | §13 |
| C18 | Consent gate (`CONSENT_REQUIRED`, whole call rejected) absent from v1.3's drain | Backend + front end | P4 |
| C19 | Layer-2 canonicalisation (`superseded_by`) has no counterpart in their schema; their §12 defers it | Client (D2) | §13 |
| C20 | Plugin identity: `BPHealthKit` / `com.corveo.bphealthkit` vs `registerPlugin("CorveoHealth")` | Native + front end | Integration |

**Bright-line audit of their code: PASS.** `BpChart.tsx` and `bounds.ts` are clean; their
§2 constraint list is stronger than ours in one respect (no traffic-light colour anywhere)
and that wording is worth adopting.

## Logged deviations

### D-001 — §18 estimate revised to 3 days to a working prototype

- **Date:** 20 August 2026
- **Guide section(s) affected:** §18 (estimates and descope ladder). Touches open decision D4.
- **What the guide says:** 15–19 developer-days, planning number 15–18, summed per phase after
  ship-gate 28 called out the original arithmetic.
- **What was done instead:** the lane owner revised it to **3 days to a working prototype**,
  worked as dedicated consecutive days. §18 carries an amendment note; the original table is
  retained unamended for the as-built record.
- **Why:** the estimate is the lane's own, and the lane owner is the person doing the work.
  The original was built for a fragmented cadence and against a spec that did not yet exist;
  both of those changed. Guide v1.3 is exhaustive to the point of carrying the load-bearing
  code inline, the architecture is decided, and the paper track is already committed, so the
  remaining work is implementation against a settled design rather than design.
- **Settled by:** lane owner's direction, 20 Aug, reaffirmed after the effort-versus-elapsed
  distinction was put to him.
- **Amendment status:** §18 amended in the guide; tracker and task record updated.

**Recorded alongside, because it is arithmetic rather than opinion and the two get conflated:**
a working prototype is not Stage 2 acceptance, and the gap is not developer speed. Acceptance
additionally needs **(a)** T6's 48-hour soak, which is wall-clock and can only begin once the
engine arms — so it should be kicked off the moment P2 stands, not at P3; **(b)** T15/T16 in
the client-controlled non-production Supabase, a hard gate for criterion (b) that depends on
that environment being booked and on the backend lane; and **(c)** the C1/C15 contract
decision, since the engine is precisely where the two candidate designs diverge. The faster
cadence makes (c) more urgent, not less: P2 now arrives within a day.

## Log format

Each entry, once there is one:

```
### D-00n — <one-line title>
- **Date:** 
- **Guide section(s) affected:** 
- **What the guide says:** 
- **What was done instead:** 
- **Why (device evidence, not reasoning):** 
- **Settled by:** <ADR / test ID / raw output reference>
- **Amendment status:** <guide section amended | pending republish>
```

---
title: "BP Reset V1 — Native HealthKit Workstream"
subtitle: "Implementation & Integration Specification · v1.3 · Self-Contained Edition"
author: "Luca Brighenti — AI Please Pty Ltd · Native/mobile lane"
date: "Version 1.3 · 18 August 2026 · Status: BUILD SPECIFICATION — FINAL (closes round-three blockers B1–B5; supersedes v1.2)"
lang: en
fontsize: 10pt
mainfont: "DejaVu Sans"
monofont: "DejaVu Sans Mono"
monofontoptions: "Scale=0.74"
geometry: "a4paper, margin=2.0cm"
colorlinks: true
linkcolor: RoyalBlue
urlcolor: RoyalBlue
toc: true
toc-depth: 2
numbersections: true
header-includes:
  - \usepackage{fvextra}
  - \DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,breakanywhere,commandchars=\\\{\}}
  - \usepackage{etoolbox}
  - \AtBeginEnvironment{Highlighting}{\small}
  - \usepackage{longtable}
  - \setlength{\emergencystretch}{3em}
  - \usepackage{xcolor}
---

\newpage

# How to read this document

This is the **build specification and handoff contract** for one workstream of a four-person app build: the native iOS layer of a blood-pressure tracking app. It is fully self-contained — a reader with **no prior knowledge of the project, client, or contract** has everything needed inside this document. Three audiences:

- **The implementing developer (Luca):** §11–§12 are the build plan, code included; §14 is the test script.
- **The integrating team** (backend, front end, submission, assembly): §7 (bridge contract), §13 (executable backend migration) and §17 (integration spec) are yours. The stated goal is integration **without a meeting**; any question those sections fail to answer is a defect in this document — file it as one.
- **External reviewers:** §2 closes the round-two ship gate item by item. §19 defines the (deliberately narrow) round-three ask. The hard constraints below bind reviewers too.

**Version history.** v1.0 (17 Aug) — pre-code proposal. Round-one adversarial review: 7 factual corrections, 25 findings, 25 edge cases, 20 contradictions; all adjudicated in v1.1. v1.1 (18 Aug) — corrected spec. Round-two review: verdict *not yet executable*; two held-position rulings; 20 fix-induced defects; a 28-item ship gate. **v1.2 closes that ship gate.** The major design changes: deletion capture is **removed from V1** (replaced by a reconciliation-based fast-follow, §8.3); acknowledgement moves from domain UUIDs to **snapshot-safe queue-item IDs** (§7); the configuration lifecycle becomes a **complete state machine with a reset operation** (§6); the backend contract becomes an **executable SECURITY INVOKER migration** (§13); the state store gains **two checksummed generations** (§10); and the estimate is restated honestly at **15–18 developer-days** (§18). Round three (ship-gate verdict) returned **NO-GO with five admissible blockers** — all specification-level, none architectural. **v1.3 closes them:** a reclaim-or-discard exit for held data (B1, §6.3/§7.1); snapshot generations that advance on **every** queue mutation, not only fresh enqueues (B2, §7.1/§12); an SQL privilege chain that executes as written — the `canonicalise_bp` EXECUTE revocation would have broken the invoker call chain, and the absent UPDATE policy would have made canonicalisation a **silent no-op** under RLS (B3, §13); explicit teardown semantics for `stopObserving`/reset — queries actually stopped, delivery actually disabled, race-safe behind the barrier (B4, §7.1/§12); and the crash-between-RPC-and-acknowledge re-drain pinned down end to end (B5, §12 P4, M5/M8). §2.3 maps each blocker to its fix. No production code exists yet; the spike (§11) is the first code.

## Hard constraints (bind the developer, the team, and every reviewer)

- **No interpretation of readings.** No thresholds, "high/normal/low" classification, colour zones or bands, value-triggered alerts or notifications, risk scores, heart-age or cardiovascular-risk metrics, no transmitting readings to a clinician for monitoring. The app **displays** readings; it never evaluates them.
- **No identifiable health data on developer systems.** Synthetic/seeded data in non-production environments only; no health values in any log line, crash report, retained screenshot/recording, or commit.
- **No writing to HealthKit from the product app.** The product plugin is read-only. (The separate test-writer app writes synthetic data during development only and never ships.)
- **No feature additions outside the sixteen contracted deliverables** — anything else is a formal change request first.

---

# Ship-gate closure (round two → v1.2)

Each round-two ship-gate item, its resolution, and where it now lives. The round-one adjudication (25 findings) is compressed here to a sentence: v1.1 rebuilt the fetch architecture anchor-primary, made local state atomic, added patient binding and the client-environment test, and corrected seven factual claims; that history is preserved in the v1.1 document in the repo.

| # | Ship-gate item | Resolution | Where |
|---|---|---|---|
| 1 | Withdraw "correlation type in read set = runtime error" | Withdrawn. Correlation types are legal in read sets per Apple's API contract; **quantity-only is the chosen minimal set**, and the two-bundle spike records observed behaviour on the acceptance OS. | §7.4, §11 SPK-3 |
| 2 | Freeze acceptance OS; account for the iOS 26.5 BP-authorisation regression | **Acceptance OS baseline frozen: iOS 26.6 or later** (26.5 shipped a reported blank/incomplete Blood Pressure permission sheet, fixed in 26.6 [R23]). Spike, soak, and walkthrough run on it. | §3.5, §11, §14 |
| 3 | Complete configuration state machine | Specified: six states, all transitions, all triggers. | §6 |
| 4 | `configure()` idempotency on the full tuple | The immutable unit is the tuple `(enrolmentRef, importStart)`; identical tuple = idempotent no-op; any difference = `CONFIG_CONFLICT`. Binding renamed **`enrolmentRef`** — it identifies a *program enrolment*, not a person, which makes re-enrolment a new binding by construction. | §6.2, §7.1 |
| 5 | Add the missing disconnect/reset operation | `disconnectAndReset({ pendingPolicy })` added with atomic, barrier-serialized semantics and exactly two pending policies: `holdForReauth` and `confirmedDiscard`. | §6.3, §7.1 |
| 6 | Disabled observation must drain without new capture | `fetchNewReadings` **removed**; split into `runCatchUp()` (HealthKit touch) and `getPendingSnapshot()` (pure queue read, works while disabled/locked/held). | §7.1 |
| 7 | Snapshot-safe acknowledgement | Every queued item carries a native `itemId`; `acknowledge({ snapshotId, itemIds })` validates the snapshot generation and removes exactly those items; stale snapshots reject `SNAPSHOT_STALE`. UUID-collision races are unrepresentable. | §7.1, §12 P4 |
| 8 | Resolve the incoherent "frozen-but-dormant" tombstones | **Deletion capture is out of V1 entirely** — no tombstone persistence, no dormant state, the anchor advances past deletions by explicit decision. The fast-follow is **reconciliation-based** (full Health-vs-backend compare from `importStart`), which recovers *historical* deletions without anchor history — defusing the "unrecoverable deletions" objection. | §8.3 |
| 9 | Denied-state bootstrap must not defeat backfill | **Bootstrap rule:** no anchor is persisted until a delta containing ≥1 readable BP correlation has been committed; until then every catch-up runs nil-anchor from `importStart`. | §5.3, §12 P2, T10 |
| 10 | Anchor advances after every successful query | Post-bootstrap, **every** successful anchored query commits its returned anchor and diagnostics, including malformed-only or empty deltas. (Pre-bootstrap re-query cost is trivially bounded; post-bootstrap replay-forever was the real bug.) | §12 P2 |
| 11 | Exact anchor-reset triggers and containment | Triggers enumerated: (a) secure-unarchive failure at load; (b) three consecutive anchored-query failures followed by a successful nil-anchor probe; (c) test fault-injection. Reset clears **only** `anchorData` + `bootstrapComplete`, preserves queue/config/observation, records a reason code, runs the bounded re-import in foreground. | §12 P2 |
| 12 | One executor owns all state; fix launch ordering | The engine is a single-executor actor: every read, commit, and observer-list mutation happens on its serial queue. Launch re-arming **registers observers first**, then verifies background delivery asynchronously; the user-facing `startObserving()` still awaits both enablements. Persisted intent (`desiredObservationEnabled`) is separated from persisted result (`lastArm`). | §12 P2 |
| 13 | Harden the state store | Two alternating **checksummed generations** with monotonic `commitSeq`; strict load policy (newest valid → other generation → hard `INTERNAL`, never silent re-init); backup exclusion applied to the containing directory and re-verified each commit; M5 corrected to *old-or-new* (acknowledged rows may reappear; backend idempotency absorbs the replay). | §10, §14 M4/M5/M17 |
| 14 | Rewrite the spike production-shaped | SPK-1..4 rebuilt: production predicate, real `EngineState` persistence, process termination and relaunch, backdated insert, post-relaunch deletion characterisation, **two-bundle** authorisation comparison, corrupt-anchor reset drill, and a closing end-to-end mini-loop. Duration now a full day. The spike settles API shape only; the 48-hour soak remains the background-mechanics evidence. | §11 |
| 15 | Executable backend migration, not a sketch | Full migration in §13: complete DDL with source-kind CHECK constraints and indexes, RLS policies, a fully-written `jsonb_to_recordset` rowset, all-or-nothing validation semantics, explicit return type, grants/revokes, the complete canonicalisation function, and an enumerated SQL test list. | §13 |
| 16 | Remove or secure `SECURITY DEFINER` | Removed. The RPC is **SECURITY INVOKER**; the caller's identity is bound server-side by resolving `enrolmentRef → patient_id` against `auth.uid()` inside the function, backed by RLS. (If definer security is ever reintroduced: `search_path=''`, schema-qualified objects, revoked public/anon execute — noted for the record.) | §13 |
| 17 | Scope deletions by patient; preserve early tombstones | Moot in V1 (item 8). The fast-follow spec requires patient-scoped predicates and a deletion-intent ledger for early tombstones. | §8.3 |
| 18 | Deterministic canonicalisation incl. non-transitive chains, ties, replays, reversal | Total order and a **canonical-anchored clustering algorithm** specified and implemented: preference order healthkit → earliest `ingested_at` → `id` → `client_uuid`; clusters anchor to the canonical row's `taken_at` (the 3-row chain A/B/C resolves deterministically: B superseded by A, C starts a new cluster); recompute is neighbourhood-scoped and idempotent against replays; deletion-reversal algorithm specified with the fast-follow. | §8.2, §13 |
| 19 | Source-specific DB constraints | CHECK constraints: `healthkit` rows require `source_bundle_id`/`source_name`; `manual` rows require them null. `obs_type` is server-fixed, never client-supplied. | §13 |
| 20 | Define the binding identity fully | `enrolmentRef` = the server-side enrolment row's UUID (patient × program instance), created at enrolment, recovered from the authenticated session, stable across reinstall; `importStart` = the **server** enrolment timestamp, never handset clock. Full lifecycle in §6. | §6.2 |
| 21 | Expand front-end integration (logout, switch, HOLD, ack-failure, listeners, errors) | Written: logout and account-switch sequences, HOLD resolution contract, ack-retry behaviour, listener lifecycle, error-rendering table, pending-count now **required** (contradiction resolved), `toRows` mapping table. | §17.3 |
| 22 | Make T5a physically executable | Rewritten around the writer's **delayed-save (+60 s)** control: arm → schedule synthetic write → background harness and lock → write fires while locked → unlock → verify commit markers. | §14 T5a, §12 P3b |
| 23 | Layer-2 test must include manual-vs-HealthKit | T8 rebuilt manual-vs-Omron; T8b = three-row chain; T8c = HealthKit-vs-HealthKit tie-break. | §14 |
| 24 | Criterion (b) needs the loan-cuff reading end-to-end | New T16: during the walkthrough the exact T4 loan-cuff reading continues through the normal drain into the **client-controlled non-production Supabase environment**, verified live; retained evidence is value-free. T15 (synthetic) remains the repeatable integration check. | §14, §17.5 |
| 25 | Manual path missing from walkthrough | T-A (manual entry, front-end lane) added to the walkthrough sequence. | §14, §17.5 |
| 26 | Correct all stale cross-references | Document renumbered and re-verified end to end in this version. | throughout |
| 27 | Package-name contradiction | Rule refined: the `dev.lucab.*` prohibition applies to **app bundle IDs / App IDs** (signing identities). The plugin's *package identifier* is a library name with no signing implication and is created client-named from the start: `com.corveo.bphealthkit`. Harness (`dev.lucab.bpspike`) and writer (`dev.lucab.bpwriter`) never ship. | §4.3, §9.2 |
| 28 | Estimate arithmetic | Phase ranges restated to sum honestly: **15–19 developer-days, planning number 15–18**, 48-h soak parallel from day 3. The gap versus the Stage-2 window is flagged to the engagement lead as an open decision, not hidden in a total. | §18, §16 |

## Round-three blockers → v1.3

| # | Blocker (round-three verdict) | Fix | Where |
|---|---|---|---|
| B1 | `holdForReauth` created held buckets with **no reclaim path**: `getPendingSnapshot` is active-enrolment-only, and re-`configure` of the old tuple rejects `CONFIG_CONFLICT` — trace (a) strands A's readings permanently | New `getHeldSnapshot({enrolmentRef})` + held-aware `acknowledge` give held data a drain path under a matching session, without touching the active tuple; `discardHeld({enrolmentRef, confirmed})` is the explicit destructive exit; `Status.held[]` exposes per-enrolment counts so the front end knows a reclaim is possible. Drain runs held-first on login (§12 P4). | §6.3, §7.1, §12 P4, T-L2/M20 |
| B2 | `snapshotSeq` advanced only on fresh enqueues; acknowledgement, hold moves and discards mutated the queue **without invalidating outstanding snapshots** | The generation now advances on **every mutation** of the active queue or any held bucket (enqueue, ack-removal, hold, reclaim-drain, discard). Snapshots remain pure reads; consecutive snapshots without a mutation share an ID; any mutation makes prior snapshots reject `SNAPSHOT_STALE`. | §7.1, §10, §12, M21 |
| B3 | §13 failed at execution time three ways: revoking EXECUTE on `canonicalise_bp` from `authenticated` breaks the call chain (EXECUTE is checked against the **calling role** even inside an invoker function); with **no UPDATE policy** on `observations`, the canonicalisation UPDATE silently matched zero rows under RLS; and the invoker binding `select` presumed an `enrolments` read policy that was never migrated | Migration rewritten: `000_prerequisites.sql` adds the enrolments select-own policy + grant; `canonicalise_bp` becomes **SECURITY DEFINER under the ship-gate-16 carve-out** (pinned `search_path`, schema-qualified objects, an internal `auth.uid()` ownership guard, explicit grants) — required precisely *because* clients hold no update privilege by design; EXECUTE is granted to `authenticated` with the guard making direct calls safe; the temp table is removed (no TEMP-privilege dependency); a zero-row batch fast-path added. New tests cover the full call chain as `authenticated`, the foreign-patient direct call, and visible `superseded_by` updates. | §13, §17.2 |
| B4 | `stopObserving`/reset **specified** teardown but the engine never showed it: executed observer queries were not stopped, background delivery never disabled, so a "disabled" engine could still be woken and a post-reset wake raced the barrier | `stopObservingLocked` implemented and shown: `HKHealthStore.stop` on each executed query, `disableBackgroundDelivery` for both types (awaited), observer array cleared, intent persisted — all on the executor; reset performs the same teardown inside the `RESETTING` barrier, and any wake block enqueued after it no-ops on the `config == nil` / disabled guards. | §7.1, §12 P2, M18 |
| B5 | Trace (d) — crash between server-RPC success and acknowledge — was asserted safe but never walked through the snapshot-generation mechanics after relaunch | Walked and pinned: relaunch strict-loads old-or-new state; re-drain takes a **fresh snapshot** (new generation), replays the same rows into the uniqueness constraint (`duplicates` counted, zero inserts), then acknowledges the fresh snapshot; any zombie ack against the pre-crash `snapshotId` rejects `SNAPSHOT_STALE`. | §12 P4, M5, M8, M21 |

## Open decisions register (outside this document's authority)

| ID | Decision | Owner | Needed by |
|---|---|---|---|
| D1 | HOLD retention: what happens to held pending data after N days (no automatic disposal is specified here; silence is not a policy) | Client, via engagement lead | Before release; placeholder = indefinite hold, support-visible |
| D2 | Layer-2 false-positive acceptance (identical-value readings <3 min display as one; all rows retained) | Client + backend sign-off | Phase 0 exit |
| D3 | Enrolments table shape (§13 assumes `enrolments(id, patient_id, auth_user_id, program_start, …)`) | Backend lane | Phase 0 exit |
| D4 | Stage-2 window vs the 15–18-day estimate | Engagement lead | Immediately |

---

# Project context

## The product

**BP Reset V1** is the first program of Corveo, an Australian, cardiologist-led heart-health venture (Intelecor Pty Ltd t/a Corveo). A six-week blood-pressure education and behaviour-change course delivered through a native iOS (iPhone) app: readings recorded **manually** or **imported from Apple Health** (where consumer cuffs — Omron, Withings and similar — deposit readings via their companion apps), displayed on a display-only trend view ("My Heart Record"), alongside six weeks of clinician-authored education content. Built under fixed-price SOW-2026-001 (four stages, ~5–6 weeks) by **AI Please Pty Ltd**. The product is deliberately **education-first**, scoped outside Australian medical-device classification; the client owns regulatory review and the intended-purpose statement. The bright line, from the SOW:

> *"The Solution as built under this Statement of Work will not interpret a reading, apply a clinical threshold, apply a colour zone or band, raise an alert, calculate a risk score, calculate a heart-age or equivalent metric, or transmit a reading to a clinician for monitoring. Any of those functions is outside this Statement of Work and is a Variation."* — SOW-2026-001, cl. A.3.3

## Team and workstream

| Person | Lane |
|---|---|
| **Luca** (this document) | Native/mobile: Swift HealthKit plugin, Apple Health auto-sync, Capacitor shell, integration package |
| Michael | React front end (web V1 deployed) |
| Ben (engagement lead) | Supabase backend: schema, RLS, ingest, privacy features |
| Nick | Docs, test scripts, App Store submission package |

Deliverables owned here (SOW cl. A.3): **#2** the native Swift HealthKit plugin (authorisation flow, observer query with background delivery, source de-duplication, denied-permission handling — *source in the client's repository; demonstrated on a physical device*); **#3** Apple Health auto-sync from validated cuffs (*demonstrated on a physical device against a written test script*); **#1 (part)** the Capacitor shell (*development-signed physical-device build*); **#14 (adjusted)** pipeline — account posture §4.3.

## Stage 2 acceptance criteria

Demonstrated on a physical iOS device against a written test script: **(a)** manual entry writes to the client's Supabase project with agreed data-quality bounds *(front-end/backend lanes; in the walkthrough as T-A)*; **(b)** a loan-cuff reading written to Apple Health **syncs to the application and is written to the client's Supabase project** *(T4 + T16 end-to-end)*; **(c)** authorisation flow, observer query with background delivery, source de-duplication, denied-permission handling each operate as described; **(d)** both capture paths on a physical device using the loan cuff; **(e)** **no interpretation** artefact of any kind present; **(f)** client walkthrough held.

**"Auto-sync" definition (contract-anchoring):** background capture of new Apple Health readings into a durable on-device queue, followed by upload on the next authenticated foreground session, with every foreground activation performing an unconditional drain. Not real-time push; not monitoring.

## Current state (18 August 2026)

Contract executed; clock running; Stage 2 open. **No code exists.** In hand: Omron Bluetooth cuff, teammate's Qardio, physical iPhone, iPad (sidecar only). Two adversarial review rounds complete; this version closes the round-two ship gate. First build action: the spike (§11).

## Acceptance OS baseline (frozen)

**iOS 26.6 or later.** Round two surfaced a field-reported iOS 26.5 regression in which the Blood Pressure read-authorisation sheet rendered blank/incomplete, fixed per the iOS 26.6 notes [R23]. The dev iPhone is updated before the spike; SPK-3, the soak, and the walkthrough all run on the frozen baseline, and the baseline is recorded in every evidence artefact.

---

# Constraints and account posture

## The bright line — consequences in native code

Payloads carry values, units, timestamps, provenance — **no derived fields** (no category, flag, delta). Plugin events and status responses carry *counts and states*, never values. Reading-triggered notifications are prohibited. **Structural validation** (§7.3) checks well-formedness, never normality — "is systolic a finite number" is allowed; "is systolic high" is a contract breach. No range checks anywhere in this lane (the manual form's contracted "data-quality bounds" are input validation owned by the front-end lane).

## Model B data handling

Identifiable client data never leaves the client's environment; developers use named MFA accounts and synthetic/seeded data in non-production environments. Binding rules: **(1)** the log wrapper accepts event names, counts, type identifiers, error codes, and truncated opaque IDs — it has *no overload* accepting a reading; a stray value in any build is a severity-1 privacy defect. **(2)** The developer's own cuff readings on the developer's own device are fine but never committed, exported, or retained in evidence — retained recordings/screenshots use writer-generated synthetic values or full redaction; live-cuff demonstrations are live-only, and every artefact is audited before leaving the device (T-EV). **(3)** The on-device state directory holds health payloads pending upload: file-protected, backup-excluded, never `UserDefaults` (§10).

## Account posture and naming rules

Development proceeds under a personal/sandbox Apple team; the production Apple Developer organisation account, production bundle ID, TestFlight and submission belong to the team/client at integration. This workstream delivers **source plus §7/§13/§17**, not a signed distribution.

Naming rules, refined: the `dev.lucab.*` prohibition applies to **signing identities** — app bundle IDs / App IDs — because an explicit App ID binds to a team at first automatic-signing use and to an App Store Connect record permanently at first upload [R8, R9]. The two sandbox apps therefore use throwaway IDs forever: harness `dev.lucab.bpspike`, writer `dev.lucab.bpwriter`; neither ships. The **plugin package identifier** is a library name with no signing implication and is created client-named from day one: `com.corveo.bphealthkit`. Free-team mechanics for the sandbox: HealthKit capability available for on-device dev; 10 App IDs, 3 devices/platform, 3 installed dev apps/device, 7-day profiles [R6, R7, R21]; the paid studio login removes the weekly expiry. Toolchain: Capacitor 8 = Xcode 26.0+, iOS 15+ target, Node 22+ [R1, R2]; store submissions require Xcode 26 / iOS 26 SDK from 28 Apr 2026 [R3].

---

# Architecture

## Components and the two capture paths

```
 Omron cuff        Withings cuff       Qardio cuff         Patient
     |                  |                  |                   |
     v                  v                  v                   |
 Omron Connect     Withings app       Qardio app              |
     +--------+---------+------------------+                   |
              v                                                v
      +---------------+                             +-------------------+
      |  Apple Health |                             |  React front end  |
      |  (HealthKit)  |                             |  (manual entry)   |
      +-------+-------+                             +---------+---------+
              | read-only                                     |
              v                                               |
   +------------------------------------+                     |
   | BPHealthKit plugin (THIS LANE)     |   typed bridge      |
   | wake -> anchored catch-up ->       | <------------------ +
   | atomic commit (2-gen state store)  |  status + snapshot  |
   +------------------+-----------------+                     |
                      | snapshot (itemIds)                    |
                      v                                       v
        +--------------------------------------------------------+
        | JS drain: serialized; enrolment-binding verified on    |
        | EVERY item; one atomic ingest RPC; ack(snapshot) only  |
        | after server success                                   |
        +---------------------------+----------------------------+
                                    v
                      +------------------------------+
                      |  Client's Supabase (AU, RLS) |
                      |  observations = SOURCE OF    |
                      |  TRUTH for the trend view    |
                      +------------------------------+
```

Anchoring facts: Supabase is the single source of truth (manual entries never touch HealthKit; the trend view renders from Supabase only); the plugin's whole job is *HealthKit change → well-formed payload → atomic local commit → snapshot for drain*; every vendor cuff routes through Apple Health, so "Omron, Withings and similar" is one integration.

| Path | Flow | This lane |
|---|---|---|
| Auto-sync | Cuff → vendor app → `HKCorrelation` in Health → wake/foreground catch-up → atomic commit → drain → Supabase | Everything from Apple Health onward |
| Manual | React form → validated → upload → Supabase | Nothing at runtime; shares the backend row contract (§13) |

## Blood pressure in HealthKit

BP is a **correlation** — `HKCorrelationType(.bloodPressure)` containing exactly one systolic and one diastolic quantity sample (mmHg). Authorisation attaches to the contained quantity types; correlation types are also legal in read sets per Apple's API contract [R24] — this design requests the **quantity types as the chosen minimal set** (§7.4), with observed behaviour recorded by SPK-3. Observers and background delivery register per quantity type; the incremental cursor targets the correlation type.

## Change capture: anchor-primary with a bootstrap rule

**Wake signal:** `HKObserverQuery` on each quantity type + `enableBackgroundDelivery(.immediate)` on both — a request for the highest available frequency, not a latency guarantee [R4, R15]. **Cursor:** one persisted `HKQueryAnchor` over the BP correlation type, predicated `startDate ≥ importStart`. Anchored queries return inserts *and* deletions since the token [R16]; V1 ignores deletions by explicit decision (§8.3).

**Bootstrap rule (closes ship-gate 9):** because read denial is indistinguishable from an empty store, an anchor established while nothing was readable could otherwise bury the patient's history. Therefore **no anchor is persisted until a delta containing at least one readable BP correlation has been committed**; until that moment (`bootstrapComplete == false`) every catch-up runs a nil-anchor query from `importStart` — trivially cheap against an empty-or-unreadable store. From the first committed reading onward, **every successful query commits its returned anchor**, including empty and malformed-only deltas (ship-gate 10), so nothing replays forever and backdated vendor inserts are still caught by the anchor rather than any time window.

**Anchor recovery (ship-gate 11):** triggers are exactly (a) secure-unarchive failure of `anchorData` at load, (b) three consecutive anchored-query failures with the same error followed by one successful nil-anchor probe, (c) test injection. Recovery atomically clears `anchorData` + `bootstrapComplete` only — queue, configuration, observation state, diagnostics are preserved — records a reason code, and runs the bounded (`importStart`-limited, a few hundred rows) re-import in foreground. All other errors retain the anchor.

## Sync trigger (retained; harm case owned)

Background wakes commit locally; upload happens in authenticated foreground. Rationale: token custody stays in the JS tier (Model B auditability); background wakes have tight budgets and an absolute completion-handler obligation [R4]; BP arrives a few times daily and the trend view is foreground-only. The honest worst case: readings queued on a phone that is never reopened are lost with the device. Mitigations: durable two-generation protected storage, **unconditional drain on every bridge-ready and foreground activation**, and a **required** pending-count affordance so a stuck queue is visible (§17.3). Native background upload remains a documented extension.

---

# Lifecycle: configuration, binding, and the state machine

This section exists because round two showed the lifecycle was the most dangerous part of the design. It defines the identity model, the state machine, and the three flows (connect, logout/switch, disconnect/reset) that the front end wires.

## Identity model

**`enrolmentRef`** — the UUID of the server-side **enrolment row** (one patient × one program instance), created by the backend at enrolment, delivered to the app inside the authenticated session, and therefore stable across reinstall and device restore. It identifies an *enrolment*, not a person: a patient who completes the program and enrols again gets a **new** `enrolmentRef` and a new `importStart`, which is exactly the semantics re-enrolment needs — no mutation of an immutable binding, just a new one via disconnect+reset. **`importStart`** — the enrolment row's **server** timestamp (`program_start`), never handset clock; it bounds every HealthKit query forever. The pair `(enrolmentRef, importStart)` is **one immutable configuration tuple**: `configure()` with the identical tuple is an idempotent no-op; any difference — either field — rejects `CONFIG_CONFLICT` and routes through `disconnectAndReset`.

## The state machine

Persisted engine states (all transitions execute on the engine's single executor; every transition is one atomic state-store commit):

| State | Meaning |
|---|---|
| `UNCONFIGURED` | Fresh install / post-reset. Only `configure()` and status calls are legal. |
| `CONFIGURED_DISABLED` | Tuple set; observation off (`desiredObservationEnabled=false`). Catch-up is **not** performed; snapshot/drain of existing queue works. |
| `CONFIGURED_ENABLED` | Tuple set; observation intended on; last arm succeeded (`lastArm.ok`). |
| `ARM_FAILED` | Tuple set; observation intended on; last arm failed (`lastArm.errorCode`). Foreground catch-up still works; background wake may not. Re-arm retried at each launch and via `startObserving()`. |
| `RESETTING` | Transient barrier state inside `disconnectAndReset` — all engine work serialized behind it. |
| *(condition)* `BINDING_HOLD` | Not an engine state: a **drain-side condition** — the snapshot's `enrolmentRef` ≠ the authenticated session's. The engine is unaware of sessions by design; the front end owns HOLD (§17.3). Held data is simply the untouched queue. |

Transitions:

```
UNCONFIGURED --configure(t)--------------------> CONFIGURED_DISABLED
CONFIGURED_DISABLED --startObserving ok--------> CONFIGURED_ENABLED
CONFIGURED_DISABLED --startObserving fail------> ARM_FAILED
CONFIGURED_ENABLED --stopObserving-------------> CONFIGURED_DISABLED
CONFIGURED_ENABLED --launch re-arm fail--------> ARM_FAILED
ARM_FAILED --startObserving ok / launch ok-----> CONFIGURED_ENABLED
ANY CONFIGURED* --disconnectAndReset-----------> RESETTING --> UNCONFIGURED
ANY --configure(same tuple)--------------------> no-op (idempotent)
ANY CONFIGURED* --configure(different tuple)---> reject CONFIG_CONFLICT
```

Intent vs result are separate persisted fields (ship-gate 12): `desiredObservationEnabled` records what the user asked for; `lastArm {ok, at, errorCode?}` records what actually happened; launch re-arming honours intent and updates result.

## The three flows

**Connect (first run):** authenticate → session supplies `{enrolmentRef, importStart}` → `configure()` → `requestAuthorization()` → `startObserving()`. If `startObserving` rejects (`BG_DELIVERY_FAILED`), state is `ARM_FAILED`: the connect UI reports "connected — background updates unavailable on this build" (a mechanism statement, not a value statement) and foreground refresh still works.

**Logout / account switch:** logout attempts one final `drain()` first; if it can't complete, plain sign-out leaves engine state intact — configuration persists, capture continues per intent. If the **same** enrolment signs back in, the next drain proceeds normally. If a **different** account signs in, the drain's binding check trips `BINDING_HOLD`: nothing uploads, nothing is discarded, the UI shows a held count and two resolution paths — *reauthenticate the original account and drain*, or *the disconnect+discard flow below*. No automatic age-based disposal exists (open decision D1); indefinite hold is the placeholder and it is support-visible, never silent.

**Disconnect / reset:** `disconnectAndReset({ pendingPolicy })` — the only exit from a configured tuple. Atomic semantics, in order, all behind the `RESETTING` barrier (any in-flight catch-up completes or aborts first; no commit may land after the reset resolves): stop observer queries; disable background delivery for both types; then per policy — **`holdForReauth`**: pending items move to a `held` bucket keyed by the old `enrolmentRef` — surviving reset and any subsequent `configure()`, visible via `Status.held[]`, and **drainable at any time** through `getHeldSnapshot({enrolmentRef})` + the normal RPC + `acknowledge`, provided the authenticated session matches that enrolment (the drain's binding check applies to held items identically). Held buckets are never touched by a later enrolment's `confirmedDiscard`; their only exits are a successful reclaim-drain or an explicit, UI-confirmed `discardHeld({enrolmentRef})`; **`confirmedDiscard`** (requires explicit patient confirmation in the UI): pending items, anchor, bootstrap flag and configuration are wiped in one commit. Either way the engine lands in `UNCONFIGURED` and a new `configure()` is legal. The UI copy for disconnect must say it *stops BP Reset importing* — it cannot and does not change Health-app permissions at the OS level.

---

# The bridge contract (v1.2 — frozen for integration)

## TypeScript definitions

```typescript
import type { PluginListenerHandle } from '@capacitor/core';

/** One HealthKit-path reading. Manual entries do NOT pass through the plugin;
 *  the shared BACKEND row contract is §13. */
export interface BPReading {
  itemId: string;            // native queue identity — the ACK key
  hkUuid: string;            // HealthKit CORRELATION UUID — backend idempotency key
  enrolmentRef: string;      // binding stamped at commit (§6.1)
  systolic: number;          // mmHg, as recorded; no rounding, no evaluation
  diastolic: number;         // mmHg
  takenAt: string;           // ISO-8601 UTC instant of the reading
  tzOffsetMinutes: number | null; // ONLY from HKMetadataKeyTimeZone; null when
                                  // absent — never fabricated from device TZ.
                                  // UI fallback: render in viewer's local time
                                  // and omit the "local time of reading" claim.
  sourceBundleId: string;
  sourceName: string;
  deviceModel?: string;
  receivedAt: string;        // set ONCE at first durable commit; persisted
}

export type PromptStatus = 'notRequested' | 'requested';
// iOS never reveals whether READ access was granted or denied.

export type EngineState =
  | 'unconfigured' | 'configuredDisabled' | 'configuredEnabled'
  | 'armFailed' | 'resetting';

export interface Status {
  state: EngineState;
  promptStatus: PromptStatus;
  pendingCount: number;      // active queue (current enrolment)
  heldCount: number;         // total items across all held buckets (§6.3)
  held: { enrolmentRef: string; count: number }[];  // per-bucket; refs are
                                                    // opaque UUIDs, no values
  bootstrapComplete: boolean;
  lastArm?: { ok: boolean; at: string; errorCode?: string };
}

export interface CatchUpResult {
  queued: number;            // newly committed this pass (count only)
  deferred: boolean;         // true when HK_TEMP_UNAVAILABLE deferred the pass
  bootstrap: boolean;        // true while the bootstrap rule is active (§5.3)
}

export interface Snapshot {
  snapshotId: string;        // generation token; ack validates it
  readings: BPReading[];     // ALL unacknowledged items for the ACTIVE enrolment
  heldCount: number;
}

export interface AckResult { removed: number; alreadyAbsent: number; }

export interface BPHealthKitPlugin {
  isAvailable(): Promise<{ available: boolean }>;
  getStatus(): Promise<Status>;

  /** Sets the immutable tuple. Identical tuple: idempotent no-op.
   *  Any difference: rejects CONFIG_CONFLICT (route via disconnectAndReset). */
  configure(opts: { enrolmentRef: string; importStart: string }): Promise<void>;

  /** The ONLY exit from a configured tuple. Atomic; see §6.3 semantics.
   *  'confirmedDiscard' REQUIRES prior explicit user confirmation in the UI. */
  disconnectAndReset(opts: {
    pendingPolicy: 'holdForReauth' | 'confirmedDiscard';
  }): Promise<void>;

  /** System permission sheet (first time only). Resolves when dismissed;
   *  NEVER rejects on user denial — denial is not observable. */
  requestAuthorization(): Promise<void>;

  /** Arms observers + background delivery for both quantity types.
   *  Registers observers first, then awaits BOTH enablement results;
   *  rejects BG_DELIVERY_FAILED if either fails (state -> armFailed,
   *  foreground catch-up unaffected). Sets desiredObservationEnabled. */
  startObserving(): Promise<void>;

  /** Full teardown, on the executor (B4): calls HKHealthStore.stop on each
   *  executed observer query, awaits disableBackgroundDelivery for BOTH
   *  quantity types, clears the observer list, persists
   *  desiredObservationEnabled=false. Serializes behind in-flight catch-up:
   *  no post-stop commit can land after this resolves. Existing queue
   *  remains drainable via getPendingSnapshot (NO new capture). */
  stopObserving(): Promise<void>;

  /** Performs an anchored catch-up NOW if state is configured+enabled and
   *  the store is reachable. Never runs while disabled (no new capture
   *  after stopObserving) — returns { queued: 0, deferred: false } then.
   *  HK_TEMP_UNAVAILABLE (locked store) -> { deferred: true }, retried
   *  automatically on unlock/foreground/next wake. */
  runCatchUp(): Promise<CatchUpResult>;

  /** Pure queue read (ACTIVE enrolment). No HealthKit access; works while
   *  disabled or locked. Generation contract (B2): snapshotId is stable
   *  across reads, and is invalidated by EVERY queue/held mutation —
   *  enqueue, acknowledge-removal, hold, reclaim, discard. */
  getPendingSnapshot(): Promise<Snapshot>;

  /** Pure read of one HELD bucket (B1). Same Snapshot shape and generation
   *  contract; readings carry the held bucket's enrolmentRef, so the
   *  drain's binding check works unchanged. HELD_NOT_FOUND if absent. */
  getHeldSnapshot(opts: { enrolmentRef: string }): Promise<Snapshot>;

  /** Explicit destructive exit for a held bucket (B1). REQUIRES prior
   *  user confirmation in the UI; confirmed must be literal true.
   *  HELD_NOT_FOUND if absent; CONFIRM_REQUIRED otherwise. */
  discardHeld(opts: { enrolmentRef: string; confirmed: true }): Promise<void>;

  /** Removes exactly the given items from the given snapshot generation —
   *  active queue or held bucket, resolved by itemId (ULIDs are globally
   *  unique). Idempotent per item; the removal itself advances the
   *  generation (B2). A stale snapshotId rejects SNAPSHOT_STALE —
   *  caller re-snapshots and retries. */
  acknowledge(opts: { snapshotId: string; itemIds: string[] }): Promise<AckResult>;

  /** HINT ONLY. Fired after a catch-up that queued items and re-fired on
   *  bridge-ready when the queue is non-empty. The drain runs
   *  unconditionally on bridge-ready and foreground regardless (§12 P4). */
  addListener(
    eventName: 'bpReadingsAvailable',
    listener: (data: { count: number }) => void,
  ): Promise<PluginListenerHandle>;
}
```

## Error model

| Code | Meaning | Caller behaviour |
|---|---|---|
| `HK_UNAVAILABLE` | No HealthKit store | Manual-only mode |
| `CONFIG_MISSING` | catch-up/observe before `configure()` | Fix call order |
| `CONFIG_CONFLICT` | `configure()` with a different tuple (either field) | Route via `disconnectAndReset` |
| `PROMPT_PENDING` | `runCatchUp` before `requestAuthorization` ever ran | Route to connect step |
| `BG_DELIVERY_FAILED` | Arming failed (entitlement/profile); state → `armFailed` | Show "background updates unavailable"; foreground refresh works |
| `HK_TEMP_UNAVAILABLE` | Store locked (`errorDatabaseInaccessible`); pass deferred | Transparent; snapshot/drain unaffected |
| `SNAPSHOT_STALE` | `acknowledge`/`ack` against a superseded generation (any mutation since) | Re-snapshot, retry |
| `HELD_NOT_FOUND` | `getHeldSnapshot`/`discardHeld` for an unknown bucket | Refresh `Status.held` |
| `CONFIRM_REQUIRED` | `discardHeld` without literal `confirmed: true` | UI confirmation first |
| `QUERY_FAILED` | Other HealthKit error (code only) | Retry affordance; report if persistent |
| `INTERNAL` | State-store fault incl. both generations invalid (§10) | Hard-report; never silent re-init |

Arming before authorisation is defined behaviour (observers may exist pre-sheet; they deliver nothing until data is readable); `PROMPT_PENDING` applies only to `runCatchUp`.

## Payload and validation rules

`hkUuid` is the backend idempotency key for HealthKit rows; manual entries use a client UUIDv4 in the same column — one uniqueness constraint covers both (§13). `itemId` is a native ULID assigned at commit and exists solely for snapshot-safe acknowledgement. `receivedAt` is assigned exactly once at first commit; informational only — **all backend ordering uses server-side `ingested_at` then `id`** (§8.2). **Structural validation (never clinical)** before commit and again at ingestion: exactly one systolic + one diastolic child; both finite; unit convertible to mmHg; `takenAt` parseable and ≥ `importStart`; UUID present. Failures are not queued; a **count-by-source** diagnostic map (`malformedBySource: [bundleId: count]`) is persisted — counts and identifiers only, never values.

## Canonical type contract

```swift
enum BPTypes {
    static let systolic    = HKQuantityType(.bloodPressureSystolic)
    static let diastolic   = HKQuantityType(.bloodPressureDiastolic)
    static let correlation = HKCorrelationType(.bloodPressure)
    static let mmHg        = HKUnit.millimeterOfMercury()
    /// CHOSEN MINIMAL SET. Correlation types are also legal in read sets per
    /// Apple's API contract [R24]; SPK-3 records observed behaviour of both
    /// sets on the frozen acceptance OS. If SPK-3 shows the quantity-only set
    /// under-authorises, amend HERE and only here (ADR-0004 records why).
    static let authorizationRead: Set<HKObjectType> = [systolic, diastolic]
    /// Wake signals + background delivery register per QUANTITY type.
    static let observed: [HKSampleType] = [systolic, diastolic]
    /// The incremental cursor targets the CORRELATION type.
    static let fetched: HKSampleType = correlation
}
```

---

# De-duplication and deletions

## Layer 1 — idempotency

Replays (anchor recovery, double wakes, reinstall re-imports, ack-after-timeout retries) are absorbed by the backend uniqueness constraint on `(patient_id, client_uuid)` with `on conflict do nothing`. The plugin's persisted recent-UUID ring only reduces redundant queueing; **correctness depends solely on the constraint**, so the fetch path is deliberately replay-generous.

## Layer 2 — cross-source canonicalisation (deterministic, reversible)

The same physiological event recorded twice (cuff + manual; vendor resync minting new UUIDs). Layer 2 is **presentation-level canonicalisation, not proof of event identity**; every row is retained; reversal is an `update`.

- **Candidates:** same patient, same `obs_type`, **exact** systolic and diastolic equality, `taken_at` proximity per the clustering rule below, different `client_uuid`, not soft-deleted.
- **Total preference order:** `source_kind='healthkit'` beats `'manual'` → earliest `ingested_at` → smallest `id` → smallest `client_uuid`. (`now()` is transaction-stable in PostgreSQL, so same-batch rows can tie on `ingested_at` [R25]; `id` breaks the tie deterministically.)
- **Canonical-anchored clustering (closes the non-transitive chain):** order all candidate rows in a neighbourhood by the preference order; the first unsuperseded row is canonical of its cluster; every later row whose `taken_at` is within **±3 minutes of the canonical's `taken_at`** and value-equal is superseded by it; a row outside the canonical's window starts a new cluster. The three-row chain A(00:00) / B(00:02:50) / C(00:05:40) therefore resolves deterministically: B → superseded by A; C → new canonical. T8b tests exactly this chain.
- **Idempotent recompute:** the function operates on **persisted rows** in a padded neighbourhood (never on the assumption that its inputs were newly inserted), clearing and re-electing `superseded_by` inside the ingest transaction — replays and late-arriving preferred rows converge to the same result. Implementation: §13.
- **Documented false-positive:** two genuinely distinct readings, identical values, within the canonical's window display as one (both retained). Client sign-off = open decision D2; T8b makes the behaviour visible before the field does.

## Deletions: V1 posture and the reconciliation fast-follow

**V1 captures no deletions** (ship-gate 8): no tombstone persistence, no dormant contract, and the anchor advances past deletion events by explicit decision — a reading deleted in the Health app after upload continues to display from Supabase, documented as V1 behaviour in the walkthrough.

**Fast-follow design (specified now so V1 stays honest):** *reconciliation sync* — on a foreground pass, query Health for all BP correlation UUIDs since `importStart` (bounded: a few hundred), compare against the backend's `source_kind='healthkit'` UUIDs for this enrolment, and soft-delete (`deleted_at`) the difference — patient-scoped in every predicate, executed via a dedicated RPC. Because reconciliation compares *current whole states*, it recovers deletions that happened **before** the feature shipped, requiring no anchor history — which is why V1 can safely ignore deletion deltas. Early-tombstone ordering (delete intent arriving before its row) is handled by a deletion-intent ledger keyed `(patient_id, client_uuid)` in the fast-follow migration. Canonical reversal on soft-delete (re-electing a superseded survivor) ships with the same migration; the algorithm is the §8.2 recompute run over the affected neighbourhood.

---

# Environment setup from zero

## Toolchain and accounts

macOS + **Xcode 26.x** (`xcode-select --install` after) [R2, R3]; **Node 22 LTS** pinned per-repo [R2]; device updated to the **frozen acceptance OS (iOS 26.6+, §3.5)**. Apple account: personal free team (limits §4.3) or the paid studio login. Verify: `node -v`, `xcodebuild -version`, device OS.

## Scaffold

```bash
npm create vite@latest bp-harness -- --template react-ts
cd bp-harness && npm install
npm install @capacitor/core @capacitor/cli @capacitor/app
npx cap init "BP Harness" "dev.lucab.bpspike" --web-dir dist

# Client-named plugin package identifier from day one (§4.3):
npm init @capacitor/plugin@latest packages/bp-healthkit -- \
  --name bp-healthkit --package-id com.corveo.bphealthkit \
  --class-name BPHealthKit
npm install ./packages/bp-healthkit

npm install @capacitor/ios
npm run build && npx cap add ios && npx cap sync ios && npx cap open ios
```

Plugin discovery is generated by `cap sync` (the iOS `packageClassList` is tooling output, never authored [R22]); the clean-clone test (T1) verifies discovery from scratch on a second machine.

## Xcode configuration

App target, *Signing & Capabilities*: **HealthKit** capability; **HealthKit Background Delivery** entitlement (`com.apple.developer.healthkit.background-delivery` — a *runtime* failure when missing, which is why arming surfaces `BG_DELIVERY_FAILED`; T14 builds once without it deliberately). Info.plist: `NSHealthShareUsageDescription` — final wording is client-approved at P0 and recorded in §17.4 (placeholder until then: "BP Reset reads blood-pressure readings you have chosen to store in Apple Health, so they can appear in your record."). **No** `NSHealthUpdateUsageDescription` in harness or product — its absence is deliberate, review-relevant proof of the read-only posture (the writer app alone carries it). Deployment target iOS 16.0 (lowerable to Capacitor 8's 15.0 floor at integration [R1]).

## Hardware and the vendor chain

Physical iPhone for everything evidential; iPad is a sidecar at most. **Omron chain, once, before plugin code:** pair cuff in Omron Connect → enable Apple Health sharing *inside Omron Connect* (off by default: *Contents → Add contents → Apple Health Data Sharing*, or *Profile → App Settings → Apple Health*) [R11] → grant its write permission in the Health sheet → verify a cuff reading appears in Health → Browse → Heart → Blood Pressure. Quirks: transfer runs on Omron-app launch or via iBeacon + location in background [R10]; post-iOS-26 field reports of the handoff silently stopping until re-toggled/re-paired [R12]. Debug order when readings vanish: cuff→Omron app? Omron→Health? Health→plugin? — in that order.

---

# State and persistence (two-generation atomic store)

One logical state document; **two alternating generation files**, each a checksummed envelope; one commit primitive; strict load policy. Directory: `Application Support/BPEngine/` — created with file protection, and `isExcludedFromBackup` set on the **directory** at creation and **re-verified after every commit** (the resource value lives on filesystem items and must survive replacement [R26]; a transient upload queue must never restore onto a different device/store identity).

```swift
struct EngineState: Codable {
    var schemaVersion = 3
    var enrolmentRef: String?
    var importStart: Date?
    var desiredObservationEnabled = false
    var lastArm: ArmResult?            // {ok, at, errorCode?}
    var bootstrapComplete = false      // §5.3 bootstrap rule
    var anchorData: Data?              // HKQueryAnchor via NSKeyedArchiver(secure)
    var anchorResetReason: String?     // last recovery reason code, if any
    var queue: [QueuedReading] = []    // itemId(ULID), BPReading fields,
                                       //   receivedAt set ONCE here
    var held: [HeldBucket] = []        // {enrolmentRef, items} — §6.3 holdForReauth
    var recentUuids: [String] = []     // bounded ring; convenience only
    var snapshotSeq: UInt64 = 0        // generation: bumped by EVERY queue/held
                                       //   mutation (enqueue, ack, hold, reclaim,
                                       //   discard) — B2; reads never bump it
    var diagnostics = Diagnostics()    // armed/lastWake timestamps, error codes,
                                       //   malformedBySource: [String: Int] —
                                       //   counts + identifiers, NEVER values
}

struct Envelope: Codable {             // what actually hits disk
    let commitSeq: UInt64              // strictly monotonic
    let sha256: String                 // of the encoded state payload
    let state: EngineState
}

final class StateStore {               // used ONLY from the engine executor
    // Files: BPEngine/state.a.json and BPEngine/state.b.json (alternating).
    // COMMIT: encode -> checksum -> atomic write to the OLDER generation with
    //   [.completeFileProtectionUntilFirstUserAuthentication] -> re-assert
    //   directory backup exclusion -> swap in memory.
    // LOAD (strict, ship-gate 13): decode both files; verify checksum +
    //   schemaVersion migration; adopt the highest valid commitSeq; if only
    //   one is valid, adopt it and log a generation-fallback diagnostic; if
    //   files exist but NEITHER is valid -> surface INTERNAL and stop —
    //   NEVER silently initialise empty state over existing files.
    func commit(_ mutate: (inout EngineState) throws -> Void) throws { ... }
    func loadStrict() throws -> EngineState { ... }
}
```

Consequences owned: a crash at any boundary leaves *old or new* — including acknowledgement, so **acknowledged items may legitimately reappear after a crash** and replay harmlessly into the backend constraint (M5's corrected expectation). The one failure a single file couldn't absorb — newest generation undecodable before upload — now falls back to the previous valid generation (M17); a defective migration is caught by the strict loader before any drain. Schema is versioned from day one; upgrades with pending rows are tested (M15). SQLite remains a documented drop-in behind the same two methods if the integrating team prefers; every fault-injection test applies unchanged.

---

# The spike (day 0–1; production-shaped; the gate before dependent code)

One full day, on the **frozen acceptance OS**. Three bare SwiftUI targets, no Capacitor: `dev.lucab.bpspike` (reader, quantity-only auth), `dev.lucab.bpspikec` (reader, correlation-inclusive auth — SPK-3 needs two clean permission identities; a single app's Health state contaminates an A/B), `dev.lucab.bpwriter` (synthetic writer, carries the update usage key). The spike settles **API shape only**; background-delivery mechanics are settled by the 48-hour soak (§12 P2), not here.

| ID | Question | Method (production-shaped) | Pass ⇒ |
|---|---|---|---|
| SPK-1 | Correlation-anchored **inserts** with a real resumable cursor | Reader Q: `configure`-equivalent state with real `importStart`; nil-anchor query with the production predicate `startDate ≥ importStart`; commit anchor **into the actual `Envelope`/`EngineState` JSON**; terminate the process; writer saves one current **and one 7-day-backdated** correlation; relaunch; strict-load; resume query | Both returned exactly once; third query empty; anchor survives the real persistence path |
| SPK-2 | Correlation-anchored **deletions** (informs the fast-follow only — V1 ignores deletions) | Persist anchor; terminate; delete the current reading in the Health app; relaunch; strict-load; resume with the production predicate | Deleted set carries the **correlation UUID**; not repeated after the next commit. Recorded in ADR-0004 for the reconciliation fast-follow design |
| SPK-3 | Authorisation-set behaviour on the acceptance OS | Reader Q (quantity-only) vs reader C (correlation-inclusive), same device/OS: record `statusForAuthorizationRequest` before/after, sheet appearance and which Blood Pressure controls it shows, then a correlation query and both quantity observers, with error codes | The chosen minimal set (quantity-only) authorises correlation reads and observer registration cleanly; any divergence amends §7.4 and ADR-0004 — the spike wins over this document |
| SPK-4 | State-store & anchor survival incl. corruption | Write the full production-shaped two-generation store; terminate; relaunch; strict-load; resume the anchored query. Then inject one corrupt `anchorData`: verify the **anchor-only reset** (queue/config preserved, reason code recorded) and the `importStart` re-import. Then corrupt the newest generation file: verify fallback to the previous valid generation (M17) | The §10 loader and §5.3 recovery behave as specified before any engine code depends on them |
| SPK-close | End-to-end mini-loop | configure → authorise (set Q) → install both quantity observers → anchored query → commit anchor+payload into the store → terminate → writer: one current insert, one backdated insert, one deletion → relaunch → resume | Exact correlation UUIDs, no repeats after commit; deletion characterised; ADR-0004 written same-day |

**Path B (fallback, pre-specified so a platform surprise costs hours):** if SPK-1 fails — correlation-anchored queries do not behave — the cursor moves to **anchors on the two quantity types** used purely as *change signals*, and each catch-up resolves payloads with a bounded correlation `HKSampleQuery` predicated `startDate ≥ max(importStart, oldestChangedSample.startDate − 5 min)`, deduplicated by UUID against the persisted ring + backend constraint. Executable consequence: backdated-insert capture is preserved (the quantity anchor still reports the child insert, whose own `startDate` bounds the correlation query); deletions are out of scope entirely (child-UUID→correlation mapping is exactly the trap round one identified); everything else in this document stands. Bounded-query semantics: the correlation query window derives from the returned child samples, never from wall-clock windows.

---

# Implementation plan (v1.2)

## Phase 0 — Spike + lock the paper (1.5–2 days)

Run §11 in full; write ADR-0004. Publish §7 as the final Plugin Bridge Spec. Obtain **written backend sign-off** on: the §13 migration as-is (or a redlined return), the Layer-2 policy incl. the D2 false-positive, the enrolments-table assumption (D3), and RLS test results. Book the client non-production Supabase environment for T15/T16. File ADR-0003 (custom plugin: community plugins centre on foreground fitness reads; none covers BP correlations + background delivery + source de-dup + denial handling [R13, R14]). Escalate D4 (window vs estimate) to the engagement lead in writing.

## Phase 1 — Harness, authorisation, first read (2–2.5 days)

Scaffold §9.2; implement `configure` (full-tuple idempotency), `getStatus`, `requestAuthorization`, prompt status, the mapper, and foreground `runCatchUp` in bootstrap mode.

```swift
enum Mapper {
    /// Correlation -> pre-commit payload. Structural checks only (§7.3).
    /// receivedAt/itemId are NOT set here — StateStore.commit assigns both
    /// exactly once at first enqueue (MappedReading -> QueuedReading).
    static func map(_ sample: HKSample) -> MappedReading? {
        guard let corr = sample as? HKCorrelation,
              corr.objects(for: BPTypes.systolic).count == 1,
              corr.objects(for: BPTypes.diastolic).count == 1,
              let sys = corr.objects(for: BPTypes.systolic).first
                        as? HKQuantitySample,
              let dia = corr.objects(for: BPTypes.diastolic).first
                        as? HKQuantitySample
        else { return nil }        // counted per-source, never silently lost
        let s = sys.quantity.doubleValue(for: BPTypes.mmHg)
        let d = dia.quantity.doubleValue(for: BPTypes.mmHg)
        guard s.isFinite, d.isFinite else { return nil }
        return MappedReading(
            hkUuid: corr.uuid.uuidString, systolic: s, diastolic: d,
            takenAt: corr.startDate,
            tzOffsetMinutes: offsetFromMetadata(corr),   // nil when absent [R17]
            sourceBundleId: corr.sourceRevision.source.bundleIdentifier,
            sourceName: corr.sourceRevision.source.name,
            deviceModel: corr.device?.model)
    }
    static func offsetFromMetadata(_ c: HKCorrelation) -> Int? {
        guard let id = c.metadata?[HKMetadataKeyTimeZone] as? String,
              let tz = TimeZone(identifier: id) else { return nil }
        return tz.secondsFromGMT(for: c.startDate) / 60
    }
}
```

**Exit:** clean-clone discovery on a second machine (T1); sheet shows once; a Health-app manual reading round-trips with exact values, `com.apple.Health` source, and metadata-honest `tzOffsetMinutes`.

## Phase 2 — Engine: single executor, arming, catch-up, snapshots (4.5–6 days)

The engine is one actor-equivalent: a serial queue that owns the `StateStore`, the observer list, and every transition — **no bridge method touches state off-executor** (ship-gate 12). Sketch of the load-bearing parts:

```swift
final class HealthKitEngine {
    static let shared = HealthKitEngine()
    private let store = HKHealthStore()
    private let work = DispatchQueue(label: "bp.healthkit.engine")  // the executor
    private let state = StateStore()                                 // §10
    private var observers: [HKObserverQuery] = []
    private var catchUpPending = false

    /// LAUNCH ORDER (ship-gate 12): observers are per-process and urgent on a
    /// HealthKit background relaunch; background-delivery registration is
    /// already persistent system state. Register FIRST, verify async SECOND.
    func armAtLaunchIfConfigured() {
        work.async { [self] in
            let s = state.current
            guard s.enrolmentRef != nil, s.desiredObservationEnabled else { return }
            registerObserversLocked()                       // synchronous, first
            Task { await self.verifyBackgroundDelivery() }  // async, second;
        }                                                   // updates lastArm only
    }

    /// User-facing arm: sets intent, registers, AWAITS both enablements,
    /// records result, rejects on failure (state -> armFailed).
    func startObserving() async throws {
        try onExecutor { s in
            guard s.enrolmentRef != nil else { throw BPError.configMissing }
            s.desiredObservationEnabled = true              // intent
        }
        onExecutorSync { registerObserversLocked() }
        do {
            try await enableDelivery(BPTypes.systolic)
            try await enableDelivery(BPTypes.diastolic)
            try onExecutor { $0.lastArm = .ok(Date()) }     // result
        } catch {
            try? onExecutor { $0.lastArm = .failed(Date(), code: error) }
            throw BPError.bgDeliveryFailed                  // armFailed state
        }
    }

    private func registerObserversLocked() {                // on `work` only
        guard observers.isEmpty else { return }
        for type in BPTypes.observed {
            let q = HKObserverQuery(sampleType: type, predicate: nil)
            { [weak self] _, systemDone, error in
                self?.work.async {
                    defer { systemDone() }   // EVERY path, EXACTLY once [R4]
                    if error != nil { Log.event("observerErr"); return }
                    self?.runCatchUpLocked(.backgroundWake)
                }
            }
            store.execute(q); observers.append(q)
        }
    }

    /// ONE catch-up path (wake, foreground, retry, bridge runCatchUp).
    private func runCatchUpLocked(_ trigger: Trigger) {
        let s = state.current
        guard let cfg = s.config else { return }             // CONFIG_MISSING
        guard s.desiredObservationEnabled else { return }    // no capture when
                                                             // disabled (§7.1)
        do {
            // BOOTSTRAP RULE (§5.3): nil anchor until first readable reading.
            let anchor = s.bootstrapComplete ? s.decodedAnchor : nil
            let delta = try fetchDeltaSync(anchor: anchor, since: cfg.importStart)
            try state.commit { st in
                let fresh = delta.readings.filter { !st.recentUuids.contains($0.hkUuid) }
                st.enqueue(fresh, enrolmentRef: cfg.enrolmentRef)  // itemId +
                                                                   // receivedAt HERE
                st.mergeMalformedCounts(delta.malformedBySource)
                if st.bootstrapComplete || !fresh.isEmpty {
                    st.anchorData = delta.newAnchorData     // advance ALWAYS
                    st.bootstrapComplete = true             // post-bootstrap —
                }                                           // even empty deltas
                if !fresh.isEmpty { st.snapshotSeq &+= 1 }  // B2: every queue
                                                            // mutation bumps —
                                                            // ack/hold/discard/
                                                            // reclaim do too
            }
            catchUpPending = false
            notifyBridgeIfAlive(count: state.pendingCount)   // hint only
        } catch let e as HKError where e.code == .errorDatabaseInaccessible {
            catchUpPending = true                            // anchor untouched;
            Log.event("hkLocked.retryPending")               // retried below [R18]
        } catch { handleQueryFailure(error) }                // anchor-recovery
    }                                                        // ladder, §5.3
}
```

```swift
    /// Full teardown (B4) — runs on the executor; reset performs the same
    /// steps inside the RESETTING barrier before its policy commit.
    private func stopObservingLocked() async throws {
        for q in observers { store.stop(q) }        // stop EXECUTED queries
        observers.removeAll()
        try await disableDelivery(BPTypes.systolic)  // awaited, both types
        try await disableDelivery(BPTypes.diastolic)
        try state.commit { $0.desiredObservationEnabled = false }
    }

    /// Acknowledge (B2): resolves each itemId in the active queue OR any
    /// held bucket; validates the snapshot generation first; the removal
    /// commit advances snapshotSeq, invalidating all older snapshots.
    func acknowledge(snapshotId: String, itemIds: [String]) throws -> AckResult {
        try onExecutor { st in
            guard st.snapshotToken == snapshotId else { throw BPError.snapshotStale }
            let r = st.removeEverywhere(itemIds)     // active + held, by ULID
            st.snapshotSeq &+= 1
            return r                                 // {removed, alreadyAbsent}
        }
    }
```

Retry triggers for a pending catch-up (all funnel to the executor): `protectedDataDidBecomeAvailableNotification`, foreground activation, bridge-ready, next wake, explicit `runCatchUp()`. Anchor recovery (§5.3 triggers only) clears `anchorData`+`bootstrapComplete` atomically with a reason code and schedules the foreground re-import. `disconnectAndReset` enqueues a **barrier** on the executor: in-flight catch-up completes/aborts first, observers stop, delivery disables, then the single policy commit (§6.3) — no post-reset commit can land. AppDelegate carries one line: `HealthKitEngine.shared.armAtLaunchIfConfigured()`.

**Exit:** T5a pattern (delayed-writer, §14) ×5 across 48 h incl. one reboot and one deliberate locked-store deferral that converges; kill-injection at every commit boundary (M3–M6) loses nothing; generation-fallback (M17) recovers; anchor-reset drill (M12) preserves queue/config; entitlement-removed build (T14) rejects loudly.

## Phase 3 — Real sources, de-dup proof, denial handling (3–3.5 days + parallel soak)

**3a Omron end-to-end** as v1.1, on the frozen OS. **3b Writer buttons:** *one now* · *save in 60 s* (the T5a lock-first sequence) · *10 across last week* · *duplicate of last +90 s* · *identical values, distinct events ×3 chained* (T8b) · *backdated 7 d* · *future-dated +1 d* · *no timezone metadata* · *bare systolic* (structural-reject diagnostic). **3c Denial UX** unchanged from v1.1 (neutral three-branch copy verbatim; button labelled "Open BP Reset Settings" [R20]; empty state only after a requested-and-completed fetch), with the bootstrap rule now guaranteeing recovery: any number of empty denied-state fetches persist no anchor, so a later grant backfills from `importStart` (T10 tests exactly this).

## Phase 4 — Drain protocol and client-environment integration (2.5–3 days)

```typescript
import { App } from '@capacitor/app';

let draining = false;                              // process-wide mutex
export async function drain(): Promise<void> {
  if (draining) return; draining = true;
  try {
    const session = await requireAuthenticatedEnrolment(); // {enrolmentRef,
                                                           //  accessToken}
    // HELD-FIRST (B1): if this session's enrolment has a held bucket from a
    // previous disconnect, reclaim it before the active queue.
    const st = await BPHealthKit.getStatus();
    if (st.held.some(h => h.enrolmentRef === session.enrolmentRef)) {
      const hs = await BPHealthKit.getHeldSnapshot({
        enrolmentRef: session.enrolmentRef });
      if (hs.readings.length) {
        const { error } = await supabase.rpc('ingest_bp_batch', {
          p_enrolment_ref: session.enrolmentRef, p_rows: toRows(hs.readings) });
        if (!error) await ackWithRetry(hs.snapshotId,
                                       hs.readings.map(r => r.itemId));
      }
    }
    await BPHealthKit.runCatchUp().catch(() => {});        // deferred is fine
    const snap = await BPHealthKit.getPendingSnapshot();
    if (!snap.readings.length) return;

    // BINDING CHECK — EVERY item (ship-gate 18 heritage):
    if (snap.readings.some(r => r.enrolmentRef !== session.enrolmentRef)) {
      enterBindingHold(snap);                              // §6.3 / §17.3;
      return;                                              // upload nothing,
    }                                                      // discard nothing
    const { error } = await supabase.rpc('ingest_bp_batch', {
      p_enrolment_ref: session.enrolmentRef,
      p_rows: toRows(snap.readings),                       // §17.3 mapping table
    });                                                    // ONE atomic call,
    if (error) return;                                     // all-or-nothing (§13)
    await ackWithRetry(snap.snapshotId,
                       snap.readings.map(r => r.itemId));  // SNAPSHOT_STALE ->
  } finally { draining = false; }                          // re-snapshot+retry;
}                                                          // replay is safe
App.addListener('appStateChange', s => { if (s.isActive) void drain(); });
void drain();                                              // bridge-ready
BPHealthKit.addListener('bpReadingsAvailable', () => void drain());
```

Guarantees: one serialized drain; stable snapshot; one **all-or-nothing** server call (§13 raises and rolls back on any invalid row, so a success return means every row is inserted-or-duplicate — acknowledging the whole snapshot is therefore sound); ack exactly the snapshot's `itemIds` after success; ack idempotent; **nothing removed on timeout or ambiguity** — server-commit-then-client-timeout replays into the constraint (M8). Ack failure after server success: retry ack (readings already safe); if the process dies first, the reappeared rows replay harmlessly (M5's corrected model). **Client-environment integration:** synthetic batch against the client-controlled non-prod Supabase (T15) — auth, RLS positive/negative, uniqueness, all-or-nothing rejection, canonicalisation, ack — plus the live loan-cuff end-to-end during the walkthrough (T16), evidence value-free.

## Phase 5 — Evidence and handoff (1.5–2 days)

Assemble the §17 manifest; clean-clone verification on a second machine; rebuild provisioning the morning of the walkthrough; audit every artefact for values (T-EV); log deviations; republish as-built.

---

# Backend integration migration (executable)

Assumption (open decision D3, confirmed at P0): an `enrolments` table exists shaped at least `enrolments(id uuid pk, patient_id uuid not null, auth_user_id uuid not null, program_start timestamptz not null, status text)`. Greenfield migration follows; if the client project already carries an observations table, Ben derives a diff migration from this canonical form. **Privilege model (B3), stated up front:** `ingest_bp_batch` is SECURITY INVOKER and depends on the caller being able to *read their own enrolment* (migration 000). Clients hold **no update privilege** on `observations` and no RLS update policy exists — by design — which is exactly why `canonicalise_bp` is SECURITY **DEFINER** under the ship-gate-16 carve-out: pinned `search_path`, schema-qualified objects, an internal `auth.uid()` ownership guard, explicit grants. EXECUTE on it is **granted** to `authenticated` because PostgreSQL checks EXECUTE against the *calling role* even when the call comes from inside another function; the internal guard is what makes direct client calls safe.

```sql
-- =============================== 000_prerequisites.sql
-- The INVOKER ingest function must be able to read the caller's own
-- enrolment row. If the enrolments table already carries an equivalent
-- select-own policy, verify it and skip (D3).
alter table public.enrolments enable row level security;
create policy enr_select_own on public.enrolments for select
  using (auth_user_id = auth.uid());
grant select on public.enrolments to authenticated;

-- =============================== 001_bp_observations.sql
create table if not exists public.observations (
  id               bigint generated always as identity primary key,
  patient_id       uuid        not null references public.patients(id),
  client_uuid      uuid        not null,   -- HK correlation UUID | manual UUIDv4
  source_kind      text        not null
                     check (source_kind in ('healthkit','manual')),
  obs_type         text        not null default 'blood_pressure'
                     check (obs_type = 'blood_pressure'),   -- server-fixed
  systolic         numeric     not null,   -- structural only; NO range checks
  diastolic        numeric     not null,   --   (range = interpretation)
  unit             text        not null default 'mmHg' check (unit = 'mmHg'),
  taken_at         timestamptz not null,
  tz_offset_min    smallint,               -- nullable; HK metadata only
  source_bundle_id text,
  source_name      text,
  device_model     text,
  received_at      timestamptz,            -- client-assigned; informational
  ingested_at      timestamptz not null default now(),
  superseded_by    bigint references public.observations(id),
  deleted_at       timestamptz,            -- reserved for the reconciliation
                                           --   fast-follow (§8.3)
  constraint obs_patient_clientuuid_uniq unique (patient_id, client_uuid),
  constraint obs_source_fields_chk check (
    (source_kind = 'healthkit' and source_bundle_id is not null
                               and source_name is not null)
    or
    (source_kind = 'manual'    and source_bundle_id is null
                               and source_name is null)
  )
);
create index if not exists obs_display_ix
  on public.observations (patient_id, obs_type, taken_at desc)
  where superseded_by is null and deleted_at is null;
create index if not exists obs_candidate_ix
  on public.observations (patient_id, obs_type, systolic, diastolic, taken_at)
  where deleted_at is null;

alter table public.observations enable row level security;
create policy obs_select_own on public.observations for select
  using (patient_id in (select e.patient_id from public.enrolments e
                        where e.auth_user_id = auth.uid()));
create policy obs_insert_own on public.observations for insert
  with check (patient_id in (select e.patient_id from public.enrolments e
                             where e.auth_user_id = auth.uid()));
-- Deliberately NO update/delete policies and NO update grant to clients:
-- superseded_by is mutated only by canonicalise_bp (DEFINER, guarded below);
-- deleted_at only by the reconciliation fast-follow's own guarded function.

-- =============================== 002_ingest_bp_batch.sql
-- SECURITY INVOKER. All-or-nothing: any structurally invalid row raises and
-- rolls back the whole call, so the client's whole-snapshot acknowledge is
-- sound. No temporary tables (no TEMP-privilege dependency); the jsonb input
-- is scanned inline. Returns counts for caller logging.
create or replace function public.ingest_bp_batch(
  p_enrolment_ref uuid,
  p_rows          jsonb
) returns table (inserted int, duplicates int)
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare
  v_patient uuid;
  v_start   timestamptz;
  v_total   int;
  v_ins     int;
begin
  -- Server-side binding: the enrolment must belong to the caller.
  select e.patient_id, e.program_start into v_patient, v_start
    from public.enrolments e
   where e.id = p_enrolment_ref and e.auth_user_id = auth.uid();
  if v_patient is null then
    raise exception 'ENROLMENT_NOT_OWNED';
  end if;

  select count(*) into v_total
    from jsonb_to_recordset(p_rows) as r(client_uuid uuid);
  if v_total = 0 then
    return query select 0, 0; return;      -- zero-row batch fast path
  end if;

  -- Structural validation (never clinical). Any failure aborts the batch.
  if exists (
    select 1 from jsonb_to_recordset(p_rows) as r(
      client_uuid uuid, source_kind text, systolic numeric, diastolic numeric,
      taken_at timestamptz, tz_offset_min smallint, source_bundle_id text,
      source_name text, device_model text, received_at timestamptz)
    where r.client_uuid is null
       or r.source_kind not in ('healthkit','manual')
       or r.systolic is null or r.diastolic is null
       or r.taken_at is null or r.taken_at < v_start
       or (r.source_kind = 'healthkit'
           and (r.source_bundle_id is null or r.source_name is null))
       or (r.source_kind = 'manual'
           and (r.source_bundle_id is not null or r.source_name is not null)))
  then
    raise exception 'STRUCTURAL_VALIDATION_FAILED';
  end if;

  with ins as (
    insert into public.observations
      (patient_id, client_uuid, source_kind, systolic, diastolic,
       taken_at, tz_offset_min, source_bundle_id, source_name,
       device_model, received_at)
    select v_patient, r.client_uuid, r.source_kind, r.systolic, r.diastolic,
           r.taken_at, r.tz_offset_min, r.source_bundle_id, r.source_name,
           r.device_model, r.received_at
      from jsonb_to_recordset(p_rows) as r(
        client_uuid uuid, source_kind text, systolic numeric,
        diastolic numeric, taken_at timestamptz, tz_offset_min smallint,
        source_bundle_id text, source_name text, device_model text,
        received_at timestamptz)
    on conflict (patient_id, client_uuid) do nothing
    returning 1)
  select count(*) into v_ins from ins;

  -- Layer-2 canonicalisation over the padded neighbourhood (§8.2),
  -- computed from PERSISTED rows (replay-safe).
  perform public.canonicalise_bp(
    v_patient,
    (select min(r.taken_at) from jsonb_to_recordset(p_rows)
       as r(taken_at timestamptz)) - interval '3 minutes',
    (select max(r.taken_at) from jsonb_to_recordset(p_rows)
       as r(taken_at timestamptz)) + interval '3 minutes');

  return query select v_ins, v_total - v_ins;
end $$;

-- =============================== 003_canonicalise_bp.sql
-- SECURITY DEFINER — deliberately, under the ship-gate-16 carve-out (B3):
-- pinned search_path, schema-qualified objects, internal ownership guard,
-- explicit grants. DEFINER is required because clients hold NO update
-- privilege on observations (by design), yet canonicalisation must set
-- superseded_by. Deterministic, idempotent, reversible (§8.2).
create or replace function public.canonicalise_bp(
  p_patient uuid, p_from timestamptz, p_to timestamptz
) returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare r record; v_canon_id bigint; v_canon_at timestamptz;
        v_canon_s numeric; v_canon_d numeric;
begin
  -- Ownership guard: direct client calls may only touch the caller's data.
  if not exists (select 1 from public.enrolments e
                  where e.patient_id = p_patient
                    and e.auth_user_id = auth.uid()) then
    raise exception 'CANONICALISE_NOT_OWNED';
  end if;

  update public.observations
     set superseded_by = null
   where patient_id = p_patient and obs_type = 'blood_pressure'
     and taken_at between p_from and p_to;

  v_canon_id := null;
  for r in
    select id, systolic, diastolic, taken_at
      from public.observations
     where patient_id = p_patient and obs_type = 'blood_pressure'
       and deleted_at is null
       and taken_at between p_from and p_to
     order by systolic, diastolic,                    -- value groups together
              (source_kind <> 'healthkit'),           -- healthkit first
              ingested_at, id, client_uuid            -- total order [R25]
  loop
    if v_canon_id is not null
       and r.systolic = v_canon_s and r.diastolic = v_canon_d
       and abs(extract(epoch from (r.taken_at - v_canon_at))) <= 180
    then
      update public.observations
         set superseded_by = v_canon_id where id = r.id;
    else
      v_canon_id := r.id; v_canon_at := r.taken_at;   -- new cluster anchor
      v_canon_s  := r.systolic; v_canon_d := r.diastolic;
    end if;
  end loop;
end $$;

-- =============================== 004_grants.sql
revoke execute on function public.ingest_bp_batch(uuid, jsonb)
  from public, anon;
grant  execute on function public.ingest_bp_batch(uuid, jsonb)
  to authenticated;
revoke execute on function public.canonicalise_bp(uuid, timestamptz, timestamptz)
  from public, anon;
grant  execute on function public.canonicalise_bp(uuid, timestamptz, timestamptz)
  to authenticated;   -- REQUIRED (B3): EXECUTE is checked against the CALLING
                      -- role even inside ingest_bp_batch's call chain; the
                      -- ownership guard makes direct calls safe.
-- Function owner must be a privileged migration role (e.g. postgres) so the
-- DEFINER identity carries the update capability clients lack.
```

**Required SQL tests (delivered with the migration, run in the client non-prod env at T15):** the full call chain **as role `authenticated`** succeeds end to end (proving the B3 grant chain); direct `canonicalise_bp` call with a foreign `p_patient` → `CANONICALISE_NOT_OWNED`; canonicalisation **visibly updates** `superseded_by` (proving the definer path against RLS default-deny); RLS positive (own rows readable/insertable) and negative (other-patient insert/select blocked); `ENROLMENT_NOT_OWNED` on a foreign `enrolmentRef`; zero-row batch returns `(0,0)`; uniqueness replay → `duplicates` counted, zero new rows; all-or-nothing (one malformed row rejects the batch, zero inserts); T8 manual-vs-healthkit preference; T8b three-row chain (B superseded by A, C new canonical); T8c same-batch healthkit tie broken by `id`; replay of an already-persisted batch converges to the identical canonical set; late-arriving preferred row demotes the earlier canonical; the display query (`superseded_by is null and deleted_at is null`) returns the expected set throughout.

---

# Test script (v1.2) — Stage 2, native scope

**Walkthrough sequence (criterion f):** T2 → **T-A (manual entry, front-end lane)** → T4 → **T16 (the same cuff reading drains live into the client non-prod environment)** → T5a → T9 → T10 → T11.

| ID | Behaviour | Steps (condensed) | Expected | Crit. |
|----|-----------|-------------------|----------|-------|
| T1 | Discovery + availability | Clean clone on 2nd machine → sync → build → run | `isPluginAvailable` true; `isAvailable` true | c |
| T2 | First-run authorisation | Fresh install → `configure` → connect | Sheet exactly once on the frozen OS; resolves regardless of choice | c |
| T-A | Manual capture path | Front-end manual entry on device | Row in client env with `source_kind='manual'`, bounds applied (front-end lane) | a, d |
| T3 | Snapshot semantics | Health-app reading → catch-up → `getPendingSnapshot` ×2 → ack → snapshot | Same items+`snapshotId` both pre-ack calls; empty after; stale `snapshotId` ack → `SNAPSHOT_STALE` | c |
| T4 | Cuff → app, foreground | Cuff reading → open Omron Connect → open harness | Row present; Omron `sourceBundleId` | b, d |
| T5a | Background capture (valid state) | Arm → writer "save in 60 s" → background harness + lock phone → write fires locked → unlock, harness unopened | `queueCommitCompleted` marker without foregrounding; count on next open | b, c, d |
| T5b | Force-quit recovery | Swipe-kill → writer saves → relaunch manually | **No wake expected**; foreground catch-up imports exactly once | c |
| T6 | Endurance | T5a ×5 over 48 h incl. one reboot + one locked-store deferral | Still firing day 3; every deferral converges | c |
| T7 | Layer-1 idempotency | Anchor-reset replay (M12); reinstall + reconnect same enrolment | Zero duplicate backend rows | c |
| T8 | Layer-2: manual vs HealthKit | Manual entry, then Omron row, equal values <3 min | HealthKit row canonical; manual flagged, retained | c |
| T8b | Three-row chain | Writer: identical values at +0:00 / +2:50 / +5:40 | B superseded by A; **C is a new canonical**; all retained | c |
| T8c | Same-batch tie | Two HealthKit candidates in one RPC | Deterministic winner via `ingested_at` then `id` | c |
| T9 | Attribution | One reading each: Omron, Qardio, writer | Three rows, three correct sources | c |
| T10 | Denial + bootstrap backfill | Fresh install → deny → **run ≥2 empty fetches** → use app → grant via Health → catch-up | No anchor persisted while empty (bootstrap rule); full backfill from `importStart`; neutral copy, no false "denied" | c |
| T10b | Revocation after flow | Grant → import+drain → revoke → new cuff reading → foreground | Store appears empty; no false claim; prior data intact downstream | c |
| T11 | Bright-line audit | Inspect UI, payloads, events, notifications | Zero interpretive artefacts | e |
| T13 | Locked-store behaviour | Reading while locked; stay locked 10 min | Observed behaviour recorded; converges post-unlock; anchor never advanced on failure | c |
| T14 | Arming failure surfaced | Build once **without** the bg-delivery entitlement | `BG_DELIVERY_FAILED`; state `armFailed`; foreground fetch works | c |
| T15 | Client-env integration (synthetic) | Full SQL test list (§13) against client non-prod | All green; screenshots synthetic-only | b |
| T16 | Loan-cuff end-to-end (live) | The T4 reading continues through drain into client non-prod, verified live in the walkthrough | Row present; retained evidence value-free (UUID prefix + count only) | b |
| T-L | Lifecycle | configure idempotency; different tuple → `CONFIG_CONFLICT`; `disconnectAndReset` both policies; re-enrolment via new tuple | State machine transitions exactly per §6.2 | c |
| T-L2 | Held reclaim + discard | Trace (a) end to end: A captures → hold → configure B → B captures → A logs in → held-first drain; then `discardHeld` (confirmed) on a second bucket | A's rows land under A with zero crossing into B; `Status.held` empties per bucket; unconfirmed discard → `CONFIRM_REQUIRED` | c |
| T-EV | Evidence privacy audit | Review all retained artefacts | Synthetic or redacted values only | Model B |

**Fault-injection matrix (P2/P4):** **M1** backdated insert 7 d behind cursor → imported once · **M2** future-dated insert → no cursor poisoning · **M3** kill between fetch and commit → replay, no loss · **M4** kill mid-commit → old-or-new generation, never mixed · **M5** kill during ack → **old-or-new acceptable**; reappeared rows replay into the constraint harmlessly · **M6** disk-full/protected-write failure → anchor unmoved, completion still called, later retry imports · **M7** three simultaneous drain triggers → one serialized drain · **M8** server-commit + client-timeout → retry: one row, then ack succeeds · **M9** expired session mid-drain → queue intact; next trigger drains · **M10** account switch with pending queue → HOLD on every item; nothing uploads or vanishes; resolution flows work · **M11** partial permission grant → recorded, no user-facing inference · **M12** corrupt `anchorData` → anchor-only reset, reason code, queue/config preserved, `importStart` replay converges · **M13** uninstall→reinstall→reconnect same enrolment → backfill, zero duplicates · **M14** TZ metadata present/absent + device TZ change → only metadata-backed offsets claimed · **M15** upgrade with pending old-schema rows → migration then drain · **M16** six-week max volume (+margin) → launch/fetch/drain timings acceptable · **M17** newest generation undecodable → previous valid generation loads; both invalid → hard `INTERNAL`, never silent re-init · **M18** `disconnectAndReset` during in-flight catch-up → barrier holds; no post-reset commit; observers stopped and delivery disabled (B4 teardown verified with a post-reset writer save producing **no** wake) · **M19** empty/malformed-only delta post-bootstrap → anchor still advances; diagnostics counted · **M20** held bucket survives reset + new-enrolment capture + app relaunch, then reclaims fully under the original session (B1) · **M21** zombie ack with a pre-mutation `snapshotId` after any of {ack, hold, reclaim, discard} → `SNAPSHOT_STALE`; fresh snapshot then drains (B2/B5).

---

# Pitfalls catalogue (v1.2)

1. **The simulator lies** — vendor apps, sources, and background delivery only exist on the physical iPhone.
2. **Force-quit ≠ background.** Swipe-kill suppresses HealthKit relaunch; recovery is foreground catch-up. Never run T5a from a force-quit state.
3. **The completion handler is absolute.** Exactly once, every path, `defer` [R4]. The punishment for sloppiness is undocumented and delayed.
4. **Observers are per-process.** Launch re-arming registers observers **first**; delivery verification is async second (§12 P2).
5. **`.immediate` is a request, not an SLA** [R15]. Promise eventual capture + foreground reconciliation.
6. **Locked store = retryable error, not a deferred callback.** `errorDatabaseInaccessible` is the dependable fact [R18]; classify, keep the anchor, converge later.
7. **Anchors advance on every success post-bootstrap** — including empty and malformed-only deltas — or something replays forever. Pre-bootstrap, no anchor persists at all, or denial buries history.
8. **Vendor resyncs mint new UUIDs and backdated rows.** The anchor catches the insert; Layer 2 catches the duplicate identity.
9. **Omron's chain has two manual switches** and post-iOS-26 breakage reports [R10–R12]. Debug vendor-first.
10. **The acceptance OS matters:** the 26.5 BP-authorisation sheet regression is exactly the class of bug that burns a demo [R23]. Frozen baseline, recorded in evidence.
11. **App IDs bind at first signing use; uploads bind forever** [R8, R9]. Production identifiers appear nowhere in the sandbox; library package names are exempt (§4.3).
12. **Free-team profiles die weekly** [R21]. Rebuild the morning of any demo.
13. **Never trust `authorizationStatus` for reads** [R13]; ship the heuristic UX.
14. **Timezone honesty:** metadata or null; never `TimeZone.current` archaeology [R17].
15. **Events are hints.** Drains run unconditionally on bridge-ready and foreground.
16. **One executor or bust.** Every state read/commit/observer mutation on the engine queue; the round-two race in `startObserving` is the cautionary tale.
17. **Ack by domain UUID was a data-loss bug** (reading/tombstone collision). Item IDs + snapshot generations make the race unrepresentable; keep it that way in any future extension.
18. **Logging is a compliance surface** — counts, codes, truncated opaque IDs; no overload accepts a reading.

---

# Risk register and open decisions (v1.2)

| Risk | L | I | Mitigation |
|---|---|---|---|
| Spike forces Path B | Low | Med | Path B pre-specified with bounded-query semantics (§11); deletions were already out of V1 |
| D4 unresolved: window vs 15–18 d | High | High | Escalated in writing at P0; descope ladder ready (§18) |
| Client non-prod env late | Med | High | Booked at P0 as a gate; escalate via tracker at P2 exit |
| Backend redlines §13 late | Low | Med | P0 sign-off is a gate; migration is executable, so review is concrete |
| Omron→Health chain breaks | Med | High | Qardio + writer keep every behaviour demonstrable; vendor-first debug |
| Background throttling on demo device | Med | Med | Demo on the soaked device; promise capture, not latency |
| HOLD retention undefined (D1) | Med | Med | Placeholder = indefinite, support-visible; client decision requested |
| Solo-lane bus factor | Low | Med | This document + ADRs + named backup (existing team task) |

Open decisions D1–D4: see §2.2.

---

# Integration & handoff specification

Together with §7 (bridge) and §13 (migration), this section is sufficient to integrate **without a meeting**; unanswered questions are documentation defects.

## Package manifest

| Item | Where | Form |
|---|---|---|
| `bp-healthkit` plugin (`com.corveo.bphealthkit`) | `packages/bp-healthkit` | Local Capacitor 8 package: Swift engine + two-generation state store, TS defs, README |
| Harness app | `apps/bp-harness` | The regression rig (throwaway ID; never ships) |
| Test-writer app | `apps/bp-writer` | Synthetic-source generator incl. delayed-save (throwaway ID; never ships) |
| Bridge contract | §7 + `docs/plugin-bridge-spec.md` | Frozen v1.2 |
| Backend migration + tests | §13 + `db/migrations/00*.sql`, `db/tests/` | Executable |
| Test script + results | §14 executed, `docs/stage2-test-script.md` | With device/OS versions + evidence index |
| ADR-0003/0004 | `docs/adr/` | Custom-plugin decision; spike outcome |
| This document, as-built | `docs/` | v1.2 + deviations log |

## Backend (Ben)

Apply §13 as written or return a redline at P0 (D3 confirms the enrolments shape first). Non-negotiables from this lane's correctness argument: the ingest RPC stays **SECURITY INVOKER** with the in-function `auth.uid()`→enrolment binding; `canonicalise_bp` stays **SECURITY DEFINER under the carve-out conditions exactly as written** (pinned `search_path`, ownership guard, granted-to-authenticated — the B3 privilege chain fails at runtime if any one is altered); **no client update privilege** on `observations`; **all-or-nothing** batch semantics (the client acknowledges whole snapshots); the total order ending in `id`; canonicalisation computed from persisted rows; migration 000's enrolments read policy present. The §13 test list runs in the client non-prod env at T15. `deleted_at` is reserved for the reconciliation fast-follow (§8.3) — no V1 code path writes it.

## Front end (Michael)

1. Install + verify discovery (T1). 2. **Connect order:** `isAvailable` → `configure({enrolmentRef, importStart})` (both from the authenticated session's enrolment record — `enrolments.id` and `enrolments.program_start`; never handset time) → `requestAuthorization` → `startObserving`. `ARM_FAILED` renders "connected — background updates unavailable"; foreground refresh still works. 3. **Drain:** §12 P4 verbatim; unconditional on bridge-ready + every foreground; retain and clean up the listener handle on unmount; **pending-count affordance is required** (a stuck queue must be visible). 4. **`toRows` mapping:**

| RPC field | From | Notes |
|---|---|---|
| `client_uuid` | `reading.hkUuid` | — |
| `source_kind` | `'healthkit'` | manual rows come from the form path, not the plugin |
| `systolic`/`diastolic` | as-is | never rounded/derived |
| `taken_at` | `reading.takenAt` | ISO UTC |
| `tz_offset_min` | `reading.tzOffsetMinutes` | null passes through as null |
| `source_bundle_id`/`source_name`/`device_model` | as-is | — |
| `received_at` | `reading.receivedAt` | informational |

5. **Error rendering:** `HK_TEMP_UNAVAILABLE` → nothing user-facing required (optional quiet "will update after unlock"); `BG_DELIVERY_FAILED` → the ARM_FAILED copy above; `QUERY_FAILED` persistent → generic retry + support report; `SNAPSHOT_STALE` → internal re-snapshot, invisible; `INTERNAL` → support-visible error state, never auto-reset. 6. **Logout:** attempt `drain()` first; plain sign-out otherwise (state persists). **Account switch:** the binding check produces HOLD — render held count + the two resolution paths (§6.3); no timer-based disposal (D1). **Held reclaim (B1):** the drain runs held-first (§12 P4) — on any login, if `Status.held` contains the session's enrolment, that bucket drains before the active queue; `discardHeld` is only reachable behind an explicit confirmation dialog and renders per-bucket counts from `Status.held`, never values. **Disconnect:** the two-policy flow with explicit confirmation gating `confirmedDiscard`; copy states it stops BP Reset importing and does not change Health permissions. 7. Empty-state copy verbatim (§12 P3c); button label "Open BP Reset Settings".

## Production app assembly

1. Production bundle ID + app record created **fresh in the client's Apple Developer organisation account**; sandbox app IDs appear nowhere; the plugin package name (`com.corveo.bphealthkit`) is exempt (§4.3). 2. Capabilities: HealthKit + Background Delivery on the **app target only**; verify the entitlements **in the signed archive** (`codesign -d --entitlements :- App.app`), not just project settings. 3. Verify the built product's Info.plist has the share key and **lacks** the update key; verify neither writer nor harness is embedded (archive content check + scheme audit; CI assertion recommended). 4. AppDelegate: the one `armAtLaunchIfConfigured()` line (§12 P2) — in the app project's AppDelegate, which `cap sync` does not regenerate; add a unit assertion that the symbol is referenced so a future refactor can't silently drop it. 5. Environment: build-time assertion that the Supabase URL/key are present and not the dev project (fail the build otherwise). 6. First-run migration for existing web users: obtain the enrolment record from the session **before** offering the connect flow; `configure` precedes `requestAuthorization` always. 7. Acceptance OS on the demo device = the frozen baseline (§3.5). 8. One production-signed build must pass a T5a run before submission — sandbox soak does not prove production entitlements survived assembly.

## Acceptance evidence map (Nick)

| Criterion | Evidence |
|---|---|
| (a) manual path | T-A in the walkthrough (front-end lane) |
| (b) cuff → app → client Supabase | T4 + **T16 live end-to-end** (same reading), T15 synthetic suite |
| (c) four named behaviours | T2/T3 · T5a/T6 · T7/T8/T8b/T8c/T9 · T10/T10b |
| (d) both paths, physical device, loan cuff | Walkthrough sequence §14 |
| (e) no interpretation | T11 audit, co-signed |
| Deliverable #2 medium | Plugin source in client repo + physical-device demo record |

---

# Estimates and descope ladder

| Phase | Range |
|---|---|
| P0 spike + paper | 1.5–2 d |
| P1 harness/auth/first read | 2–2.5 d |
| P2 engine | 4.5–6 d |
| P3 sources/de-dup/denial | 3–3.5 d (+2–3 elapsed soak, parallel from day 3) |
| P4 drain + client-env | 2.5–3 d |
| P5 evidence/handoff | 1.5–2 d |
| **Total** | **15–19 developer-days; planning number 15–18** |

> **AMENDED 20 August 2026 (deviation D-001, `docs/deviations.md`).** The lane owner revises
> this to **3 days to a working prototype**, worked as dedicated consecutive days. The table
> above is retained unamended as the original estimate for the as-built record. The revision
> is the lane's to make: §18 is this lane's own estimate, whereas **D4 — whether the Stage-2
> window accommodates it — remains the engagement lead's decision**, and a shorter estimate
> narrows that gap rather than closing the question.
>
> **What the 3 days covers, and what it does not.** "Working prototype" is P1 through P4
> functioning on the device: authorisation, anchored catch-up, the engine on its executor, the
> durable store, drain, and de-dup. It is *not* Stage 2 acceptance, and the difference is not
> developer speed. Three things gate acceptance and none are inside this lane:
> **(a)** T6, the 48-hour soak — wall-clock, and it can only start once the engine arms, so it
> must be kicked off the moment P2 stands rather than at P3;
> **(b)** T15/T16 in the **client-controlled non-production Supabase**, which is a hard gate
> for criterion (b) and depends on that environment being booked and on the backend lane;
> **(c)** the C1/C15 contract decision — the engine is exactly where the two candidate designs
> diverge, so a P2 built before that lands may be built twice.
> Consequence of the faster cadence: the C1 escalation becomes **more** urgent, not less,
> because P2 now arrives within a day rather than within a week.

The v1.1 "12–15" claim is withdrawn; these ranges sum honestly (ship-gate 28), and the delta against the Stage-2 window is open decision D4 for the engagement lead — with this ladder ready if it compresses (each step to a *documented* fast-follow, never silent absence): **(1)** already taken — deletion capture is out of V1 by design (§8.3); **(2)** bare-quantity diagnostics beyond the count-by-source map; **(3)** retail-source evidence beyond loan cuff + writer (Qardio/Withings extras); **(4)** iPad exploration; **(5)** T6 soak repetitions beyond the contractual minimum. **Never descope:** the anchor cursor + bootstrap rule, the two-generation store, unconditional foreground drain, snapshot-safe acknowledgement, the lifecycle state machine, physical Omron evidence, Layer-1 idempotency, neutral denial recovery, enrolment binding, or the client-environment runs (T15/T16).

---

# Round four (terminal delta check)

The loop ends here. Round three's verdict was NO-GO on five specification defects; v1.3 changes **only** what those five demanded — §2.3 is the delta map. The round-four ask is a **15-minute check of the five fixes, nothing else**: for each of B1–B5, confirm the cited fix closes the exact failure sequence from the round-three trace, and re-run the two artefacts that changed materially — the §13 migration desk-check (privilege chain as `authenticated`, definer guard, no-temp-table pattern) and the trace-(a) walk with the held-first drain. Verdict is one word, GO or NO-GO; a NO-GO requires a concrete failure sequence **in a changed section**. Anything outside the delta is out of scope and will be treated as noise. On GO, Phase 0 (the spike) starts the next morning and all subsequent review happens on code, not documents.
---

# Glossary

**HealthKit / Health app** — Apple's on-device encrypted health datastore; access is entitlement- and per-type-permission gated. **Correlation** — a sample grouping related samples; BP is one correlation containing one systolic + one diastolic quantity sample (mmHg). **Observer query** — long-running query notifying *that* data changed, never *what*. **Background delivery** — iOS waking an app for observer updates; entitlement-gated, per-type, throttled; a request, not an SLA. **Anchored query / anchor** — query returning inserts and deletions since an opaque resumable token; this design's cursor. **Bootstrap rule** — no anchor persists until the first readable reading is committed (§5.3). **enrolmentRef / importStart** — the immutable configuration tuple: server-side enrolment UUID + server enrolment timestamp (§6.1). **itemId / snapshotId** — native queue identity and generation token; the acknowledgement keys (§7.1). **HOLD** — the drain-side condition when queued items' enrolment ≠ the session's; nothing uploads, nothing is discarded (§6.3). **Held bucket / reclaim** — items parked under a previous enrolmentRef by `holdForReauth`; drained via `getHeldSnapshot` under a matching session, or destroyed only by confirmed `discardHeld` (§6.3, §7.1). **disconnectAndReset** — the only exit from a configured tuple; two pending policies (§6.3). **Canonicalisation** — reversible presentation-level de-dup; canonical-anchored clustering with a total order (§8.2). **Reconciliation fast-follow** — the deferred deletion design: whole-state compare, patient-scoped soft-delete (§8.3). **Drain** — serialized foreground upload: catch-up → snapshot → binding check → one atomic RPC → acknowledge. **Model B** — identifiable data stays in the client environment; developers use synthetic data. **Bright line** — the contractual prohibition on interpreting readings. **Validated cuff** — clinically validated upper-arm monitor (Omron/Withings class). **Bundle ID / App ID vs package ID** — signing identity (team-binding) vs library name (no signing implication). **Frozen acceptance OS** — iOS 26.6+ (§3.5).

---

# References

[R1]–[R22] verified 17–18 Aug 2026; [R23]–[R27] supplied by review rounds and adopted.

- **[R1]** Capacitor iOS docs — iOS 15+, Xcode 26.0+. capacitorjs.com/docs/ios
- **[R2]** Capacitor 8 upgrade + environment — Xcode 26 min, Node 22+, SPM default. capacitorjs.com/docs/updating/8-0 · /docs/getting-started/environment-setup
- **[R3]** Apple toolchain floor from 28 Apr 2026. capawesome.io/blog/xcode-26-requirement-for-capacitor-apps · capgo.app/blog/xcode-26-requirement-for-capacitor-apps
- **[R4]** HealthKit background-delivery architecture; completion-handler requirement. 3nsofts.com/insights/healthkit-architecture-production-ios-apps
- **[R5]** Observer/anchored pairing; pipeline shape. openwearables.io/blog/getting-apple-health-data-into-your-backend
- **[R6]** Free-provisioning capability set incl. HealthKit. appbuilder24.com/blog/apple-developer-account-needed
- **[R7]** Free personal-team mechanics. developer.apple.com/forums/thread/90133
- **[R8]** Bundle ID immutable once a build uploads. developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer
- **[R9]** App-transfer criteria: a released version required. developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria
- **[R10]** Omron Connect sync triggers. omron-healthcare.com/omronconnect-support
- **[R11]** Enabling Apple Health sharing inside Omron Connect. javafun.github.io/posts/omron-hem-7600t-smart-elite
- **[R12]** Field reports: Omron→Health sync stops post-iOS-26. discussions.apple.com/thread/256100682
- **[R13]** Community plugins; denied reads look empty. github.com/perfood/capacitor-healthkit · github.com/iAmMrHands/capacitor-healthkit
- **[R14]** Community-plugin survey. github.com/mley/capacitor-health · github.com/Cap-go/capacitor-health · github.com/Flomentum-Solutions/capacitor-health-extended
- **[R15]** Background-delivery throttling variance. developer.apple.com/forums/thread/814914 · /thread/781261
- **[R16]** `HKAnchoredObjectQuery` — sample types incl. correlations; predicate filters samples and deleted objects. developer.apple.com/documentation/healthkit/hkanchoredobjectquery
- **[R17]** `HKMetadataKeyTimeZone`. developer.apple.com/documentation/healthkit/hkmetadatakeytimezone
- **[R18]** `HKError.errorDatabaseInaccessible`. developer.apple.com/documentation/healthkit/hkerror/code/errordatabaseinaccessible
- **[R19]** `HKDeletedObject.uuid`. developer.apple.com/documentation/healthkit/hkdeletedobject
- **[R20]** `UIApplication.openSettingsURLString`. developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring
- **[R21]** Apple membership comparison — free-team limits. developer.apple.com/support/compare-memberships
- **[R22]** `packageClassList` is generated by `cap sync`. github.com/ionic-team/capacitor/discussions/7405
- **[R23]** iOS 26.5 Blood Pressure authorisation-sheet regression; fixed in 26.6 (review-supplied; verified on-device at SPK-3). developer.apple.com/forums/thread/825866
- **[R24]** `requestAuthorization(toShare:read:)` — read sets accept concrete `HKSampleType`s incl. correlation types (review-supplied). developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)
- **[R25]** PostgreSQL `now()` is transaction-stable — same-batch `ingested_at` ties. postgresql.org/docs/current/functions-datetime.html
- **[R26]** `isExcludedFromBackup` is a filesystem resource value. developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup
- **[R27]** Function security guidance: invoker by default; safe `search_path` for definer. postgresql.org/docs/current/sql-createfunction.html · supabase.com/docs/guides/database/postgres/row-level-security

*v1.2 is the build specification. On execution: deviations logged per phase; republished as-built with the handoff package.*

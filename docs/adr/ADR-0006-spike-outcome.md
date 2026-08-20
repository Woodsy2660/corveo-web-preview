# ADR-0006 — Spike outcome: cursor architecture (Path A or Path B)

- **Status:** ⛔ **NOT YET RUN — template awaiting the on-device spike (§11).**
- **Date:** _(fill: date the spike ran)_
- **Phase:** P0 (§12 Phase 0 — "Run §11 in full; write ADR-0004", same-day — filed here as ADR-0006, see note below)
- **Decider:** Luca (native/mobile lane)

> **Numbering.** Guide v1.3 calls this ADR-0004 internally, because it was written before
> tracker entries 0004 and 0005 existed. **The tracker series wins**, so it is filed here as
> ADR-0006. References to "ADR-0004" inside the frozen guide mean this document.


> **Filling rule.** Nothing in this document is written from expectation. Every cell is an
> observation from the frozen acceptance OS on the physical iPhone, or it stays empty. Where
> a result contradicts guide v1.3, the **device wins**: record it here, stop, and amend the
> guide before any dependent code exists (§1 authority rules, §11 SPK-3).

## Evidential environment (fill before any SPK step)

| Field | Value |
|---|---|
| Device model | _(e.g. iPhone 1x,x — exact identifier, not marketing name)_ |
| iOS version | **26.6+ — confirmed 20 Aug 2026.** _(record the precise version string)_ |
| Exact build number | ⚠️ _**Still needed.** Settings → General → About → Software Version. Every evidence artefact carries it (§3.5); without it the run is not attributable to the frozen baseline._ |
| Xcode version | _(26.x)_ |
| Apple team | _(personal free team / studio paid login)_ |
| Reader Q bundle ID | `dev.lucab.bpspike` (quantity-only auth set) |
| Reader C bundle ID | `dev.lucab.bpspikec` (correlation-inclusive auth set) |
| Writer bundle ID | `dev.lucab.bpwriter` (carries `NSHealthUpdateUsageDescription`; never ships) |
| Omron chain verified (§9.4) | **Yes — 20 Aug 2026.** Cuff readings landing in Apple Health on the dev iPhone. |
| Date/time of run | _(fill)_ |

**Gate:** if the iOS version is anything other than 26.6+, **stop**. Results against any other
build are void (§3.5, standing order 2). **Both Phase 0 gates cleared 20 Aug 2026** — device on
the frozen baseline, vendor chain proven end to end. The spike is unblocked.

**Evidence discipline from here (§4.2).** The readings now in Apple Health are the developer's
own, taken on the developer's own device, which the guide expressly permits. They must not
reach a commit, an export, a log line or a screenshot. Every cell below takes UUID prefixes,
counts and error codes. Anything that would otherwise show a value uses the writer app's
synthetic data instead.

## Decision

> _(fill exactly one, after SPK-1 and SPK-close)_
>
> - [ ] **Path A** — correlation-anchored cursor, as specified in §5.2. One persisted
>   `HKQueryAnchor` over `HKCorrelationType(.bloodPressure)`, predicated `startDate ≥ importStart`.
> - [ ] **Path B** — anchors on the two **quantity** types used purely as change signals; each
>   catch-up resolves payloads with a bounded correlation `HKSampleQuery` predicated
>   `startDate ≥ max(importStart, oldestChangedSample.startDate − 5 min)`, deduplicated by UUID
>   against the persisted ring + backend constraint. Query window derives from returned child
>   samples, never wall-clock.

**Consequence if Path B:** backdated-insert capture is preserved (the quantity anchor still
reports the child insert, whose own `startDate` bounds the correlation query); deletions are
out of scope entirely (child-UUID → correlation mapping is the trap round one identified);
everything else in the guide stands unchanged.

## Results against §11

### SPK-1 — Correlation-anchored inserts with a real resumable cursor

*Method (as specified):* configure-equivalent state with real `importStart`; nil-anchor query
with the production predicate; commit anchor into the **actual `Envelope`/`EngineState` JSON**;
terminate the process; writer saves one current **and one 7-day-backdated** correlation;
relaunch; strict-load; resume query.

| Observation | Result |
|---|---|
| Current insert returned | _(yes/no — correlation UUID prefix only, never values)_ |
| 7-day-backdated insert returned | _(yes/no)_ |
| Each returned **exactly once** | _(yes/no)_ |
| Third query empty | _(yes/no)_ |
| Anchor survived the real persistence path (terminate → strict-load → resume) | _(yes/no)_ |
| Raw output / error codes | _(paste; codes and UUID prefixes only)_ |

**Verdict:** _(PASS → Path A · FAIL → Path B)_

> **This is the load-bearing result for the whole architecture. Report it the moment it
> passes; stop and report with raw output if it fails.**

### SPK-2 — Correlation-anchored deletions (characterisation ONLY)

*Standing order 1: deletions are out of V1 by decision (§8.3). No tombstone persistence, no
dormant contract, no "while we're in there" capture. Record and move on.*

| Observation | Result |
|---|---|
| Deleted set carries the **correlation** UUID | _(yes/no — this is the fact the fast-follow needs)_ |
| Deleted set carries child quantity UUIDs instead | _(yes/no)_ |
| Deletion repeated after the next commit | _(yes/no — expected: no)_ |
| Raw output | _(paste)_ |

**Implication recorded for the §8.3 reconciliation fast-follow:** _(fill — one paragraph, design
input only, no V1 code follows from this)_

### SPK-3 — Authorisation-set behaviour on the acceptance OS

*Two clean permission identities. Do not collapse into one target — a single app's Health
state contaminates the A/B (standing order 2).*

| | Reader **Q** (`dev.lucab.bpspike`, quantity-only) | Reader **C** (`dev.lucab.bpspikec`, correlation-inclusive) |
|---|---|---|
| `statusForAuthorizationRequest` **before** | | |
| Sheet appeared | | |
| Which Blood Pressure controls the sheet showed | | |
| `statusForAuthorizationRequest` **after** | | |
| Correlation query result | | |
| Systolic observer registration | | |
| Diastolic observer registration | | |
| Error codes | | |

**26.5 regression check [R23]:** sheet rendered complete on 26.6+ — _(yes/no)_

**Verdict:** _(does the chosen minimal quantity-only set authorise correlation reads and
observer registration cleanly? yes/no)_

**If no:** amend `BPTypes.authorizationRead` in §7.4 **and only there**, record why here, and
log the amendment in `docs/deviations.md`. The spike wins over the document.

### SPK-4 — State store & anchor survival including corruption

| Step | Expected (§10, §5.3) | Result |
|---|---|---|
| Two-generation store written, terminate → relaunch → strict-load → resume | Anchored query resumes | |
| Inject corrupt `anchorData` | **Anchor-only** reset: `anchorData` + `bootstrapComplete` cleared; queue, config, observation state, diagnostics **preserved**; reason code recorded | |
| Post-reset re-import | Bounded `importStart` re-import runs in foreground and converges | |
| Corrupt the **newest** generation file | Falls back to the previous valid generation (M17); generation-fallback diagnostic logged | |
| Corrupt **both** generations | Hard `INTERNAL`, never silent re-init | |
| Raw output | | |

**Verdict:** _(does the §10 loader behave as specified before any engine code depends on it?)_

### SPK-close — End-to-end mini-loop

configure → authorise (set Q) → install both quantity observers → anchored query → commit
anchor+payload into the store → terminate → writer: one current insert, one backdated insert,
one deletion → relaunch → resume.

| Observation | Result |
|---|---|
| Exact correlation UUIDs matched (prefixes only in evidence) | |
| No repeats after commit | |
| Deletion characterised | |

### SPK-extra — Bundle-ID authorisation-persistence check *(added; not in §11)*

*Rationale: §11 gives the spike reader `dev.lucab.bpspike` and §9.2 gives the Capacitor
harness the same ID, so the harness inherits that bundle's Health permission identity — while
T2 requires the sheet to appear exactly once on a fresh install. Whether deleting an app
clears its HealthKit authorisation on iOS 26 is exactly the folklore this project refuses to
guess at. Five minutes, on-device, while the identities are already set up.*

| Step | Result |
|---|---|
| Delete `dev.lucab.bpspike` from the device | |
| Reinstall, call `statusForAuthorizationRequest` | |
| Call `requestAuthorization` — does the sheet return? | |

**If the sheet does NOT return:** T2 cannot be executed against a bundle ID the spike already
authorised. The harness needs its own throwaway ID (e.g. `dev.lucab.bpharness`, still within
the free team's 10 App IDs) → **DEVIATION against §9.2**, logged in `docs/deviations.md`.
**If the sheet DOES return:** no change; record the fact and close the question.

## Deviations arising from this spike

_(list, or "none". Each also goes in `docs/deviations.md` for the as-built republish.)_

## References

[R16] `HKAnchoredObjectQuery` — sample types incl. correlations; predicate filters samples and
deleted objects. [R19] `HKDeletedObject.uuid`. [R23] iOS 26.5 Blood Pressure
authorisation-sheet regression, fixed in 26.6. [R24] `requestAuthorization(toShare:read:)` —
read sets accept concrete `HKSampleType`s incl. correlation types.

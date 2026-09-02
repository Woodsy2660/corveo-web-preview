# Deviations log

Every departure from `BP-Reset-HealthKit-Implementation-Guide-v1.3.md`, logged as it happens,
for the as-built republish at P5 (§12 Phase 5, §17.1).

**Rule (guide §1):** the guide is not silently deviated from. Where device reality contradicts
the document, the device wins — the spike result is recorded in an ADR, the guide section is
amended, and the change is logged here. Where I merely *believe* a section is wrong, I say so
explicitly, propose the smallest on-device experiment that settles it, and nothing changes
until it is settled.

## Status: 26 August 2026 — SPIKE RUN, PATH A ACCEPTED

**Deviations: three — D-001, D-002 and D-003, below.** S1 is **closed** (no deviation). S2 is a
confirmed contradiction of the frozen spec and is owed an amendment at republish rather than
being a deviation in itself.

**Paper track (unchanged).** The §13 migration was extracted verbatim (sha256-verified
against guide lines 797–997) with nothing corrected in transit.

**Phase 0 gates, cleared 20 Aug 2026.** Dev iPhone on the frozen acceptance OS (iOS 26.6+;
exact build still to be recorded into ADR-0004), and the §9.4 Omron chain proven — cuff
readings landing in Apple Health on the device.

**Native work started 25–26 Aug.** The §11 spike now exists: three bare SwiftUI targets in
`native/spike/` (`dev.lucab.bpspike`, `dev.lucab.bpspikec`, `dev.lucab.bpwriter`), no Capacitor,
production-shaped `BPTypes`/`EngineState`/`Envelope`/`StateStore`/`Mapper`/engine per §7.4,
§10 and §12 P1–P2. All three build clean. Signed-archive entitlements verified per §17.4
step 2: both readers carry `healthkit` + `healthkit.background-delivery` and **no**
`NSHealthUpdateUsageDescription`; the writer alone carries the update key. The §4.2 log guard
is a compile error, demonstrated by a deliberate failing build.

**The spike has now RUN on a physical iPhone, and Path A is accepted.** Full results in
[`adr/ADR-0006-spike-outcome.md`](adr/ADR-0006-spike-outcome.md). SPK-1 passes: the current and
7-day-backdated correlations each return exactly once after a real process termination, the
third query is empty, and the anchor survives through the two-generation store. SPK-2, SPK-3,
SPK-4, SPK-close and SPK-extra all have acceptance-device results; the §10 store passes 12/12
there; D-002's fix is confirmed on the device.

**With one caveat that was logged as D-003, closed 2 September by a re-take on a 26.x public build (see the entry).** The handset runs **iOS 27.0,
build `24A5424a`** — a different OS generation from the 26.x the baseline was validated
against, and a build with the shape of an Apple seed. It is the only iPhone available to the
lane and the run proceeded on the lane owner's direction. Every artefact from it is stamped
**`BASELINE-MISMATCH`** by the binaries themselves. **The client walkthrough must run on this
same handset and OS, or the results must be re-taken first** — the sequence is scripted, so
re-taking is cheap, but it is not free.

**Also unproven on this handset: the §9.4 Omron chain.** The only real vendor source present is
`com.withings.wiScaleNG`. The 20 Aug gate recorded the chain proven on "the dev iPhone", which
was evidently a different device. Stage 2 criteria (b) and (d) need the loan cuff paired to
*this* phone.

**Earlier the same day, on an iPad Pro sidecar (§9.4) — development testing, not evidence.**
Retained because it is where the two findings were made and because it is a second, independent
OS generation for S2:

- **SPK-1's mechanism behaves as §5.2/§5.3 specify.** Nil-anchor bootstrap committed the
  anchor; after a real process termination, a fresh process strict-loaded and resumed the
  anchored query, returning the current **and** the 7-day-backdated correlation exactly once
  (`returned=2 queued=2`); the third query returned empty with the anchor still advancing
  (ship-gate 10 / M19). Generations alternated and `commitSeq` stayed monotonic across four
  separate processes. This is a strong prior for **Path A**; it is not a Path A decision, and
  ADR-0004 stays empty until the iPhone.
- **The bootstrap rule (§5.3) held against the ambiguous case.** Repeated catch-ups over an
  unreadable/empty store persisted no anchor and left `bootstrapComplete=false` — the property
  T10 depends on.
- **§10 store: 12/12** against real on-device file protection, including the M17
  previous-generation fallback and the hard `INTERNAL` when both generations are invalid.
- **`CONFIG_CONFLICT`** correctly rejected on a differing tuple; identical-tuple `configure`
  is an idempotent no-op (§6.2, T-L).
- **S2 found** — see the table below.
- Source attribution works against a real vendor source: a Withings app on that iPad is
  depositing BP correlations, and the queue reports counts by `sourceBundleId` (T9's shape).
  Per §4.2 those are real readings on a developer device; every artefact from the run carries
  UUID prefixes, counts and error codes only.

**End-to-end pipeline proven, 26 Aug — against the client's real schema, though not yet their
server.** Apple Health → anchored query → plugin queue → snapshot → drain → PostgREST →
`observation` + `observation_component` → acknowledge → queue empty. Three synthetic readings;
every field round-tripped exactly, including the child sample UUIDs. Replay of the same snapshot
inserted nothing. The acknowledge advanced the snapshot generation (B2) and emptied the queue.

Run against a **local stand-in**, not the client's project: Postgres plus PostgREST carrying the
client's DDL verbatim. Their Supabase is reachable and its RLS is enforced (every table returns
401 through `get_app_user_id`), but nobody on the build team can authenticate against it —
signups need email confirmation, anonymous auth is off, and the lane has no dashboard access.
The RLS policies and the `get_app_user_id` body in the stand-in are **reconstructed**, since the
client's dump is tables only. Two schema defects fell out of the run: **Q6** and **Q7** below.

One code change came with it: `Mapper` now captures the **child quantity sample UUIDs**.
`observation_component.source_uuid` is `NOT NULL`, and the correlation UUID alone cannot satisfy
it — the children were previously read for their values and discarded.

**Next actions.** (1) Pair the loan Omron cuff to this handset and prove the §9.4 chain, without
which criteria (b) and (d) cannot be claimed. (2) Settle D-003 with the engagement lead: either
re-take on a 26.x release handset or amend §3.5 to name the walkthrough OS. (3) Record the
operator observation still owed on SPK-3 — which Blood Pressure controls the sheet displayed.
(4) **C1/C15**, which now blocks P2 and nothing else does.

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
| Q6 | **No uniqueness constraint on `observation`.** The deployed schema carries no unique index beyond the primary key — nothing on `(user_id, source_uuid)`. Proven 26 Aug against a local copy of the real schema: the same `source_uuid` inserted twice was accepted. §8.1 states Layer-1 idempotency *"depends solely on the constraint"*, and the fetch path is deliberately replay-generous **because** that constraint was assumed. Anchor recovery, double wakes, reinstall re-imports, ack-after-timeout retries and the crash-between-RPC-and-ack case are all duplicate generators without it. | Defect → backend | §8.1, `native/spike/drain/drain.py`, Risks & Issues (1 Critical, Ben) | **Open — raised 26 Aug.** Fix is a unique index on `(user_id, source_uuid)` with `on conflict do nothing`; decide at the same time whether it is partial on `deleted_at is null`, which changes re-import behaviour after a deletion and matters to the §8.3 fast-follow. `observation_component.source_uuid` has the same shape. |
| Q7 | **`observation.effective_tz` is `NOT NULL DEFAULT 'Australia/Sydney'`**, so the database stamps a timezone on readings that carry none. Confirmed 26 Aug: three readings with no `HKMetadataKeyTimeZone` all landed as Australia/Sydney without the client sending the field. Contradicts pitfall 14 (*metadata or null, never `TimeZone.current` archaeology*) and the nullable `tzOffsetMinutes` in §7.1, which exists precisely so the UI can drop the "local time of reading" claim. Same defect as C5, one layer lower and less visible. | Defect → backend | §7.1, pitfall 14, C5, Risks & Issues (2 Major, Ben) | **Open — raised 26 Aug.** Make the column nullable and drop the default, or require the ingest path to supply it. Note `effective_offset_minutes` is already nullable, so the two columns currently disagree about whether "unknown" is representable. |
| S1 | Bundle-ID collision: §11 gives the spike reader `dev.lucab.bpspike`, §9.2 gives the Capacitor harness the same ID, while T2 requires a first-run sheet | Risk → settled on device | `docs/adr/ADR-0006-spike-outcome.md` (SPK-extra) | **Closed 26 Aug — no deviation.** SPK-extra on the acceptance iPhone: after deleting and reinstalling `dev.lucab.bpspike`, `statusForAuthorizationRequest` returns `shouldRequest` and the sheet **does** return. HealthKit authorisation does not survive app deletion, so §9.2 may keep giving the harness the same bundle ID and T2 stays executable against it. Measurement note: sampled immediately after reinstall the status returns a stale `unnecessary`; it must be sampled after a short settle. |
| S2 | **Correlation types abort `requestAuthorization` in both sets.** Passing `HKCorrelationType(.bloodPressure)` to `requestAuthorization(toShare:read:)` raises `NSInvalidArgumentException` (*"Authorization to read/share the following types is disallowed"*) and the process aborts on SIGABRT — not a catchable error. Measured on the iPad sidecar (iPadOS 26.6.1, `iPad14,5`, build 23G83) with the same binary run against both sets, so bundle identity and prior permission state are excluded. A correlation still **saves** under quantity-only share authorisation, so §5.1 holds exactly: authorisation attaches to the contained quantity types and the correlation is a grouping, not an authorisable type. This **vindicates §7.4's chosen set** — quantity-only is not merely minimal, it is the only legal set — and **contradicts ship-gate item 1**, which withdrew "correlation type in read set = runtime error" per [R24]. It also reshapes **SPK-3**: the correlation-inclusive arm aborts on call, so the A/B has no second arm (reader C remains the control that proves the abort is the *set*, not the app). Path A is untouched — SPK-1 is anchored *queries* on the correlation type, a different API surface. **CONFIRMED ON THE ACCEPTANCE DEVICE 26 Aug**, and it is broader than first recorded: the abort also fires on `getRequestStatusForAuthorization`, not only `requestAuthorization` — merely *asking about* a set containing the correlation type is enough. Now reproduced on two OS generations and two device classes (iPadOS 26.6.1 on `iPad14,5`; iOS 27.0 on `iPhone17,2`), on clean permission identities, isolated with the same binary run against both sets. Device class, OS generation, bundle identity and prior permission state are all excluded: this is framework behaviour. | Finding → spec contradiction, confirmed on device | `docs/adr/ADR-0006-spike-outcome.md` (SPK-3), `native/spike/README.md`, §7.4, §2.1 ship-gate 1, §11 | **Open — amendment owed, not a deviation.** §7.4 needs **no** change: it chose quantity-only and was right, and this makes it the only legal set rather than merely the minimal one. What needs amending is **§2.1 ship-gate item 1**, whose withdrawal of "correlation type in read set = runtime error" is contradicted, and **§11 SPK-3**, whose two-arm A/B cannot be run because one arm aborts the process. Both at the as-built republish. |
| S3 | **§12 P2 never re-commits an anchor after a §5.3 anchor reset — the engine re-reads the whole history on every wake, permanently.** The commit gate is `if st.bootstrapComplete \|\| !fresh.isEmpty` (§12 P2, guide line 686), where `fresh` is the delta *after* the `recentUuids` filter. Following an anchor reset `bootstrapComplete` is false; the bounded `importStart` re-import returns the full history, but every UUID is already in the ring, so `fresh` is empty, the anchor is never persisted and `bootstrapComplete` never returns to true. Reproduced at SPK-4 steps 4–5 on 26 Aug: two consecutive passes byte-identical at `returned=11 queued=0 anchorCommitted=false`. This is the replay-forever failure **ship-gate 10** exists to prevent, surviving in the one path that ship gate did not walk — recovery. **Proposed fix, one word:** gate on `!delta.readings.isEmpty`, which matches §5.3's own wording (*"a delta containing at least one readable BP correlation"*) and respects §8.1's statement that the recent-UUID ring *"only reduces redundant queueing; correctness depends solely on the constraint"* — gating a correctness property on a convenience cache is the category error. Unlike S2 this is **not** a HealthKit behaviour claim: it is control flow, visible in the output, and reproduces independently of device class, so the sidecar caveat does not apply to the defect itself. | Defect → spec | §12 P2 (guide line 686), §5.3 anchor recovery, §8.1 Layer 1, §2.1 ship-gate 10; evidence in `native/spike/README.md` and `native/spike/spk4.sh` | **Closed 26 Aug — fix applied and verified, logged as D-002 below.** The M12 drill (`native/spike/spk4.sh`) now carries a regression guard asserting `anchorCommitted=true` and `bootstrapComplete=true` at the post-reset re-import. §12 P2 to be amended at the as-built republish. |
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

### D-002 — §12 P2 commit gate: `!fresh.isEmpty` → `!delta.readings.isEmpty`

- **Date:** 26 August 2026
- **Guide section(s) affected:** §12 Phase 2 (the catch-up commit gate, guide line 686).
  Interacts with §5.3 (anchor recovery), §8.1 (Layer 1 idempotency) and §2.1 ship-gate 10.
- **What the guide says:** `if st.bootstrapComplete || !fresh.isEmpty { ... }`, where `fresh`
  is the delta filtered against the persisted `recentUuids` ring. The anchor and
  `bootstrapComplete` are committed only when that filtered set is non-empty.
- **What was done instead:** the gate now reads
  `if st.bootstrapComplete || !delta.readings.isEmpty { ... }` — the delta as returned by the
  anchored query, before the ring filter. The ring still governs what is *enqueued*; it no
  longer governs whether the cursor advances.
- **Why (device evidence, not reasoning):** SPK-4's M12 drill on 26 Aug. After the §5.3
  anchor-only reset, the bounded `importStart` re-import returned the full history, but every
  UUID was already ringed, so `fresh` was empty and the gate never fired. Two consecutive
  passes were byte-identical — `returned=11 queued=0 anchorCommitted=false`,
  `bootstrapComplete` stuck at false. The engine would have re-read the entire history on
  every wake indefinitely: ship-gate 10's replay-forever failure, surviving in the one path
  that ship gate did not walk. After the change, the same drill gives
  `returned=12 queued=0 anchorCommitted=true bootstrapComplete=true` at the re-import and
  `bootstrapMode=false returned=0` on the next pass — recovery converges in one pass and the
  anchor resumes doing the work. SPK-1 re-run end to end twice afterwards, unchanged:
  `returned=2 queued=2` for the current and 7-day-backdated inserts, then `returned=0`.
- **The bootstrap rule is unaffected**, which was the thing to check: when reads are denied or
  the store is empty, `delta.readings` is empty too, so no anchor is persisted and a later
  grant still backfills from `importStart`. That property was separately demonstrated the same
  day when an uninstall/reinstall revoked read access and the subsequent grant backfilled the
  full history (T10).
- **Consistency with the rest of the spec:** §5.3 states the rule as *"no anchor is persisted
  until a delta containing at least one readable BP correlation has been committed"* — a
  property of the delta, not of the ring. §8.1 states the ring *"only reduces redundant
  queueing; correctness depends solely on the constraint"*. Gating a correctness property on a
  convenience cache was the category error; this change removes it.
- **Settled by:** `native/spike/spk4.sh` steps 4–5 (before/after), `native/spike/spk1.sh` full re-run;
  raised as S3 in the table above. Evidence is counts, error codes and UUID prefixes only.
  Recorded on the **iPad sidecar** — but unlike S2 this is control flow rather than a
  HealthKit behaviour claim, so it reproduces independently of device class.
- **Amendment status:** applied in `native/spike/`; §12 P2 pending republish. A regression guard is
  in the M12 drill so a future refactor cannot silently reintroduce it.

### D-003 — §11 spike run on an OS generation the frozen baseline never validated

- **Date:** 26 August 2026
- **Guide section(s) affected:** §3.5 (acceptance OS baseline). Touches §11 (the spike runs on
  the frozen baseline), §14 (the walkthrough runs on it too), and every evidence artefact,
  which §3.5 requires to carry the baseline.
- **What the guide says:** the acceptance OS baseline is frozen at **iOS 26.6 or later**. The
  floor exists because iOS 26.5 shipped a Blood Pressure read-authorisation sheet that rendered
  blank or incomplete, fixed in 26.6 [R23]. SPK-3, the soak and the walkthrough all run on the
  frozen baseline, and results against any other build are void.
- **What was done instead:** the §11 spike was run on **iOS 27.0, build `24A5424a`**, on
  `iPhone17,2`. This satisfies "26.6 or later" *literally* but is a different OS generation from
  the one the baseline was validated against, and the build number's trailing lower-case letter
  is the shape of an Apple seed/beta build rather than a public release. Xcode 26.6 carries only
  the iOS 26.5 SDK, so the iOS 27 SDK was not shipping when this ran.
- **Why:** it is the only iPhone available to the lane. The alternative was not running the
  spike at all, which would have left Path A undecided and P1 unable to start. The lane owner
  was shown the baseline problem before the run and directed that it proceed as the main
  device run-through. That decision is his to make; recording it is not optional.
- **Why this is a deviation and not simply a passing result:** §3.5's purpose is
  *attributability* — every artefact carries the baseline so a later reader can reproduce the
  result on the same OS. A seed build cannot serve that purpose, because Apple supersedes seeds
  and behaviour can change between them. The floor is evidence about 26.x; it carries none about
  27.x. Treating a newer major version as automatically compliant is exactly the folklore the
  three review rounds existed to kill.
- **Containment, so the risk cannot be forgotten:** the spike binaries classify their own host
  and emit an evidence class with every environment block. A run on this device stamps
  **`BASELINE-MISMATCH`** into the block, together with the OS generation check and a flag for
  the seed-build shape. A result from it therefore cannot be pasted into an ADR as a clean 26.x
  baseline result by mistake. ADR-0004 carries that stamp at the top of the document.
- **Residual risk, open and owned above this lane:** **the client walkthrough must run on this
  same handset and this same OS, or the evidence does not transfer.** If the walkthrough will
  run on a 26.x release, or on a different phone, SPK-1 to SPK-close must be re-taken there
  first. That is cheap — the whole sequence is scripted (`native/spike/spk1.sh`, `spk2.sh`, `spk4.sh`,
  `spkclose.sh`) and re-runs verbatim — but it is not free, and it must happen before Stage 2
  evidence is presented.
- **Related gap found in the same run:** the §9.4 Omron chain is **not** proven on this handset.
  The only real vendor source present is `com.withings.wiScaleNG`. The 20 Aug gate recorded the
  chain proven on "the dev iPhone", which was evidently a different device. Stage 2 criteria (b)
  and (d) require the loan Omron cuff paired to *this* phone.
- **Settled by:** `docs/adr/ADR-0006-spike-outcome.md` (evidence-class callout and environment
  table); lane owner's direction, 26 Aug, given after the baseline problem was put to him.
- **Amendment status:** §3.5 **not** amended. Amending it is not this lane's call alone — it
  changes what Corveo is shown at acceptance. The options are (a) re-take the results on a 26.x
  release handset, or (b) amend §3.5 to name the OS the walkthrough will actually run on, as a
  written decision with the engagement lead. Pending that, ADR-0006 stands with its
  BASELINE-MISMATCH stamp and this entry is the record of why.

## Log format

Each entry, once there is one:

```
- **Closure, 2 September 2026 (Nick, integration lane):** the full scripted sequence was
  re-taken on a public 26.x release: **iPhone 17 (`iPhone18,3`), iOS 26.6.1, build `23G83`**,
  paired and in Developer Mode, reader Q (`dev.lucab.bpspike`) and the writer installed beside
  the product build. The binaries stamped every environment block **`EVIDENTIAL`** (generation
  matches baseline: yes; seed shape: no). Outcomes, counts and prefixes only: SPK-1 seed queued
  once, current plus 7-day-backdated pair returned exactly twice with new prefixes, empty delta
  with `anchorCommitted=true`, slots alternating a/b across relaunches. SPK-2 the deleted
  correlation's prefix reported once in the deleted set on the next catch-up, never again.
  SPK-4 `anchorResets=1 anchorResetReason=UNARCHIVE_FAILED`, replay absorbed by the recent-UUID
  ring, converged in foreground. SPK-close bootstrap of ten with one prior deletion reported,
  the new pair handled exactly once, nothing repeats. Logs retained in the integration session
  (`spike-26x/*.log`). The residual risk above is discharged: Stage 2 evidence now exists on the
  frozen baseline, and the walkthrough can run on this handset. ADR-0006 carries the addendum.

### D-00n — <one-line title>
- **Date:** 
- **Guide section(s) affected:** 
- **What the guide says:** 
- **What was done instead:** 
- **Why (device evidence, not reasoning):** 
- **Settled by:** <ADR / test ID / raw output reference>
- **Amendment status:** <guide section amended | pending republish>
```

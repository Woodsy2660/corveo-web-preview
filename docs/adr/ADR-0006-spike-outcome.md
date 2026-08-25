# ADR-0006 — Spike outcome: cursor architecture (Path A or Path B)

- **Status:** ✅ **ACCEPTED — Path A.** Run 26 August 2026 on the physical iPhone.
- **Date:** 26 August 2026
- **Phase:** P0 (§12 Phase 0 — "Run §11 in full; write ADR-0004", same-day)
- **Decider:** Luca (native/mobile lane)
- **Numbering:** guide v1.3 internally labels this ADR-0004; it was written before the tracker's
  0004 and 0005 existed. Tracker numbering wins, so it is **ADR-0006** here and in Notion.

> ## ⚠️ Evidence class: BASELINE-MISMATCH — read this before citing anything below
>
> The run was performed on **iOS 27.0, build `24A5424a`**. §3.5 freezes the acceptance OS at
> "iOS 26.6 or later", which this satisfies *literally* — but the floor exists because of a
> specific iOS 26.5 regression fixed in 26.6 [R23], so it is evidence about the 26.x
> generation and says nothing about 27.x. The build number's trailing lower-case letter is the
> shape of an Apple **seed/beta** build rather than a public release, and Xcode 26.6 carries
> only the iOS 26.5 SDK, so the iOS 27 SDK was not yet shipping when this ran.
>
> **Why it was run anyway:** it is the only iPhone available to the lane. That is a deliberate,
> recorded decision by the lane owner, not an oversight — logged as **deviation D-003**.
>
> **The residual risk is concrete and is not closed by this document.** Evidence taken on a
> seed build is not reproducible once the seed is superseded, which is the whole reason §3.5
> freezes a baseline at all. **The client walkthrough must run on this same handset and this
> same OS, or the evidence does not transfer.** If the walkthrough will run on a 26.x release,
> these results must be re-taken there first.
>
> The spike binaries classify their own host and stamp this classification into every
> environment block they emit, so no result can be quoted as a clean 26.x baseline result by
> mistake.

## Evidential environment

| Field | Value |
|---|---|
| Device model | `iPhone17,2` (iPhone 16 Pro Max) |
| iOS version | `27.0` |
| Exact build number | `24A5424a` |
| Frozen baseline (≥ 26.6) met literally | yes |
| OS generation matches the validated baseline (26.x) | **no — see the callout above** |
| Build has the shape of an Apple seed/beta | **yes** |
| Xcode version | 26.6 (17F113), iOS 26.5 SDK |
| Apple team | personal free (sandbox) team, 7-day profiles |
| Reader Q bundle ID | `dev.lucab.bpspike` (quantity-only auth set) |
| Reader C bundle ID | `dev.lucab.bpspikec` (correlation-inclusive auth set) |
| Writer bundle ID | `dev.lucab.bpwriter` (carries `NSHealthUpdateUsageDescription`; never ships) |
| Omron chain verified on **this** device (§9.4) | **NO — see "Gaps" below** |
| Date of run | 26 August 2026 |

**Evidence discipline (§4.2).** Every cell below carries UUID prefixes, counts, states and
error codes. No reading value appears in this document, in the spike binaries' logs, or in any
artefact produced by the run. The `Log` wrapper's value-carrying overloads are `unavailable`,
so a slip is a compile error rather than a review finding.

**Health data on the device is iCloud-synced across the developer's devices.** Correlations
written by the throwaway writer on the iPad appeared on this iPhone under identical UUIDs and
identical source attribution, and deletions performed there were reported here. So this handset
was never a clean store. The observation is itself useful: **correlation UUIDs are stable
across a user's devices**, which is what Layer 1 idempotency (§8.1) rests on.

## Decision

> - [x] **Path A** — correlation-anchored cursor, as specified in §5.2. One persisted
>   `HKQueryAnchor` over `HKCorrelationType(.bloodPressure)`, predicated `startDate ≥ importStart`.
> - [ ] **Path B** — anchors on the two quantity types used purely as change signals.

**Path B is not required.** Correlation-anchored queries behave exactly as §5.2 assumes:
they resume from a persisted anchor across a real process termination, they return backdated
inserts that a timestamp watermark would miss, and they do not repeat committed rows.
Everything in guide v1.3 that depends on the cursor stands unchanged.

## Results against §11

### SPK-1 — Correlation-anchored inserts with a real resumable cursor

*Method as specified: configure-equivalent state with a real `importStart`; nil-anchor query
with the production predicate; commit the anchor into the actual `Envelope`/`EngineState` JSON;
terminate the process; writer saves one current and one 7-day-backdated correlation; relaunch;
strict-load; resume.* Each step ran as a separate process launch, so the termination between
commit and resume is structural rather than remembered.

| Observation | Result |
|---|---|
| Current insert returned | **yes** — correlation UUID prefix `31D50E5D` |
| 7-day-backdated insert returned | **yes** — correlation UUID prefix `64085354` |
| Each returned **exactly once** | **yes** — `returned=2 queued=2`, no repeats |
| Third query empty | **yes** — `returned=0 queued=0`, and `anchorCommitted=true` on the empty delta (ship-gate 10 / M19) |
| Anchor survived the real persistence path | **yes** — `load=ok:state.b.json` then `ok:state.a.json`, generations alternating, `commitSeq` monotonic across four separate processes |
| Raw output | `catchUp=ok bootstrapMode=false returned=2 queued=2 malformed=0 deletedReported=0 anchorCommitted=true deferred=false` |

**Verdict: PASS → Path A.**

### SPK-2 — Correlation-anchored deletions (characterisation ONLY)

*Standing order: deletions are out of V1 by decision (§8.3). No tombstone persistence, no
dormant contract. Recorded for the reconciliation fast-follow and nothing else.*

| Observation | Result |
|---|---|
| Deleted set carries the **correlation** UUID | **yes** — `deletedUuid=B57B6FB8` matched the correlation queued moments earlier, exactly |
| Deleted set carries child quantity UUIDs instead | **no** |
| Deletion repeated after the next commit | **no** |
| Queue behaviour | `pending` unchanged across the deletion — V1 correctly ignores it |

**Implication for the §8.3 reconciliation fast-follow.** The fast-follow can compare
correlation UUIDs directly against the backend's `source_kind='healthkit'` UUIDs. No
child-to-correlation mapping is needed, which is precisely the trap review round one
identified and the reason deletion capture was descoped rather than half-built. The deletion
signal is also non-repeating once the anchor advances past it, so a reconciliation pass does
not have to de-duplicate its own inputs.

### SPK-3 — Authorisation-set behaviour on the acceptance OS

*Two clean permission identities on the same device: both readers were fresh installs and
neither had ever been authorised on this handset.*

| | Reader **Q** (`dev.lucab.bpspike`, quantity-only) | Reader **C** (`dev.lucab.bpspikec`, correlation-inclusive) |
|---|---|---|
| `statusForAuthorizationRequest` **before** | `shouldRequest` | **process aborted** — see below |
| Sheet appeared | yes, and was actionable | never reached |
| Which Blood Pressure controls the sheet showed | *operator observation still owed — the sheet was presented and Allow was tapped, but the specific controls were not recorded* | n/a |
| `statusForAuthorizationRequest` **after** | `unnecessary` | n/a |
| Correlation query result | 18 correlations returned, `malformed=0` | n/a |
| Systolic observer registration | ok | n/a |
| Diastolic observer registration | ok | n/a |
| Background delivery arming | `startObserving=ok` for both quantity types | n/a |
| Error codes | none | `NSInvalidArgumentException`, SIGABRT |

**The A/B has no second arm, and that is the finding.** Reader C does not fail to authorise —
it **terminates the process**:

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
    reason: 'Authorization to read the following types is disallowed:
             HKCorrelationTypeIdentifierBloodPressure'
```

**It aborts on `getRequestStatusForAuthorization`, not only on `requestAuthorization`** —
merely *asking about* a set containing the correlation type is enough. The same exception is
raised for a **share** set, with "share" substituted for "read". A correlation **can** still be
saved under quantity-only share authorisation, so §5.1 holds exactly as written: authorisation
attaches to the contained quantity types and the correlation is a grouping, not an authorisable
type.

**Verdict: the chosen minimal quantity-only set authorises correlation reads and observer
registration cleanly — and it is the only legal set, not merely the minimal one.**
`BPTypes.authorizationRead` (§7.4) requires **no amendment**; it was right. What is wrong is
**ship-gate item 1**, which withdrew "correlation type in read set = runtime error" on the
strength of [R24]. On this evidence the withdrawal was incorrect and §2.1 needs amending, along
with §11's SPK-3 method, which assumes an A/B that cannot be run.

Reproduced on two OS generations and two device classes (iPadOS 26.6.1 on `iPad14,5`, iOS 27.0
on `iPhone17,2`) and isolated with the same binary run against both sets, so bundle identity,
prior permission state, device class and OS generation are all excluded as explanations. This
is framework behaviour. Recorded as **S2** in `docs/native/deviations.md`.

### SPK-4 — State store & anchor survival including corruption

| Step | Expected (§10, §5.3) | Result |
|---|---|---|
| Two-generation store written, terminate → relaunch → strict-load → resume | Anchored query resumes | **PASS** — resumed across every process boundary; generations alternated; `commitSeq` strictly monotonic |
| Inject corrupt `anchorData` | **Anchor-only** reset: `anchorData` + `bootstrapComplete` cleared; queue, config, observation state, diagnostics **preserved**; reason code recorded | **PASS** — `anchorResets=1`, `anchorResetReason=UNARCHIVE_FAILED`, `anchorPersisted=false`, `bootstrapComplete=false`, and `pending=22` / `recentUuids=22` / source counts / config all unchanged |
| Post-reset re-import | Bounded `importStart` re-import runs in foreground and converges | **PASS** — `returned=21 queued=0 anchorCommitted=true bootstrapComplete=true`, then `bootstrapMode=false returned=0` on the next pass. **This is the D-002 regression guard**; the unfixed gate gave `anchorCommitted=false` and never converged |
| Corrupt the **newest** generation file | Falls back to the previous valid generation (M17); diagnostic logged | **PASS** — `m17FallsBackToPreviousGeneration (before=4 after=3)`, fallback diagnostic recorded |
| Corrupt **both** generations | Hard `INTERNAL`, never silent re-init | **PASS** — `bothInvalidRaisesInternal (INTERNAL)` |
| Directory backup exclusion re-asserted after commit [R26] | Set and verified | **PASS** |

**Raw output:** `-spikeStoreSelfTest` on the acceptance device — **12 passed, 0 failed**, against
real on-device file protection.

**Verdict: the §10 loader and the §5.3 recovery behave as specified.** With one correction
found in the process — see D-002 below.

### SPK-close — End-to-end mini-loop

| Observation | Result |
|---|---|
| Exact correlation UUIDs matched | **yes** — surviving insert `C6F905F5` returned exactly once |
| No repeats after commit | **yes** — following pass `returned=0 queued=0 deletedReported=0` |
| Deletion characterised | **yes** — `deletedUuid=6AD34EFA`, reported by correlation UUID |

### SPK-extra — Bundle-ID authorisation-persistence check

| Step | Result |
|---|---|
| Delete `dev.lucab.bpspike` from the device | done; app container wiped (`state=unconfigured`, `commitSeq=0`, `load=fresh`) |
| Reinstall, call `statusForAuthorizationRequest` | `shouldRequest` |
| Call `requestAuthorization` — does the sheet return? | **YES** |

**HealthKit authorisation does NOT survive app deletion.** §9.2 may keep giving the Capacitor
harness the same bundle ID as the spike reader, and T2's "sheet exactly once on a fresh install"
remains executable against it. **No deviation against §9.2.** Closes **S1**.

*Measurement note, recorded because it produced a wrong answer first.* Sampled immediately
after reinstall, `getRequestStatusForAuthorization` returns a stale `unnecessary`; sampled again
after a short settle it correctly returns `shouldRequest`. Anyone writing the T2 or T10 steps
must not sample it straight after install.

### T14 — Arming failure surfaced (run alongside, §14)

Built once **without** `com.apple.developer.healthkit.background-delivery`, verified absent in
the signed archive. `startObserving` failed `BG_DELIVERY_FAILED/HK:4/authorizationDenied`,
state went to `armFailed`, and foreground catch-up continued to work per §6.2. Run on the iPad
sidecar; not re-run on this handset.

### T10 — Denial and bootstrap backfill (demonstrated, unplanned)

The SPK-extra uninstall/reinstall revoked read access. Successive catch-ups returned zero and
persisted **no anchor**, leaving `bootstrapComplete=false` — the bootstrap rule (§5.3) holding
against the ambiguous case, which is the property that stops a denied-state fetch burying the
patient's history. After the grant, the full history backfilled from `importStart` and the row
count reconciled exactly against the live correlations. That is the T10 sequence, against a real
revocation rather than a simulated one.

## Gaps — what this run does NOT evidence

1. **The Omron chain is unproven on this handset.** The only real vendor source present is
   `com.withings.wiScaleNG` (4 correlations). The 20 Aug gate recorded the §9.4 Omron chain
   proven on "the dev iPhone"; that was evidently a different device. **Stage 2 criteria (b)
   and (d) require the loan Omron cuff paired to this phone**, and T4/T9/T16 cannot be claimed
   until it is.
2. **The 26.5 sheet-regression check [R23] is not fully recorded.** The sheet was presented and
   was actionable, but which Blood Pressure controls it displayed was not captured. Operator
   observation still owed.
3. **Background delivery was observed but not measured.** The queue populated between scripted
   steps without invocation, which implies iOS woke the app. Consistent with arming having
   succeeded, but the mechanics are the 48-hour soak's subject (T6), not this spike's.
4. **The OS baseline**, per the callout at the top of this document.

## Deviations arising from this spike

- **D-002** — §12 P2's commit gate never re-committed an anchor after a §5.3 anchor reset.
  Found on the sidecar, fixed, and **confirmed fixed on this device** at SPK-4 step 4. Logged
  in `docs/native/deviations.md`.
- **D-003** — this run was performed on an OS generation the frozen baseline never validated.
  Logged in `docs/native/deviations.md`.
- **S2** — correlation types are disallowed in either authorisation set; ship-gate item 1's
  withdrawal is contradicted. Now confirmed on the acceptance device; §7.4 needs no change,
  §2.1 ship-gate 1 and §11 SPK-3 do. Logged in `docs/native/deviations.md`.
- **S1** — closed by SPK-extra above. No deviation.

## References

[R16] `HKAnchoredObjectQuery` — sample types incl. correlations; predicate filters samples and
deleted objects. [R19] `HKDeletedObject.uuid`. [R23] iOS 26.5 Blood Pressure
authorisation-sheet regression, fixed in 26.6. [R24] `requestAuthorization(toShare:read:)` —
**contradicted by S2 for correlation types**. [R26] `isExcludedFromBackup` is a filesystem
resource value.

# §11 spike — three bare SwiftUI targets

Built to run [`../../docs/native/spike-run-sheet.md`](../../docs/native/spike-run-sheet.md) against guide §11.
No Capacitor, no package manager, no dependencies. Results go into
[`../../docs/adr/ADR-0006-spike-outcome.md`](../../docs/adr/ADR-0006-spike-outcome.md).

**Nothing here has run on a device yet.** What is proven is stated under *Verified so far*;
everything else is code awaiting the iPhone. No SPK verdict is written anywhere.

| Target | Bundle ID | Auth read set | `NSHealthUpdateUsageDescription` |
|---|---|---|---|
| Reader **Q** | `dev.lucab.bpspike` | quantity-only (§7.4 verbatim) | **absent** — verified in the built plist |
| Reader **C** | `dev.lucab.bpspikec` | correlation-inclusive | **absent** — verified in the built plist |
| **Writer** | `dev.lucab.bpwriter` | writes synthetic samples | **present** — the only target that carries it |

Free-team ceiling is 3 installed dev apps per device. This is exactly 3, no headroom.

## Build

`xcode-select` on this Mac points at the Command Line Tools, so every invocation needs
`DEVELOPER_DIR` until that is switched (see *Blockers*).

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project spike/BPSpikeQ.xcodeproj -scheme BPSpikeQ -destination generic/platform=iOS build
```

Two launch arguments print to the console instead of starting the UI, so both can be taken
over the cable: `-spikeEnvReport` (ADR-0004 environment block, evidence-class stamped) and
`-spikeStoreSelfTest` (the §10 checks).

Open in the IDE with `open spike/BPSpikeQ.xcodeproj`. Each project uses Xcode 16+
file-system-synchronized groups, so sources are picked up by directory — adding a file needs
no project edit, and there is no per-file bookkeeping to drift.

## Layout

| Path | What |
|---|---|
| `Shared/` | Compiled into **both readers**. `BPTypes` (§7.4 verbatim), `EngineState`/`Envelope` (§10), `StateStore`, `Mapper` (§12 P1), `SpikeEngine`, `Log`, the SwiftUI readout. |
| `ReaderQ/`, `ReaderC/` | One `@main` App each. The only difference is the `SPIKE_READER_C` compilation condition. |
| `Writer/` | Its own sources, deliberately sharing nothing with the readers. |
| `Entitlements/` | Outside the synchronized groups so they are never treated as bundle resources. |
| `Signing.xcconfig` | Team ID and the reader entitlements path, in one place for all three projects. |

`TARGETED_DEVICE_FAMILY` is `1,2` so the spike installs on the iPad as well as the iPhone.
This is a spike-target build setting only — the spike ships nothing, and §18 already lists
iPad exploration as optional scope.

`BPTypes.authorizationRead` is §7.4 **verbatim and unconditional**. The SPK-3 A/B lives in
`SpikeAuthSet`, which is spike-only code — so if SPK-3 shows the quantity-only set
under-authorises, §7.4 is amended in one place and the amendment is visible as an amendment.

## Code → run sheet

| Run sheet | Where |
|---|---|
| Step 0 · environment | Reader *Step 0* section. **Reads the exact iOS build number and the device model identifier off the device** and copies ADR-0004's environment table to the clipboard — the two fields the run sheet still lists as outstanding, without hand transcription. |
| SPK-1 · resumable anchor | `SpikeEngine.runCatchUp` (production predicate `startDate ≥ importStart`, `.strictStartDate`), anchor archived with secure coding into the real `Envelope`/`EngineState` JSON. *TERMINATE PROCESS* calls `exit(0)` — a real process termination, not a debugger stop. |
| SPK-2 · deletions | Deleted objects are surfaced as counts and UUID prefixes and **not persisted**. No tombstone, no dormant contract, the anchor advances past them (§8.3). |
| SPK-3 · auth sets | *SPK-3* section: `getRequestStatusForAuthorization` before/after, `requestAuthorization`, both quantity observer registrations, error codes. Run once per reader. |
| SPK-4 · store & anchor | *SPK-4* section: corrupt `anchorData`, nil-anchor probe → anchor-only reset, corrupt newest generation, corrupt both. |
| SPK-close | Same buttons in the §11 order. |
| SPK-extra | Delete `dev.lucab.bpspike`, reinstall, read *statusForAuthorizationRequest*, then *requestAuthorization*. |

## Verified so far (not spike evidence)

Everything below is a **pre-device check**, run in the simulator on the iOS 26.5 SDK. It
carries no SPK verdict and none of it appears in ADR-0004. Pitfall 1 stands: the simulator
lies about vendor apps, sources and background delivery.

- All three targets build clean — zero Swift warnings.
- Built `Info.plist` posture: both readers carry `NSHealthShareUsageDescription` and
  **lack** `NSHealthUpdateUsageDescription`; only the writer carries it. Bundle IDs are the
  three throwaway identities and nothing else.
- The §4.2 log guard is a **compile error**, not a convention. Adding a file that calls
  `Log.event(_:reading:)` fails the build with the guide citation in the message; the file
  was removed after the check.
- The evidence-class guard itself: an iPhone simulator and an iPad simulator both produce a
  block stamped `SIDECAR — DO NOT RECORD IN ADR-0004`, and the simulated model identifier is
  reported correctly rather than as the host architecture.
- §10 store, 12/12 checks (`-spikeStoreSelfTest` launch argument, `StoreSelfTest.swift`),
  passing on both the iPhone and iPad idioms:
  fresh-load-empty, monotonic `commitSeq`, alternating generations, checksum reproducible
  across a decode/re-encode round trip, queue and `anchorData` survival, `itemId` assigned
  once, diagnostics counts-only, **M17** fallback to the previous valid generation with the
  diagnostic recorded, both-generations-invalid raising hard `INTERNAL`, and directory backup
  exclusion. This one is legitimate off-device: the store is pure Foundation + CryptoKit and
  has no device-dependent behaviour. SPK-4 still runs on the frozen OS against the app's own
  container.

## Hosts, and what a run on each is worth

§9.4: *"Physical iPhone for everything evidential; iPad is a sidecar at most."* §3.5 freezes
the acceptance OS. Pitfall 1: the simulator lies. The app classifies its own host and stamps
the classification into the ADR-0004 block it produces, so a block from a host that was never
entitled to produce one carries its own disqualification in the first line.

| Host | Class | What it can settle |
|---|---|---|
| Dev iPhone, iOS 26.6+ | `EVIDENTIAL` | Everything. The only host whose results enter ADR-0004. |
| Dev iPhone below 26.6 | `VOID` | Nothing — §3.5. |
| iPad (`iPad14,5`, iPadOS 26.6.1) | `SIDECAR` | Development testing. See below. |
| Simulator | `SIDECAR` | Pure-Foundation checks only (the §10 store). |

**What the iPad is genuinely good for.** Path A vs Path B is a question about *HealthKit
framework* behaviour — whether a correlation-anchored query resumes across a real
terminate/relaunch. If that is broken, it is very likely broken on iPadOS 26.6.1 too. So the
iPad cannot *decide* Path A, but it can tell us early and cheaply that the code is wrong, and
it exercises the §10 store against real on-device data protection rather than the simulator's
approximation. Run it, learn from it, record nothing from it.

**What it cannot do, at all.** SPK-3 — the two-bundle authorisation A/B turns on the [R23]
Blood Pressure sheet behaviour on the acceptance device. The Omron chain — the vendor app is
iPhone-only, so T4/T9/T16 and criterion (b) are untouchable here. Background delivery
behaviour — unknown on iPad and settled by the soak on the iPhone regardless.

**iPad run order for SPK-1.** On the iPhone the Omron readings already in Health bootstrap the
anchor. This iPad has no BP data, so the writer has to seed it:

1. Writer → *Save one NOW*.
2. Reader Q → `configure()` → `requestAuthorization()` → `startObserving()` → `runCatchUp()`.
   The anchor commits only now, because the bootstrap rule persists none until a delta
   containing a readable reading lands (§5.3).
3. Reader Q → *TERMINATE PROCESS*.
4. Writer → *Save one NOW* and *Save one BACKDATED 7 d*.
5. Relaunch Reader Q → `runCatchUp()`. Both should return exactly once.
6. `runCatchUp()` again → empty.

## Blockers to running on a device

1. **`xcode-select` points at `/Library/Developer/CommandLineTools`.** Xcode 26.6 (17F113) is
   installed and works via `DEVELOPER_DIR`. The permanent fix needs your password:
   `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
2. ~~Developer Mode on the iPad~~ — **done, 26 Aug.** `developerModeStatus: enabled`, DDI
   services available, and the device now resolves as a clean build destination.
3. ~~No development team is selected.~~ — **done, 26 Aug.** Set your own team ID once in
   [`Signing.xcconfig`](Signing.xcconfig) and all three projects inherit it. The certificate exists and **background delivery provisioned on the
   free team** — no T14 detour needed. Free-team profiles expire in 7 days: rebuild the
   morning of any demo (pitfall 12).
4. **The developer profile is not trusted on the iPad yet.** Install succeeds; launch fails
   with *"its profile has not been explicitly trusted by the user"*. On the device:
   Settings → General → VPN & Device Management → Developer App → trust
   the `Apple Development: …` profile for your team. Once per certificate, not per app.
5. **Superseded:** An Apple ID is now registered in Xcode, but no team
   has been resolved, and `xcodebuild` will not infer one — it fails with *"Signing for
   BPSpikeQ requires a development team"* even under `-allowProvisioningUpdates`. Put the
   10-character Team ID on the `DEVELOPMENT_TEAM` line of
   [`Signing.xcconfig`](Signing.xcconfig) and all three projects pick it up; the signing
   certificate itself does **not** need to pre-exist, `-allowProvisioningUpdates` mints it on
   the first device build.
4. **No iPhone is paired.** The acceptance device is still absent, so no evidential run is
   possible yet regardless of the above.

Free-team limits apply once the iPad is registered: 3 devices per platform, 3 installed dev
apps per device, 7-day profiles (§4.3). Three spike apps on the iPad is exactly the per-device
ceiling, and it does not consume the iPhone's own three.

Also note the installed iOS SDK is **26.5**, while the frozen acceptance OS is 26.6+. Building
against an older SDK and deploying to a newer OS is normal, but Xcode 26.6 may want a device
support package the first time a 26.6 handset is attached.

## FIXED (D-002) · §12 P2 never re-committed an anchor after an anchor reset

Found by SPK-4 on 26 Aug. **Not a HealthKit behaviour claim** — pure control flow, visible in
the output, so unlike S2 it does not depend on device class.

```swift
let fresh = delta.readings.filter { !st.recentUuids.contains($0.hkUuid) }
if st.bootstrapComplete || !fresh.isEmpty {     // guide §12 P2, line 686 — verbatim
```

After a §5.3 anchor reset, `bootstrapComplete` is false. The re-import returns the full
`importStart` history, but every UUID is already in `recentUuids`, so `fresh` is empty and the
anchor is **never persisted**. The engine stays in bootstrap permanently and re-reads the
whole history on every wake. SPK-4 steps 4 and 5 are byte-identical:
`returned=11 queued=0 anchorCommitted=false`.

This is the replay-forever failure that ship-gate 10 exists to prevent, surviving in the one
path the ship gate did not walk — recovery.

**Proposed fix, one word:**

```swift
if st.bootstrapComplete || !delta.readings.isEmpty {
```

It matches §5.3's own wording — *"a delta containing at least one readable BP correlation"* —
and §8.1 is explicit that the recent-UUID ring "only reduces redundant queueing; correctness
depends solely on the constraint". Gating a correctness property on a convenience cache is the
category error.

**Applied 26 Aug as D-002** (`docs/native/deviations.md`), on the lane owner's decision. Verified by
re-running the drill that exposed it:

| | before | after |
|---|---|---|
| step 4 | `returned=11 queued=0 anchorCommitted=false` | `returned=12 queued=0 anchorCommitted=true` |
| step 5 | byte-identical to step 4 — stuck in bootstrap | `bootstrapMode=false returned=0` — converged |

`queued=0` and `pending` unchanged throughout, so the ring still does its de-dup job; it just
no longer decides whether the cursor advances. SPK-1 re-run end to end twice afterwards,
unchanged. The bootstrap rule is intact — with reads denied, `delta.readings` is empty too, so
no anchor persists and a later grant still backfills (demonstrated the same day as T10).
`spike/spk4.sh` now carries a regression guard so a refactor cannot silently reintroduce it.

## Finding · correlation types are disallowed in an authorisation set

Measured on the iPad, 26 Aug, iPadOS 26.6.1 (`iPad14,5`, build 23G83). **SIDECAR — this needs
re-running on the acceptance iPhone before it amends anything in `docs/`.**

Passing `HKCorrelationType(.bloodPressure)` to `requestAuthorization(toShare:read:)` raises
`NSInvalidArgumentException` and the process aborts on SIGABRT. It is **not** a catchable
error. Both sets are affected, with distinct messages:

```
read set:  'Authorization to read the following types is disallowed:
            HKCorrelationTypeIdentifierBloodPressure'
share set: 'Authorization to share the following types is disallowed:
            HKCorrelationTypeIdentifierBloodPressure'
```

Isolated with the same binary run twice, so bundle identity and prior permission state are
not explanations:

| Run | Bundle | Set | Result |
|---|---|---|---|
| A | `bpspikec` | read `[sys, dia, corr]` | abort |
| B | `bpspikec` | read `[sys, dia]` | returned |
| C | `bpwriter` | share `[sys, dia, corr]`, read `[sys, dia, corr]` | abort |
| D | `bpwriter` | share `[sys, dia, corr]`, read `[sys, dia]` | abort |
| E | `bpwriter` | share `[sys, dia]`, read `[sys, dia]` | returned |

And the question that follows: **a correlation still saves under quantity-only share
authorisation** (E, then `saveNow=ok`). So §5.1 is exactly right — *"authorisation attaches
to the contained quantity types"* — and the correlation is a grouping, not an authorisable
type.

**What this touches in the guide.** Not §7.4's chosen set, which is vindicated: quantity-only
is not merely the minimal legal set, it is the **only** legal one. What it contradicts is
**ship-gate item 1**, which *withdrew* "correlation type in read set = runtime error" and
recorded correlation types as legal in read sets per [R24]. On this evidence the withdrawal
was wrong.

**What it does to SPK-3.** SPK-3 is specified as an A/B between reader Q (quantity-only) and
reader C (correlation-inclusive). If the correlation-inclusive set aborts on call, the A/B has
no second arm — SPK-3's question is answered, but not in the shape §11 anticipated. Reader C
still earns its bundle: it is the control that proves the abort is the *set* and not the app.

**Not touched:** Path A. SPK-1 is about anchored *queries* on the correlation type, a
different API surface from authorisation — and those work (below).

## ACCEPTANCE-DEVICE RUN, 26 Aug — Path A accepted

Full record in [`../../docs/adr/ADR-0006-spike-outcome.md`](../../docs/adr/ADR-0006-spike-outcome.md).
Device `iPhone17,2`, **iOS 27.0 build `24A5424a`** — which is a different OS generation from the
validated 26.x baseline, so every artefact is stamped `BASELINE-MISMATCH` and the caveat is
logged as **D-003**. It is the only iPhone available to the lane and the run proceeded on the
lane owner's direction.

- **SPK-1 PASS → Path A.** `returned=2 queued=2`, current and 7-day-backdated correlations each
  exactly once, third query empty, anchor survived a real terminate/relaunch.
- **SPK-2** confirmed: the deleted set carries the correlation UUID.
- **SPK-3**: reader Q authorises cleanly and reads; reader C **aborts**. The A/B has no second
  arm, and that is the finding. S2 confirmed on a second OS generation, and **broader than first
  recorded** — it aborts on `getRequestStatusForAuthorization`, not only `requestAuthorization`.
- **SPK-4** PASS including the **D-002 regression guard** on the device; store 12/12.
- **SPK-close** PASS. **SPK-extra** closes S1 — the sheet returns, no deviation against §9.2.
- **T10** demonstrated end to end against a real revocation.

Two gaps this run does not close: the **Omron chain is unproven on this handset** (only a
Withings source is present), and the SPK-3 operator observation of the sheet's controls.

Also worth knowing: **Health data is iCloud-synced across the developer's devices** — the
iPad's writer correlations appeared here under identical UUIDs and source attribution. Useful,
because it confirms correlation UUIDs are stable across devices, which is what §8.1's Layer 1
idempotency rests on.

## Sidecar results, 26 Aug

None of this is spike evidence (§9.4). Recorded so the acceptance-device run is a re-run
rather than a first attempt.

| Step | Result |
|---|---|
| **SPK-1** | Mechanism passes. Nil-anchor bootstrap commits; fresh process strict-loads and resumes; current **and** 7-day-backdated correlations returned exactly once (`returned=2 queued=2`); third query empty with the anchor still advancing (M19). Strong prior for Path A; **not** a Path A decision. |
| **SPK-2** | **The deleted set carries the CORRELATION UUID.** `deletedUuid` matched the queued correlation exactly — no child→correlation mapping, which is the trap round one identified. Deletion did not repeat after commit. `pending` never dropped: V1 ignores deletions (§8.3). This is the input the reconciliation fast-follow needs. |
| **SPK-4** | Anchor-only reset correct: `anchorResets=1`, `anchorResetReason=UNARCHIVE_FAILED`, anchor and `bootstrapComplete` cleared, and config, queue, `recentUuids` and source counts all preserved. M17 and both-generations-invalid covered by the 12/12 store self-test. Then the §12 P2 defect above. |
| **SPK-close** | Pass. Surviving insert returned exactly once, deletion reported by correlation UUID, next pass `returned=0 queued=0 deletedReported=0`. |
| **SPK-extra** | **The sheet DOES return after uninstall/reinstall.** So §9.2's shared bundle ID is fine and T2 is executable — no deviation. *Measurement note:* read immediately after reinstall, `getRequestStatusForAuthorization` returns a stale `unnecessary`; moments later it reads `shouldRequest` and the sheet appears. Do not sample it straight after install. |
| **T14** | Pass. Signed archive lacks the entitlement; `startObserving` fails `BG_DELIVERY_FAILED/HK:4/authorizationDenied`; state `armFailed`; foreground catch-up unaffected (§6.2). |
| **T10** | Demonstrated end to end, unplanned. The reinstall revoked read access; catch-ups returned 0 and persisted **no anchor**; after granting, the full history backfilled from `importStart` — 12 rows, `4` Withings + `8` writer, exactly the live correlations once the two deleted ones are excluded. |

## Watch this one: Xcode re-adds Clinical Health Records

Selecting a team in the Signing & Capabilities editor made Xcode tick **Clinical Health
Records** and write this into `Entitlements/BPSpikeQ.entitlements`:

```xml
<key>com.apple.developer.healthkit.access</key>
<array><string>health-records</string></array>
```

It was removed. §9.3 specifies the HealthKit capability and the background-delivery
entitlement and nothing else; we read blood-pressure quantity samples, never clinical
records; and it is a materially wider data surface than this lane is contracted for (§1.1,
no feature additions outside the sixteen deliverables). It also wants
`NSHealthClinicalHealthRecordsShareUsageDescription`, which nothing sets.

**It will come back if anyone touches the HealthKit capability in that editor again.** The
check that catches it is the signed archive, not the project settings (§17.4 step 2):

```bash
codesign -d --entitlements :- "${TMPDIR}/bpspike-derived/Build/Products/Debug-iphoneos/BPSpikeQ.app"
```

Verified clean after signing on 26 Aug: both readers carry `healthkit` +
`healthkit.background-delivery` and no `healthkit.access`; the writer carries `healthkit`
alone and is the only bundle with `NSHealthUpdateUsageDescription`.

## Decisions taken, and what I want you to look at

None of these change the guide. Listed because they are choices I made in its gaps.

1. **`importStart` default is 30 days back, and it is a stepper.** SPK-1 asks the writer for a
   7-day-backdated correlation; if `importStart` were "now", the production predicate would
   exclude that insert and SPK-1 would fail for a reason that has nothing to do with anchors.
   The run sheet does not call this out. The reader screen states the constraint above the
   control.
2. **Checksum scope.** §10 says "sha256 of the encoded state payload". Implemented as the
   digest of a canonical encoding (sorted keys, fixed millisecond ISO-8601 dates, base64
   data), verified on load by re-encoding the decoded state. Determinism is proven, not
   assumed — check 4 of the self-test exists for exactly this.
3. **Swift 5 language mode**, not Swift 6 strict concurrency. The guide's own engine sketch is
   `DispatchQueue`-based and this is a throwaway spike; the product plugin should revisit that
   choice rather than inherit it.
4. **Synthetic magnitudes live as two named constants in the writer.** §4.2 expressly permits
   writer-generated synthetic values as the substitute for real ones; your handoff phrases the
   same rule as "no values in … fixtures". I read the prohibition as aimed at real readings —
   a synthetic writer cannot write nothing — but it is your call and it is a two-line change.
   They are never rendered on screen and never reach a log line.
5. **The writer shares no code with the readers.** Slightly more duplication (its own `Log`,
   its own type constants), and in exchange "the readers contain no write path" stays a
   structural fact rather than a claim about discipline.
6. **T5a delayed save is a picker (10–90 s), not a fixed 60 s.** `beginBackgroundTask` grants
   a window at iOS's discretion, and how long is an on-device fact. The log records whether
   the write fired or the assertion expired instead of assuming 60 s survives.
7. **The observer completion handler** runs in a `Task { defer { systemDone() } … }` rather
   than the guide's `work.async { defer … }`. Same guarantee — exactly once, every path
   [R4] — and it avoids a re-entrant `sync` onto the executor that the literal sketch would
   deadlock on. Flagging it because §12 P2 shows the other shape.
8. **Whether the writer needs read authorisation to delete its own rows** is left as an
   on-device question. `deleteObjects(of:predicate:)` can only remove objects the calling app
   owns, so the writer requests read access and the answer gets recorded rather than guessed.

9. **The spike's stand-in `enrolmentRef` lives in `UserDefaults`.** §10's "never
   `UserDefaults`" rule is about *health payloads*, and this is a synthetic opaque UUID with
   no health content — kept outside the store deliberately, so it stays stable across the
   SPK-4 store-destruction drills. In the product this value arrives from the authenticated
   session and is never minted on the handset.

## Not done here

- Nothing is committed to `docs/`. ADR-0004 and `deviations.md` stay untouched until there
  are device results to put in them.
- No Capacitor harness, no plugin package. §11 is explicitly bare SwiftUI; §9.2 is P1.
- No range check, no threshold, no classification, no colour band, no derived field — in the
  engine, the writer, or either debug screen. The only comparison against a number anywhere is
  `SpikeEnvironment.meetsFrozenBaseline`, which tests the **OS build**, per §3.5.

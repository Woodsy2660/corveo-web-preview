# 07 — Native Swift rebuild

| | |
|---|---|
| **Status** | Phase 1 delivered; Phase 3 (backend wiring) built and verified live on device; Stage 2 evidence re-taken on the 26.x baseline; Stage 3 features built, all 2 September 2026. Supersedes the Capacitor-shell assumptions in `06-native-app-build-plan.md` wherever the two differ; the decisions, backend contract, test map and asks in 06 still stand. |
| **Owner** | Nick (integration), with Luca (native), Michael (front end), Ben (platform) |
| **Direction** | Rebuild the React front end as a native SwiftUI app. No Capacitor, no WebView, no JavaScript bridge. The HealthKit engine proven by the spike becomes the app's own module and the app calls it directly. |

## 1. The decision, and the contract note

The reviewed web preview stays the design reference; the shipped product is SwiftUI. Reasons: one language across the engine and the UI, no bridge contract to freeze (C1/C20 dissolve), no WebView storage surface for health values (the 1 Critical iCloud risk becomes moot), native accessibility and Dynamic Type for free, and a codebase one iOS engineer can maintain.

**Contract.** SOW A.3 deliverable 1 and Stage 1 criterion (a) describe "a Capacitor shell around a React front end". A pure Swift app exceeds that technically but changes the described medium, and the tracker's ADR-0001 records the Capacitor decision as locked. Ben should paper this with Corveo as a variation under A.10 before the Stage 1 acceptance notice. Nothing else in the SOW changes: the sixteen deliverables, the bright line, Model B, and the four Stages are unaffected.

## 2. Project layout

```
ios/
├── BPReset.xcodeproj              one app target, file-system-synchronised group
├── Signing.xcconfig               DEVELOPMENT_TEAM (sandbox team only)
├── Entitlements/BPReset.entitlements   healthkit + healthkit.background-delivery, nothing else
└── BPReset/
    ├── App/                       BPResetApp (App, AppDelegate, AppState, Router, RootView),
    │                              AppModel (in-memory record), PrivacyInfo.xcprivacy
    ├── Design/                    Tokens (colour, spacing, radii, type scale, Dynamic Type),
    │                              Components (button, card, chip, field, segmented, dots,
    │                              screen scaffold, floating tab bar, option/check rows)
    ├── Copy/                      every user-facing string (Copy.swift), placeholder content
    ├── Data/                      Models (view rows, ingest payload, bounds, formatting),
    │                              API (CorveoAPI protocol, MockAPI, payload builders),
    │                              Fixtures (deterministic synthetic readings), Programs
    ├── Engine/                    the HealthKit engine: HealthKitEngine, StateStore,
    │                              EngineState, Mapper, BPTypes, BPError, Log, ULID
    ├── Health/                    HealthModel: the UI's view of the engine, and the drain
    ├── Features/                  Journey, Record (chart, manual entry, Apple Health card),
    │                              Program, Learn, Settings, Main (tabs + navigation)
    └── Assets.xcassets            Corveo logotype (vector), AppIcon placeholder, AccentColor
```

Bundle ID `dev.aiplease.bpreset` (throwaway, sandbox team). Deployment target iOS 17. Swift 5 language mode for now; strict concurrency is a deliberate later pass. No third-party dependencies in Phase 1.

## 3. Architecture

**State.** Four `@Observable` objects injected through the environment at the root: `AppState` (journey choices, enrolment stand-ins; UserDefaults; never health data), `AppModel` (the in-memory record: readings, trend, consent, progress; refetched, never persisted), `HealthModel` (engine status and the drain), `Router` (selected tab and navigation path). `FollowState` holds the programs-library follow state (change-request scope).

**Navigation.** `RootView` switches between `JourneyFlow` (a `NavigationStack` over `JourneyStep`) and `MainTabsView` (one `NavigationStack` over `AppRoute` with the three tab roots and the floating tab bar; pushed screens hide the bar). Every screen renders inside the `Screen` scaffold: wordmark header with eyebrow and action slot, scrolling content with overline and serif title, pinned footer.

**Data.** Screens call `AppModel`, which calls a `CorveoAPI`. `MockAPI` is an actor with synthetic fixtures in memory. The Supabase implementation (Phase 3) implements the same protocol against the deployed v0.2 views and RPCs; no screen changes. `PayloadBuilder` holds the two ingest mappings: manual entry (with body site and the phone's zone) and HealthKit (the §17.3 `toRows` mapping against `ingest_observations`, timezone metadata-or-nil).

**Engine.** `HealthKitEngine` is the spike's `SpikeEngine` grown into the §7 surface: `configure`, `requestAuthorization` (records only that the prompt ran), `startObserving`, `stopObserving`, `runCatchUp` (bootstrap rule, D-002 commit gate, anchor-recovery ladder), `pendingSnapshot`, `heldSnapshot`, `acknowledge` (generation-checked), `disconnectAndReset` (both policies, behind a barrier), `discardHeld`, and the `onReadingsAvailable` hint. Single executor, two-generation checksummed store, file-protected and backup-excluded, the compile-time log guard. The spike-only code (auth-set A/B, fault injection, CLI, environment stamp) is not in the app; `native/spike` remains the on-device regression rig.

**Drain.** `HealthModel.drain` runs on every foreground activation, on the engine's readings hint, and from the Sync button, under one mutex: catch-up, snapshot, binding check on every item (mismatch holds everything), one `ingest_observations` call, then per-item acknowledgement. Structurally rejected rows are acknowledged and counted per source (never a value) and the count is shown on the Apple Health card (plan N-04). Whole-call failures acknowledge nothing.

**Health values at rest.** The only on-disk copy of a reading is the engine's protected queue. `AppModel` is memory-only; `AppState`, `FollowState` and the engine's config hold identifiers and choices, never values. There is no WebView, no Preferences, no cache.

## 4. What Phase 1 delivered

- The Xcode project, signed for device under the sandbox team. The signed `.app` carries exactly `com.apple.developer.healthkit` and `healthkit.background-delivery`; Info.plist carries the share usage string and no update key; `PrivacyInfo.xcprivacy` declares health and email data (linked, app functionality, no tracking) and the UserDefaults required-reason API.
- The design system as Swift tokens and components, on the values the reviewed web preview renders from; the Figma Mobile scale is one file away.
- Every screen ported: welcome, signup, consent, connect, Apple Health explainer (real system sheet), first capture, result, cadence; Record with the Swift Charts trend and history; Program with chapter list, reading view, library and rail; Learn with the Pulse viewer and In Focus; Settings with the Apple Health card, export via the share sheet, deletion, safety surface, cuffs; validated cuffs.
- The engine wired end to end against the mock: connect → configure → real permission sheet → observe → catch-up → snapshot → ingest → acknowledge, with the Apple Health card reporting mechanism only.
- Simulator run verified by screenshot (welcome, record). No errors in the app log; the engine's backup-exclusion attribute confirmed set on its directory at first launch.

## 4a. Phase 3: backend wiring (built 2 Sep, live test pending a confirmed user)

- `supabase-swift` 2.55 via Swift Package Manager. `SupabaseFactory` builds the client only when
  `Secrets.xcconfig` (generated from `.env.local` by `ios/gen-secrets.sh`, gitignored) supplies the
  non-production URL and publishable key through `Config/Info.plist`; otherwise the app runs on the
  mock. `AppConfig` is the single reader.
- `KeychainSessionStorage`: the auth session in the Keychain, after-first-unlock, this device only,
  never synchronisable. No token ever touches UserDefaults or a backup.
- `SupabaseAPI: CorveoAPI`: reads through `v_bp_readings`, `v_bp_trend`, `v_consent_status`,
  `v_program_progress`; writes through `ingest_observations`, `record_consent`, `withdraw_consent`,
  `enrol_patient`, `delete_account`, `export_patient_data`; progress upserts `program_progress`
  under RLS. `CONSENT_REQUIRED` and `UNAUTHORIZED` map to whole-call errors the drain never
  acknowledges against.
- `SessionModel`: restore on launch, sign up (email confirmation pending state), sign in, sign out,
  enrol. The engine's binding tuple now comes from the `app_user` row: `id` and `created_at`.
- Screens: the account step gains a password field and a sign-in switch; a sign-in gate shows for
  a returning patient whose session is gone; Settings gains sign out (drains first, engine state
  persists); deletion signs out after `delete_account`.
- Verified: builds; the backend-configured build launches on the simulator, detects the backend,
  restores no session and shows the sign-in gate; no errors in the app log.
- **Live round trip verified, 2 Sep 2026, on an iPhone 17 (iOS 26.6.1, build 23G83).** With a
  dashboard-created confirmed user: sign in, `enrol_patient`, `record_consent`, a manual reading
  through `ingest_observations`, and the reading read back from `v_bp_readings` on the Record tab.
  That is Stage 2 criterion (a) on a physical device against the dev project. One defect found
  and fixed on the way: PostgREST resolves an RPC by its named parameters, so a nil display name
  must be sent as an explicit null, never omitted.
- **Apple Health path verified live the same day, same handset.** With Luca's synthetic writer
  (`dev.lucab.bpwriter`, the only app carrying the write permission) installed beside the product:
  a synthetic correlation saved to Apple Health arrived on the Record tab with the Apple Health
  provenance chip after a foreground activation (foreground catch-up and drain through
  `ingest_observations`). Then, with BP Reset backgrounded and the phone locked, a delayed save
  from the writer was already in the record when the app was reopened: the observer query woke
  the app, the engine committed to the protected queue, and the drain uploaded on activation.
  That is the T4 and T5a shape of Stage 2 criterion (c) on a physical device, synthetic data
  only. Still owed for acceptance: the loan Omron cuff on this handset (criteria (b) and (d)),
  the 48-hour soak (T6), the client non-production environment (T15/T16), and the written script.

## 4b. Stage 3 features (built 2 Sep, simulator-verified at accessibility type sizes)

- **Reminders.** `ReminderModel` schedules repeating local notifications from the cadence
  choice only: 8 am and 8 pm for twice daily, 8 am daily, Monday/Wednesday/Friday 8 am for a
  few times a week. Fixed copy, no value, no count, nothing derived from a reading (SOW A.3.3;
  rulebook value-blind notifications). The cadence step explains first and offers "Remind me at
  these times"; the one system prompt follows on Continue. Settings has a Reminders card to
  change the rhythm or turn reminders off, with a note when iOS has notifications off. Sign
  out, deletion and the development reset clear the schedule.
- **Release flag for change-request scope (N-12).** `CR_SCOPE_ENABLED` in `Signing.xcconfig`
  is YES for Debug and NO for Release, reaches the app through `Config/Info.plist`, and hides
  the Learn tab and the programs rail until the CR is signed.
- **Chart.** Series identity is carried by marker shape (circle, square) and line dash as well
  as colour, so the trend reads without colour.
- **Accessibility pass (rulebook §8.3).** Reduce Motion turns the brand curve off; 44pt hit
  targets on the tab bar and header links; at accessibility Dynamic Type sizes the reading row
  and the segmented control stack instead of wrapping or clipping. Verified by screenshot on
  the simulator at the accessibility-medium size.
- **Unit tests (2 Sep, afternoon).** `BPResetTests` is a host-app XCTest target: the spike's
  §10 store self-test ported (fresh load, alternating generations, checksum idempotence, the
  M17 fallback, tampered checksum, both-invalid → INTERNAL, backup exclusion), the mapper against
  in-memory HealthKit samples (metadata-or-nil timezone, unit conversion, no range checks), the
  ingest and enrolment wire shapes (including the explicit-null regression from the morning),
  the manual-entry bounds, ULID ordering, and bright-line guards over the reading and reminder
  copy. 35 tests, all passing on the simulator. Run with:
  `xcodebuild test -project ios/BPReset.xcodeproj -scheme BPReset -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BPResetTests SUPABASE_URL= SUPABASE_PUBLISHABLE_KEY=`
  (the two blank overrides keep the host app on the mock). HealthKit validates correlations at
  construction, so the mapper's missing-child and duplicate-child guards remain device-only.
- **Retry funnel (2 Sep, afternoon).** The engine now observes `protectedDataDidBecomeAvailable`:
  a wake that found the store locked leaves the pending flag set with the anchor untouched, and
  the next unlock retries the catch-up in place if the process is still alive. Not yet on the
  phone (the soak build is frozen); it is exercised by soak checkpoint C3's shape once installed.
- **Release configuration checked on the simulator (2 Sep).** `CRScopeEnabled` reaches the
  bundle as NO, the tab bar shows Program and Record only, the share usage string is present and
  the update key absent. The development card is compiled out of Release, which the Release build
  caught as a compile error the first time.
- **T14 variant.** `Entitlements/BPReset-NoBackgroundDelivery.entitlements` exists for the
  arming-failure test after the soak: build with `CODE_SIGN_ENTITLEMENTS` pointing at it.
- **Still open for Stage 3:** the strict-concurrency pass; T14 on the product build; the
  48-hour soak (running, `docs/soak-log.md`); Corveo's review of the reminder copy; privacy
  policy and support URLs; App Store assets.

## 5. Phase 1 exit checks

| Check | Result |
|---|---|
| Builds for simulator and device | Yes, zero errors |
| Signed entitlements exactly as specified | Yes (`codesign -d --entitlements`) |
| Share key present, update key absent, Clinical Health Records absent | Yes |
| Privacy manifest bundled | Yes |
| Launches and renders on the simulator | Yes (screenshots in the session) |
| Launches on a physical iPhone | Yes: iPhone 17 (`iPhone18,3`), iOS 26.6.1 build 23G83, paired and in Developer Mode on 2 Sep. This handset is on the frozen 26.x baseline, so re-running the spike scripts on it closes D-003. |

## 6. What changes in the plan (06)

| Plan item | Now |
|---|---|
| P1 Capacitor shell | Done as the SwiftUI shell above. |
| P2 Plugin package (`packages/bp-healthkit`, TS definitions, web mock) | Replaced by the `Engine/` module already in the app. Remaining P2 work: XCTest port of the store self-test, device runs of T1–T3, T-L, T-L2, and the retry funnel on protected-data-available. |
| P3 Backend wiring (supabase-js, Keychain plugin) | `supabase-swift` via SPM; its Keychain session storage configured after-first-unlock, this device only. `SupabaseAPI: CorveoAPI`. Auth screens gain a password field and call `enrol_patient`. |
| P4 Drain + Apple Health UX | Foreground (T4 shape) and background (T5a shape) verified live on 2 Sep with the writer. Remaining device evidence: T5b, T7, T9, T10, T10b, T13, T14, and the soak. |
| N-07 WebView storage rule | Moot. Replaced by "no reading value outside the engine's protected queue". |
| N-10 presentation surfaces | Not ported. The replica sheet and Behind-the-scenes stay web-only. |
| N-12 CR-scope tabs | Ported for IA review; a release build flag still needs to hide them. |
| L-5 device pass (scroll-snap, safe areas, mount heights) | Moot; native paging and safe areas. Replaced by the rulebook §8.3 accessibility pass. |

## 7. Running it

```bash
cd ios
xcodebuild -project BPReset.xcodeproj -scheme BPReset \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or `open ios/BPReset.xcodeproj`, pick the paired iPhone, run. The synthetic dataset loads on first launch; Settings carries a development-only reset. HealthKit on the simulator presents the real permission sheet but holds no vendor data; only the physical iPhone evidences anything (pitfall 1).

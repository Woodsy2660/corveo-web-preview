# 06 — Native app build plan

| | |
|---|---|
| **Status** | Proposed, 2 September 2026. Built on `integration/native-app`. |
| **Owner** | Nick (integration), with Luca (native), Michael (front end), Ben (platform) |
| **Inputs** | Notion tracker `Corveo · BP Reset V1` (tasks, deliverables, risks, stage gates, Apple rulebook, HealthKit plugin page, ADR-0006); repo branches `main`, `frontend/foundation`, `frontend/presentation`, `Frontend/Presentation-Luca`, `native/healthkit-lane`; Luca's lane repo (`~/Downloads/Plugin`) incl. guide v1.3, spike, drain harness, migrations, deviations; SOW-2026-001 and the Corveo Engineering Brief; the dev Supabase project as probed on 2 Sep. |
| **Contract refs** | SOW A.3 (deliverables 1, 2, 3, 4, 5, 6, 12, 14), A.3.3, A.8.2 (Stage 1–3 criteria), A.12, Annexure D Model B |

This document turns the front-end mockup, the proven native spike and the deployed Supabase schema into one native iPhone app. Everything below is ordered so that each phase leaves a build that runs on the acceptance iPhone.

---

## 0. Where the build actually is

### 0.1 Branch state (GitHub, 2 Sep 2026)

| Branch | Tip | What it holds | Verdict |
|---|---|---|---|
| `main` | `6e70467` | Skeleton, July docs, empty `ios/` and `src/` | Two commits. Nothing merged since 29 July. |
| `frontend/foundation` | `42e92fc` | Michael's complete V1 screen flow on mocks. **PR #1, open since 14 Aug.** | Superseded by `frontend/presentation`. |
| `frontend/presentation` | `014b9a2` | Foundation tip + Luca's Apple Health demo surface (replayed by Michael) + programs rail + authoritative Figma token export (28 Aug) | **The UI base.** Builds clean, 10/10 tests. |
| `Frontend/Presentation-Luca` | `211eed1` | Stale front-end base + **the 16 Supabase migrations actually applied to the dev project** (`ltggfrlnhquvrrnxpdtr`), `src/lib/config.ts`, `vite-env.d.ts`, migration plan v0.2, a John Smith demo persona | Migrations and config taken. Demo persona not taken (uses raw Tailwind colours incl. green ticks; demo-only). |
| `native/healthkit-lane` | `a308a35` | Guide v1.3, bridge spec, integration review C1–C20, deviations D-001..D-003, ADR-0003/0006, the §11 spike (three SwiftUI targets), drain harness, guide §13 migrations 000–004 and 15 SQL tests | Merged clean (adds files only). |

### 0.2 What is proven

- **Front end.** Every V1 screen exists and runs on synthetic mocks: journey (welcome, signup, consent, connect, health-auth, first capture, result, cadence), Record (chart + history), Program, Learn, Settings (export, deletion, consent receipt, safety surface), validated cuffs. Bright-line audit passed (chart categorical colours only; bounds mechanical).
- **Native.** Path A accepted on a physical iPhone 16 Pro Max (26 Aug): one persisted `HKQueryAnchor` over the BP correlation type resumes across process termination, catches backdated inserts, never repeats. Two-generation checksummed state store 12/12 on device. Bootstrap rule and T10 backfill demonstrated against a real revocation. Correlation types abort authorisation (S2), so the quantity-only read set is the only legal set. D-002 fixed (anchor commit gate).
- **Pipeline.** Apple Health → anchored query → queue → snapshot → `observation` + `observation_component` → acknowledge → empty queue, every field round-tripped, replay inserted nothing. Against a local stand-in carrying the client DDL, not the client project.
- **Backend.** The v0.2 migrations are deployed to the dev project. Probed 2 Sep with the anon key: REST root 401, `v_bp_readings` and `ingest_observations` both `permission denied` for anon (correct), signups enabled with email confirmation required, Apple provider enabled, anonymous sign-in disabled.

### 0.3 What is not built

Capacitor shell and Xcode project · the plugin *package* (the spike is a bare SwiftUI engine, not a Capacitor plugin) · `disconnectAndReset`, held buckets, `getHeldSnapshot`, `discardHeld`, prompt status, the `bpReadingsAvailable` event · a Supabase client in the app · real auth and enrolment · the JS drain · local notifications · export via the iOS share sheet · in-app account deletion wired to `delete_account()` · `PrivacyInfo.xcprivacy` · signing and TestFlight pipeline · the Stage 1/2 test scripts.

### 0.4 What was assembled today

`integration/native-app` = `frontend/presentation` + merge of `native/healthkit-lane` + `supabase/`, `src/lib/config.ts`, `src/vite-env.d.ts`, `docs/migration-plan-v0.2.md`, `docs/05-migration-plan.md` from `Frontend/Presentation-Luca`. `.env.example` now matches `config.ts` (VITE_ names). `.env.local` (dev URL + publishable key, gitignored) in place. `.nvmrc` pinned to 22 and `.xcode-version` to 26 (C12). `npm run build` and `npm test` green.

Toolchain on this Mac: Xcode 26.6 (17F113, iOS 26.5 SDK), Node 25.5 (Capacitor 8 needs ≥22), Swift 6.3, Apple Development identity under personal team `RQD4CW5B4V`, iPhone 16 Pro Max paired (`iPhone17,2`, iOS 27.0 seed), iPad Pro sidecar. No CocoaPods (Capacitor 8 uses SPM). Capacitor 8.5.1 and supabase-js 2.112.4 are current.

---

## 1. Decisions this plan is built on

Each of these is a stated assumption. The build proceeds on them; the named owner can overturn any of them and the plan says what changes if they do.

| ID | Decision | Choice made here | Why | Ratify |
|---|---|---|---|---|
| **N-01** | Bridge contract (C1: who uploads) | **Guide v1.3 §7.** Background wakes commit to the protected native queue; the JS tier drains on every bridge-ready and foreground activation. No refresh tokens in native code. | Proven on device; it is the verified Apple rulebook's "accepted capture shape" (§4.5); Model B token custody stays in the app session; the front end's v0.1 `setCredentials` model was never cleared with the client (P-04). The v0.1 interface in `src/lib/health/types.ts` is replaced, not adapted. | Ben |
| **N-02** | Backend schema | **The deployed v0.2 schema** (`app_user`, `observation` + `observation_component`, `ingest_observations`, `enrol_patient`, `record_consent`, `withdraw_consent`, `soft_delete_observation`, `delete_account`, `export_patient_data`). Guide §13 migrations 000–004 stay in `db/` as reference and are **not applied**. | C13/C14/C16: the guide's flat `observations` + `enrolments` model does not fit the project. What survives from §13 is the privilege discipline, already present in v0.2. | Ben |
| **N-03** | Enrolment binding (C16, D3) | `enrolmentRef` = `app_user.id` (returned by `enrol_patient()`), `importStart` = `app_user.created_at` (server clock, "start of the retention clock"). Both read via the `app_user` select-own policy. | Gives the immutable tuple a home with zero schema change. One `app_user` = one enrolment in V1; re-enrolment as a new program instance is a fast-follow. | Ben, Luca |
| **N-04** | Batch semantics (C15) | Keep `ingest_observations` per-item rejection. **Drain acknowledges per item**: every reading whose `source_uuid` is absent from `rejected[]` (inserted or duplicate) is acknowledged; rejected readings are acknowledged too and counted in a counts-only diagnostic surfaced on the Apple Health card ("N readings could not be imported"). Whole-call failures (`CONSENT_REQUIRED`, `UNAUTHORIZED`, network) acknowledge nothing. | A structurally rejected HealthKit row can never succeed; leaving it queued replays forever and pins the pending count. Recommend Ben exempt `source_type='healthkit'` rows from the manual-entry data-quality bounds, which removes the only realistic rejection. | Ben |
| **N-05** | Timezone (C5, Q7) | Additive bridge field `tzIdentifier: string \| null` (the IANA name from `HKMetadataKeyTimeZone`) alongside `tzOffsetMinutes`. `effective_tz` is sent only when present; `effective_offset_minutes` likewise. The DB default (`Australia/Sydney`) stands until Q7 is decided. | Honest provenance without blocking on a schema change. | Luca (bridge), Ben (Q7) |
| **N-06** | Authentication | Supabase **email + password**, no anonymous bootstrap (disabled on the project anyway). Sign in with Apple deferred to Stage 3 (provider already enabled). Session persisted through a small native **Keychain** storage plugin (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, non-synchronisable), never WebView localStorage. Signup calls `enrol_patient(display_name, adult_attested)`. | Email/password alone does not trigger Guideline 4.8. Keychain keeps the token out of iCloud backup. | Ben (auth config), Corveo (self-registration vs clinic provisioning) |
| **N-07** | Health values at rest | **No systolic or diastolic value is ever written to WebView storage, Preferences or UserDefaults.** The mock API and mock plugin (which persist to localStorage) run only when `!Capacitor.isNativePlatform()`. React Query stays in memory. Journey state (choices, not values) may persist. | Guideline 5.1.3(ii); Model B; the 1 Critical risk raised 26 Aug. Verified by the container audit in P7. | Michael |
| **N-08** | HealthKit read set (C6) | Systolic + diastolic quantity types only. `heartRate` dropped. | Only legal set (S2); heart rate is outside the sixteen deliverables and is not even seeded in `observation_definition`. | Ben |
| **N-09** | Deletions and canonicalisation (C8, C19, D2) | Both out of V1. `deleted_source_uuids` is always empty. All rows display. | Guide §8.3 and Ben's §12 agree deletions and near-duplicate detection are deferred. The fixture already shows an honest two-source duplicate. | Corveo via Ben |
| **N-10** | Presentation-only surfaces | Replica iOS permission sheet, "Behind the scenes", demo reset card, `VITE_DEMO` behaviour: **web preview only**, excluded from the native bundle at build time. | Apple rulebook §4.4, §8.1, Gate F. | Luca, Michael |
| **N-11** | Signing and identifiers | Throwaway bundle ID under the AI Please sandbox team for every dev and internal build. Production bundle ID, app record and pipeline created only inside Intelecor's organisation. | 1 Critical risk: a first upload binds the ID forever. | Ben |
| **N-12** | Change-request scope in the code | Programs library and Learn tab stay in the codebase for IA review, behind a build flag that is **off in release**. | Placeholder clinical content must not ship (Gate F); CR-1 undecided. | Corveo |

---

## 2. Target architecture

### 2.1 Repo layout after the build

```
├── ios/App/                          Capacitor iOS app (cap add ios), SPM
│   ├── App/AppDelegate.swift         one line: BPHealthKit.armAtLaunchIfConfigured()
│   ├── App/App.entitlements          healthkit + healthkit.background-delivery, nothing else
│   ├── App/Info.plist                NSHealthShareUsageDescription only (no update key)
│   └── App/PrivacyInfo.xcprivacy     required-reason APIs actually used + collected data
├── packages/
│   ├── bp-healthkit/                 @corveo/bp-healthkit  (package id com.corveo.bphealthkit)
│   │   ├── Package.swift
│   │   ├── ios/Sources/BPHealthKitPlugin/
│   │   │   ├── BPHealthKitPlugin.swift    CAPPlugin bridge: §7 methods + bpReadingsAvailable
│   │   │   ├── HealthKitEngine.swift      single-executor engine (from SpikeEngine)
│   │   │   ├── StateStore.swift           two-generation store (verbatim from spike)
│   │   │   ├── EngineState.swift          + tzIdentifier, promptRequested
│   │   │   ├── Mapper.swift · BPTypes.swift · BPError.swift · Log.swift · ULID.swift
│   │   ├── ios/Tests/                     StoreSelfTest as XCTest
│   │   └── src/definitions.ts · index.ts · web.ts (web mock)
│   └── secure-store/                 @corveo/secure-store: Keychain get/set/remove for the session
├── src/
│   ├── lib/api/supabase.ts           CorveoApi over supabase-js (views + RPCs)
│   ├── lib/api/index.ts              picks supabase when config.hasSupabase, mock otherwise
│   ├── lib/auth/                     session provider, signUp/signIn/signOut, enrol, RequireAuth
│   ├── lib/health/index.ts           registerPlugin("BPHealthKit") on native, mock on web
│   ├── lib/health/drain.ts           §12 P4 drain adapted to ingest_observations
│   ├── lib/health/payload.ts         BPReading → IngestObservation (the toRows table)
│   ├── lib/health/status.ts          derives the UI state (notRequested / requested / unknown)
│   └── lib/notifications/            cadence → local notification schedule
├── native/spike/                     kept as the regression rig (never ships)
├── db/                               guide §13 migrations + tests (reference only)
└── supabase/migrations/              the deployed v0.2 schema (Ben's lane)
```

### 2.2 Runtime flow

```
Cuff → vendor app → Apple Health
   │  observer wake (both quantity types) or foreground activation
   ▼
HealthKitEngine (serial executor)
   anchored query on HKCorrelationType(.bloodPressure), startDate ≥ importStart
   Mapper (structural checks only) → StateStore.commit (itemId, receivedAt assigned once)
   bootstrap rule: no anchor persisted until the first readable reading commits
   │  bpReadingsAvailable { count }   (hint only)
   ▼
drain()  [JS, one process-wide mutex; on bridge-ready, appStateChange(active), event]
   session → { enrolmentRef = app_user.id, importStart = app_user.created_at }
   held-first: getHeldSnapshot for this enrolment if Status.held names it
   runCatchUp()   (deferred is fine)
   getPendingSnapshot()
   binding check on EVERY item; mismatch → HOLD (upload nothing, discard nothing)
   supabase.rpc('ingest_observations', { payload })
   per-item ack: acknowledge({ snapshotId, itemIds: landed })  → SNAPSHOT_STALE → re-snapshot, retry
   │
   ▼
Supabase (RLS)  observation + observation_component  →  v_bp_readings / v_bp_trend  →  Record tab
```

Manual entry never touches the plugin: `ManualEntryForm` → `ingest_observations` with `source_type: "manual"`, unchanged.

### 2.3 Connect order (first run)

`isAvailable()` → sign in → `enrol_patient` (signup only) → `record_consent` → `configure({ enrolmentRef, importStart })` → explainer screen → `requestAuthorization()` (real iOS sheet) → `startObserving()` → `drain()`.

`BG_DELIVERY_FAILED` leaves the state `armFailed`: the card says "Connected. Background updates unavailable on this build." and foreground refresh still works.

### 2.4 Error rendering

| Source | Code | User-facing behaviour |
|---|---|---|
| plugin | `HK_UNAVAILABLE` | Connect option hidden; manual-only. |
| plugin | `PROMPT_PENDING`, `CONFIG_MISSING` | Route back to the connect step. Internal. |
| plugin | `CONFIG_CONFLICT` | Different account on this phone: HOLD path (below). |
| plugin | `BG_DELIVERY_FAILED` | "Background updates unavailable on this build." |
| plugin | `HK_TEMP_UNAVAILABLE` | Nothing. Retried on unlock / foreground. |
| plugin | `SNAPSHOT_STALE` | Internal re-snapshot and retry. |
| plugin | `QUERY_FAILED` (persistent) | Generic retry + support prompt. |
| plugin | `INTERNAL` | Support-visible error state. Never auto-reset. |
| RPC | `CONSENT_REQUIRED` (42501) | Nothing acknowledged. Consent nudge in the card and Settings. |
| RPC | `UNAUTHORIZED` / 401 | Session expired: sign-in sheet; queue intact. |
| RPC | `rejected[]` items | Acknowledged and counted; card shows the count. Never a value. |
| network | any | Nothing acknowledged. Next trigger drains. |

### 2.5 Account switch, disconnect, deletion

- **Logout.** Attempt `drain()`; then sign out and clear the Keychain session. Engine state persists; capture continues per intent.
- **Different account signs in.** Binding check trips HOLD: card shows a held count and two exits: sign back in as the original account (held-first drain reclaims it) or **Disconnect and discard**, gated behind an explicit confirmation → `disconnectAndReset({ pendingPolicy: 'confirmedDiscard' })`.
- **Disconnect Apple Health (Settings).** `disconnectAndReset({ pendingPolicy: 'holdForReauth' })` by default; copy states it stops BP Reset importing and does not change Health permissions.
- **Withdraw consent.** `withdraw_consent()` then `stopObserving()`; queue stays drainable when consent is re-granted.
- **Delete account.** Confirm → `delete_account()` → `disconnectAndReset({ confirmedDiscard })` → sign out → Keychain cleared → journey reset. Clinical rows are retained server-side under A.12.6; the copy already says so.

---

## 3. Phases

Estimates are developer-days of focused work on this Mac with the iPhone paired. Wall-clock items (the soak, client dependencies) are called out separately. "Exit" is the test that ends the phase.

### P1 — Capacitor shell on the iPhone (0.5–1 day) · Stage 1 (a)

1. `npm i @capacitor/core @capacitor/cli @capacitor/ios @capacitor/app` (8.5.x). `npx cap init "BP Reset" dev.aiplease.bpreset --web-dir dist`. `npx cap add ios`.
2. `capacitor.config.ts`: `webDir: dist`, `ios.contentInset: always`, `server.iosScheme: capacitor` (default). No live-update tooling ever (Guideline 2.5.2).
3. Xcode target: HealthKit capability + background delivery entitlement; `NSHealthShareUsageDescription` (rulebook §4.2 wording, placeholder until client-approved); **no** `NSHealthUpdateUsageDescription`; **no** Clinical Health Records (Xcode re-adds it silently when the capability editor is touched; verify with `codesign -d --entitlements`).
4. `PrivacyInfo.xcprivacy` from day one: `NSPrivacyAccessedAPITypes` for the categories the app genuinely uses (file timestamps for the protected queue directory; UserDefaults only if any plugin uses it), `NSPrivacyCollectedDataTypes` for health data linked to the user, no tracking.
5. Signing: personal team `RQD4CW5B4V` or the AI Please paid team. The free team caps three installed dev apps per device and the three spike apps already fill it: remove `dev.lucab.bpspikec` (its job is done) or move to the paid team.
6. Web build inside the shell: `viewport-fit=cover` is already set; verify `--safe-top` / `--safe-bottom`, the fixed tab bar, the `#root` phone-frame media query (must not apply on device), and the Pulse viewer scroll-snap (L-5).
7. Build flags: `VITE_NATIVE_RELEASE=true` strips the demo card, the replica sheet, the `/behind` route and the CR-scope tabs (N-10, N-12).

**Exit:** the React app launches full-screen on the iPhone from Xcode; `codesign -d --entitlements :-` on the built `.app` shows exactly `healthkit` + `healthkit.background-delivery`; merged Info.plist has the share key and lacks the update key.

### P2 — The plugin package (2–3 days) · deliverable #2

1. `npm init @capacitor/plugin@latest packages/bp-healthkit -- --name bp-healthkit --package-id com.corveo.bphealthkit --class-name BPHealthKit`; install as a local dependency.
2. Move the spike's production-shaped sources in verbatim: `StateStore`, `EngineState`/`Envelope`, `Mapper` (with child UUIDs), `BPTypes`, `BPError`, `Log` (with its unavailable overloads), `ULID`. Drop `SpikeAuthSet`, injections, `destroyStoreForSpikeRecovery`, the CLI, `SpikeEnvironment`.
3. `HealthKitEngine` from `SpikeEngine`, then the parts the spike did not need:
   - `promptRequested` persisted (PromptStatus); `requestAuthorization` never rejects on denial.
   - `PROMPT_PENDING` on `runCatchUp` before the prompt has run.
   - `disconnectAndReset` inside a `RESETTING` barrier on the executor: in-flight catch-up completes, observers stopped, delivery disabled, then one policy commit (`holdForReauth` moves the queue into `held[]` keyed by the old `enrolmentRef`; `confirmedDiscard` wipes queue, anchor, bootstrap, config).
   - `getHeldSnapshot`, `discardHeld` (`CONFIRM_REQUIRED` unless `confirmed === true`), `Status.held[]`.
   - Retry funnels: `protectedDataDidBecomeAvailableNotification`, foreground activation, bridge-ready.
   - `bpReadingsAvailable` event after any catch-up that queued items and on bridge-ready with a non-empty queue.
   - Additive `tzIdentifier` (N-05).
4. `BPHealthKitPlugin.swift`: thin `CAPPlugin` mapping each §7 method; every state touch goes through the engine executor; errors map to the §7.2 codes via `call.reject(code, code)`.
5. `AppDelegate`: `HealthKitEngine.shared.armAtLaunchIfConfigured()` before the bridge loads (observers are per-process; a background relaunch must re-register them natively, never from JS).
6. TS: `definitions.ts` = §7 verbatim (+ `tzIdentifier`); `web.ts` = the mock for the browser, re-implemented against this interface (the current v0.1 mock is deleted).
7. Tests: port `StoreSelfTest` to XCTest in the package; keep `native/spike` as the on-device regression rig (`spk1.sh`, `spk4.sh` unchanged).
8. Log discipline: the `Log` wrapper's compile-time guard travels with the package; a CI grep for `print(` and string interpolation of `systolic`/`diastolic` in `packages/bp-healthkit/ios`.

**Exit:** T1 (clean-clone discovery), T2 (sheet exactly once), T3 (snapshot semantics incl. `SNAPSHOT_STALE`), T-L (configure idempotency, `CONFIG_CONFLICT`, both reset policies), T-L2 (held reclaim + discard) pass on the iPhone from the app's own dev screen; `spk1.sh` and `spk4.sh` still pass against the spike targets.

### P3 — Backend wiring (1.5–2 days) · deliverables #4, #5, #9 consumer side

1. `npm i @supabase/supabase-js`. `src/lib/api/supabase.ts` implements `CorveoApi` over the four views and the RPCs; `getApi()` returns it when `config.hasSupabase`, the mock otherwise (web preview keeps working).
2. `packages/secure-store`: tiny Capacitor plugin with `get/set/remove` over Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecAttrSynchronizable = false`). supabase-js `auth.storage` uses it on native; `sessionStorage` (not localStorage) on web.
3. Auth: `SessionProvider`, `signUp`/`signIn`/`signOut`, `RequireAuth` guard in `App.tsx`. Signup screen gains a password field and calls `enrol_patient(display_name, adult_attested)` after the auth user exists. Email confirmation is on in the dev project: either Ben disables it for dev or the app shows a "check your email" interstitial (needed for the review account anyway, see rulebook §9.2).
4. Consent: `recordConsentEvent` → `record_consent(version, document_hash)`; `withdrawConsent` → `withdraw_consent()`. Consent receipt reads `v_consent_status` (B-1 closed by Ben's RPC; the mock's `method` field goes).
5. Program progress: `v_program_progress` + upsert on `program_progress` (RLS allows insert/update own). Key format stays `"<slug>:<n>"` (B-3 stays open with Ben; the back-compat read for `week-N` is removed once he confirms).
6. Export: `export_patient_data()` → on native, write `my-heart-record.csv` and `my-heart-record.fhir.json` to the cache directory via `@capacitor/filesystem`, hand both to `@capacitor/share`, delete afterwards. Web keeps the download.
7. Deletion: `requestAccountDeletion` → `delete_account()` (rest of the sequence in §2.5).
8. Manual entry unchanged except `effective_tz` from `Intl` stays (the phone's zone is genuinely the reading's zone for a manual entry).
9. `bounds.ts` is now owned by whoever changes `observation_definition` seeds; add a vitest that asserts the mirrored numbers against a checked-in copy of the seed migration.

**Exit:** T-A on device (manual reading lands in `v_bp_readings` in the dev project under RLS); signup → enrol → consent → progress round-trips against dev; nothing health-valued in `localStorage`, `IndexedDB` or `UserDefaults` after a full flow (first container audit).

### P4 — Drain and the Apple Health experience (1.5–2 days) · deliverable #3, Stage 2 (b), (c)

1. `src/lib/health/drain.ts`: §12 P4 verbatim in shape, `ingest_observations` in payload. `payload.ts` maps `BPReading` → `IngestObservation` (`hkUuid`→`source_uuid`, child UUIDs→`components[].source_uuid`, `takenAt`→`effective_time`, `tzIdentifier`→`effective_tz`, `tzOffsetMinutes`→`effective_offset_minutes`, `sourceBundleId`→`source_system`, `sourceName`, `deviceModel`→`source_device_model`, `source_user_entered: false`, `body_site_code: null`). Per-item ack per N-04.
2. Triggers: bridge-ready, `App.addListener('appStateChange')`, `bpReadingsAvailable`, the Sync button. One mutex.
3. `HealthAuth.tsx` on native: explainer copy + **Continue** / **Not now**, then the real sheet. The replica sheet renders on web only.
4. `AppleHealthCard.tsx` reads `getStatus()`: connected/armFailed states, pending and held counts, rejected count, last drain time, Sync = `drain()`. Never a denied state; the three-branch neutral copy after a requested-and-completed fetch with zero samples.
5. Settings: disconnect (two policies), held-bucket reclaim/discard UI, "Open BP Reset Settings" deep link (`UIApplication.openSettingsURLString` via `@capacitor/app` or a one-line plugin method).
6. Denial path end to end: decline → manual entry and all six weeks usable → grant later in Health → backfill from `importStart` (T10, T10b).
7. **Kick off T6 (48-hour soak) the moment arming works**, using the writer app's delayed save (T5a) five times across two days including a reboot and a locked-store deferral.

**Exit:** T4 (cuff reading, foreground) once the Omron chain is proven on this handset; T5a (background capture, phone locked); T5b (force-quit recovery); T7 (anchor reset replay → zero duplicates); T9 (three sources attributed); T10/T10b; T13 (locked store); T14 (build without the entitlement → `armFailed`, foreground still works).

### P5 — Stage 2 evidence (2–3 days + the soak) · Stage 2 (a)–(f)

1. Prove the Omron chain on the acceptance iPhone (vendor-first order in guide §9.4). Criteria (b) and (d) cannot be claimed without it.
2. Settle D-003: re-take `spk1.sh`/`spk2.sh`/`spk4.sh`/`spkclose.sh` on a 26.x release handset, or the engagement lead amends §3.5 in writing to name the walkthrough OS.
3. T15 in the client-controlled non-prod project: needs a confirmed auth user plus its `app_user` row (Ben). Run the RLS positive/negative, uniqueness replay, consent-gate and all-or-nothing checks against Ben's RPC (translate the shape of `db/tests`, not the SQL).
4. Verify Q6 directly: the v0.2 migration declares `observation_dedup_key unique (user_id, source_system, source_uuid)`; the 20 Aug dump does not show it. One `\d public.observation` in the dev project decides whether the 1 Critical stands.
5. T16 live during the walkthrough: the T4 reading drains into the client non-prod project, evidence value-free.
6. T11 bright-line audit co-signed; T-EV artefact audit.
7. Write the Stage 2 test script (`docs/stage2-test-script.md`) from guide §14 with the front-end steps (T-A) and the Settings locations (N-1).

**Exit:** every Stage 2 criterion has an evidence row; walkthrough held.

### P6 — Stage 3 features (3–4 days) · deliverables #5, #6, #7, #8, #12

1. Local notifications (`@capacitor/local-notifications`): scheduled from the cadence choice; static, value-blind body ("A reminder from BP Reset: record a reading from your cuff when it suits your routine."); ordinary interruption level; **Not now** honoured; reschedule on cadence change; cancel on withdraw/delete; timezone change must not duplicate.
2. Export and deletion on device (P3.6, P3.7) demonstrated against the test script.
3. Sign in with Apple if Corveo wants it (provider is enabled): revoke the Apple token in `delete_account`.
4. Device accessibility pass (rulebook §8.3): Dynamic Type incl. accessibility sizes, VoiceOver labels on the chart rows (the spec's spoken form), Reduce Motion (the `fade-up`/`spin` animations already respect it), safe areas on the smallest supported iPhone, touch targets.
5. Chart: add shape/line differentiation and a text legend so colour is never the only channel (rulebook §8.2). Categorical colours stay fixed; no value mapping.
6. Content: the six-week program container is built; swap `program-placeholder.ts` for Corveo's signed-off content when it lands. Learn tab and programs library flagged off in release (N-12).
7. Adopt the Figma **Mobile** scale from `figma-tokens.css` as a reviewed design pass (the app is currently on the Desktop scale), or record the decision not to.
8. TestFlight: internal testing from the AI Please sandbox team under the throwaway ID for the review session; Corveo org pipeline (deliverable #14) once enrolment lands.

**Exit:** Stage 3 criteria (a)–(d) demonstrable from a TestFlight build against a written script.

### P7 — Release hygiene (1.5–2 days, plus Corveo dependencies) · Stage 4

Signed-archive checklist from the rulebook §10.6; container audit for a known synthetic value; Xcode Privacy Report reconciled with the manifest and App Privacy answers; export-compliance answered from the real dependency inventory; Review Notes versioned in the repo and under 4,000 bytes; review account seeded with synthetic readings and all six weeks unlocked; privacy and support URLs live and rendering; production app record created fresh in Intelecor's org; one production-signed build passes T5a before submission.

### Estimate summary

| Phase | Developer-days | Wall-clock dependencies |
|---|---|---|
| P1 Shell | 0.5–1 | Apple team choice (free vs AI Please paid) |
| P2 Plugin package | 2–3 | none |
| P3 Backend wiring | 1.5–2 | dev auth config (email confirmation), a confirmed dev user |
| P4 Drain + Apple Health UX | 1.5–2 | T6 soak: 48 h, starts inside P4 |
| **Working native prototype (P1–P4)** | **5.5–8** | |
| P5 Stage 2 evidence | 2–3 | Omron cuff on this handset; D-003 decision; client non-prod access |
| P6 Stage 3 features | 3–4 | signed-off content; Corveo wording; Apple org enrolment for TestFlight |
| P7 Release hygiene | 1.5–2 | privacy policy URL; intended-purpose statement; territory and access-model decisions |

Luca's D-001 estimate of three days covered P1–P4 for the native lane alone at a settled contract. The figure above adds the JS integration (drain, auth, Supabase client) and the parts of §7 the spike deliberately left out.

---

## 4. Acceptance map

| Criterion | Evidence | Phase |
|---|---|---|
| Stage 1 (a) skeleton on a physical iPhone | Xcode run + screenshot of the app on `iPhone17,2` | P1 |
| Stage 1 (b) design system rendering | Existing tokens; Figma export adopted or decision recorded | P1, P6 |
| Stage 1 (c) schema + document | Ben's v0.2 migrations deployed; schema document (Ben) | done / Ben |
| Stage 1 (d) TestFlight to a nominated tester | Corveo org pipeline (blocked on enrolment); AI Please internal TestFlight as interim | P6 |
| Stage 1 (e) Security Baseline | Ben; this plan's §1 and §2 feed the as-built controls | Ben |
| Stage 2 (a) manual entry with bounds → Supabase | T-A | P3 |
| Stage 2 (b) loan-cuff reading → Apple Health → app → Supabase | T4 + T16 (+ T15 synthetic) | P4, P5 |
| Stage 2 (c) authorisation, observer + background delivery, de-dup, denial | T2/T3 · T5a/T6 · T7/T9 · T10/T10b | P2, P4 |
| Stage 2 (d) both paths on device with the loan cuff | walkthrough sequence §14 | P5 |
| Stage 2 (e) no interpretation | T11 audit | P5 |
| Stage 3 (a)–(d) | TestFlight build + script | P6 |

---

## 5. Blockers and asks, by owner

**Ben (platform, engagement lead)**
- Ratify N-01 (C1) and N-04 (C15). These two decide what P2 and P4 build; everything else follows.
- Confirm Q6 with one `\d public.observation` on the dev project. If the unique constraint is missing, apply it before any real drain (`on conflict do nothing` is already in the RPC).
- Decide Q7 (`effective_tz` nullable vs documented invariant).
- Consider exempting `source_type='healthkit'` from `min_value`/`max_value` in `ingest_observations` (removes the only realistic per-item rejection).
- Dev auth: disable email confirmation on the dev project, or create a confirmed dev user. Create the matching `app_user` via `enrol_patient` from the app once P3 lands.
- Client non-prod environment booked for T15/T16.
- B-3 key format written into the spec; B-2 only if the library CR is approved.
- Apple: a paid AI Please team for dev (7-day free profiles and the three-app cap bite), per-person App Store Connect roles, Corveo org enrolment chased.

**Luca (native)**
- Review P2's engine additions against guide §6/§7 and the deviations log; approve the additive `tzIdentifier` field (log as D-004 at the as-built republish).
- Omron chain on the acceptance iPhone (vendor-first).
- Record the SPK-3 operator observation still owed.
- D-003: your call with Ben (re-take on 26.x or amend §3.5).

**Michael (front end)**
- Own N-07 in the front end: no reading value in web storage; React Query in memory; mock persistence gated to web.
- Chart shape/text differentiation (rulebook §8.2); VoiceOver row labels.
- Decide the Figma Mobile scale adoption with Userkind.

**Nick (docs, validation)**
- Stage 1 and 2 test scripts (N-1, N-2 locations); Review Notes draft; privacy policy and support URL chased with Corveo; the intended-purpose statement in writing.

**Corveo / Andrew**
- Intended-purpose statement; territory (recommend Australia only); distribution and access model (recommend free app, clinic-provisioned account, no code entry); self-registration vs provisioning; privacy policy and terms live; six-week content signed off; D2 (canonicalisation false positive) sign-off, or confirm it stays out of V1.

---

## 6. Open questions with a recommendation attached

| # | Question | Recommendation |
|---|---|---|
| C6 | Request `heartRate`? | No. Outside deliverables; not seeded; costs a permission V1 never uses. |
| D1 | Held-bucket retention | Indefinite, support-visible (the placeholder in the guide). Show the held count in Settings. |
| B-4 | Anonymous bootstrap session? | No. Disabled on the project; journey choices before signup are app state, not health data. |
| D-06 | FHIR bundle in plpgsql vs Edge Function | Ship the plpgsql RPC that exists; revisit only if it proves slow at review-account volumes. |
| — | Weekly chapter release: server or client? | Client computes the open week from `app_user.created_at` and writes `current_week` on open; server stays the record. Cheap, honest, no cron. Confirm with Ben. |
| — | Spike apps on the free team | Remove Reader C from the phone; keep Reader Q and the writer as the regression rig. |

---

## 7. Working agreements for every PR on this branch

- The bright line: no threshold, band, zone, alert, score, or value-triggered anything, in Swift, SQL, TypeScript, copy or notification payloads. Structural validation only. If unsure, it crosses the line.
- No reading value in a log line, a commit, a fixture with realistic magnitudes, a screenshot, or web storage. The Swift `Log` wrapper enforces its half at compile time; the JS side gets a lint rule that flags `console.*` calls carrying `systolic`/`diastolic`.
- Synthetic data only, everywhere except the developer's own device.
- Every user-facing string in `src/copy/*`, Australian English, no em dashes on screen (F-06), the IPS verb set.
- Throwaway bundle ID until Corveo's org exists. `dev.lucab.*` and `dev.aiplease.*` never ship.
- Deviations from guide v1.3 go into `docs/native/deviations.md`, never silently.

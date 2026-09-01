# Stage 2 test script — Apple Health and data capture

| | |
|---|---|
| **Status** | Working script, v0.1, 2 September 2026. Results column filled as evidence lands. |
| **Owner** | Nick (validation), with Luca (native) and Ben (platform) |
| **Acceptance** | SOW A.8.2 Stage 2, criteria (a) to (f). Milestone: BP capture working, both paths. |
| **Source** | Guide v1.3 §14 (T1 to T-EV, fault matrix M1 to M21), adapted to the native SwiftUI build (`docs/07`) and the deployed v0.2 schema. Settings holds the safety surface and the cuff list (N-1). |

## 0. Evidence discipline

Every artefact retained from this script carries counts, states, error codes, source identifiers and 8-character UUID prefixes. **No systolic or diastolic value is ever written into this document, a screenshot, a log line or a commit** (guide §4.2, Model B). Where a screen must be shown, use readings from the synthetic writer, or redact. Real readings taken on a team member's own phone during development stay on that phone.

## 1. Environment

| Field | Value |
|---|---|
| Acceptance handset | iPhone 17, `iPhone18,3`, iOS 26.6.1 build **23G83** (public release, on the frozen 26.x baseline, guide §3.5) |
| Mac | Xcode 26.6 (17F113), iOS 26.5 SDK, Swift 6.3 |
| Product build | `dev.aiplease.bpreset` (throwaway sandbox ID), Debug, from `integration/native-app` |
| Harness | `dev.lucab.bpspike` (reader Q, §11 spike) and `dev.lucab.bpwriter` (synthetic writer, the only binary carrying the Health write permission). Neither ships. |
| Backend | Corveo dev Supabase project `ltggfrlnhquvrrnxpdtr`, v0.2 migrations, RLS on, email confirmation on |
| Test account | Dashboard-created, auto-confirmed. Credentials held by Nick, never in this document. |
| Cuff | Omron, paired to the handset in OMRON connect, Apple Health sharing enabled inside OMRON connect |
| Second real source | Withings (Nick's), if available |

The client-controlled **non-production** environment is a separate, later run for T15 and T16. The dev project run here proves behaviour; it does not discharge criterion (b) on its own.

## 2. Walkthrough sequence (criterion f)

Run in this order in front of Corveo: **T2 → T-A → T4 → T16 → T5a → T9 → T10 → T11.** Rebuild and reinstall the morning of the session (free-team profiles expire weekly). Do not take cuff readings while the §11 spike scripts (§5 below) are running.

## 3. Tests

Result key: **PASS**, **FAIL**, **PARTIAL** (state what is missing), **N/R** (not run). Date and initials on every result.

| ID | Behaviour | Steps | Expected | Crit. | Result |
|---|---|---|---|---|---|
| T1 | Clean build from a fresh clone | Second Mac: clone, `ios/gen-secrets.sh`, open `ios/BPReset.xcodeproj`, build and run on the handset | Builds without manual project edits; app launches | c | N/R |
| T2 | First-run authorisation | Fresh install → journey → Connect → Apple Health → Continue | The real iOS sheet appears exactly once; both blood-pressure read types listed; app proceeds identically on Allow or Don't Allow; no "denied" wording anywhere | c | **PASS** 2 Sep (NB) on `iPhone18,3` |
| T-A | Manual capture path | Journey first capture, or Record → + → values within bounds → Save | Row appears on Record tab with the Manual chip; a row exists in `v_bp_readings` with `source_type = manual` and the chosen arm; out-of-bounds input shows only "Please check this value." | a, d | **PASS** 2 Sep (NB), dev project |
| T3 | Snapshot semantics | Harness reader Q: catch-up → `getPendingSnapshot` twice → acknowledge → snapshot; then acknowledge with a stale id | Same items and snapshotId on both reads; empty after acknowledge; stale id rejects `SNAPSHOT_STALE` | c | PASS in `spkclose.sh` on the sidecar 26 Aug; **re-run on this handset in §5** |
| T4 | Cuff → Apple Health → app, foreground | Take an Omron reading → open OMRON connect (transfer) → confirm it in Health → Browse → Heart → Blood Pressure → open BP Reset | Row appears with the Apple Health chip **and the OMRON connect source chip**; count of Apple Health rows increases by one; `source_system` in the DB is the Omron bundle id | b, d | N/R, cuff paired 2 Sep |
| T5a | Background capture | BP Reset running, sent to the home screen (not swiped away). Writer: delay 30 s → Schedule save → lock the phone → wait 60 s → unlock → open BP Reset | The reading is already on the Record tab without tapping Sync (observer wake → queue → drain on activation) | b, c, d | **PASS** 2 Sep (NB), writer source |
| T5b | Force-quit recovery | Swipe BP Reset away → writer Save one NOW → relaunch BP Reset manually | **No wake expected** while force-quit; the reading arrives once on the first foreground catch-up, exactly once | c | N/R |
| T6 | Endurance (48 h soak) | T5a five times across 48 h, including one phone reboot and one save while the phone has been locked for 10 min | Still capturing on day 3; every deferred pass converges; zero duplicate rows | c | N/R, start now |
| T7 | Layer-1 idempotency | (i) uninstall → reinstall → sign in same account → connect; (ii) `spk4.sh` anchor-reset drill on the harness | Backfill from enrolment produces zero duplicate rows in `v_bp_readings`; `duplicates` counted by the RPC. Depends on the uniqueness constraint (Q6, Ben) | c | N/R |
| T8 | Layer-2 manual vs HealthKit | Out of V1 (N-09): manual and Apple Health rows of the same event both display | Both rows shown honestly, no merge, no evaluation | c | N/A in V1, record as such |
| T9 | Attribution | One reading each from Omron, the writer, and a second real source if available, in one session | Three rows, three distinct source chips; DB `source_system` matches each writing app's bundle id; nothing labels a writer row as a cuff | c | PARTIAL 2 Sep: writer attributed correctly; Omron pending T4 |
| T10 | Denial and bootstrap backfill | Fresh install → Connect → Don't Allow → use the app, add a manual reading → Settings → Health → Data Access → BP Reset → allow both → open BP Reset | Card shows the neutral "no readings yet" copy, never "denied"; manual entry and all six weeks usable; after granting, history backfills from the enrolment date, exactly once | c | N/R |
| T10b | Revocation after flow | Granted and synced → Health → revoke BP Reset's read access → take a cuff reading → open BP Reset | Store appears empty to the app; card copy stays neutral; existing rows intact; nothing claims denial | c | N/R |
| T11 | Bright-line audit | Inspect every screen, the chart, the card copy, notification text, the ingest payload and the Swift/SQL sources for thresholds, bands, zones, alerts, scores or value-mapped colour | Zero interpretive artefacts. Chart colours are fixed series identities; bounds are typo checks with fixed copy | e | Code audit PASS 2 Sep (§6); screen audit at walkthrough |
| T13 | Locked-store behaviour | Writer Save one NOW while the phone has been locked 10+ min, BP Reset backgrounded → wait → unlock → open | Deferred pass converges after unlock; anchor never advanced on a failed pass; reading appears once | c | N/R |
| T14 | Arming failure surfaced | Build BP Reset once with `Entitlements/BPReset-NoBackgroundDelivery` (copy the spike's variant), install, connect | Card reads "Connected. Background updates unavailable on this build."; foreground Sync still works | c | PASS on the sidecar 26 Aug (spike); N/R on the product |
| T15 | Client environment, synthetic | Full SQL test list against the client non-prod project: RLS positive and negative, consent gate, uniqueness replay, all-or-nothing behaviour of the RPC as deployed | All green; screenshots synthetic-only | b | N/R, needs the environment |
| T16 | Loan-cuff end to end, live | The T4 reading drains into the client non-prod project during the walkthrough | Row present; evidence is a UUID prefix and a count | b | N/R |
| T-L | Lifecycle | Sign out and back in as the same account; disconnect (hold) then connect again; sign in as a different account with readings queued | Same tuple re-configures as a no-op; hold keeps the queue and the card shows a held count; a different account triggers HOLD (nothing uploads, nothing discarded) | c | N/R |
| T-L2 | Held reclaim and discard | Account A captures → disconnect (hold) → account B signs in → A signs back in | A's held readings drain under A with zero crossing into B; discard requires explicit confirmation | c | N/R |
| T-EV | Evidence privacy audit | Review every retained artefact before it leaves the device | Synthetic or redacted values only | Model B | Running |

## 4. Fault matrix (subset that can be driven from the product and the harness)

| ID | Injection | Expected | Result |
|---|---|---|---|
| M1 | Writer: Save one BACKDATED 7 d | Imported once (the anchor catches what a timestamp watermark would miss) | PASS 26 Aug (spike); re-run in `spk1.sh` |
| M3/M4 | Kill the app between fetch and commit / mid-commit | Old-or-new generation, never mixed; nothing lost | `spk4.sh` + store self-test 12/12 |
| M5/M8 | Server commit then client failure before acknowledge | Rows reappear and replay into the RPC as `duplicates`, zero new rows | Needs Q6 confirmed |
| M7 | Three drain triggers at once (foreground + event + Sync) | One serialised drain | Code: `HealthModel.drain` mutex |
| M10 | Account switch with a pending queue | HOLD on every item | T-L |
| M12 | Corrupt `anchorData` | Anchor-only reset, config and queue preserved, re-import converges | `spk4.sh` |
| M14 | Reading with and without timezone metadata | Only metadata-backed zone and offset are sent; otherwise null (server default applies, Q7) | Writer "No timezone metadata" |
| M19 | Empty or malformed-only delta after bootstrap | Anchor still advances; malformed counted per source | Writer "Bare systolic" |

## 5. Re-taking the §11 spike on the 26.x handset (closes D-003)

Reader Q and the writer are installed beside the product. Grant reader Q's read access once by opening **BP spike** and tapping `requestAuthorization()`. Then, from `native/spike/`, with no cuff readings taken during the run:

```bash
./spk1.sh 5CD159C8-CD27-5F00-A3A4-3BE71F53669E
./spk2.sh 5CD159C8-CD27-5F00-A3A4-3BE71F53669E
./spk4.sh 5CD159C8-CD27-5F00-A3A4-3BE71F53669E
./spkclose.sh 5CD159C8-CD27-5F00-A3A4-3BE71F53669E
```

Pass criteria are printed at the end of each script. Step 0 of `spk1.sh` prints the environment block; on this handset it must read **EVIDENTIAL**. Record the outputs (prefixes and counts only) as an addendum to ADR-0006 and close D-003 in `docs/native/deviations.md`.

## 6. Bright-line code audit (T11, 2 September 2026)

Checked in the native app sources:

- `Features/Record/RecordViews.swift`: chart colours are `CColor.chartSeries1/2`, fixed per series, never a function of a value; the y domain derives from the data with padding and rounding, no clinical scale; the tooltip shows the recorded daily mean only; no `RuleMark` at a fixed value, no bands.
- `Data/Models.swift`: `Bounds` are the seed data-quality limits; the only copy they produce is "Please check this value." and "Systolic should be higher than diastolic."
- `Engine/`: `Mapper` checks finiteness, unit compatibility and structure only; `Diagnostics` holds counts and identifiers; the `Log` wrapper's value-carrying overloads are `unavailable`.
- `Health/HealthModel.swift`: the card reports connected, pending count, held count, rejected count and last drain time. No value, no verdict.
- `Copy/`: no word from the escalate list (diagnose, detect, treat, lower, reduce, control, manage, risk, warning, alert, abnormal, accurate) is used about a reading. Reminders are rhythm-only by copy and by design.
- No notification code exists yet (Stage 3); when it lands, the scheduler must never receive a reading object.

## 7. Results log

| Date | Test | Handset | Result | Notes (counts and codes only) |
|---|---|---|---|---|
| 2 Sep 2026 | T2 | iPhone18,3 / 23G83 | PASS | Sheet shown once; app proceeded |
| 2 Sep 2026 | T-A | iPhone18,3 / 23G83 | PASS | 1 manual row via `ingest_observations`, visible in `v_bp_readings` |
| 2 Sep 2026 | T4 shape (writer as source) | iPhone18,3 / 23G83 | PASS | 1 Apple Health row after foreground activation, source = writer bundle id |
| 2 Sep 2026 | T5a shape (writer, delayed save, locked) | iPhone18,3 / 23G83 | PASS | Row present on reopen without Sync |
| 2 Sep 2026 | T11 code audit | n/a | PASS | §6 |

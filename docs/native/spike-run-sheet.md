# §11 spike — on-device run sheet

One full day, on the frozen acceptance OS. Three bare SwiftUI targets, **no Capacitor**. The
spike settles **API shape only**; background-delivery mechanics are settled by the 48-hour
soak in P2, not here.

Record results directly into [`adr/ADR-0006-spike-outcome.md`](adr/ADR-0006-spike-outcome.md)
as you go. Evidence carries UUID prefixes, counts and error codes — never values (§4.2).

---

## Step 0 — Gates ✅ BOTH GREEN, 20 August 2026

- [x] **iPhone on iOS 26.6 or later.** Confirmed 20 Aug. **Still outstanding: the exact build
      number**, which goes in every evidence artefact (§3.5) and in ADR-0004's environment
      table. Settings → General → About → Software Version. Results against any other build
      are **void** — the 26.5 Blood Pressure authorisation sheet rendered blank/incomplete
      [R23], which is the whole reason the baseline is frozen.
- [x] **Omron chain verified (§9.4).** Confirmed 20 Aug: cuff readings taken on the Omron are
      landing in Apple Health on the dev iPhone. The chain below is what was exercised; it is
      kept here as the debug ladder for when it stops working, which the field reports say it
      will.
      **Model B note for everything downstream:** those are real readings on a real person's
      device, which §4.2 expressly permits. What it does not permit is any of them reaching a
      commit, an export, a log line, or a screenshot. From here on, spike evidence is UUID
      prefixes, counts and error codes only, and any capture that would show a value gets the
      writer app's synthetic data instead.

<details>
<summary>The §9.4 chain, retained as the debug ladder</summary>
      1. Pair the cuff in Omron Connect.
      2. Enable Apple Health sharing **inside Omron Connect** — it is off by default:
         *Contents → Add contents → Apple Health Data Sharing*, or
         *Profile → App Settings → Apple Health*.
      3. Grant its **write** permission in the Health sheet.
      4. Take a reading and confirm it appears in **Health → Browse → Heart → Blood Pressure**.
      - Transfer runs on Omron-app launch, or via iBeacon + location in background [R10].
        Post-iOS-26 field reports describe the handoff silently stopping until re-toggled or
        re-paired [R12].
- **Debug order when readings vanish, always:** cuff → Omron app? → Omron → Health? →
  Health → plugin? In that order. Vendor first.

</details>

- [x] **Xcode 26.x, device provisioned — done 26 Aug.** Xcode 26.6 (17F113), a personal free (sandbox)
      team, developer mode enabled, three targets signed and installed. Free team:
      profiles expire in 7 days — if a demo is near, rebuild that morning; 3 installed dev apps
      per device, which these three exactly consume.

## Step 1 — Three targets

| Target | Bundle ID | Auth read set | `NSHealthUpdateUsageDescription` |
|---|---|---|---|
| Reader **Q** | `dev.lucab.bpspike` | quantity-only (`systolic`, `diastolic`) | **absent** |
| Reader **C** | `dev.lucab.bpspikec` | correlation-inclusive | **absent** |
| **Writer** | `dev.lucab.bpwriter` | — (writes) | **present** — the only target that carries it |

Two reader bundles are non-negotiable: a single app's Health permission state contaminates the
SPK-3 A/B. Do not collapse them.

Free-team ceiling is 3 installed dev apps per device — this is exactly 3, no headroom.

All three carry `NSHealthShareUsageDescription`. Readers get the **HealthKit** capability;
background delivery is not needed for the spike (it is P2's subject), but arming the observers
in SPK-close requires the entitlement if you want registration to succeed — record which
configuration you ran.

## Step 2 — SPK-1 · resumable correlation anchor  ← **load-bearing**

1. Set configure-equivalent state with a real `importStart`.
2. Nil-anchor query with the **production predicate** `startDate ≥ importStart`.
3. Commit the anchor into the **actual `Envelope`/`EngineState` JSON** — not a scratch file.
4. **Terminate the process.**
5. Writer: save one **current** correlation and one **7-day-backdated** correlation.
6. Relaunch → `loadStrict()` → resume the anchored query.

**Pass:** both returned exactly once; a third query returns empty; the anchor survived the real
persistence path.

**Stop and report the moment this passes or fails.** Pass → Path A, continue through SPK-close
without waiting. Fail → Path B, stop and report with raw output before anything depends on it.

## Step 3 — SPK-2 · deletion characterisation **only**

Persist anchor → terminate → delete the current reading in the Health app → relaunch →
strict-load → resume with the production predicate.

Record: does the deleted set carry the **correlation** UUID? Does it repeat after the next
commit?

**Do not persist tombstones.** Deletions are out of V1 by decision (§8.3) — no tombstone
persistence, no dormant contract, the anchor advances past deletion events. This step feeds
the §8.3 reconciliation fast-follow design and nothing else.

## Step 4 — SPK-3 · authorisation sets, Q vs C

Same device, same OS, two clean identities. For each reader: `statusForAuthorizationRequest`
before → sheet (does it appear; which Blood Pressure controls does it show) → after → a
correlation query → both quantity observer registrations → error codes.

**Pass:** the chosen minimal quantity-only set authorises correlation reads and observer
registration cleanly. Any divergence amends `BPTypes.authorizationRead` in §7.4 **and only
there**, recorded in ADR-0004 and `deviations.md`. The spike wins over the document.

## Step 5 — SPK-4 · state store and anchor survival

1. Write the full production-shaped two-generation store → terminate → relaunch → strict-load
   → resume.
2. Inject one corrupt `anchorData` → verify the **anchor-only** reset: `anchorData` +
   `bootstrapComplete` cleared, queue/config/observation/diagnostics preserved, reason code
   recorded, bounded `importStart` re-import runs in foreground.
3. Corrupt the **newest** generation file → verify fallback to the previous valid generation
   (M17).
4. Corrupt **both** → verify hard `INTERNAL`, never silent re-init.

## Step 6 — SPK-close · end-to-end mini-loop

configure → authorise (set Q) → install both quantity observers → anchored query → commit
anchor + payload into the store → terminate → writer: one current insert, one backdated
insert, one deletion → relaunch → resume.

**Pass:** exact correlation UUIDs, no repeats after commit, deletion characterised.

## Step 7 — SPK-extra · bundle-ID authorisation persistence *(added, ~5 min)*

Delete `dev.lucab.bpspike` → reinstall → `statusForAuthorizationRequest` → `requestAuthorization`.
**Does the sheet return?**

Why: §9.2 gives the Capacitor harness the *same* bundle ID as this spike reader, so the harness
inherits its Health permission identity — while T2 requires the sheet exactly once on a fresh
install. If the sheet does not return, the harness needs its own throwaway ID and that is a
DEVIATION against §9.2. Cheapest possible answer to a question we would otherwise guess at.

## Step 8 — Close out, same day

- [x] **ADR-0004 filled, 26 Aug — Path A accepted.** Device `iPhone17,2`, iOS 27.0 build
      `24A5424a`, per-SPK results recorded. Carries a `BASELINE-MISMATCH` callout: the handset
      is a different OS generation from the validated 26.x baseline (D-003).
- [x] **`docs/native/deviations.md` updated.** Three deviations (D-001, D-002, D-003); S1 closed by
      SPK-extra; S2 confirmed on the acceptance device and owed a §2.1 / §11 amendment.
- [x] **Artefacts audited (T-EV).** Everything emitted by the run is UUID prefixes, counts,
      states and error codes. No reading value appears in the ADR, the logs, or any artefact —
      the `Log` wrapper's value-carrying overloads are `unavailable`, so a slip is a compile
      error rather than a review finding.
- [ ] **Still owed:** the §9.4 Omron chain on *this* handset (only `com.withings.wiScaleNG` is
      present), and the SPK-3 operator observation — which Blood Pressure controls the sheet
      displayed.

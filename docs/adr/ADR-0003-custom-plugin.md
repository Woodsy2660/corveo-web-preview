# ADR-0003 — Build a custom Capacitor HealthKit plugin rather than adopt a community one

- **Status:** Accepted
- **Date:** 18 August 2026
- **Phase:** P0 (§12 Phase 0 — "File ADR-0003")
- **Decider:** Luca (native/mobile lane), under guide v1.3
- **Supersedes / superseded by:** —

## Context

Deliverable #2 (SOW cl. A.3) is a native Swift HealthKit plugin with four named behaviours:
authorisation flow, observer query **with background delivery**, source de-duplication, and
denied-permission handling. Deliverable #3 is Apple Health auto-sync from validated cuffs,
demonstrated on a physical device against a written test script.

Several community Capacitor HealthKit plugins exist [R13, R14]. The question is whether any
of them discharges those four behaviours, or whether adopting one would leave the load-bearing
parts to be written anyway — inside somebody else's architecture.

## Decision

Build the plugin in this lane, client-named `com.corveo.bphealthkit` from day one (§4.3),
sources delivered into the client's repository.

## Rationale

The surveyed plugins centre on **foreground fitness reads** — steps, workouts, heart rate —
fetched on demand while the app is open [R13, R14]. This design's hard requirements are
somewhere else entirely:

1. **Blood pressure is a correlation**, not a quantity sample. It requires
   `HKCorrelationType(.bloodPressure)` handling with exactly-one-systolic /
   exactly-one-diastolic structural validation. Quantity-oriented plugins do not model it.
2. **Background delivery + observer queries** with an absolute, exactly-once completion-handler
   obligation [R4]. This is the single most failure-prone surface in the design and it is not
   a feature the surveyed plugins carry.
3. **Source de-duplication** across vendor apps and a manual path, with a durable anchor
   cursor and a bootstrap rule (§5.3).
4. **Denied-permission handling** where denial is indistinguishable from an empty store [R13] —
   requiring the heuristic UX and the bootstrap rule rather than a status check.
5. **A durable, file-protected, backup-excluded two-generation state store** (§10) holding
   health payloads pending upload. No community plugin owns persistence of this shape, and
   the Model B data-handling rules (§4.2) constrain it in ways a general-purpose plugin
   would not anticipate.

Adopting a community plugin would mean writing all five of these inside a dependency whose
release cadence, permission model and error surface we do not control, then defending that
seam at Stage 2 acceptance. The integration risk exceeds the build.

## Consequences

- **Accepted:** the full 15–18 developer-day estimate (§18) sits in this lane; bus factor is
  a named risk with the document + ADRs as mitigation (§16).
- **Accepted:** we own every HealthKit behaviour, including the ones Apple documents poorly.
  Mitigated by the guide's standing rule — uncertain runtime behaviour gets the smallest
  on-device experiment, never a guess from training data or forum folklore.
- **Gained:** the bridge contract (§7) is ours to freeze, which is what makes integration
  without a meeting possible (§17).
- **Gained:** the read-only posture is structural — no `NSHealthUpdateUsageDescription`
  anywhere in plugin or harness — rather than a property of a dependency we would have to
  audit each upgrade.

## References

[R4] HealthKit background-delivery architecture; completion-handler requirement.
[R13] Community plugins; denied reads look empty.
[R14] Community-plugin survey.

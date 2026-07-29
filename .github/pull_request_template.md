# Pull Request

## Summary

<!-- One or two sentences describing what this PR does -->

## Changes

<!-- Bullet list of changes -->

## Test plan

<!-- How was this tested? -->

---

## Build Constraints Checklist

> These constraints are contractual (SOW A.3.3, A.13.5). Tick each honestly before requesting review.

### The Solution must not:

- [ ] Interpret a reading, or classify it as high, normal or low
- [ ] Apply a clinical threshold, colour zone or band
- [ ] Raise an alert or notification whose content depends on a reading value
- [ ] Calculate a risk score, heart-age or equivalent metric
- [ ] Transmit a reading to a clinician for monitoring
- [ ] Use traffic-light colours anywhere in the interface

### Additional constraints:

- [ ] No third-party analytics, crash reporting or telemetry SDKs added (requires D.5 disclosure and Andrew's sign-off)
- [ ] Validation copy is mechanical, never evaluative (e.g. "Please check this value" is fine; "That reading is very high" is a breach)

---

## Review requirements

- [ ] PRs touching `supabase/migrations/` require Ben's review
- [ ] PRs touching `ios/` require Luca's review

# Native / mobile lane — what this branch adds

Branch `native/healthkit-lane`, based on `main`. Owner: Luca. Nothing here touches the front
end, so it should merge without meeting `frontend/foundation` in a conflict.

## What is here

| Path | What it is |
|---|---|
| `docs/native/BP-Reset-HealthKit-Implementation-Guide-v1.3.md` | The build specification. v1.3 FINAL, 18 Aug, after three adversarial review rounds ending in GO. Self-contained: architecture, bridge contract, state machine, backend migration, test script, integration spec. |
| `docs/native/plugin-bridge-spec.md` | §7 of the guide, published as the frozen bridge contract. **Read the integration review before coding against it.** |
| `docs/native/integration-review-frontend-foundation.md` | C1–C20. The front end is built against a different, older plugin contract. This is the reconciliation. |
| `docs/native/spike-run-sheet.md` | Ordered on-device run sheet for the §11 spike. Both gates now cleared. |
| `docs/native/deviations.md` | Deviations log. One so far: D-001, the estimate revision. |
| `docs/adr/ADR-0003-custom-plugin.md` | Why a custom plugin rather than a community one. Accepted. |
| `docs/adr/ADR-0006-spike-outcome.md` | Spike outcome. **Template — the spike has not run yet.** |
| `db/migrations/000–004.sql` | The backend contract, executable. Verbatim §13. |
| `db/tests/` | 15 tests covering everything §13 requires, plus harness and runner. |

## Two things to know before using any of it

**1. The bridge spec is frozen on the native side but not agreed across lanes.** The front end
is coded against `docs/03-plugin-bridge-spec.md` v0.1 (29 July, DRAFT), and the two interfaces
share no method signature beyond `startObserving`/`stopObserving`. That document's own open item
P-01 — *"Freeze this interface with Luca before implementation hardens. Blocks: Everything"* —
was never actioned. **C1 (who uploads) and C15 (batch semantics) decide what actually gets
built**, and both sit above this lane. See the integration review.

**2. `db/migrations/` does not fit this project's schema as written.** It assumes an
`enrolments` table and a flat observations row. `docs/02-data-model-and-api.md` has neither —
it has `app_user` and a parent/child `observation` + `observation_component` model. That
answers open decision D3, in the awkward direction. What survives translation regardless is
the privilege chain (invoker ingest with server-side binding, guarded definer canonicalisation,
EXECUTE checked against the calling role) and the shape of the test suite. **Do not apply these
migrations as-is; read the review first.**

## Verifying the SQL extraction

`db/migrations/00*.sql` is a verbatim extract of guide §13, not a retyping. It reproduces:

```bash
sed -n '797,997p' docs/native/BP-Reset-HealthKit-Implementation-Guide-v1.3.md | sha256sum
cat db/migrations/00*.sql | sha256sum
# both: 3b4af7126599515ef6551b30f402477ba941f55b30c3e6a7e26fa3d0ccd57db9
```

`.gitattributes` on this branch pins LF for `*.sql` and `*.md` so that check reproduces on a
clone from any platform.

## Two deliberate departures from the guide's §17.1 manifest

- **Paths.** The manifest puts the bridge spec at `docs/plugin-bridge-spec.md`. `docs/` already
  carries a numbered scheme owned by other lanes, and a second bridge spec sitting beside
  `03-plugin-bridge-spec.md` would be actively confusing given they disagree. Native lane docs
  therefore live under `docs/native/`. ADRs stay in the shared `docs/adr/`.
- **ADR numbering.** The guide calls the spike outcome ADR-0004, written before tracker entries
  0004 and 0005 existed. The tracker series wins, so it is filed as **ADR-0006**. References to
  "ADR-0004" inside the frozen guide mean that document.

## What is deliberately not here

The Apple Health demo surface — the iOS permission sheet, the sync card, and the Behind the
Scenes presentation — is front-end work and belongs on `frontend/presentation`, not on this
branch. A round of changes to it from 20 Aug is still outstanding and needs replaying onto the
foundation tip rather than merging from a stale base.

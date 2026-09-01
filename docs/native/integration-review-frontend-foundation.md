# Integration review — front-end foundation vs guide v1.3

**Date:** 19 August 2026 · **Reviewer:** Luca (native/mobile lane) · **Subject:**
`Demo/Corveo-IOS-App-frontend-foundation` (Michael's lane, plus the project-level
architecture and data-model docs)

**Read this first:** the front-end foundation is built against a **different plugin contract
and a different backend schema** from guide v1.3. Neither side did anything wrong — their
`docs/03-plugin-bridge-spec.md` is **v0.1 DRAFT, dated 29 July 2026**, and its own open item
**P-01 says "Freeze this interface with Luca before implementation hardens — Blocks:
Everything."** Guide v1.3 is dated 18 August and is the output of three adversarial review
rounds that specifically killed several things the July draft assumes. P-01 is the mechanism
for exactly this conversation. This document is the input to it.

Nothing here is a criticism of Michael's build. The React foundation is careful work and it
passes the bright-line audit (§4 below), which is the part that is contractually hardest.

---

## 1. What their code already assumes about my lane

`src/lib/health/index.ts`:

> *"LUCA: when the native plugin lands, replace the web branch with Capacitor's
> `registerPlugin("CorveoHealth")` — the interface in `./types.ts` is the frozen contract,
> so no screen changes are needed."*

`src/lib/health/types.ts` is a verbatim copy of their §3 interface. Decision **F-02** records
the plan as *"Integration is a one-file change."*

**That is true only if the two interfaces match. They do not overlap on a single method
signature** beyond `startObserving`/`stopObserving`/`addListener` names. As it stands,
swapping in my plugin makes every screen that touches health data fail at runtime.

Two smaller drifts inside their own lane, worth fixing regardless of how this resolves:

- `types.ts` declares `HealthErrorCode` including `INGEST_REJECTED`, but their §8 table
  defines `UPLOAD_REJECTED`, `UPLOAD_FAILED`, `HEALTHKIT_UNAVAILABLE` and `QUERY_FAILED`,
  none of which appear in the type. The "verbatim copy" has already diverged from its source.
- `ios/Plugins/CorveoHealthPlugin/` vs my package `com.corveo.bphealthkit` / class
  `BPHealthKit`. The `registerPlugin` string must match the Swift `@objc` plugin name exactly —
  this is the cheapest possible integration failure to hit and to fix.

---

## 2. Plugin contract — §7 (v1.3, frozen) vs `03-plugin-bridge-spec.md` §3 (v0.1, draft)

| # | Concern | Guide v1.3 §7 | Front-end foundation §3 | Verdict |
|---|---|---|---|---|
| C1 | **Who uploads** | JS drain, in an authenticated foreground session. Token custody stays in the JS tier for Model B auditability. Background wakes commit locally only. | **Native plugin uploads directly to Supabase during background wakes**, holding refresh tokens in Keychain and refreshing autonomously (A-03, §2, §6.3). | **Load-bearing conflict. Decision needed.** Not a merge — one of the two is built. |
| C2 | **Durability model** | Durable two-generation, file-protected, backup-excluded on-device queue (§10). Anchor advances after **every** successful query post-bootstrap. | **"There is no local queue. HealthKit is the queue."** Anchor advances **only after a 2xx** (A-02, §2.1). | **Load-bearing conflict.** Follows directly from C1. |
| C3 | **Configuration / binding** | `configure({enrolmentRef, importStart})` — one immutable tuple; `CONFIG_CONFLICT` on any difference; `disconnectAndReset` is the only exit. | `setCredentials({accessToken, refreshToken, userId, projectUrl, anonKey})` / `clearCredentials()`. | No overlap. Falls out of C1. |
| C4 | **Backfill bound** | `importStart` — the **server** enrolment timestamp. Bounds every query forever. | **Rolling 30 days**, build constant (§9). | v1.3 is strictly safer: on a six-week program a 30-day window silently truncates weeks 1–2 on any reinstall. Recommend `importStart` regardless of how C1 lands. |
| C5 | **Timezone provenance** | `HKMetadataKeyTimeZone` or **null**. Never `TimeZone.current`. UI drops the "local time of reading" claim when null (§7.1, pitfall 14). | `effective_tz` ← metadata, *"fall back to device tz"* (§5.4). Their `BpReadingRow.effective_tz` is non-nullable. | **I believe theirs is a defect**: device-TZ fallback fabricates provenance that reads as recorded fact. Recommend v1.3's rule; needs a nullable `effective_tz`. |
| C6 | **Read set** | `{bloodPressureSystolic, bloodPressureDiastolic}` — chosen minimal set; SPK-3 records observed behaviour. | Adds **`heartRate`** and the correlation type (§5.1). | `heartRate` is outside the sixteen contracted deliverables and asks the patient for a permission V1 never uses. Recommend dropping until SPK-3 says otherwise. |
| C7 | **Observer registration** | Both quantity types. | **systolic only**, as trigger (§5.2). | Low impact; v1.3 is belt-and-braces. Their §5.2 reasoning ("trigger on the part, read the whole") is sound and matches v1.3 — v1.3 just observes both parts. |
| C8 | **Deletions** | **Out of V1 by explicit decision** (§8.3). Reconciliation fast-follow specified. | **In scope**: three UUIDs stored, `deleted_source_uuids`, soft delete, audit, test 9. | Scope difference, and theirs is *more* work. §8.3 exists because deletion capture via anchors was the trap round one identified. Needs an explicit call. |
| C9 | **Acknowledgement** | `itemId` + `snapshotId` generation; `SNAPSHOT_STALE`; whole-snapshot ack sound only because ingest is all-or-nothing. | No concept — the native side acks implicitly by advancing the anchor. | Falls out of C1/C2. |
| C10 | **Permission states** | `notRequested \| requested` | `notDetermined \| requested \| unknown` | Trivially reconcilable. **Both honour the never-report-denied rule**, independently derived. Their `unknown` (requested but no samples ever) is a genuinely useful third state — recommend adopting it into §7. |
| C11 | **Error codes** | 11 codes (§7.2) | 10 different codes (§8) | Reconcilable once C1 is decided; most codes only exist because of the upload location. |
| C12 | **Toolchain / OS** | Xcode 26.x, Node 22 LTS, **iOS 26.6+ frozen acceptance OS** (§3.5, the 26.5 BP-sheet regression). | `.xcode-version` **16**, `.nvmrc` **20**, README says iOS 16+. | Must reconcile: Capacitor 8 requires Xcode 26.0+ and Node 22+, and Stage 2 evidence is only valid on 26.6+. Their `package.json` (React 19 / Vite 8 / TS 5.9) is fine and unaffected. |

---

## 3. Backend contract — §13 vs `02-data-model-and-api.md`

This is the larger of the two collisions, and it **answers open decision D3**.

D3 was registered as *"Enrolments table shape (§13 assumes `enrolments(id, patient_id,
auth_user_id, program_start, …)`)"*. The answer is now visible: **their data model has no
`enrolments` table at all.** It has `app_user`, `consent_event`, `program_progress`,
`observation`, `observation_component`, `observation_definition`, `audit_event`.

Consequences for the migration I committed yesterday:

| # | Concern | Guide §13 | Their `02-data-model` | Verdict |
|---|---|---|---|---|
| C13 | **Table shape** | One flat `observations` table with `systolic`/`diastolic` numeric columns. | **Parent/child**: `observation` + `observation_component`, LOINC-coded, FHIR AU Core aligned (A-05). BP = one parent, two components. | §13's DDL does not fit. Theirs is the better model for the contract — A.3.4 requires a generic, migration-safe observation model. |
| C14 | **Ingest RPC** | `ingest_bp_batch(p_enrolment_ref uuid, p_rows jsonb) → (inserted, duplicates)` | `ingest_observations(payload)` → `{inserted, duplicates, soft_deleted, rejected[]}` (A-04) | Different name, arguments, return. |
| C15 | **Batch semantics** | **All-or-nothing** — any invalid row raises and rolls back the whole call. | **Per-item rejections**, *"never fatal to the batch"*. | **Directly opposed.** My whole-snapshot `acknowledge` is sound *only because* success means every row is inserted-or-duplicate. Under per-item rejection, acking a whole snapshot silently drops the rejected rows. If theirs wins, the drain must ack per item — a real change to §12 P4, not a rename. |
| C16 | **Identity / binding** | `enrolmentRef` → `patient_id` resolved against `auth.uid()` inside the RPC. | `user_id` from `app_user`, RLS on `auth_user_id`. No enrolment concept. | **D3 answered.** `enrolmentRef`/`importStart` have no home. Either their schema gains an enrolment row, or v1.3's binding model is re-expressed against `app_user` + program start. |
| C17 | **Dedup key** | `unique (patient_id, client_uuid)` | `(user_id, source_system, source_uuid)` | Theirs is stronger — it survives two source apps minting the same UUID. Recommend theirs. |
| C18 | **Consent gate** | None. | Missing consent → `CONSENT_REQUIRED`, **whole call rejected** (§4.2, §3.3). | My drain has no consent branch. It needs one — and note the interaction: a consent-rejected batch must **not** be acknowledged, or the queue empties into nothing. |
| C19 | **Canonicalisation** | Layer 2: `superseded_by` clustering, total preference order, ±3 min window (§8.2). | **Not present.** Their §12 explicitly defers near-duplicate detection between HealthKit and manual as out of scope. | v1.3 adds a concept their schema lacks. This is the D2 open decision, and their doc has already decided it the other way. |
| C20 | **Deletions** | No V1 deletion path; `deleted_at` reserved. | `deleted_source_uuids`, `deleted_reason`, soft delete, `audit_event` per state change (A-06). | Follows C8. |

**Practical consequence:** the `db/migrations/` package I committed is a *correct implementation
of §13* and a *poor fit for this project's actual schema*. Do not send it to Ben as-is without
this document attached. The parts that survive translation regardless are the **privilege
chain** (B3: invoker ingest with server-side binding, definer canonicalisation with an
ownership guard, the EXECUTE-against-calling-role rule) and the **test suite's shape** — those
lessons apply to `ingest_observations` unchanged.

---

## 4. Bright-line audit of their code — PASS

I audited the surfaces most likely to breach SOW A.3.3. Findings:

| Surface | Result |
|---|---|
| `src/components/ui/BpChart.tsx` | **Clean.** Fixed categorical series colours (systolic always series-1, diastolic always series-2), never mapped to value. No thresholds, zones, bands, target ranges or evaluative annotations. Y-axis derives from the data, not from a clinical scale. Tooltip shows recorded values only. Matches decision F-05, which reasons about A.3.3 correctly. |
| `src/lib/api/bounds.ts` | **Clean.** 60–260 / 30–160 plus systolic>diastolic — mechanical typo bounds, explicitly documented as input validation, not interpretation. Consistent with guide §4.1, which assigns data-quality bounds to the front-end lane. |
| `docs/01-system-architecture.md` §2 | **Stronger than guide §1.1 in one respect** — it adds *"no traffic-light colours anywhere in the interface"*, which forecloses an argument before it starts. Recommend adopting the phrasing into our own constraint list. |
| Their test 14 | Equivalent to guide T11. Both treat the no-interpretation audit as a contractual acceptance criterion, not a checklist item. |

**One observation, not a finding:** `v_bp_trend` exposes daily `min`/`max`/`mean`. Aggregation
is not evaluation, so I read this as inside the line — but it is a *derived* field, and guide
§4.1 says payloads carry "no derived fields". The distinction (payload vs display aggregate)
is defensible; worth naming to Nick so it is a decision on the record rather than a diff
someone queries at acceptance.

---

## 5. What I recommend

1. **Trigger P-01 now, in writing** — the open item their own doc says blocks everything. Put
   C1 (who uploads) and C15 (batch semantics) in front of the engagement lead as the two
   decisions that change what gets built. Everything else follows from those two.
2. **Adopt from their side, regardless of C1:** the parent/child observation model (C13), the
   `(user_id, source_system, source_uuid)` dedup key (C17), the `unknown` permission state
   (C10), the consent gate (C18), and the no-traffic-light constraint wording.
3. **Hold from v1.3, regardless of C1:** `importStart` over a rolling 30-day window (C4),
   metadata-or-null timezone (C5), the quantity-only read set until SPK-3 says otherwise (C6),
   deletions out of V1 (C8), and the B3 privilege chain (invoker ingest + guarded definer).
4. **Do not resolve C1 in code.** It is an architecture decision with a Model B dimension
   (where refresh tokens live) and it is above this lane. Their §13 open item P-04 —
   *"Confirm background upload reaching Supabase on wake is acceptable to Andrew"* — is
   unresolved on their side too, which means **nobody has cleared native background upload
   with the client.** That is the single most important sentence in this review.
5. **The spike is unaffected.** SPK-1..4 settle HealthKit API shape — the anchored cursor, the
   authorisation set, the state store. Every one of those results is needed under either
   architecture. Phase 0 proceeds unchanged.

---

## 6. Registered as open items

Added to `docs/deviations.md` as **C1–C20**, kind *conflict*, all owned above this lane.
None is a deviation yet — a deviation is when we build something different from the frozen
spec. Right now we have two frozen-ish specs disagreeing, which is a decision, not a drift.

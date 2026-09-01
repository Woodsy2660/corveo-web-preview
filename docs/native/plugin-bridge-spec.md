# Plugin Bridge Spec — BP Reset V1 native HealthKit lane

**Status: FROZEN for integration (bridge contract v1.2, carried unchanged into guide v1.3).**

Verbatim extract of §7 of `BP-Reset-HealthKit-Implementation-Guide-v1.3.md` (lines 267–437).
Published per §12 Phase 0. This file is the integration surface for Michael's lane;
it is a copy, not a fork — the guide remains the source of truth and any change lands
there first, then here, with a note in `docs/deviations.md`.

Related: error model and `toRows` mapping table live in §17.3 of the guide.

---

# The bridge contract (v1.2 — frozen for integration)

## TypeScript definitions

```typescript
import type { PluginListenerHandle } from '@capacitor/core';

/** One HealthKit-path reading. Manual entries do NOT pass through the plugin;
 *  the shared BACKEND row contract is §13. */
export interface BPReading {
  itemId: string;            // native queue identity — the ACK key
  hkUuid: string;            // HealthKit CORRELATION UUID — backend idempotency key
  enrolmentRef: string;      // binding stamped at commit (§6.1)
  systolic: number;          // mmHg, as recorded; no rounding, no evaluation
  diastolic: number;         // mmHg
  takenAt: string;           // ISO-8601 UTC instant of the reading
  tzOffsetMinutes: number | null; // ONLY from HKMetadataKeyTimeZone; null when
                                  // absent — never fabricated from device TZ.
                                  // UI fallback: render in viewer's local time
                                  // and omit the "local time of reading" claim.
  sourceBundleId: string;
  sourceName: string;
  deviceModel?: string;
  receivedAt: string;        // set ONCE at first durable commit; persisted
}

export type PromptStatus = 'notRequested' | 'requested';
// iOS never reveals whether READ access was granted or denied.

export type EngineState =
  | 'unconfigured' | 'configuredDisabled' | 'configuredEnabled'
  | 'armFailed' | 'resetting';

export interface Status {
  state: EngineState;
  promptStatus: PromptStatus;
  pendingCount: number;      // active queue (current enrolment)
  heldCount: number;         // total items across all held buckets (§6.3)
  held: { enrolmentRef: string; count: number }[];  // per-bucket; refs are
                                                    // opaque UUIDs, no values
  bootstrapComplete: boolean;
  lastArm?: { ok: boolean; at: string; errorCode?: string };
}

export interface CatchUpResult {
  queued: number;            // newly committed this pass (count only)
  deferred: boolean;         // true when HK_TEMP_UNAVAILABLE deferred the pass
  bootstrap: boolean;        // true while the bootstrap rule is active (§5.3)
}

export interface Snapshot {
  snapshotId: string;        // generation token; ack validates it
  readings: BPReading[];     // ALL unacknowledged items for the ACTIVE enrolment
  heldCount: number;
}

export interface AckResult { removed: number; alreadyAbsent: number; }

export interface BPHealthKitPlugin {
  isAvailable(): Promise<{ available: boolean }>;
  getStatus(): Promise<Status>;

  /** Sets the immutable tuple. Identical tuple: idempotent no-op.
   *  Any difference: rejects CONFIG_CONFLICT (route via disconnectAndReset). */
  configure(opts: { enrolmentRef: string; importStart: string }): Promise<void>;

  /** The ONLY exit from a configured tuple. Atomic; see §6.3 semantics.
   *  'confirmedDiscard' REQUIRES prior explicit user confirmation in the UI. */
  disconnectAndReset(opts: {
    pendingPolicy: 'holdForReauth' | 'confirmedDiscard';
  }): Promise<void>;

  /** System permission sheet (first time only). Resolves when dismissed;
   *  NEVER rejects on user denial — denial is not observable. */
  requestAuthorization(): Promise<void>;

  /** Arms observers + background delivery for both quantity types.
   *  Registers observers first, then awaits BOTH enablement results;
   *  rejects BG_DELIVERY_FAILED if either fails (state -> armFailed,
   *  foreground catch-up unaffected). Sets desiredObservationEnabled. */
  startObserving(): Promise<void>;

  /** Full teardown, on the executor (B4): calls HKHealthStore.stop on each
   *  executed observer query, awaits disableBackgroundDelivery for BOTH
   *  quantity types, clears the observer list, persists
   *  desiredObservationEnabled=false. Serializes behind in-flight catch-up:
   *  no post-stop commit can land after this resolves. Existing queue
   *  remains drainable via getPendingSnapshot (NO new capture). */
  stopObserving(): Promise<void>;

  /** Performs an anchored catch-up NOW if state is configured+enabled and
   *  the store is reachable. Never runs while disabled (no new capture
   *  after stopObserving) — returns { queued: 0, deferred: false } then.
   *  HK_TEMP_UNAVAILABLE (locked store) -> { deferred: true }, retried
   *  automatically on unlock/foreground/next wake. */
  runCatchUp(): Promise<CatchUpResult>;

  /** Pure queue read (ACTIVE enrolment). No HealthKit access; works while
   *  disabled or locked. Generation contract (B2): snapshotId is stable
   *  across reads, and is invalidated by EVERY queue/held mutation —
   *  enqueue, acknowledge-removal, hold, reclaim, discard. */
  getPendingSnapshot(): Promise<Snapshot>;

  /** Pure read of one HELD bucket (B1). Same Snapshot shape and generation
   *  contract; readings carry the held bucket's enrolmentRef, so the
   *  drain's binding check works unchanged. HELD_NOT_FOUND if absent. */
  getHeldSnapshot(opts: { enrolmentRef: string }): Promise<Snapshot>;

  /** Explicit destructive exit for a held bucket (B1). REQUIRES prior
   *  user confirmation in the UI; confirmed must be literal true.
   *  HELD_NOT_FOUND if absent; CONFIRM_REQUIRED otherwise. */
  discardHeld(opts: { enrolmentRef: string; confirmed: true }): Promise<void>;

  /** Removes exactly the given items from the given snapshot generation —
   *  active queue or held bucket, resolved by itemId (ULIDs are globally
   *  unique). Idempotent per item; the removal itself advances the
   *  generation (B2). A stale snapshotId rejects SNAPSHOT_STALE —
   *  caller re-snapshots and retries. */
  acknowledge(opts: { snapshotId: string; itemIds: string[] }): Promise<AckResult>;

  /** HINT ONLY. Fired after a catch-up that queued items and re-fired on
   *  bridge-ready when the queue is non-empty. The drain runs
   *  unconditionally on bridge-ready and foreground regardless (§12 P4). */
  addListener(
    eventName: 'bpReadingsAvailable',
    listener: (data: { count: number }) => void,
  ): Promise<PluginListenerHandle>;
}
```

## Error model

| Code | Meaning | Caller behaviour |
|---|---|---|
| `HK_UNAVAILABLE` | No HealthKit store | Manual-only mode |
| `CONFIG_MISSING` | catch-up/observe before `configure()` | Fix call order |
| `CONFIG_CONFLICT` | `configure()` with a different tuple (either field) | Route via `disconnectAndReset` |
| `PROMPT_PENDING` | `runCatchUp` before `requestAuthorization` ever ran | Route to connect step |
| `BG_DELIVERY_FAILED` | Arming failed (entitlement/profile); state → `armFailed` | Show "background updates unavailable"; foreground refresh works |
| `HK_TEMP_UNAVAILABLE` | Store locked (`errorDatabaseInaccessible`); pass deferred | Transparent; snapshot/drain unaffected |
| `SNAPSHOT_STALE` | `acknowledge`/`ack` against a superseded generation (any mutation since) | Re-snapshot, retry |
| `HELD_NOT_FOUND` | `getHeldSnapshot`/`discardHeld` for an unknown bucket | Refresh `Status.held` |
| `CONFIRM_REQUIRED` | `discardHeld` without literal `confirmed: true` | UI confirmation first |
| `QUERY_FAILED` | Other HealthKit error (code only) | Retry affordance; report if persistent |
| `INTERNAL` | State-store fault incl. both generations invalid (§10) | Hard-report; never silent re-init |

Arming before authorisation is defined behaviour (observers may exist pre-sheet; they deliver nothing until data is readable); `PROMPT_PENDING` applies only to `runCatchUp`.

## Payload and validation rules

`hkUuid` is the backend idempotency key for HealthKit rows; manual entries use a client UUIDv4 in the same column — one uniqueness constraint covers both (§13). `itemId` is a native ULID assigned at commit and exists solely for snapshot-safe acknowledgement. `receivedAt` is assigned exactly once at first commit; informational only — **all backend ordering uses server-side `ingested_at` then `id`** (§8.2). **Structural validation (never clinical)** before commit and again at ingestion: exactly one systolic + one diastolic child; both finite; unit convertible to mmHg; `takenAt` parseable and ≥ `importStart`; UUID present. Failures are not queued; a **count-by-source** diagnostic map (`malformedBySource: [bundleId: count]`) is persisted — counts and identifiers only, never values.

## Canonical type contract

```swift
enum BPTypes {
    static let systolic    = HKQuantityType(.bloodPressureSystolic)
    static let diastolic   = HKQuantityType(.bloodPressureDiastolic)
    static let correlation = HKCorrelationType(.bloodPressure)
    static let mmHg        = HKUnit.millimeterOfMercury()
    /// CHOSEN MINIMAL SET. Correlation types are also legal in read sets per
    /// Apple's API contract [R24]; SPK-3 records observed behaviour of both
    /// sets on the frozen acceptance OS. If SPK-3 shows the quantity-only set
    /// under-authorises, amend HERE and only here (ADR-0006 records why).
    static let authorizationRead: Set<HKObjectType> = [systolic, diastolic]
    /// Wake signals + background delivery register per QUANTITY type.
    static let observed: [HKSampleType] = [systolic, diastolic]
    /// The incremental cursor targets the CORRELATION type.
    static let fetched: HKSampleType = correlation
}
```

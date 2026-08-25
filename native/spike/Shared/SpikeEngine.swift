import Foundation
import HealthKit

/// The §11 spike engine: production-shaped, no Capacitor.
///
/// Every read, commit and observer-list mutation happens on the single executor
/// (`work`) — guide §12 P2 / pitfall 16. HealthKit's own callbacks are awaited off the
/// executor; only state touches go back onto it.
///
/// The spike settles **API shape only**. Background-delivery mechanics are settled by the
/// 48-hour soak in P2, not here.
final class SpikeEngine: @unchecked Sendable {

    static let shared = SpikeEngine()

    enum Trigger: String {
        case foreground, backgroundWake, retry, manual, relaunch
    }

    struct Delta {
        let readings: [MappedReading]
        let malformedBySource: [String: Int]
        /// SPK-2 characterisation ONLY. Deletions are out of V1 by decision (§8.3):
        /// no tombstone persistence, no dormant contract, the anchor advances past them.
        let deletedUuids: [String]
        let newAnchorData: Data?
        let returnedSampleCount: Int
    }

    struct CatchUpOutcome {
        var queued = 0
        var deferred = false
        var bootstrap = false
        var returned = 0
        var malformed = 0
        var deleted = 0
        var anchorCommitted = false
        /// Evidence alphabet: UUID prefixes only, never values (§4.2).
        var uuidPrefixes: [String] = []
        var deletedUuidPrefixes: [String] = []
    }

    private let health = HKHealthStore()
    private let work = DispatchQueue(label: "bp.healthkit.engine")
    private let workKey = DispatchSpecificKey<Bool>()
    let store = StateStore()

    private var observers: [HKObserverQuery] = []
    private var catchUpInFlight = false
    private(set) var catchUpPending = false
    private(set) var loadFault: BPError?

    private init() {
        work.setSpecific(key: workKey, value: true)
    }

    // MARK: - Executor discipline

    private func onExecutor<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: workKey) == true { return try body() }
        return try work.sync(execute: body)
    }

    private func read<T>(_ body: (EngineState) -> T) -> T {
        onExecutor { body(store.current) }
    }

    @discardableResult
    private func mutate<T>(_ body: (inout EngineState) throws -> T) throws -> T {
        try onExecutor { try store.commit(body) }
    }

    // MARK: - Launch

    /// Strict-load, then apply anchor-recovery trigger (a): secure-unarchive failure of
    /// `anchorData` at load clears `anchorData` + `bootstrapComplete` ONLY.
    func loadAtLaunch() {
        onExecutor {
            do {
                try store.loadStrict()
                loadFault = nil
            } catch let e as BPError {
                loadFault = e                       // INTERNAL — surfaced, never auto-reset
                Log.event("engine.load.internal", code: e.code)
                return
            } catch {
                loadFault = .internalFault("LOAD_FAILED")
                return
            }
            if let data = store.current.anchorData, decodeAnchor(data) == nil {
                try? store.commit { st in
                    st.anchorData = nil
                    st.bootstrapComplete = false
                    st.anchorResetReason = "UNARCHIVE_FAILED"
                    st.diagnostics.anchorResets += 1
                }
                Log.event("anchor.reset", code: "UNARCHIVE_FAILED")
            }
        }
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Configuration (§6.2 — the immutable tuple)

    func configure(enrolmentRef: String, importStart: Date) throws {
        try mutate { st in
            if let existing = st.config {
                // Idempotent only on the FULL tuple; any difference is CONFIG_CONFLICT.
                guard existing.enrolmentRef == enrolmentRef,
                      abs(existing.importStart.timeIntervalSince(importStart)) < 0.001 else {
                    throw BPError.configConflict
                }
                return
            }
            st.enrolmentRef = enrolmentRef
            st.importStart = importStart
        }
        Log.event("configure.ok", id8: Log.prefix8(enrolmentRef))
    }

    // MARK: - Authorisation (SPK-3)

    func authorizationRequestStatus() async -> String {
        await withCheckedContinuation { c in
            health.getRequestStatusForAuthorization(toShare: [], read: SpikeAuthSet.read) { status, error in
                if let error {
                    c.resume(returning: "error:\((error as NSError).code)")
                    return
                }
                switch status {
                case .unknown:     c.resume(returning: "unknown")
                case .shouldRequest: c.resume(returning: "shouldRequest")
                case .unnecessary: c.resume(returning: "unnecessary")
                @unknown default:  c.resume(returning: "unhandled")
                }
            }
        }
    }

    /// Never rejects on user denial — denial is not observable (§7.1).
    ///
    /// MEASURED 26 Aug (iPadOS 26.6.1, SIDECAR): a correlation type in EITHER authorisation
    /// set raises `NSInvalidArgumentException` and aborts the process — it is not an error
    /// you can catch. The guard below fails early and by name rather than letting HealthKit
    /// abort from the inside. It cannot be a compile-time check: `HKCorrelationType` is an
    /// `HKObjectType`, which is exactly why this was reachable at all.
    func requestAuthorization() async -> String? {
        assert(!SpikeAuthSet.read.contains(where: { $0 is HKCorrelationType }),
               "HealthKit disallows correlation types in an authorisation set; "
               + "authorisation attaches to the contained quantity types (§5.1, §7.4).")
        do {
            try await health.requestAuthorization(toShare: [], read: SpikeAuthSet.read)
            Log.event("auth.requested", type: SpikeAuthSet.variant)
            return nil
        } catch {
            let code = "\((error as NSError).code)"
            Log.event("auth.requestFailed", code: code)
            return code
        }
    }

    // MARK: - Observation (§7.1 / §12 P2)

    func startObserving() async throws {
        try mutate { st in
            guard st.enrolmentRef != nil else { throw BPError.configMissing }
            st.desiredObservationEnabled = true              // intent
        }
        onExecutor { registerObserversLocked() }
        do {
            try await enableDelivery(BPTypes.systolic)
            try await enableDelivery(BPTypes.diastolic)
            try mutate { $0.lastArm = .ok(Date()); $0.diagnostics.armedAt = Date() }
            Log.event("arm.ok")
        } catch {
            let code = Self.errorCode(error)
            try? mutate { $0.lastArm = .failed(Date(), code: code) }
            Log.event("arm.failed", code: code)
            throw BPError.bgDeliveryFailed(code)             // state -> armFailed
        }
    }

    /// Full teardown (B4) — runs on the executor. Queries actually stopped, delivery
    /// actually disabled, observer array cleared, intent persisted.
    func stopObserving() async throws {
        onExecutor {
            for q in observers { health.stop(q) }            // stop EXECUTED queries
            observers.removeAll()
        }
        try await disableDelivery(BPTypes.systolic)          // awaited, both types
        try await disableDelivery(BPTypes.diastolic)
        try mutate { $0.desiredObservationEnabled = false }
        Log.event("observe.stopped")
    }

    /// LAUNCH ORDER (ship-gate 12): observers are per-process and urgent on a HealthKit
    /// background relaunch; background-delivery registration is already persistent system
    /// state. Register FIRST, verify async SECOND.
    func armAtLaunchIfConfigured() {
        work.async { [self] in
            let s = store.current
            guard s.enrolmentRef != nil, s.desiredObservationEnabled else { return }
            registerObserversLocked()                        // synchronous, first
            Task { await self.verifyBackgroundDelivery() }   // async, second
        }
    }

    private func verifyBackgroundDelivery() async {
        do {
            try await enableDelivery(BPTypes.systolic)
            try await enableDelivery(BPTypes.diastolic)
            try? mutate { $0.lastArm = .ok(Date()) }         // updates lastArm only
        } catch {
            try? mutate { $0.lastArm = .failed(Date(), code: Self.errorCode(error)) }
        }
    }

    private func registerObserversLocked() {                 // on `work` only
        guard observers.isEmpty else { return }
        for type in BPTypes.observed {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, systemDone, error in
                guard let self else { systemDone(); return }
                Task {
                    defer { systemDone() }   // EVERY path, EXACTLY once [R4]
                    if error != nil { Log.event("observerErr"); return }
                    try? self.mutate { $0.diagnostics.lastWakeAt = Date() }
                    _ = try? await self.runCatchUp(trigger: .backgroundWake)
                }
            }
            health.execute(q); observers.append(q)
        }
        Log.event("observers.registered", count: observers.count)
    }

    private func enableDelivery(_ type: HKObjectType) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            health.enableBackgroundDelivery(for: type, frequency: .immediate) { ok, error in
                if let error { c.resume(throwing: error) }
                else if !ok { c.resume(throwing: BPError.bgDeliveryFailed("NOT_ENABLED")) }
                else { c.resume() }
            }
        }
    }

    private func disableDelivery(_ type: HKObjectType) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            health.disableBackgroundDelivery(for: type) { _, error in
                if let error { c.resume(throwing: error) } else { c.resume() }
            }
        }
    }

    // MARK: - Catch-up (§12 P2 — the ONE catch-up path)

    @discardableResult
    func runCatchUp(trigger: Trigger) async throws -> CatchUpOutcome {
        if let loadFault { throw loadFault }

        let entry: (config: EngineConfig, anchor: HKQueryAnchor?, bootstrap: Bool)? = onExecutor {
            guard !catchUpInFlight else { return nil }
            let s = store.current
            guard let cfg = s.config else { return nil }              // CONFIG_MISSING
            guard s.desiredObservationEnabled else { return nil }     // no capture when disabled
            catchUpInFlight = true
            // BOOTSTRAP RULE (§5.3): nil anchor until first readable reading is committed.
            let anchor = s.bootstrapComplete ? s.anchorData.flatMap(decodeAnchor) : nil
            return (cfg, anchor, !s.bootstrapComplete)
        }

        guard let entry else {
            let s = read { $0 }
            if s.config == nil { throw BPError.configMissing }
            if !s.desiredObservationEnabled { return CatchUpOutcome() }
            throw BPError.queryFailed("CATCHUP_IN_FLIGHT")
        }
        defer { onExecutor { catchUpInFlight = false } }

        var out = CatchUpOutcome()
        out.bootstrap = entry.bootstrap

        let delta: Delta
        do {
            delta = try await fetchDelta(anchor: entry.anchor, since: entry.config.importStart)
        } catch let e as BPError where e.code == "HK_TEMP_UNAVAILABLE" {
            catchUpPending = true                            // anchor untouched; retried [R18]
            try? mutate { $0.diagnostics.lastErrorCode = e.code }
            Log.event("hkLocked.retryPending")
            out.deferred = true
            return out
        } catch {
            try handleQueryFailure(error)
            throw error
        }

        out.returned = delta.returnedSampleCount
        out.malformed = delta.malformedBySource.values.reduce(0, +)
        out.deleted = delta.deletedUuids.count
        out.deletedUuidPrefixes = delta.deletedUuids.map(Log.prefix8)

        let queued: [String] = try mutate { st in
            let fresh = delta.readings.filter { !st.recentUuids.contains($0.hkUuid) }
            st.enqueue(fresh, enrolmentRef: entry.config.enrolmentRef)
            st.mergeMalformedCounts(delta.malformedBySource)
            // DEVIATION D-002 (S3). The guide's §12 P2 gates on `!fresh.isEmpty` — the delta
            // AFTER the recentUuids filter. Following a §5.3 anchor reset that is empty even
            // when the re-import returned the whole history, so the anchor is never
            // re-persisted and the engine re-reads everything on every wake, permanently.
            // Gating on the delta itself matches §5.3's own wording ("a delta containing at
            // least one readable BP correlation") and respects §8.1: the ring "only reduces
            // redundant queueing; correctness depends solely on the constraint".
            if st.bootstrapComplete || !delta.readings.isEmpty {
                st.anchorData = delta.newAnchorData          // advance ALWAYS post-bootstrap
                st.bootstrapComplete = true                  // even on empty deltas
                out.anchorCommitted = true
            }
            if !fresh.isEmpty { st.snapshotSeq &+= 1 }       // B2: every queue mutation bumps
            st.diagnostics.consecutiveQueryFailures = 0
            st.diagnostics.lastQueryFailureCode = nil
            return fresh.map(\.hkUuid)
        }

        catchUpPending = false
        out.queued = queued.count
        out.uuidPrefixes = queued.map(Log.prefix8)
        Log.event("catchUp.committed", count: out.queued, code: trigger.rawValue)
        if out.malformed > 0 { Log.event("catchUp.malformed", count: out.malformed) }
        if out.deleted > 0 { Log.event("catchUp.deletedReported", count: out.deleted) }
        return out
    }

    /// Anchor-recovery ladder (§5.3), trigger (b): three consecutive anchored-query
    /// failures with the same error, followed by one successful nil-anchor probe.
    /// All other errors retain the anchor.
    private func handleQueryFailure(_ error: Error) throws {
        let code = Self.errorCode(error)
        let shouldProbe: Bool = try mutate { st in
            if st.diagnostics.lastQueryFailureCode == code {
                st.diagnostics.consecutiveQueryFailures += 1
            } else {
                st.diagnostics.lastQueryFailureCode = code
                st.diagnostics.consecutiveQueryFailures = 1
            }
            st.diagnostics.lastErrorCode = code
            return st.diagnostics.consecutiveQueryFailures >= 3 && st.bootstrapComplete
        }
        Log.event("query.failed", count: read { $0.diagnostics.consecutiveQueryFailures }, code: code)
        if shouldProbe { Log.event("anchor.resetCandidate", code: code) }
    }

    /// Explicit nil-anchor probe. On success the anchor-only reset is applied: `anchorData`
    /// and `bootstrapComplete` cleared, queue/config/observation/diagnostics preserved,
    /// reason code recorded, bounded `importStart` re-import runs in foreground.
    func runAnchorResetProbe(reason: String) async throws {
        guard let cfg = read({ $0.config }) else { throw BPError.configMissing }
        _ = try await fetchDelta(anchor: nil, since: cfg.importStart)   // probe must succeed
        try mutate { st in
            st.anchorData = nil
            st.bootstrapComplete = false
            st.anchorResetReason = reason
            st.diagnostics.anchorResets += 1
            st.diagnostics.consecutiveQueryFailures = 0
        }
        Log.event("anchor.reset", code: reason)
    }

    // MARK: - The query itself

    /// The **production predicate**: `startDate >= importStart` (§5.2, §11 SPK-1).
    func productionPredicate(since importStart: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: importStart, end: nil, options: [.strictStartDate])
    }

    func fetchDelta(anchor: HKQueryAnchor?, since importStart: Date) async throws -> Delta {
        guard HKHealthStore.isHealthDataAvailable() else { throw BPError.hkUnavailable }
        let predicate = productionPredicate(since: importStart)
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<Delta, Error>) in
            var resumed = false
            let query = HKAnchoredObjectQuery(
                type: BPTypes.fetched,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { query, samples, deleted, newAnchor, error in
                self.health.stop(query)
                guard !resumed else { return }
                resumed = true

                if let error {
                    let ns = error as NSError
                    if ns.domain == HKError.errorDomain,
                       ns.code == HKError.Code.errorDatabaseInaccessible.rawValue {
                        c.resume(throwing: BPError.hkTempUnavailable)
                    } else {
                        c.resume(throwing: BPError.queryFailed(Self.errorCode(error)))
                    }
                    return
                }

                var mapped: [MappedReading] = []
                var malformed: [String: Int] = [:]
                for sample in samples ?? [] {
                    if let m = Mapper.map(sample) {
                        mapped.append(m)
                    } else {
                        malformed[Mapper.sourceIdentifier(sample), default: 0] += 1
                    }
                }
                let anchorData = newAnchor.flatMap(self.encodeAnchor)
                c.resume(returning: Delta(
                    readings: mapped,
                    malformedBySource: malformed,
                    deletedUuids: (deleted ?? []).map { $0.uuid.uuidString },
                    newAnchorData: anchorData,
                    returnedSampleCount: (samples ?? []).count))
            }
            health.execute(query)
        }
    }

    // MARK: - Anchor archiving

    func encodeAnchor(_ anchor: HKQueryAnchor) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    func decodeAnchor(_ data: Data) -> HKQueryAnchor? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    // MARK: - Pure reads

    func snapshot() -> (snapshotId: String, itemIds: [String], uuidPrefixes: [String], heldCount: Int) {
        read { s in
            (s.snapshotToken, s.queue.map(\.itemId), s.queue.map { Log.prefix8($0.hkUuid) }, s.heldCount)
        }
    }

    func currentState() -> EngineState { read { $0 } }

    func acknowledge(snapshotId: String, itemIds: [String]) throws -> (removed: Int, alreadyAbsent: Int) {
        try mutate { st in
            guard st.snapshotToken == snapshotId else { throw BPError.snapshotStale }
            let r = st.removeEverywhere(itemIds)
            st.snapshotSeq &+= 1                             // B2
            return r
        }
    }

    // MARK: - Helpers

    static func errorCode(_ error: Error) -> String {
        if let bp = error as? BPError { return bp.description }
        return HKErrorName.describe(error)
    }
}

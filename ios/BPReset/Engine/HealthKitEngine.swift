import Foundation
import HealthKit

/// The product engine (guide §12 P2), grown from the §11 spike engine that was proven on
/// the acceptance iPhone on 26 Aug 2026 (ADR-0006, Path A).
///
/// Every read, commit and observer-list mutation happens on the single executor (`work`).
/// HealthKit's own callbacks are awaited off the executor; only state touches go back onto
/// it. Nothing here interprets a reading, and nothing here writes to HealthKit.
///
/// This is the Swift surface of the frozen bridge contract (§7). There is no JavaScript
/// bridge in the native rebuild: the app calls these methods directly.
final class HealthKitEngine: @unchecked Sendable {

    static let shared = HealthKitEngine()

    enum Trigger: String {
        case foreground, backgroundWake, retry, manual, relaunch
    }

    enum PendingPolicy {
        case holdForReauth
        case confirmedDiscard
    }

    struct Delta {
        let readings: [MappedReading]
        let malformedBySource: [String: Int]
        /// Deletions are out of V1 by decision (§8.3): reported as a count, never persisted.
        let deletedCount: Int
        let newAnchorData: Data?
        let returnedSampleCount: Int
    }

    struct CatchUpResult {
        var queued = 0
        var deferred = false
        var bootstrap = false
        var returned = 0
        var malformed = 0
        var anchorCommitted = false
    }

    struct Snapshot {
        let snapshotId: String
        let readings: [QueuedReading]
        let heldCount: Int
    }

    struct Status {
        let state: String                 // §7.1 EngineState names
        let promptRequested: Bool
        let pendingCount: Int
        let heldCount: Int
        let held: [(enrolmentRef: String, count: Int)]
        let bootstrapComplete: Bool
        let lastArm: ArmResult?
        let rejectedCount: Int
    }

    private let health = HKHealthStore()
    private let work = DispatchQueue(label: "dev.aiplease.bpreset.engine")
    private let workKey = DispatchSpecificKey<Bool>()
    let store = StateStore()

    private var observers: [HKObserverQuery] = []
    private var catchUpInFlight = false
    private var resetting = false
    private(set) var catchUpPending = false
    private(set) var loadFault: BPError?

    /// Hint only (§7.1 addListener). The app drains unconditionally on foreground regardless.
    var onReadingsAvailable: ((Int) -> Void)?

    private init() {
        work.setSpecific(key: workKey, value: true)
    }

    // MARK: - Executor discipline

    private func onExecutor<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: workKey) == true { return try body() }
        return try work.sync(execute: body)
    }

    private func read<T>(_ body: (EngineState) throws -> T) rethrows -> T {
        try onExecutor { try body(store.current) }
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

    // MARK: - Status

    func status() -> Status {
        read { s in
            Status(
                state: Self.stateName(s),
                promptRequested: s.promptRequestedAt != nil,
                pendingCount: s.queue.count,
                heldCount: s.heldCount,
                held: s.held.map { ($0.enrolmentRef, $0.items.count) },
                bootstrapComplete: s.bootstrapComplete,
                lastArm: s.lastArm,
                rejectedCount: s.diagnostics.rejectedBySource.values.reduce(0, +))
        }
    }

    static func stateName(_ s: EngineState) -> String {
        guard s.enrolmentRef != nil else { return "unconfigured" }
        guard s.desiredObservationEnabled else { return "configuredDisabled" }
        if let arm = s.lastArm, !arm.ok { return "armFailed" }
        return "configuredEnabled"
    }

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

    /// The only exit from a configured tuple (§6.3). Runs behind a barrier on the
    /// executor: in-flight catch-up cannot land a commit after this resolves.
    func disconnectAndReset(_ policy: PendingPolicy) async throws {
        onExecutor { resetting = true }
        defer { onExecutor { resetting = false } }
        onExecutor {
            for q in observers { health.stop(q) }
            observers.removeAll()
        }
        try? await disableDelivery(BPTypes.systolic)
        try? await disableDelivery(BPTypes.diastolic)
        try mutate { st in
            switch policy {
            case .holdForReauth:
                if let ref = st.enrolmentRef, !st.queue.isEmpty {
                    if let i = st.held.firstIndex(where: { $0.enrolmentRef == ref }) {
                        st.held[i].items.append(contentsOf: st.queue)
                    } else {
                        st.held.append(HeldBucket(enrolmentRef: ref, items: st.queue))
                    }
                }
            case .confirmedDiscard:
                break
            }
            st.queue.removeAll()
            st.recentUuids.removeAll()
            st.enrolmentRef = nil
            st.importStart = nil
            st.desiredObservationEnabled = false
            st.lastArm = nil
            st.bootstrapComplete = false
            st.anchorData = nil
            st.anchorResetReason = nil
            st.snapshotSeq &+= 1                             // B2: every mutation bumps
        }
        Log.event("disconnect.reset", code: policy == .holdForReauth ? "hold" : "discard")
    }

    // MARK: - Authorisation

    /// Presents the system sheet. Never rejects on user denial — denial is not observable
    /// (§7.1). Records only that the prompt ran.
    func requestAuthorization() async throws {
        do {
            try await health.requestAuthorization(toShare: [], read: BPTypes.authorizationRead)
        } catch {
            let code = Self.errorCode(error)
            Log.event("auth.requestFailed", code: code)
            throw BPError.queryFailed(code)
        }
        try mutate { $0.promptRequestedAt = Date() }
        Log.event("auth.requested")
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
                    if let out = try? await self.runCatchUp(trigger: .backgroundWake), out.queued > 0 {
                        self.onReadingsAvailable?(self.status().pendingCount)
                    }
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
    func runCatchUp(trigger: Trigger) async throws -> CatchUpResult {
        if let loadFault { throw loadFault }

        let entry: (config: EngineConfig, anchor: HKQueryAnchor?, bootstrap: Bool)? = onExecutor {
            guard !catchUpInFlight, !resetting else { return nil }
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
            if !s.desiredObservationEnabled { return CatchUpResult() }
            throw BPError.queryFailed("CATCHUP_IN_FLIGHT")
        }
        defer { onExecutor { catchUpInFlight = false } }

        if read({ $0.promptRequestedAt }) == nil { throw BPError.promptPending }

        var out = CatchUpResult()
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

        let queued: Int = try mutate { st in
            guard !resetting else { return 0 }               // barrier: no post-reset commit
            let fresh = delta.readings.filter { !st.recentUuids.contains($0.hkUuid) }
            st.enqueue(fresh, enrolmentRef: entry.config.enrolmentRef)
            st.mergeMalformedCounts(delta.malformedBySource)
            // D-002: gate on the delta as returned, not the ring-filtered set, or an
            // anchor reset re-reads the whole history on every wake, forever.
            if st.bootstrapComplete || !delta.readings.isEmpty {
                st.anchorData = delta.newAnchorData          // advance ALWAYS post-bootstrap
                st.bootstrapComplete = true                  // even on empty deltas
                out.anchorCommitted = true
            }
            if !fresh.isEmpty { st.snapshotSeq &+= 1 }       // B2: every queue mutation bumps
            st.diagnostics.consecutiveQueryFailures = 0
            st.diagnostics.lastQueryFailureCode = nil
            return fresh.count
        }

        catchUpPending = false
        out.queued = queued
        Log.event("catchUp.committed", count: out.queued, code: trigger.rawValue)
        if out.malformed > 0 { Log.event("catchUp.malformed", count: out.malformed) }
        return out
    }

    /// Anchor-recovery ladder (§5.3), trigger (b): three consecutive anchored-query
    /// failures with the same error, followed by one successful nil-anchor probe.
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
        if shouldProbe {
            Log.event("anchor.resetCandidate", code: code)
            Task { try? await self.runAnchorResetProbe(reason: "QUERY_FAILURES") }
        }
    }

    /// Explicit nil-anchor probe. On success the anchor-only reset is applied: `anchorData`
    /// and `bootstrapComplete` cleared, queue/config/observation/diagnostics preserved,
    /// reason code recorded, bounded `importStart` re-import runs on the next catch-up.
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

    /// The **production predicate**: `startDate >= importStart` (§5.2).
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
                    deletedCount: (deleted ?? []).count,
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

    // MARK: - Snapshot and acknowledgement (§7.1)

    /// Pure queue read of the ACTIVE enrolment. No HealthKit access; works while disabled
    /// or locked. The generation token is invalidated by every queue/held mutation (B2).
    func pendingSnapshot() -> Snapshot {
        read { s in Snapshot(snapshotId: s.snapshotToken, readings: s.queue, heldCount: s.heldCount) }
    }

    /// Pure read of one HELD bucket (B1). `HELD_NOT_FOUND` if absent.
    func heldSnapshot(enrolmentRef: String) throws -> Snapshot {
        try read { s in
            guard let b = s.held.first(where: { $0.enrolmentRef == enrolmentRef }) else {
                throw BPError.heldNotFound
            }
            return Snapshot(snapshotId: s.snapshotToken, readings: b.items, heldCount: s.heldCount)
        }
    }

    /// Explicit destructive exit for a held bucket (B1). Requires literal confirmation.
    func discardHeld(enrolmentRef: String, confirmed: Bool) throws {
        guard confirmed else { throw BPError.confirmRequired }
        try mutate { st in
            guard st.held.contains(where: { $0.enrolmentRef == enrolmentRef }) else {
                throw BPError.heldNotFound
            }
            st.held.removeAll { $0.enrolmentRef == enrolmentRef }
            st.snapshotSeq &+= 1
        }
        Log.event("held.discarded", id8: Log.prefix8(enrolmentRef))
    }

    /// Removes exactly the given items from the given snapshot generation — active queue or
    /// held bucket, resolved by itemId. A stale snapshotId rejects SNAPSHOT_STALE.
    func acknowledge(snapshotId: String, itemIds: [String]) throws -> (removed: Int, alreadyAbsent: Int) {
        try mutate { st in
            guard st.snapshotToken == snapshotId else { throw BPError.snapshotStale }
            let r = st.removeEverywhere(itemIds)
            st.snapshotSeq &+= 1                             // B2
            return r
        }
    }

    /// Counts-only record of rows the backend rejected and the drain acknowledged (N-04).
    func recordRejected(bySource counts: [String: Int]) {
        try? mutate { st in
            for (source, n) in counts { st.diagnostics.rejectedBySource[source, default: 0] += n }
        }
    }

    // MARK: - Helpers

    static func errorCode(_ error: Error) -> String {
        if let bp = error as? BPError { return bp.description }
        return HKErrorName.describe(error)
    }
}

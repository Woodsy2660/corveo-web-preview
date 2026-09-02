import Foundation
import Observation
import UIKit

/// What one ingest response means for the rows that were sent. Pure, so it is unit-tested.
enum DrainReconciliation: Equatable {
    /// Every row landed, was a duplicate, or was rejected for its own content: acknowledge all
    /// (plan N-04; a structurally rejected row can never succeed and would pin the queue).
    case acknowledge
    /// Nothing landed and every rejection names the environment, not the reading (no
    /// definitions seeded, a unit or timestamp contract mismatch): keep the rows, surface it.
    case environmentFault(reason: String)
    /// The response does not account for every row sent: keep the rows, surface it.
    case mismatch

    static let environmental: Set<RejectionReason> = [.unknownCode, .unitMismatch, .malformedTimestamp]

    static func verdict(sent: Int, response: IngestResponse) -> DrainReconciliation {
        let landed = response.inserted + response.duplicates
        guard landed + response.rejected.count == sent else { return .mismatch }
        if landed == 0, let first = response.rejected.first,
           response.rejected.allSatisfy({ environmental.contains($0.reason) }) {
            return .environmentFault(reason: first.reason.rawValue)
        }
        return .acknowledge
    }
}

/// The UI's view of the HealthKit engine, and the owner of the drain (§12 P4).
///
/// Everything the UI shows is mechanism: connected or not, whether the prompt ran, how many
/// readings are waiting, when the last check ran, and what is in the way if something is.
/// Never a "denied" state, because iOS does not disclose one. Never a value.
@MainActor
@Observable
final class HealthModel {
    private let engine = HealthKitEngine.shared
    private let app: AppModel
    private let appState: AppState

    private(set) var status: HealthKitEngine.Status
    private(set) var lastDrainAt: Date? = nil
    private(set) var lastArrived: Int = 0
    private(set) var draining = false
    private(set) var lastErrorCode: String? = nil
    /// Set when a snapshot carries readings bound to a different enrolment (§6.3 HOLD).
    private(set) var bindingHold = false
    /// Held buckets that belong to some other enrolment than the one signed in.
    private(set) var foreignHeld: [(enrolmentRef: String, count: Int)] = []

    var isAvailable: Bool { engine.isAvailable }
    var connected: Bool { status.promptRequested && status.state != "unconfigured" }
    var backgroundUnavailable: Bool { status.state == "armFailed" }
    /// Bootstrap complete means at least one readable reading has ever committed.
    var samplesEverReceived: Bool { status.bootstrapComplete }

    /// One sentence for the card when something stands between capture and the record.
    var problemText: String? {
        if engine.loadFault != nil { return HealthProblemCopy.storeFault }
        if bindingHold { return HealthProblemCopy.bindingHold }
        guard let code = lastErrorCode else { return nil }
        if code.hasPrefix("CONSENT_REQUIRED") { return HealthProblemCopy.consentRequired }
        if code.hasPrefix("UNAUTHORIZED") { return HealthProblemCopy.signInRequired }
        if code.hasPrefix("INGEST_REJECTED_ALL") { return HealthProblemCopy.rejectedAll }
        switch code {
        case "NOT_ENROLLED": return HealthProblemCopy.notEnrolled
        case "INTERNAL": return HealthProblemCopy.storeFault
        case "ACK_FAILED": return HealthProblemCopy.ackFailed
        case "UPLOAD_FAILED", "INGEST_MISMATCH", "NETWORK": return HealthProblemCopy.uploadFailed
        default: return nil                                  // arming codes are on the card already
        }
    }

    init(app: AppModel, appState: AppState) {
        self.app = app
        self.appState = appState
        self.status = engine.status()
        engine.onReadingsAvailable = { [weak self] _ in
            Task { @MainActor [weak self] in await self?.drain(trigger: .backgroundWake) }
        }
    }

    func refresh() {
        status = engine.status()
        let mine = appState.enrolmentRef
        foreignHeld = status.held.filter { $0.enrolmentRef != mine }
    }

    // MARK: Connect order (§6.3): configure -> requestAuthorization -> startObserving -> drain

    /// False when HealthKit is unavailable, the enrolment is not yet bound to the server, or
    /// the engine could not be configured or asked for authorisation. An arming failure alone
    /// is not a failure here: foreground capture still works and the card says so.
    @discardableResult
    func connect() async -> Bool {
        guard engine.isAvailable else { refresh(); return false }
        guard appState.enrolmentBound else {
            lastErrorCode = "NOT_ENROLLED"
            refresh()
            return false
        }
        var ok = true
        do {
            try engine.configure(enrolmentRef: appState.enrolmentRef,
                                 importStart: appState.programStartedAt ?? Date())
        } catch let e as BPError where e.code == "CONFIG_CONFLICT" {
            // A different enrolment is configured on this phone. Route through the reset
            // with the hold policy so nothing is discarded (§6.3), then configure again.
            ok = await rebind()
        } catch {
            lastErrorCode = HealthKitEngine.errorCode(error)
            ok = false
        }
        do {
            try await engine.requestAuthorization()
        } catch {
            lastErrorCode = HealthKitEngine.errorCode(error)
            ok = false
        }
        do {
            try await engine.startObserving()
        } catch {
            // armFailed: foreground catch-up still works. The card says so.
            lastErrorCode = HealthKitEngine.errorCode(error)
        }
        refresh()
        await drain(trigger: .foreground)
        return ok
    }

    func disconnect(_ policy: HealthKitEngine.PendingPolicy) async {
        do {
            try await engine.disconnectAndReset(policy)
        } catch {
            lastErrorCode = HealthKitEngine.errorCode(error)
        }
        refresh()
    }

    func handleForeground() async {
        refresh()
        guard status.state != "unconfigured" else { return }
        await drain(trigger: .foreground)
    }

    /// Explicit destructive exit for buckets held under some other enrolment (B1). The
    /// confirmation is the caller's; nothing is uploaded, Apple Health is untouched.
    func discardForeignHeld() {
        for bucket in foreignHeld {
            try? engine.discardHeld(enrolmentRef: bucket.enrolmentRef, confirmed: true)
        }
        refresh()
    }

    /// The signed-in tuple changed underneath a configured engine (account switch, or the
    /// server tuple replacing a local one): hold whatever the old tuple captured and bind the
    /// new one. Held readings drain when their own enrolment signs in again.
    private func rebind() async -> Bool {
        do {
            try await engine.disconnectAndReset(.holdForReauth)
            try engine.configure(enrolmentRef: appState.enrolmentRef,
                                 importStart: appState.programStartedAt ?? Date())
            try await engine.startObserving()
            Log.event("engine.rebound")
            return true
        } catch {
            lastErrorCode = HealthKitEngine.errorCode(error)
            return false
        }
    }

    private func rebindIfNeeded() async {
        guard appState.enrolmentBound,
              let current = engine.configuredEnrolmentRef,
              current != appState.enrolmentRef else { return }
        _ = await rebind()
    }

    // MARK: Drain

    /// One serialised drain: rebind if the account changed, catch-up, the held bucket for this
    /// enrolment first (B1), then the active queue with a binding check on every item, one
    /// ingest call per snapshot, reconciliation, per-item acknowledgement (plan N-04).
    /// Nothing is removed on failure.
    func drain(trigger: HealthKitEngine.Trigger) async {
        guard !draining else { return }
        draining = true
        defer { draining = false; refresh() }

        await rebindIfNeeded()

        do {
            _ = try await engine.runCatchUp(trigger: trigger)
        } catch let e as BPError where e.code == "INTERNAL" {
            lastErrorCode = "INTERNAL"                          // the store is unusable; say so
            Log.event("drain.storeFault", code: e.description)
            return
        } catch {
            // Deferred (locked store), prompt pending, unconfigured, or a pass already in
            // flight: the queue is still worth draining and the next trigger retries capture.
        }
        refresh()

        let session = appState.enrolmentRef
        if appState.enrolmentBound,
           let held = try? engine.heldSnapshot(enrolmentRef: session),
           !held.readings.isEmpty {
            guard await upload(held.readings, snapshotId: held.snapshotId, trigger: trigger) else { return }
        }

        let snap = engine.pendingSnapshot()
        refresh()
        guard !snap.readings.isEmpty else {
            if status.promptRequested { lastDrainAt = Date() }
            lastArrived = 0
            return
        }

        // BINDING CHECK on EVERY item: a mismatch holds everything, uploads nothing,
        // discards nothing (§6.3, §17.3).
        guard snap.readings.allSatisfy({ $0.enrolmentRef == session }) else {
            bindingHold = true
            Log.event("drain.bindingHold", count: snap.readings.count)
            return
        }
        bindingHold = false

        _ = await upload(snap.readings, snapshotId: snap.snapshotId, trigger: trigger)
    }

    /// One ingest call for one snapshot. Returns false when the rows must stay queued.
    private func upload(_ readings: [QueuedReading], snapshotId: String, trigger: HealthKitEngine.Trigger) async -> Bool {
        let response: IngestResponse
        do {
            response = try await app.ingest(PayloadBuilder.healthKit(readings))
        } catch {
            lastErrorCode = Self.code(for: error)
            Log.event("drain.failed", code: lastErrorCode)
            return false                                      // queue intact; next trigger drains
        }

        switch DrainReconciliation.verdict(sent: readings.count, response: response) {
        case .mismatch:
            lastErrorCode = "INGEST_MISMATCH"
            Log.event("drain.mismatch", count: readings.count)
            return false
        case .environmentFault(let reason):
            lastErrorCode = "INGEST_REJECTED_ALL:\(reason)"
            Log.event("drain.rejectedAll", count: readings.count, code: reason)
            return false
        case .acknowledge:
            break
        }

        let rejectedUuids = Set(response.rejected.map(\.sourceUuid))
        let rejected = readings.filter { rejectedUuids.contains($0.hkUuid) }
        if !rejected.isEmpty {
            var counts: [String: Int] = [:]
            for r in rejected { counts[r.sourceBundleId, default: 0] += 1 }
            var reasons: [String: Int] = [:]
            for rj in response.rejected { reasons[rj.reason.rawValue, default: 0] += 1 }
            engine.recordRejected(bySource: counts, reasons: reasons)
            for (code, n) in reasons { Log.event("drain.rejected", count: n, code: code) }
        }

        // Landed (inserted or duplicate) and structurally rejected rows are both acknowledged.
        // An acknowledgement that fails leaves the rows queued and is reported, never hidden.
        let ids = readings.map(\.itemId)
        do {
            _ = try engine.acknowledge(snapshotId: snapshotId, itemIds: ids)
        } catch let e as BPError where e.code == "SNAPSHOT_STALE" {
            // Something enqueued meanwhile; re-snapshot and acknowledge exactly what we sent.
            let fresh = engine.pendingSnapshot()
            do {
                _ = try engine.acknowledge(snapshotId: fresh.snapshotId, itemIds: ids)
            } catch {
                lastErrorCode = "ACK_FAILED"
                Log.event("drain.ackFailed", code: HealthKitEngine.errorCode(error))
                return false
            }
        } catch {
            lastErrorCode = "ACK_FAILED"
            Log.event("drain.ackFailed", code: HealthKitEngine.errorCode(error))
            return false
        }

        lastArrived = response.inserted
        lastDrainAt = Date()
        lastErrorCode = nil
        Log.event("drain.ok", count: response.inserted, code: trigger.rawValue)
        return true
    }

    private static func code(for error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .consentRequired: return "CONSENT_REQUIRED"
            case .unauthorized: return "UNAUTHORIZED"
            default: return "NETWORK"
            }
        }
        return "UPLOAD_FAILED"
    }

    // MARK: Settings deep link (§12 P3c, "Open BP Reset Settings")

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

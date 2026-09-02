import Foundation
import Observation
import UIKit

/// The UI's view of the HealthKit engine, and the owner of the drain (§12 P4).
///
/// Everything the UI shows is mechanism: connected or not, whether the prompt ran, how many
/// readings are waiting, when the last check ran. Never a "denied" state, because iOS does
/// not disclose one. Never a value.
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

    var isAvailable: Bool { engine.isAvailable }
    var connected: Bool { status.promptRequested && status.state != "unconfigured" }
    var backgroundUnavailable: Bool { status.state == "armFailed" }
    /// Bootstrap complete means at least one readable reading has ever committed.
    var samplesEverReceived: Bool { status.bootstrapComplete }

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
    }

    // MARK: Connect order (§6.3): configure -> requestAuthorization -> startObserving -> drain

    /// Returns false only when HealthKit is unavailable on this device. Denial is not
    /// observable and does not fail this call.
    @discardableResult
    func connect() async -> Bool {
        guard engine.isAvailable else { refresh(); return false }
        appState.markEnrolled()
        do {
            try engine.configure(enrolmentRef: appState.enrolmentRef,
                                 importStart: appState.programStartedAt ?? Date())
        } catch let e as BPError where e.code == "CONFIG_CONFLICT" {
            // A different enrolment is configured on this phone. Route through the reset
            // with the hold policy so nothing is discarded (§6.3), then configure again.
            try? await engine.disconnectAndReset(.holdForReauth)
            try? engine.configure(enrolmentRef: appState.enrolmentRef,
                                  importStart: appState.programStartedAt ?? Date())
        } catch {
            lastErrorCode = HealthKitEngine.errorCode(error)
        }
        do {
            try await engine.requestAuthorization()
        } catch {
            lastErrorCode = HealthKitEngine.errorCode(error)
        }
        do {
            try await engine.startObserving()
        } catch {
            // armFailed: foreground catch-up still works. The card says so.
            lastErrorCode = HealthKitEngine.errorCode(error)
        }
        refresh()
        await drain(trigger: .foreground)
        return true
    }

    func disconnect(_ policy: HealthKitEngine.PendingPolicy) async {
        try? await engine.disconnectAndReset(policy)
        refresh()
    }

    func handleForeground() async {
        refresh()
        guard status.state != "unconfigured" else { return }
        await drain(trigger: .foreground)
    }

    // MARK: Drain

    /// One serialised drain: catch-up, snapshot, binding check on every item, one ingest
    /// call, per-item acknowledgement (plan N-04). Nothing is removed on failure.
    func drain(trigger: HealthKitEngine.Trigger) async {
        guard !draining else { return }
        draining = true
        defer { draining = false; refresh() }

        _ = try? await engine.runCatchUp(trigger: trigger)   // deferred or promptPending is fine
        let snap = engine.pendingSnapshot()
        refresh()
        guard !snap.readings.isEmpty else {
            if status.promptRequested { lastDrainAt = Date() }
            lastArrived = 0
            return
        }

        // BINDING CHECK on EVERY item: a mismatch holds everything, uploads nothing,
        // discards nothing (§6.3, §17.3).
        let session = appState.enrolmentRef
        guard snap.readings.allSatisfy({ $0.enrolmentRef == session }) else {
            bindingHold = true
            Log.event("drain.bindingHold", count: snap.readings.count)
            return
        }
        bindingHold = false

        let response: IngestResponse
        do {
            response = try await app.ingest(PayloadBuilder.healthKit(snap.readings))
        } catch {
            lastErrorCode = (error as? APIError)?.errorDescription ?? "UPLOAD_FAILED"
            Log.event("drain.failed", code: lastErrorCode)
            return                                            // queue intact; next trigger drains
        }

        let rejectedUuids = Set(response.rejected.map(\.sourceUuid))
        let rejected = snap.readings.filter { rejectedUuids.contains($0.hkUuid) }
        if !rejected.isEmpty {
            var counts: [String: Int] = [:]
            for r in rejected { counts[r.sourceBundleId, default: 0] += 1 }
            var reasons: [String: Int] = [:]
            for rj in response.rejected { reasons[rj.reason.rawValue, default: 0] += 1 }
            engine.recordRejected(bySource: counts, reasons: reasons)
            for (code, n) in reasons { Log.event("drain.rejected", count: n, code: code) }
        }

        // Landed (inserted or duplicate) and structurally rejected rows are both acknowledged:
        // a rejected row can never succeed and replaying it forever pins the pending count.
        let ids = snap.readings.map(\.itemId)
        do {
            _ = try engine.acknowledge(snapshotId: snap.snapshotId, itemIds: ids)
        } catch let e as BPError where e.code == "SNAPSHOT_STALE" {
            // Something enqueued meanwhile; re-snapshot and acknowledge exactly what we sent.
            let fresh = engine.pendingSnapshot()
            _ = try? engine.acknowledge(snapshotId: fresh.snapshotId, itemIds: ids)
        } catch {
            Log.event("drain.ackFailed", code: HealthKitEngine.errorCode(error))
        }

        lastArrived = response.inserted
        lastDrainAt = Date()
        lastErrorCode = nil
        Log.event("drain.ok", count: response.inserted, code: trigger.rawValue)
    }

    // MARK: Settings deep link (§12 P3c, "Open BP Reset Settings")

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

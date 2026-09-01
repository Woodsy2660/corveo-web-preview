import Foundation
import HealthKit
import SwiftUI

/// Drives the reader targets. Every readout is a count, a state, an error code or a
/// truncated opaque ID. **No reading value is ever rendered** — including here, in a debug
/// screen (guide §1.1, §4.1; handoff hard constraint 1).
@MainActor
final class SpikeReaderModel: ObservableObject {

    @Published var importStartDaysBack: Int = 30
    @Published var enrolmentRef: String = ""
    @Published var busy: Bool = false
    @Published var lines: [String] = []
    @Published var lastFault: String?

    private let engine = SpikeEngine.shared

    init() {
        // A synthetic, spike-local stand-in for the server enrolment row's UUID (§6.1).
        // In the product this arrives from the authenticated session and is never minted
        // on the handset.
        enrolmentRef = UserDefaults.standard.string(forKey: "spike.enrolmentRef") ?? {
            let fresh = UUID().uuidString
            UserDefaults.standard.set(fresh, forKey: "spike.enrolmentRef")
            return fresh
        }()
        refresh()
    }

    var authVariant: String { SpikeAuthSet.variant }

    // MARK: - Derived readouts (counts and states only)

    struct Readout {
        var engineState = "unconfigured"
        var bootstrapComplete = false
        var anchorPresent = false
        var anchorResetReason: String?
        var pendingCount = 0
        var heldCount = 0
        var snapshotId = "gen-0"
        var commitSeq: UInt64 = 0
        var activeSlot = "-"
        var generationFallbacks = 0
        var anchorResets = 0
        var malformedTotal = 0
        var malformedSources = 0
        var lastArm = "-"
        var loadNote = "-"
        var generations: [String] = []
    }

    @Published var readout = Readout()

    func refresh() {
        let s = engine.currentState()
        var r = Readout()
        r.engineState = Self.engineStateName(s)
        r.bootstrapComplete = s.bootstrapComplete
        r.anchorPresent = s.anchorData != nil
        r.anchorResetReason = s.anchorResetReason
        r.pendingCount = s.queue.count
        r.heldCount = s.heldCount
        r.snapshotId = s.snapshotToken
        r.commitSeq = engine.store.commitSeq
        r.activeSlot = engine.store.activeSlot?.rawValue ?? "-"
        r.generationFallbacks = s.diagnostics.generationFallbacks
        r.anchorResets = s.diagnostics.anchorResets
        r.malformedTotal = s.diagnostics.malformedBySource.values.reduce(0, +)
        r.malformedSources = s.diagnostics.malformedBySource.count
        r.loadNote = engine.store.lastLoadNote ?? "-"
        if let arm = s.lastArm {
            r.lastArm = arm.ok ? "ok" : "failed/\(arm.errorCode ?? "-")"
        }
        r.generations = engine.store.generationReport().map { g in
            g.exists
                ? "\(g.slot.rawValue) seq=\(g.commitSeq.map(String.init) ?? "?") \(g.valid ? "valid" : "INVALID/\(g.reason ?? "-")") \(g.bytes)B"
                : "\(g.slot.rawValue) absent"
        }
        readout = r
        lines = Log.lines().suffix(120).reversed()
    }

    private static func engineStateName(_ s: EngineState) -> String {
        guard s.enrolmentRef != nil else { return "unconfigured" }
        guard s.desiredObservationEnabled else { return "configuredDisabled" }
        if let arm = s.lastArm, !arm.ok { return "armFailed" }
        return "configuredEnabled"
    }

    // MARK: - Actions

    private func run(_ label: StaticString, _ body: @escaping () async throws -> Void) {
        busy = true
        Task {
            do { try await body(); lastFault = nil }
            catch { lastFault = SpikeEngine.errorCode(error); Log.event(label, code: lastFault) }
            refresh()
            busy = false
        }
    }

    /// `importStart` is the server enrolment timestamp in the product (§6.1). The spike has
    /// no server, so it is set explicitly here — and it MUST precede the backdated insert
    /// SPK-1 asks the writer for, or the production predicate excludes that insert and the
    /// step fails for the wrong reason.
    func configure() {
        let importStart = Calendar.current.date(
            byAdding: .day, value: -importStartDaysBack, to: Date()) ?? Date()
        run("configure.failed") { [self] in
            try engine.configure(enrolmentRef: enrolmentRef, importStart: importStart)
        }
    }

    func configureAgainSameTuple() {
        let importStart = Calendar.current.date(
            byAdding: .day, value: -importStartDaysBack, to: Date()) ?? Date()
        run("configure.idempotency") { [self] in
            // Expect CONFIG_CONFLICT: importStart moves with wall clock, so this is the
            // "different tuple" leg of T-L. The identical-tuple leg is the no-op above.
            try engine.configure(enrolmentRef: enrolmentRef, importStart: importStart)
        }
    }

    func authStatusBefore() {
        run("auth.status") { [self] in
            let status = await engine.authorizationRequestStatus()
            Log.event("auth.requestStatus", code: status, type: SpikeAuthSet.variant)
        }
    }

    func requestAuthorization() {
        run("auth.request") { [self] in
            if let code = await engine.requestAuthorization() {
                Log.event("auth.request.error", code: code)
            }
        }
    }

    func startObserving() {
        run("observe.start") { [self] in try await engine.startObserving() }
    }

    func stopObserving() {
        run("observe.stop") { [self] in try await engine.stopObserving() }
    }

    func runCatchUp() {
        run("catchUp") { [self] in
            let out = try await engine.runCatchUp(trigger: .manual)
            Log.event("catchUp.result.returned", count: out.returned)
            Log.event("catchUp.result.queued", count: out.queued)
            Log.event("catchUp.result.bootstrapMode", count: out.bootstrap ? 1 : 0)
            Log.event("catchUp.result.anchorCommitted", count: out.anchorCommitted ? 1 : 0)
            if out.deferred { Log.event("catchUp.result.deferred", count: 1) }
            for p in out.uuidPrefixes { Log.event("queued.correlationUuid", id8: p) }
            for p in out.deletedUuidPrefixes { Log.event("reported.deletedUuid", id8: p) }
        }
    }

    func showSnapshot() {
        run("snapshot") { [self] in
            let s = engine.snapshot()
            Log.event("snapshot.id", code: s.snapshotId)
            Log.event("snapshot.items", count: s.itemIds.count)
            Log.event("snapshot.held", count: s.heldCount)
            for p in s.uuidPrefixes { Log.event("snapshot.correlationUuid", id8: p) }
        }
    }

    func acknowledgeAll() {
        run("ack") { [self] in
            let s = engine.snapshot()
            let r = try engine.acknowledge(snapshotId: s.snapshotId, itemIds: s.itemIds)
            Log.event("ack.removed", count: r.removed)
            Log.event("ack.alreadyAbsent", count: r.alreadyAbsent)
        }
    }

    func acknowledgeStale() {
        run("ack.stale") { [self] in
            // M21 / B2: a snapshotId from before any mutation must reject SNAPSHOT_STALE.
            _ = try engine.acknowledge(snapshotId: "gen-0", itemIds: [])
        }
    }

    func inject(_ injection: StateStore.Injection) {
        run("spk4.inject") { [self] in try engine.store.inject(injection) }
    }

    func anchorResetProbe() {
        run("anchor.probe") { [self] in
            try await engine.runAnchorResetProbe(reason: "TEST_INJECTION")
        }
    }

    func destroyStoreForRecovery() {
        engine.store.destroyStoreForSpikeRecovery()
        refresh()
    }

    /// SPK-1 step 4 / SPK-4: terminate the process **for real**, then relaunch from the
    /// home screen. Not a debugger stop, not a background transition.
    func terminateProcess() {
        Log.event("spike.terminate")
        exit(0)
    }

    func copyEnvironmentBlock() {
        UIPasteboard.general.string = SpikeEnvironment.adrEnvironmentBlock(authVariant: authVariant)
        Log.event("evidence.environmentCopied")
        refresh()
    }

    func copyLog() {
        UIPasteboard.general.string = Log.lines().joined(separator: "\n")
        Log.event("evidence.logCopied", count: Log.lines().count)
        refresh()
    }
}

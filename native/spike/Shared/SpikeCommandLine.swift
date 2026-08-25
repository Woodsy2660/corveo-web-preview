import Foundation
import HealthKit
import SwiftUI

/// Drives the §11 sequence from launch arguments, one step per process launch.
///
/// Why this exists rather than tapping the screen: SPK-1 requires the process to be
/// terminated for real between the commit and the resume. Running each step as its own
/// `devicectl` launch makes that unavoidable rather than remembered, and it makes the whole
/// sequence replayable verbatim on the acceptance device later.
///
/// `requestAuthorization` is deliberately NOT scriptable — the permission sheet is a UI
/// interaction and stays one.
///
/// Output alphabet is the same as everywhere else: counts, error codes, UUID prefixes.
enum SpikeCommandLine {

    private static var args: [String] { CommandLine.arguments }

    static var requested: Bool {
        args.contains { $0.hasPrefix("-spikeConfigure") || $0 == "-spikeCatchUp"
                        || $0 == "-spikeStatus" || $0 == "-spikeAuthStatus"
                        || $0 == "-spikeAck" || $0 == "-spikeStartObserving"
                        || $0 == "-spikeRequestAuth" || $0 == "-spikeWipeStore"
                        || $0 == "-spikeSources" || $0 == "-spikeNoAutoArm"
                        || $0.hasPrefix("-spikeInject") || $0 == "-spikeExportSnapshot" }
    }

    private static func intValue(after flag: String, default def: Int) -> Int {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count,
              let v = Int(args[i + 1]) else { return def }
        return v
    }

    private static func stringValue(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func run() async {
        let engine = SpikeEngine.shared
        if let v = stringValue(after: "-spikeAuthVariant"),
           let variant = SpikeAuthSet.Variant(rawValue: v) ?? {
               v == "q" ? .quantityOnly : v == "c" ? .correlationInclusive : nil }() {
            SpikeAuthSet.override = variant
        }
        print("SPIKE-CLI begin class=\(SpikeEnvironment.evidenceClass.rawValue) "
              + "authSet=\(SpikeAuthSet.variant)")

        if args.contains("-spikeAuthStatus") {
            let status = await engine.authorizationRequestStatus()
            print("  authRequestStatus=\(status) set=\(SpikeAuthSet.variant)")
        }

        if args.contains("-spikeRequestAuth") {
            print("  requestAuthorization: about to call with set=\(SpikeAuthSet.variant) "
                  + "count=\(SpikeAuthSet.read.count)")
            let code = await engine.requestAuthorization()
            print("  requestAuthorization=\(code == nil ? "returned" : "FAILED code=\(code!)")")
        }

        if args.contains("-spikeWipeStore") {
            // Spike-only. The product has no such path: §10 requires a hard INTERNAL and
            // never a silent re-init. Here it just makes a run reproducible from scratch.
            engine.store.destroyStoreForSpikeRecovery()
            engine.loadAtLaunch()
            print("  wipeStore=ok (spike-only)")
        }

        for (flag, injection) in [
            ("-spikeInjectCorruptAnchor",            StateStore.Injection.corruptAnchorData),
            ("-spikeInjectCorruptNewestGeneration",  .corruptNewestGeneration),
            ("-spikeInjectCorruptBothGenerations",   .corruptBothGenerations),
        ] where args.contains(flag) {
            do {
                try engine.store.inject(injection)
                print("  inject=\(injection.rawValue) ok")
            } catch {
                print("  inject=\(injection.rawValue) FAILED code=\(SpikeEngine.errorCode(error))")
            }
        }

        if args.contains("-spikeConfigure") {
            do {
                if let existing = engine.currentState().config {
                    // Re-configuring with the IDENTICAL tuple must be an idempotent no-op
                    // (§6.2 / T-L). Reusing the persisted tuple is also what keeps this
                    // script re-runnable: importStart is immutable once set, exactly as the
                    // server-issued value is in the product.
                    try engine.configure(enrolmentRef: existing.enrolmentRef,
                                         importStart: existing.importStart)
                    print("  configure=idempotentNoOp enrolmentRef=\(Log.prefix8(existing.enrolmentRef))")
                } else {
                    let days = intValue(after: "-spikeImportStartDaysBack", default: 30)
                    let importStart = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                    let ref = persistentEnrolmentRef()
                    try engine.configure(enrolmentRef: ref, importStart: importStart)
                    print("  configure=ok enrolmentRef=\(Log.prefix8(ref)) importStartDaysBack=\(days)")
                }
            } catch {
                print("  configure=FAILED code=\(SpikeEngine.errorCode(error))")
            }
        }

        if args.contains("-spikeConfigureConflict") {
            // The other leg of T-L: a DIFFERENT tuple must reject CONFIG_CONFLICT.
            do {
                try engine.configure(enrolmentRef: UUID().uuidString, importStart: Date())
                print("  configureConflict=UNEXPECTEDLY_ACCEPTED")
            } catch {
                print("  configureConflict=rejected code=\(SpikeEngine.errorCode(error))")
            }
        }

        if args.contains("-spikeStartObserving") {
            do {
                try await engine.startObserving()
                print("  startObserving=ok")
            } catch {
                print("  startObserving=FAILED code=\(SpikeEngine.errorCode(error))")
            }
        }

        if args.contains("-spikeCatchUp") {
            do {
                let out = try await engine.runCatchUp(trigger: .manual)
                print("  catchUp=ok bootstrapMode=\(out.bootstrap) returned=\(out.returned) "
                      + "queued=\(out.queued) malformed=\(out.malformed) "
                      + "deletedReported=\(out.deleted) anchorCommitted=\(out.anchorCommitted) "
                      + "deferred=\(out.deferred)")
                for p in out.uuidPrefixes { print("    queuedCorrelationUuid=\(p)") }
                for p in out.deletedUuidPrefixes { print("    deletedUuid=\(p)") }
            } catch {
                print("  catchUp=FAILED code=\(SpikeEngine.errorCode(error))")
            }
        }

        if args.contains("-spikeAck") {
            let snap = engine.snapshot()
            do {
                let r = try engine.acknowledge(snapshotId: snap.snapshotId, itemIds: snap.itemIds)
                print("  ack=ok removed=\(r.removed) alreadyAbsent=\(r.alreadyAbsent)")
            } catch {
                print("  ack=FAILED code=\(SpikeEngine.errorCode(error))")
            }
        }

        if args.contains("-spikeStatus") {
            let s = engine.currentState()
            let snap = engine.snapshot()
            print("  state=\(stateName(s)) bootstrapComplete=\(s.bootstrapComplete) "
                  + "anchorPersisted=\(s.anchorData != nil) pending=\(s.queue.count) "
                  + "held=\(s.heldCount) snapshotId=\(snap.snapshotId) "
                  + "commitSeq=\(engine.store.commitSeq) slot=\(engine.store.activeSlot?.rawValue ?? "-") "
                  + "load=\(engine.store.lastLoadNote ?? "-") "
                  + "anchorResets=\(s.diagnostics.anchorResets) "
                  + "anchorResetReason=\(s.anchorResetReason ?? "-") "
                  + "genFallbacks=\(s.diagnostics.generationFallbacks) "
                  + "malformedSources=\(s.diagnostics.malformedBySource.count) "
                  + "recentUuids=\(s.recentUuids.count)")
            for p in snap.uuidPrefixes { print("    pendingCorrelationUuid=\(p)") }
        }

        if args.contains("-spikeExportSnapshot") {
            // The drain payload, which by definition carries values (§7.1 getPendingSnapshot).
            // This is NOT a log line and must never be treated as one: do not commit it, do
            // not paste it into evidence, and run it against writer-generated synthetic data
            // only (§4.2). Delimited so a harness can lift it out of the console cleanly.
            let s = engine.currentState()
            struct Row: Encodable {
                let itemId, hkUuid, enrolmentRef: String
                let systolicUuid, diastolicUuid: String?
                let systolic, diastolic: Double
                let takenAt: String
                let tzOffsetMinutes: Int?
                let sourceBundleId, sourceName: String
                let deviceModel: String?
                let receivedAt: String
            }
            struct Payload: Encodable { let snapshotId: String; let readings: [Row] }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            iso.timeZone = TimeZone(identifier: "UTC")
            let payload = Payload(
                snapshotId: s.snapshotToken,
                readings: s.queue.map {
                    Row(itemId: $0.itemId, hkUuid: $0.hkUuid, enrolmentRef: $0.enrolmentRef,
                        systolicUuid: $0.systolicUuid, diastolicUuid: $0.diastolicUuid,
                        systolic: $0.systolic, diastolic: $0.diastolic,
                        takenAt: iso.string(from: $0.takenAt),
                        tzOffsetMinutes: $0.tzOffsetMinutes,
                        sourceBundleId: $0.sourceBundleId, sourceName: $0.sourceName,
                        deviceModel: $0.deviceModel,
                        receivedAt: iso.string(from: $0.receivedAt))
                })
            let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
            if let data = try? enc.encode(payload), let json = String(data: data, encoding: .utf8) {
                print("SPIKE-SNAPSHOT-JSON-BEGIN")
                print(json)
                print("SPIKE-SNAPSHOT-JSON-END")
            } else {
                print("  exportSnapshot=FAILED encode")
            }
        }

        if args.contains("-spikeSources") {
            let s = engine.currentState()
            var bySource: [String: Int] = [:]
            for r in s.queue { bySource[r.sourceBundleId, default: 0] += 1 }
            print("  pendingBySource:")
            for (source, n) in bySource.sorted(by: { $0.key < $1.key }) {
                print("    \(source)=\(n)")
            }
            for (source, n) in s.diagnostics.malformedBySource.sorted(by: { $0.key < $1.key }) {
                print("    malformed:\(source)=\(n)")
            }
        }

        print("SPIKE-CLI end")
    }

    private static func stateName(_ s: EngineState) -> String {
        guard s.enrolmentRef != nil else { return "unconfigured" }
        guard s.desiredObservationEnabled else { return "configuredDisabled" }
        if let arm = s.lastArm, !arm.ok { return "armFailed" }
        return "configuredEnabled"
    }

    /// Stand-in for the server enrolment row's UUID (§6.1), stable across launches so the
    /// configuration tuple stays idempotent between steps. Minted on the handset only
    /// because the spike has no server; the product takes it from the session.
    private static func persistentEnrolmentRef() -> String {
        if let existing = UserDefaults.standard.string(forKey: "spike.enrolmentRef") {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: "spike.enrolmentRef")
        return fresh
    }
}

struct SpikeCommandLineView: View {
    var body: some View {
        Text("running spike step…")
            .task {
                await SpikeCommandLine.run()
                UserDefaults.standard.synchronize()   // exit(0) must not race the write
                exit(0)
            }
    }
}

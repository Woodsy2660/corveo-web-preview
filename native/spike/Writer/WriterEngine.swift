import Foundation
import HealthKit
import UIKit

/// Synthetic writes for §11 (SPK-1, SPK-2, SPK-close) and §12 P3b.
/// Every readout is a UUID prefix, a count or an error code.
@MainActor
final class WriterEngine: ObservableObject {

    static let shared = WriterEngine()

    /// Correlation UUIDs this app wrote. Persisted so a scripted sequence can delete across
    /// process launches; opaque identifiers only, no magnitudes.
    @Published private(set) var written: [String] = [] {
        didSet { UserDefaults.standard.set(written, forKey: "writer.written") }
    }
    @Published var busy = false
    @Published var lastError: String?
    @Published var pendingDelaySeconds = 60

    private let health = HKHealthStore()

    private init() {
        written = UserDefaults.standard.stringArray(forKey: "writer.written") ?? []
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        do {
            try await health.requestAuthorization(toShare: WriterTypes.share, read: WriterTypes.read)
            Log.event("writer.auth.requested")
            lastError = nil
        } catch {
            lastError = "\((error as NSError).code)"
            Log.event("writer.auth.failed", code: lastError)
        }
    }

    // MARK: - The §12 P3b button set

    /// SPK-1 step 5, part one.
    func saveNow() async { await save(at: Date(), pair: .primary, label: "now") }

    /// SPK-1 step 5, part two — the 7-day-backdated correlation. `importStart` on the
    /// reader must precede this instant or the production predicate excludes it.
    func saveBackdated7d() async {
        let when = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        await save(at: when, pair: .primary, label: "backdated7d")
    }

    func saveFutureDated1d() async {
        let when = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        await save(at: when, pair: .secondary, label: "futureDated1d")
    }

    func saveTenAcrossLastWeek() async {
        for i in 0..<10 {
            let when = Calendar.current.date(byAdding: .hour, value: -(i * 16 + 1), to: Date()) ?? Date()
            await save(at: when, pair: i.isMultiple(of: 2) ? .primary : .secondary,
                       label: "bulkLastWeek")
        }
    }

    /// Layer-2 candidate: a duplicate of the last write, 90 s later.
    func saveDuplicateOfLastPlus90s() async {
        let when = Date().addingTimeInterval(90)
        await save(at: when, pair: .primary, label: "duplicatePlus90s")
    }

    /// T8b — three identical-value events at +0:00 / +2:50 / +5:40. Layer-2 must resolve
    /// B as superseded by A and C as a NEW canonical. Written here; adjudicated in SQL.
    func saveT8bChain() async {
        let base = Date()
        for offset in [0.0, 170.0, 340.0] {
            await save(at: base.addingTimeInterval(offset), pair: .primary, label: "t8bChain")
        }
    }

    func saveWithoutTimeZoneMetadata() async {
        await save(at: Date(), pair: .secondary, label: "noTzMetadata", includeTimeZone: false)
    }

    /// A lone systolic quantity sample — no correlation. The systolic observer should fire
    /// while the correlation query returns nothing: the empty-delta anchor-advance case
    /// (M19), and the reason `malformedBySource` exists.
    func saveBareSystolic() async {
        busy = true; defer { busy = false }
        let now = Date()
        let sample = HKQuantitySample(
            type: WriterTypes.systolic,
            quantity: HKQuantity(unit: WriterTypes.mmHg, doubleValue: SyntheticPair.primary.systolic),
            start: now, end: now,
            metadata: [HKMetadataKeyTimeZone: TimeZone.current.identifier])
        do {
            try await health.save(sample)
            Log.event("writer.saved.bareSystolic", id8: Log.prefix8(sample.uuid.uuidString))
            lastError = nil
        } catch {
            lastError = Self.code(error)
            Log.event("writer.save.failed", code: lastError, type: "bareSystolic")
        }
    }

    /// T5a — delayed save so the write lands while the harness is backgrounded and the
    /// phone is locked. `beginBackgroundTask` buys the window; how long iOS actually grants
    /// is an on-device fact, so the delay is adjustable and the outcome is logged either way.
    func saveAfterDelay() {
        let seconds = pendingDelaySeconds
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "writer.delayedSave") {
            Log.event("writer.delayed.expired")
            if taskId != .invalid { UIApplication.shared.endBackgroundTask(taskId); taskId = .invalid }
        }
        Log.event("writer.delayed.scheduled", count: seconds)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            await save(at: Date(), pair: .secondary, label: "delayed")
            if taskId != .invalid { UIApplication.shared.endBackgroundTask(taskId); taskId = .invalid }
        }
    }

    // MARK: - Delete (SPK-2 / SPK-close)

    /// Deletes the most recent correlation this app wrote. `deleteObjects` only ever
    /// removes objects the calling app owns, so no other source can be touched from here.
    /// The UUID removed by the most recent successful `deleteLastWritten()`, so the caller
    /// can report what was deleted rather than what is now last.
    private(set) var lastDeleted: String?

    func deleteLastWritten() async {
        guard let uuidString = written.last, let uuid = UUID(uuidString: uuidString) else {
            Log.event("writer.delete.nothingToDelete"); return
        }
        busy = true; defer { busy = false }
        do {
            let count: Int = try await withCheckedThrowingContinuation { c in
                health.deleteObjects(of: WriterTypes.correlation,
                                     predicate: HKQuery.predicateForObject(with: uuid)) { _, n, error in
                    if let error { c.resume(throwing: error) } else { c.resume(returning: n) }
                }
            }
            written.removeLast()
            lastDeleted = uuidString
            Log.event("writer.deleted", count: count, id8: Log.prefix8(uuidString))
            lastError = nil
        } catch {
            lastError = Self.code(error)
            Log.event("writer.delete.failed", code: lastError)
        }
    }

    // MARK: - Core save

    private func save(at date: Date, pair: SyntheticPair, label: StaticString,
                      includeTimeZone: Bool = true) async {
        busy = true; defer { busy = false }
        let metadata: [String: Any]? = includeTimeZone
            ? [HKMetadataKeyTimeZone: TimeZone.current.identifier]
            : nil
        let sys = HKQuantitySample(
            type: WriterTypes.systolic,
            quantity: HKQuantity(unit: WriterTypes.mmHg, doubleValue: pair.systolic),
            start: date, end: date, metadata: metadata)
        let dia = HKQuantitySample(
            type: WriterTypes.diastolic,
            quantity: HKQuantity(unit: WriterTypes.mmHg, doubleValue: pair.diastolic),
            start: date, end: date, metadata: metadata)
        let correlation = HKCorrelation(
            type: WriterTypes.correlation, start: date, end: date,
            objects: [sys, dia], metadata: metadata)
        do {
            try await health.save(correlation)
            written.append(correlation.uuid.uuidString)
            Log.event(label, id8: Log.prefix8(correlation.uuid.uuidString))
            Log.event("writer.saved", count: written.count)
            lastError = nil
        } catch {
            lastError = Self.code(error)
            Log.event("writer.save.failed", code: lastError)
        }
    }

    static func code(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == "com.apple.healthkit" else { return "\(ns.domain):\(ns.code)" }
        let name: String
        switch ns.code {
        case 1:  name = "healthDataUnavailable"
        case 2:  name = "healthDataRestricted"
        case 3:  name = "invalidArgument"
        case 4:  name = "authorizationDenied"
        case 5:  name = "authorizationNotDetermined"
        case 6:  name = "databaseInaccessible"
        case 7:  name = "userCanceled"
        case 11: name = "noData"
        default: name = "unmapped"
        }
        return "HK:\(ns.code)/\(name)"
    }
}

import Foundation
import HealthKit

/// Guide §12 Phase 1 — correlation -> pre-commit payload.
///
/// **Structural checks only (§7.3).** Exactly one systolic + one diastolic child; both
/// finite; unit convertible to mmHg; UUID present. `takenAt >= importStart` is enforced by
/// the query predicate and re-checked by the engine. There are no range checks in this lane:
/// "is systolic a finite number" is allowed, "is systolic high" is a contract breach.
///
/// `receivedAt`/`itemId` are NOT set here — `StateStore.commit` assigns both exactly once at
/// first enqueue (MappedReading -> QueuedReading).
enum Mapper {
    static func map(_ sample: HKSample) -> MappedReading? {
        guard let corr = sample as? HKCorrelation,
              corr.objects(for: BPTypes.systolic).count == 1,
              corr.objects(for: BPTypes.diastolic).count == 1,
              let sys = corr.objects(for: BPTypes.systolic).first
                        as? HKQuantitySample,
              let dia = corr.objects(for: BPTypes.diastolic).first
                        as? HKQuantitySample
        else { return nil }        // counted per-source, never silently lost
        guard sys.quantity.`is`(compatibleWith: BPTypes.mmHg),
              dia.quantity.`is`(compatibleWith: BPTypes.mmHg)
        else { return nil }
        let s = sys.quantity.doubleValue(for: BPTypes.mmHg)
        let d = dia.quantity.doubleValue(for: BPTypes.mmHg)
        guard s.isFinite, d.isFinite else { return nil }
        let tz = timeZoneFromMetadata(corr)
        return MappedReading(
            hkUuid: corr.uuid.uuidString,
            systolicUuid: sys.uuid.uuidString,
            diastolicUuid: dia.uuid.uuidString,
            systolic: s, diastolic: d,
            takenAt: corr.startDate,
            tzIdentifier: tz?.identifier,                               // nil when absent [R17]
            tzOffsetMinutes: tz.map { $0.secondsFromGMT(for: corr.startDate) / 60 },
            sourceBundleId: corr.sourceRevision.source.bundleIdentifier,
            sourceName: corr.sourceRevision.source.name,
            deviceModel: corr.device?.model)
    }

    /// Metadata or nil. Never `TimeZone.current` (pitfall 14).
    static func timeZoneFromMetadata(_ c: HKCorrelation) -> TimeZone? {
        guard let id = c.metadata?[HKMetadataKeyTimeZone] as? String else { return nil }
        return TimeZone(identifier: id)
    }

    /// The identifier a rejected sample is counted against (§7.3 `malformedBySource`).
    /// An identifier, never a value.
    static func sourceIdentifier(_ sample: HKSample) -> String {
        sample.sourceRevision.source.bundleIdentifier
    }
}

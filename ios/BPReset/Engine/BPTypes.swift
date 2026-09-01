import Foundation
import HealthKit

/// Guide §7.4 — canonical type contract, verbatim.
///
/// ADR-0006 / finding S2: a correlation type in either authorisation set aborts the
/// process, so the quantity-only read set is the only legal set, not merely the minimal one.
enum BPTypes {
    static let systolic    = HKQuantityType(.bloodPressureSystolic)
    static let diastolic   = HKQuantityType(.bloodPressureDiastolic)
    static let correlation = HKCorrelationType(.bloodPressure)
    static let mmHg        = HKUnit.millimeterOfMercury()
    /// The ONLY legal authorisation set (S2, confirmed on device 26 Aug 2026).
    static let authorizationRead: Set<HKObjectType> = [systolic, diastolic]
    /// Wake signals + background delivery register per QUANTITY type.
    static let observed: [HKSampleType] = [systolic, diastolic]
    /// The incremental cursor targets the CORRELATION type.
    static let fetched: HKSampleType = correlation
}

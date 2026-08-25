import Foundation
import HealthKit

/// Guide §7.4 — canonical type contract, verbatim.
///
/// This enum is the product contract. The SPK-3 A/B lives in `SpikeAuthSet`, not here:
/// if SPK-3 shows the quantity-only set under-authorises, `authorizationRead` is amended
/// HERE and only here, and ADR-0004 records why.
enum BPTypes {
    static let systolic    = HKQuantityType(.bloodPressureSystolic)
    static let diastolic   = HKQuantityType(.bloodPressureDiastolic)
    static let correlation = HKCorrelationType(.bloodPressure)
    static let mmHg        = HKUnit.millimeterOfMercury()
    /// CHOSEN MINIMAL SET. Correlation types are also legal in read sets per
    /// Apple's API contract [R24]; SPK-3 records observed behaviour of both
    /// sets on the frozen acceptance OS. If SPK-3 shows the quantity-only set
    /// under-authorises, amend HERE and only here (ADR-0004 records why).
    static let authorizationRead: Set<HKObjectType> = [systolic, diastolic]
    /// Wake signals + background delivery register per QUANTITY type.
    static let observed: [HKSampleType] = [systolic, diastolic]
    /// The incremental cursor targets the CORRELATION type.
    static let fetched: HKSampleType = correlation
}

/// Spike-only. §11 SPK-3 compares two authorisation sets across two clean permission
/// identities (`dev.lucab.bpspike` vs `dev.lucab.bpspikec`). Selected by the per-target
/// compilation condition so §7.4 above stays verbatim in both binaries.
enum SpikeAuthSet {
    enum Variant: String {
        case quantityOnly        = "Q-quantityOnly"
        case correlationInclusive = "C-correlationInclusive"
    }

    #if SPIKE_READER_C
    static let compiledDefault: Variant = .correlationInclusive
    #else
    static let compiledDefault: Variant = .quantityOnly
    #endif

    /// Set from a launch argument so one bundle can exercise both sets during a controlled
    /// experiment. The real SPK-3 A/B still uses two bundles — one app's Health permission
    /// state contaminates the comparison, which is why the two readers exist.
    static var override: Variant?

    static var current: Variant { override ?? compiledDefault }
    static var variant: String { current.rawValue }

    static var read: Set<HKObjectType> {
        switch current {
        case .quantityOnly:
            return BPTypes.authorizationRead
        case .correlationInclusive:
            return [BPTypes.systolic, BPTypes.diastolic, BPTypes.correlation]
        }
    }
}

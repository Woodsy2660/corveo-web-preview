import Foundation
import HealthKit

/// The writer is a throwaway synthetic-source generator (`dev.lucab.bpwriter`). It is the
/// **only** target that carries `NSHealthUpdateUsageDescription`, and it never ships.
/// It deliberately does not import the reader engine: the read-only posture of the plugin
/// and harness is proved by the absence of a write path, and sharing code would blur that.
enum WriterTypes {
    static let systolic    = HKQuantityType(.bloodPressureSystolic)
    static let diastolic   = HKQuantityType(.bloodPressureDiastolic)
    static let correlation = HKCorrelationType(.bloodPressure)
    static let mmHg        = HKUnit.millimeterOfMercury()

    /// MEASURED on device, 26 Aug (iPadOS 26.6.1, SIDECAR — needs iPhone confirmation):
    /// `HKCorrelationTypeIdentifierBloodPressure` is disallowed in BOTH authorisation sets.
    /// It does not return an error — it raises `NSInvalidArgumentException` and the process
    /// aborts. Authorisation attaches to the contained quantity types only, exactly as §5.1
    /// states; it is ship-gate 1's *withdrawal* that is wrong, not §7.4's chosen set.
    ///
    /// Defaults are therefore quantity-only. The flags remain so the experiment is
    /// repeatable verbatim on the acceptance device.
    static var shareIncludesCorrelation = false
    static var readIncludesCorrelation  = false

    static var variantLabel: String {
        "share=\(shareIncludesCorrelation ? "corr" : "qty")/read=\(readIncludesCorrelation ? "corr" : "qty")"
    }

    static var share: Set<HKSampleType> {
        shareIncludesCorrelation ? [systolic, diastolic, correlation] : [systolic, diastolic]
    }
    /// The writer also reads, so it can delete its own rows for SPK-2/SPK-close.
    static var read: Set<HKObjectType> {
        readIncludesCorrelation ? [systolic, diastolic, correlation] : [systolic, diastolic]
    }
}

/// Synthetic magnitudes. Not measurements, not derived from any person, and never rendered
/// on screen or written to a log line — the writer's own readouts are UUID prefixes and
/// counts, exactly like the readers' (§4.2). Guide §4.2 expressly permits writer-generated
/// synthetic values as the substitute for real ones in every retained artefact.
struct SyntheticPair {
    let systolic: Double
    let diastolic: Double

    static let primary   = SyntheticPair(systolic: 118, diastolic: 76)
    static let secondary = SyntheticPair(systolic: 124, diastolic: 81)
}

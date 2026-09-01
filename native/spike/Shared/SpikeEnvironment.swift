import Foundation
import HealthKit
import UIKit

/// The evidential environment block for ADR-0004's environment table.
/// Device model **identifier** (not marketing name) and the **exact build number** are both
/// outstanding run-sheet items, and both are readable here rather than transcribed by hand.
enum SpikeEnvironment {

    static var deviceModelIdentifier: String {
        // In the simulator `utsname.machine` reports the host architecture, not a model.
        // Take the simulated model instead so a pasted block is never quietly wrong.
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var sysinfo = utsname()
        uname(&sysinfo)
        let mirror = Mirror(reflecting: sysinfo.machine)
        let bytes = mirror.children.compactMap { $0.value as? Int8 }.filter { $0 != 0 }
        return String(bytes.map { Character(UnicodeScalar(UInt8(bitPattern: $0))) })
    }

    /// e.g. "Version 26.6 (Build 23G93)" — carries the exact build number (§3.5).
    static var osVersionString: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    static var osBuildNumber: String {
        let s = osVersionString
        guard let open = s.range(of: "(Build "),
              let close = s.range(of: ")", range: open.upperBound..<s.endIndex)
        else { return "unknown" }
        return String(s[open.upperBound..<close.lowerBound])
    }

    static var osShortVersion: String { UIDevice.current.systemVersion }

    static var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "unknown" }

    static var healthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// §3.5: the frozen acceptance OS is iOS 26.6 or later; results against any other build
    /// are void. This is a check on the *operating system build*. It is not, and must never
    /// become, a check on a reading.
    static var meetsFrozenBaseline: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 0))
    }

    // MARK: - Evidence class

    /// What a run on THIS host is allowed to be used for.
    ///
    /// §9.4: "Physical iPhone for everything evidential; iPad is a sidecar at most."
    /// §3.5: results against any build other than the frozen acceptance OS are void.
    /// Pitfall 1: the simulator lies — vendor apps, sources and background delivery only
    /// exist on the physical iPhone.
    ///
    /// This exists so an ADR-0004 table cannot be pasted from a host that was never entitled
    /// to produce one. The classification is stamped into the block itself, not left to the
    /// operator to remember at the end of a long day.
    enum EvidenceClass: String {
        case evidential      = "EVIDENTIAL"
        case sidecar         = "SIDECAR"
        case void            = "VOID"
        case baselineMismatch = "BASELINE-MISMATCH"

        var explanation: String {
            switch self {
            case .evidential:
                return "physical iPhone on the frozen acceptance OS (26.6 <= iOS < 27) — results may be recorded in the spike-outcome ADR"
            case .sidecar:
                return "NOT the acceptance device (§9.4) — development testing only; no SPK verdict, nothing enters the ADR"
            case .void:
                return "below the frozen acceptance OS (§3.5) — results are void"
            case .baselineMismatch:
                return "iPhone, but on an OS GENERATION the baseline never validated. §3.5 froze 26.6+ against a 26.5 regression; a 26.x floor says nothing about 27.x. Results are not attributable to the frozen baseline until §3.5 is amended to name this OS — that is a decision, not a default"
            }
        }
    }

    /// The OS generation §3.5 was frozen against. The guide states the baseline as a floor
    /// ("26.6 or later"), which literally admits any future major version — but the reason for
    /// the floor was a specific 26.5 regression fixed in 26.6 [R23], so it carries no evidence
    /// about 27.x at all. Treating a newer generation as automatically compliant is exactly the
    /// folklore this project refuses to run on. Flagged, not silently accepted.
    static let baselineMajorVersion = 26

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    static var deviceClass: String {
        let idiom: String
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: idiom = "iPhone"
        case .pad:   idiom = "iPad"
        default:     idiom = "other"
        }
        return isSimulator ? "\(idiom) (simulator)" : idiom
    }

    static var evidenceClass: EvidenceClass {
        guard !isSimulator, isPhone else { return .sidecar }
        guard meetsFrozenBaseline else { return .void }
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return major == baselineMajorVersion ? .evidential : .baselineMismatch
    }

    /// A build number ending in a lower-case letter is an Apple seed/beta build (e.g.
    /// "24A5424a") rather than a public release (e.g. "23G83"). Reported, not asserted on:
    /// the operator confirms it. Evidence taken on a seed build is not reproducible after the
    /// seed is superseded, which is the whole reason §3.5 freezes a baseline at all.
    static var looksLikeSeedBuild: Bool {
        guard let last = osBuildNumber.last else { return false }
        return last.isLowercase && last.isLetter
    }

    /// Markdown ready to paste into ADR-0004. Identifiers, versions and states only.
    ///
    /// A block produced on a non-acceptance host carries its own disqualification in the
    /// first line, so it cannot be pasted into the ADR as though it were evidence.
    static func adrEnvironmentBlock(authVariant: String) -> String {
        let banner = evidenceClass == .evidential
            ? ""
            : """
              > **\(evidenceClass.rawValue) — DO NOT RECORD IN ADR-0004.**
              > \(evidenceClass.explanation) Host: \(deviceClass) `\(deviceModelIdentifier)`.

              """
        return banner + """
        | Field | Value |
        |---|---|
        | Evidence class | **\(evidenceClass.rawValue)** — \(evidenceClass.explanation) |
        | Device class | \(deviceClass) |
        | Device model | `\(deviceModelIdentifier)` |
        | OS version | `\(osShortVersion)` |
        | Exact build number | `\(osBuildNumber)` |
        | Frozen baseline (>= 26.6) met | \(meetsFrozenBaseline ? "yes" : "NO - results are void (3.5)") |
        | OS generation matches baseline (26.x) | \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion == baselineMajorVersion ? "yes" : "NO - see evidence class") |
        | Build looks like an Apple seed/beta | \(looksLikeSeedBuild ? "YES - confirm before recording" : "no") |
        | Bundle ID | `\(bundleIdentifier)` |
        | Authorisation set | `\(authVariant)` |
        | HealthKit available | \(healthDataAvailable ? "yes" : "no") |
        """
    }
}

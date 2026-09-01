import Foundation

/// Guide §7.2 error model. The spike raises the same codes the bridge will, so the
/// vocabulary is exercised before any bridge code depends on it.
enum BPError: Error, CustomStringConvertible {
    case hkUnavailable
    case configMissing
    case configConflict
    case promptPending
    case bgDeliveryFailed(String?)
    case hkTempUnavailable
    case snapshotStale
    case heldNotFound
    case confirmRequired
    case queryFailed(String)
    case internalFault(String)

    var code: String {
        switch self {
        case .hkUnavailable:      return "HK_UNAVAILABLE"
        case .configMissing:      return "CONFIG_MISSING"
        case .configConflict:     return "CONFIG_CONFLICT"
        case .promptPending:      return "PROMPT_PENDING"
        case .bgDeliveryFailed:   return "BG_DELIVERY_FAILED"
        case .hkTempUnavailable:  return "HK_TEMP_UNAVAILABLE"
        case .snapshotStale:      return "SNAPSHOT_STALE"
        case .heldNotFound:       return "HELD_NOT_FOUND"
        case .confirmRequired:    return "CONFIRM_REQUIRED"
        case .queryFailed:        return "QUERY_FAILED"
        case .internalFault:      return "INTERNAL"
        }
    }

    /// Detail is an error code or a reason token — never a value, never a reading (§4.2).
    var detail: String? {
        switch self {
        case .bgDeliveryFailed(let d): return d
        case .queryFailed(let d):      return d
        case .internalFault(let d):    return d
        default:                       return nil
        }
    }

    var description: String { detail.map { "\(code)/\($0)" } ?? code }
}


/// HealthKit error codes by name. Evidence carries error codes (§4.2); a name is still a
/// code, and "authorizationNotDetermined" is a great deal more use at 1am than "5".
enum HKErrorName {
    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == "com.apple.healthkit" else { return "\(ns.domain):\(ns.code)" }
        let name: String
        switch ns.code {
        case 0:  name = "noError"
        case 1:  name = "healthDataUnavailable"
        case 2:  name = "healthDataRestricted"
        case 3:  name = "invalidArgument"
        case 4:  name = "authorizationDenied"
        case 5:  name = "authorizationNotDetermined"
        case 6:  name = "databaseInaccessible"
        case 7:  name = "userCanceled"
        case 8:  name = "anotherWorkoutSessionStarted"
        case 9:  name = "userExitedWorkoutSession"
        case 10: name = "requiredAuthorizationDenied"
        case 11: name = "noData"
        default: name = "unmapped"
        }
        return "HK:\(ns.code)/\(name)"
    }
}

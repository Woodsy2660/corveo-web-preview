import Foundation

/*
 API contract types. Shapes mirror docs/02-data-model-and-api.md Part 4 and the deployed v0.2
 views and RPCs: the app codes against `v_bp_readings`, `v_bp_trend`, `v_consent_status`,
 `v_program_progress` and `ingest_observations`, never base tables.
 */

enum SourceType: String, Codable, Hashable { case healthkit, manual }

/// Row shape of `v_bp_readings`.
struct BpReadingRow: Codable, Hashable, Identifiable {
    let id: String
    let effectiveTime: Date
    let effectiveTz: String?
    let systolic: Double
    let diastolic: Double
    let sourceType: SourceType
    let sourceName: String?
    let bodySiteDisplay: String?

    enum CodingKeys: String, CodingKey {
        case id
        case effectiveTime = "effective_time"
        case effectiveTz = "effective_tz"
        case systolic, diastolic
        case sourceType = "source_type"
        case sourceName = "source_name"
        case bodySiteDisplay = "body_site_display"
    }
}

/// Row shape of `v_bp_trend`: a daily aggregate, computed server-side.
struct BpTrendRow: Codable, Hashable, Identifiable {
    var id: String { day }
    let day: String            // YYYY-MM-DD, local calendar day
    let minSystolic: Double
    let maxSystolic: Double
    let meanSystolic: Double
    let minDiastolic: Double
    let maxDiastolic: Double
    let meanDiastolic: Double
    let readingCount: Int

    enum CodingKeys: String, CodingKey {
        case day
        case minSystolic = "min_systolic"
        case maxSystolic = "max_systolic"
        case meanSystolic = "mean_systolic"
        case minDiastolic = "min_diastolic"
        case maxDiastolic = "max_diastolic"
        case meanDiastolic = "mean_diastolic"
        case readingCount = "reading_count"
    }

    var date: Date { Format.parseDay(day) ?? Date() }
}

struct ConsentStatusRow: Codable, Hashable {
    let hasActiveConsent: Bool
    let version: String?
    let lastEventAt: Date?
    enum CodingKeys: String, CodingKey {
        case hasActiveConsent = "has_active_consent"
        case version
        case lastEventAt = "last_event_at"
    }
}

struct ProgramProgressRow: Codable, Hashable {
    var currentWeek: Int
    var completedSteps: [String: Bool]
    enum CodingKeys: String, CodingKey {
        case currentWeek = "current_week"
        case completedSteps = "completed_steps"
    }
}

// MARK: - Ingest payload (`ingest_observations`)

struct IngestComponent: Codable, Hashable {
    let sourceUuid: String
    let code: String            // LOINC: 8480-6 systolic, 8462-4 diastolic
    let valueQuantity: Double
    let valueUnit: String       // mm[Hg]
    enum CodingKeys: String, CodingKey {
        case sourceUuid = "source_uuid"
        case code
        case valueQuantity = "value_quantity"
        case valueUnit = "value_unit"
    }
}

struct IngestObservation: Codable, Hashable {
    let sourceUuid: String
    let code: String            // LOINC 85354-9 BP panel
    let effectiveTime: Date
    let effectiveTz: String?
    let effectiveOffsetMinutes: Int?
    let sourceSystem: String
    let sourceName: String?
    let sourceDeviceModel: String?
    let sourceUserEntered: Bool
    let bodySiteCode: String?
    let context: [String: String]
    let components: [IngestComponent]
    enum CodingKeys: String, CodingKey {
        case sourceUuid = "source_uuid"
        case code
        case effectiveTime = "effective_time"
        case effectiveTz = "effective_tz"
        case effectiveOffsetMinutes = "effective_offset_minutes"
        case sourceSystem = "source_system"
        case sourceName = "source_name"
        case sourceDeviceModel = "source_device_model"
        case sourceUserEntered = "source_user_entered"
        case bodySiteCode = "body_site_code"
        case context, components
    }
}

struct IngestPayload: Codable, Hashable {
    let sourceType: SourceType
    let observations: [IngestObservation]
    var deletedSourceUuids: [String] = []
    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case observations
        case deletedSourceUuids = "deleted_source_uuids"
    }
}

enum RejectionReason: String, Codable, Hashable {
    case valueOutOfBounds = "VALUE_OUT_OF_BOUNDS"
    case unitMismatch = "UNIT_MISMATCH"
    case unknownCode = "UNKNOWN_CODE"
    case systolicNotGreater = "SYSTOLIC_NOT_GREATER"
    case malformedTimestamp = "MALFORMED_TIMESTAMP"
    case missingComponent = "MISSING_COMPONENT"
}

struct IngestRejection: Codable, Hashable {
    let sourceUuid: String
    let reason: RejectionReason
    let detail: String
    enum CodingKeys: String, CodingKey {
        case sourceUuid = "source_uuid"
        case reason, detail
    }
}

struct IngestResponse: Codable, Hashable {
    let inserted: Int
    let duplicates: Int
    let softDeleted: Int
    let rejected: [IngestRejection]
    enum CodingKeys: String, CodingKey {
        case inserted, duplicates
        case softDeleted = "soft_deleted"
        case rejected
    }
}

struct ConsentEventInput: Hashable {
    let action: String          // granted | withdrawn
    let version: String
    let documentHash: String    // SHA-256 of the exact consent text shown
}

struct ExportResult: Hashable {
    let fhirBundleJSON: String
    let csv: String
}

// MARK: - Codes and bounds

enum LOINC {
    static let bpPanel = "85354-9"
    static let systolic = "8480-6"
    static let diastolic = "8462-4"
    static let unit = "mm[Hg]"
}

enum SNOMEDBodySite {
    static let leftArm = "368208006"
    static let rightArm = "368209003"
}

/// Data-quality bounds, mirrored from the `observation_definition` seed migration
/// (`supabase/migrations/20260729100200_seed_observation_definitions_bp.sql`).
///
/// These are input validation, not clinical interpretation (SOW Deliverable 4). They exist
/// to catch typos. Nothing here, and nothing built on top of it, may comment on whether a
/// plausible value is high, low, or concerning.
enum Bounds {
    static let systolic: ClosedRange<Double> = 60...260
    static let diastolic: ClosedRange<Double> = 30...160
}

enum FieldError: Equatable { case outOfBounds, systolicNotGreater, required }

struct ManualEntryDraft {
    var systolic: String = ""
    var diastolic: String = ""
}

struct ManualEntryErrors: Equatable {
    var systolic: FieldError?
    var diastolic: FieldError?
    var cross: FieldError?
    var isEmpty: Bool { systolic == nil && diastolic == nil && cross == nil }
}

/// Pure validation for the manual-entry form. Mechanical only.
func validateManualEntry(_ draft: ManualEntryDraft) -> ManualEntryErrors {
    var errors = ManualEntryErrors()
    let sys = Double(draft.systolic.trimmingCharacters(in: .whitespaces))
    let dia = Double(draft.diastolic.trimmingCharacters(in: .whitespaces))

    if let sys {
        if !Bounds.systolic.contains(sys) { errors.systolic = .outOfBounds }
    } else {
        errors.systolic = .required
    }
    if let dia {
        if !Bounds.diastolic.contains(dia) { errors.diastolic = .outOfBounds }
    } else {
        errors.diastolic = .required
    }
    if errors.systolic == nil, errors.diastolic == nil, let sys, let dia, sys <= dia {
        errors.cross = .systolicNotGreater
    }
    return errors
}

/// The reading as submitted, for screens that show it back immediately.
struct SubmittedReading: Hashable {
    let systolic: Double
    let diastolic: Double
    let effectiveTime: Date
    let sourceType: SourceType
}

// MARK: - Formatting (en-AU throughout)

enum Format {
    static let locale = Locale(identifier: "en_AU")

    static func date(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(locale: locale).month(.abbreviated).day(.defaultDigits))
    }
    static func dateTime(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(locale: locale).month(.abbreviated).day(.defaultDigits).hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits))
    }
    static func fullDate(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(locale: locale).month(.wide).day(.defaultDigits).year(.defaultDigits))
    }
    /// Time of day alone, for "Updated 7:14 am".
    static func time(_ d: Date) -> String {
        d.formatted(Date.FormatStyle(locale: locale).hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits))
    }
    static func mmHg(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Local calendar day (YYYY-MM-DD) of a Date.
    static func localDay(_ d: Date) -> String { dayFormatter.string(from: d) }
    static func parseDay(_ s: String) -> Date? { dayFormatter.date(from: s) }
    static func dayNDaysAgo(_ n: Int, now: Date = Date()) -> String {
        localDay(Calendar.current.date(byAdding: .day, value: -n, to: now) ?? now)
    }

    /// IANA name and offset for a manual entry: the phone's zone genuinely is the reading's.
    static func localTzInfo(_ d: Date = Date()) -> (tz: String, offsetMinutes: Int) {
        let tz = TimeZone.current
        return (tz.identifier, tz.secondsFromGMT(for: d) / 60)
    }
}

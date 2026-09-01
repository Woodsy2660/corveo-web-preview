import Foundation
import Security
import Supabase

// MARK: - Session storage

/// The auth session lives in the Keychain under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// and is never synchronisable: it stays out of iCloud Keychain and out of device backups
/// (rulebook §5.5, docs/02 §3.4). Tokens are not health data, but they travel the same road.
struct KeychainSessionStorage: AuthLocalStorage {
    private let service = "dev.aiplease.bpreset.auth"

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
    }

    func store(key: String, value: Data) throws {
        var add = query(key)
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemDelete(query(key) as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    func retrieve(key: String) throws -> Data? {
        var q = query(key)
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        return item as? Data
    }

    func remove(key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }

    enum KeychainError: Error { case status(OSStatus) }
}

// MARK: - Client

enum SupabaseFactory {
    static func makeClient() -> SupabaseClient? {
        guard let url = AppConfig.supabaseURL, AppConfig.hasSupabase else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.supabasePublishableKey,
            options: SupabaseClientOptions(auth: .init(storage: KeychainSessionStorage())))
    }
}

// MARK: - CorveoAPI over the deployed v0.2 schema

/// Reads go through the four views, writes through the security-definer RPCs. No base table
/// is ever written directly. Every call runs as the signed-in user under RLS.
final class SupabaseAPI: CorveoAPI, @unchecked Sendable {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: Errors

    /// PostgREST surfaces `raise exception 'CONSENT_REQUIRED'` as a message string; the app
    /// maps the two whole-call failures the drain must treat differently from a row rejection.
    private func mapped(_ error: Error) -> Error {
        let text = ((error as? PostgrestError)?.message ?? String(describing: error)).uppercased()
        if text.contains("CONSENT_REQUIRED") { return APIError.consentRequired }
        if text.contains("UNAUTHORIZED") || text.contains("JWT") || text.contains("401") { return APIError.unauthorized }
        return error
    }

    private func run<T>(_ body: () async throws -> T) async throws -> T {
        do { return try await body() } catch { throw mapped(error) }
    }

    // MARK: Readings and trend

    func listReadings(limit: Int, before: Date?) async throws -> [BpReadingRow] {
        try await run {
            var q = client.from("v_bp_readings")
                .select("id, effective_time, effective_tz, systolic, diastolic, source_type, source_name, body_site_display")
            if let before { q = q.lt("effective_time", value: before.iso8601String) }
            return try await q.order("effective_time", ascending: false).limit(limit).execute().value
        }
    }

    func getTrend(sinceDay: String?) async throws -> [BpTrendRow] {
        try await run {
            var q = client.from("v_bp_trend").select(
                "day, min_systolic, max_systolic, mean_systolic, min_diastolic, max_diastolic, mean_diastolic, reading_count")
            if let sinceDay { q = q.gte("day", value: sinceDay) }
            return try await q.order("day", ascending: true).execute().value
        }
    }

    // MARK: Consent

    func getConsentStatus() async throws -> ConsentStatusRow {
        try await run {
            try await client.from("v_consent_status")
                .select("has_active_consent, version, last_event_at")
                .single().execute().value
        }
    }

    func recordConsentEvent(_ input: ConsentEventInput) async throws -> ConsentStatusRow {
        try await run {
            if input.action == "withdrawn" {
                try await client.rpc("withdraw_consent").execute()
            } else {
                try await client.rpc("record_consent", params: RecordConsentParams(
                    p_version: input.version, p_document_hash: input.documentHash)).execute()
            }
            return try await getConsentStatus()
        }
    }

    // MARK: Ingest (the single write path for both capture paths)

    func ingestObservations(_ payload: IngestPayload) async throws -> IngestResponse {
        try await run {
            try await client.rpc("ingest_observations", params: IngestParams(payload: payload)).execute().value
        }
    }

    // MARK: Program progress

    func getProgramProgress() async throws -> ProgramProgressRow {
        try await run {
            let rows: [ProgramProgressRow] = try await client.from("v_program_progress")
                .select("current_week, completed_steps").limit(1).execute().value
            return rows.first ?? ProgramProgressRow(currentWeek: 1, completedSteps: [:])
        }
    }

    func updateProgramProgress(currentWeek: Int?, completedSteps: [String: Bool]) async throws -> ProgramProgressRow {
        try await run {
            let me: AppUserRow = try await client.from("app_user").select("id, created_at").single().execute().value
            var current = try await getProgramProgress()
            if let currentWeek { current.currentWeek = currentWeek }
            current.completedSteps.merge(completedSteps) { _, new in new }
            let row = ProgressUpsert(user_id: me.id, current_week: current.currentWeek, completed_steps: current.completedSteps)
            try await client.from("program_progress").upsert(row, onConflict: "user_id").execute()
            return current
        }
    }

    // MARK: Data controls (Deliverable 12)

    func exportPatientData() async throws -> ExportResult {
        try await run {
            let out: ExportRPCResponse = try await client.rpc("export_patient_data").execute().value
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bundleData = try encoder.encode(out.fhir_bundle)
            return ExportResult(fhirBundleJSON: String(decoding: bundleData, as: UTF8.self), csv: out.csv)
        }
    }

    func requestAccountDeletion() async throws {
        try await run {
            try await client.rpc("delete_account").execute()
        }
    }

    // MARK: Enrolment (the binding tuple: app_user.id and app_user.created_at)

    func enrol(displayName: String?, adultAttested: Bool) async throws -> String {
        try await run {
            let id: String = try await client.rpc("enrol_patient", params: EnrolParams(
                p_display_name: displayName, p_adult_attested: adultAttested)).execute().value
            return id
        }
    }

    func currentAppUser() async throws -> AppUserRow? {
        try await run {
            let rows: [AppUserRow] = try await client.from("app_user").select("id, created_at").limit(1).execute().value
            return rows.first
        }
    }
}

// MARK: - Wire types private to this implementation

struct AppUserRow: Codable, Sendable {
    let id: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
    }
}

private struct RecordConsentParams: Encodable {
    let p_version: String
    let p_document_hash: String
}

private struct IngestParams: Encodable {
    let payload: IngestPayload
}

private struct EnrolParams: Encodable {
    let p_display_name: String?
    let p_adult_attested: Bool
}

private struct ProgressUpsert: Encodable {
    let user_id: String
    let current_week: Int
    let completed_steps: [String: Bool]
}

private struct ExportRPCResponse: Decodable {
    let fhir_bundle: AnyJSON
    let csv: String
}

private extension Date {
    var iso8601String: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}

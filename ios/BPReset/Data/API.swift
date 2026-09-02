import Foundation
import CryptoKit

/// The API surface the app consumes. One mock implementation in Phase 1 (in memory, never
/// persisted: no reading value is written to disk by the app layer, plan N-07); the
/// Supabase-backed implementation replaces it in Phase 3 without touching any screen.
protocol CorveoAPI: Sendable {
    func listReadings(limit: Int, before: Date?) async throws -> [BpReadingRow]
    func getTrend(sinceDay: String?) async throws -> [BpTrendRow]
    func getConsentStatus() async throws -> ConsentStatusRow
    func recordConsentEvent(_ input: ConsentEventInput) async throws -> ConsentStatusRow
    func ingestObservations(_ payload: IngestPayload) async throws -> IngestResponse
    func getProgramProgress() async throws -> ProgramProgressRow
    func updateProgramProgress(currentWeek: Int?, completedSteps: [String: Bool]) async throws -> ProgramProgressRow
    func exportPatientData() async throws -> ExportResult
    /// Deletion-with-logging per SOW A.12.6, never an unconditional hard delete.
    func requestAccountDeletion() async throws
}

enum APIError: Error, LocalizedError {
    case consentRequired
    case unauthorized
    case network(String)
    var errorDescription: String? {
        switch self {
        case .consentRequired: return "CONSENT_REQUIRED"
        case .unauthorized: return "UNAUTHORIZED"
        case .network(let s): return s
        }
    }
}

// MARK: - Mock

/// DEV ONLY. Backs every screen until the Supabase implementation lands. Holds synthetic data
/// only, in memory only. Its seeded readings are deterministic so a demo is repeatable.
actor MockAPI: CorveoAPI {
    private var readings: [BpReadingRow]
    private var consent = ConsentStatusRow(hasActiveConsent: false, version: nil, lastEventAt: nil)
    /// Synthetic mid-program state so both open and locked chapters are visible.
    private var progress = ProgramProgressRow(currentWeek: 3, completedSteps: ["bp-reset:1": true])
    private var seenSourceUuids: Set<String>
    private let latency: UInt64 = 180_000_000

    init(seeded: Bool = true) {
        let rows = seeded ? Fixtures.seedReadings() : []
        readings = rows
        seenSourceUuids = Set(rows.map(\.id))
    }

    private func delay() async { try? await Task.sleep(nanoseconds: latency) }

    func reset() {
        let rows = Fixtures.seedReadings()
        readings = rows
        seenSourceUuids = Set(rows.map(\.id))
        consent = ConsentStatusRow(hasActiveConsent: false, version: nil, lastEventAt: nil)
        progress = ProgramProgressRow(currentWeek: 3, completedSteps: ["bp-reset:1": true])
    }

    func listReadings(limit: Int, before: Date?) async throws -> [BpReadingRow] {
        await delay()
        var rows = readings.sorted { $0.effectiveTime > $1.effectiveTime }
        if let before { rows = rows.filter { $0.effectiveTime < before } }
        return Array(rows.prefix(limit))
    }

    func getTrend(sinceDay: String?) async throws -> [BpTrendRow] {
        await delay()
        var rows = Fixtures.aggregateTrend(readings)
        if let sinceDay { rows = rows.filter { $0.day >= sinceDay } }
        return rows
    }

    func getConsentStatus() async throws -> ConsentStatusRow {
        await delay()
        return consent
    }

    func recordConsentEvent(_ input: ConsentEventInput) async throws -> ConsentStatusRow {
        await delay()
        consent = ConsentStatusRow(hasActiveConsent: input.action == "granted", version: input.version, lastEventAt: Date())
        return consent
    }

    func ingestObservations(_ payload: IngestPayload) async throws -> IngestResponse {
        await delay()
        // The deployed RPC refuses the whole call without active consent; the mock must too,
        // or the journey's consent step can fail unnoticed in development.
        guard consent.hasActiveConsent else { throw APIError.consentRequired }
        var inserted = 0, duplicates = 0
        var rejected: [IngestRejection] = []
        for obs in payload.observations {
            if seenSourceUuids.contains(obs.sourceUuid) { duplicates += 1; continue }
            guard obs.code == LOINC.bpPanel else {
                rejected.append(IngestRejection(sourceUuid: obs.sourceUuid, reason: .unknownCode, detail: obs.code)); continue
            }
            guard let sys = obs.components.first(where: { $0.code == LOINC.systolic }),
                  let dia = obs.components.first(where: { $0.code == LOINC.diastolic }) else {
                rejected.append(IngestRejection(sourceUuid: obs.sourceUuid, reason: .missingComponent, detail: LOINC.systolic)); continue
            }
            if !Bounds.systolic.contains(sys.valueQuantity) || !Bounds.diastolic.contains(dia.valueQuantity) {
                rejected.append(IngestRejection(sourceUuid: obs.sourceUuid, reason: .valueOutOfBounds, detail: "bounds")); continue
            }
            if sys.valueQuantity <= dia.valueQuantity {
                rejected.append(IngestRejection(sourceUuid: obs.sourceUuid, reason: .systolicNotGreater, detail: "cross")); continue
            }
            readings.append(BpReadingRow(
                id: obs.sourceUuid,
                effectiveTime: obs.effectiveTime,
                effectiveTz: obs.effectiveTz,
                systolic: sys.valueQuantity, diastolic: dia.valueQuantity,
                sourceType: payload.sourceType,
                sourceName: obs.sourceName,
                bodySiteDisplay: obs.bodySiteCode == SNOMEDBodySite.rightArm ? "Right arm"
                    : obs.bodySiteCode == SNOMEDBodySite.leftArm ? "Left arm" : nil))
            seenSourceUuids.insert(obs.sourceUuid)
            inserted += 1
        }
        return IngestResponse(inserted: inserted, duplicates: duplicates, softDeleted: 0, rejected: rejected)
    }

    func getProgramProgress() async throws -> ProgramProgressRow {
        await delay()
        return progress
    }

    func updateProgramProgress(currentWeek: Int?, completedSteps: [String: Bool]) async throws -> ProgramProgressRow {
        await delay()
        if let currentWeek { progress.currentWeek = currentWeek }
        progress.completedSteps.merge(completedSteps) { _, new in new }
        return progress
    }

    func exportPatientData() async throws -> ExportResult {
        await delay(); await delay()
        let header = "effective_time,effective_tz,systolic,diastolic,source_type,source_name"
        let iso = ISO8601DateFormatter()
        let lines = readings.map {
            "\(iso.string(from: $0.effectiveTime)),\($0.effectiveTz ?? ""),\(Format.mmHg($0.systolic)),\(Format.mmHg($0.diastolic)),\($0.sourceType.rawValue),\($0.sourceName ?? "")"
        }
        let bundle = "{\"resourceType\":\"Bundle\",\"type\":\"collection\",\"note\":\"MOCK export. The real FHIR R4 Bundle is produced server-side.\",\"total\":\(readings.count)}"
        return ExportResult(fhirBundleJSON: bundle, csv: ([header] + lines).joined(separator: "\n"))
    }

    func requestAccountDeletion() async throws {
        await delay(); await delay()
        // Real behaviour is deletion-with-logging against the retention floor, server-side.
        readings.removeAll()
        seenSourceUuids.removeAll()
        consent = ConsentStatusRow(hasActiveConsent: false, version: nil, lastEventAt: nil)
        progress = ProgramProgressRow(currentWeek: 1, completedSteps: [:])
    }
}

// MARK: - Consent hash

enum ConsentHash {
    /// SHA-256 of the exact consent copy shown. Proves which words were shown, not just that
    /// a box was ticked (docs/02 §1).
    static func current() -> String {
        let data = Data(ConsentCopy.documentText.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Payload builders

enum PayloadBuilder {
    /// Manual entry: the same ingest shape as the HealthKit path, with provenance stating
    /// exactly what is known (typed by the patient, on this phone, for the chosen arm).
    static func manual(systolic: Double, diastolic: Double, takenAt: Date, arm: String) -> IngestPayload {
        let tz = Format.localTzInfo(takenAt)
        return IngestPayload(sourceType: .manual, observations: [
            IngestObservation(
                sourceUuid: UUID().uuidString.lowercased(),
                code: LOINC.bpPanel,
                effectiveTime: takenAt,
                effectiveTz: tz.tz,
                effectiveOffsetMinutes: tz.offsetMinutes,
                sourceSystem: Bundle.main.bundleIdentifier ?? "dev.aiplease.bpreset",
                sourceName: nil,
                sourceDeviceModel: nil,
                sourceUserEntered: true,
                bodySiteCode: arm == "left" ? SNOMEDBodySite.leftArm : SNOMEDBodySite.rightArm,
                context: ["arm": arm],
                components: [
                    IngestComponent(sourceUuid: UUID().uuidString.lowercased(), code: LOINC.systolic, valueQuantity: systolic, valueUnit: LOINC.unit),
                    IngestComponent(sourceUuid: UUID().uuidString.lowercased(), code: LOINC.diastolic, valueQuantity: diastolic, valueUnit: LOINC.unit),
                ]),
        ])
    }

    /// HealthKit path: the §17.3 `toRows` mapping, expressed against the deployed schema.
    /// Timezone is metadata-or-nil (never the device zone); the server default stands until
    /// Q7 is decided.
    static func healthKit(_ readings: [QueuedReading]) -> IngestPayload {
        IngestPayload(sourceType: .healthkit, observations: readings.map { r in
            IngestObservation(
                sourceUuid: r.hkUuid,
                code: LOINC.bpPanel,
                effectiveTime: r.takenAt,
                effectiveTz: r.tzIdentifier,
                effectiveOffsetMinutes: r.tzOffsetMinutes,
                sourceSystem: r.sourceBundleId,
                sourceName: r.sourceName,
                sourceDeviceModel: r.deviceModel,
                sourceUserEntered: false,
                bodySiteCode: nil,
                context: [:],
                components: [
                    IngestComponent(sourceUuid: r.systolicUuid ?? r.hkUuid, code: LOINC.systolic, valueQuantity: r.systolic, valueUnit: LOINC.unit),
                    IngestComponent(sourceUuid: r.diastolicUuid ?? r.hkUuid, code: LOINC.diastolic, valueQuantity: r.diastolic, valueUnit: LOINC.unit),
                ])
        })
    }
}

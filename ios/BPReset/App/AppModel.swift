import Foundation
import Observation

/// The app's in-memory view of the record. Nothing here is persisted: readings live in
/// memory for the session and are refetched from the API (plan N-07). Screens read the
/// cached arrays and call the load functions from `.task`.
@MainActor
@Observable
final class AppModel {
    let api: CorveoAPI

    private(set) var readings: [BpReadingRow] = []
    private(set) var trend: [BpTrendRow] = []
    private(set) var trendSinceDay: String? = nil
    private(set) var consent: ConsentStatusRow? = nil
    private(set) var progress: ProgramProgressRow? = nil

    private(set) var readingsLoading = false
    private(set) var trendLoading = false
    /// True when the last page was full, so earlier readings may exist.
    private(set) var canLoadMoreReadings = false
    private(set) var loadingMore = false
    static let readingsPageSize = 30

    init(api: CorveoAPI) {
        self.api = api
    }

    // MARK: Readings and trend

    func loadReadings(limit: Int = AppModel.readingsPageSize) async {
        readingsLoading = readings.isEmpty
        defer { readingsLoading = false }
        if let rows = try? await api.listReadings(limit: limit, before: nil) {
            readings = rows
            canLoadMoreReadings = rows.count >= limit
        }
    }

    /// The next page, older than the last row shown (keyset on effective_time).
    func loadMoreReadings() async {
        guard canLoadMoreReadings, !loadingMore, let last = readings.last else { return }
        loadingMore = true
        defer { loadingMore = false }
        if let rows = try? await api.listReadings(limit: Self.readingsPageSize, before: last.effectiveTime) {
            readings += rows
            canLoadMoreReadings = rows.count >= Self.readingsPageSize
        }
    }

    func loadTrend(sinceDay: String?) async {
        trendLoading = trend.isEmpty || trendSinceDay != sinceDay
        defer { trendLoading = false }
        trendSinceDay = sinceDay
        if let rows = try? await api.getTrend(sinceDay: sinceDay) { trend = rows }
    }

    /// After any write that changes the record.
    func invalidateReadings() async {
        await loadReadings()
        await loadTrend(sinceDay: trendSinceDay)
    }

    func ingest(_ payload: IngestPayload) async throws -> IngestResponse {
        let res = try await api.ingestObservations(payload)
        if res.inserted > 0 { await invalidateReadings() }
        return res
    }

    #if DEBUG
    /// Development builds: a six-week synthetic record through the ordinary ingest path,
    /// batch by batch, then the record reloads. Nil when a batch could not be sent.
    func seedDemoReadings() async -> (inserted: Int, duplicates: Int, rejected: Int)? {
        var inserted = 0, duplicates = 0, rejected = 0
        for payload in DemoSeed.payloads(DemoSeed.observations()) {
            guard let res = try? await api.ingestObservations(payload) else { return nil }
            inserted += res.inserted
            duplicates += res.duplicates
            rejected += res.rejected.count
        }
        await invalidateReadings()
        return (inserted, duplicates, rejected)
    }
    #endif

    // MARK: Consent

    func loadConsent() async {
        if let c = try? await api.getConsentStatus() { consent = c }
    }

    func recordConsent() async throws {
        consent = try await api.recordConsentEvent(ConsentEventInput(
            action: "granted", version: ConsentCopy.version, documentHash: ConsentHash.current()))
    }

    // MARK: Program progress

    func loadProgress() async {
        if let p = try? await api.getProgramProgress() { progress = p }
    }

    func updateProgress(currentWeek: Int? = nil, completedSteps: [String: Bool] = [:]) async {
        if let p = try? await api.updateProgramProgress(currentWeek: currentWeek, completedSteps: completedSteps) {
            progress = p
        }
    }

    // MARK: Data controls

    func export() async throws -> ExportResult {
        try await api.exportPatientData()
    }

    func requestAccountDeletion() async throws {
        try await api.requestAccountDeletion()
        readings = []
        trend = []
        consent = nil
        progress = nil
    }

    /// Development only: restore the synthetic dataset.
    func resetSynthetic() async {
        if let mock = api as? MockAPI { await mock.reset() }
        readings = []
        trend = []
        consent = nil
        progress = nil
    }
}

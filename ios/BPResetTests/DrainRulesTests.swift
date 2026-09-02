import Foundation
import HealthKit
import XCTest
@testable import BPReset

/// The pure rules behind the drain and the wire: what one ingest response means for the rows
/// sent, which timezone identifiers may travel, and that every date sent carries a zone.
final class DrainRulesTests: XCTestCase {
    private func rejection(_ reason: RejectionReason, _ uuid: String = "X") -> IngestRejection {
        IngestRejection(sourceUuid: uuid, reason: reason, detail: "redacted")
    }

    private func response(inserted: Int = 0, duplicates: Int = 0, rejected: [IngestRejection] = []) -> IngestResponse {
        IngestResponse(inserted: inserted, duplicates: duplicates, softDeleted: 0, rejected: rejected)
    }

    // MARK: Reconciliation (plan N-04 with the environment guard)

    func testAllLandedIsAcknowledged() {
        XCTAssertEqual(DrainReconciliation.verdict(sent: 3, response: response(inserted: 2, duplicates: 1)), .acknowledge)
    }

    func testStructuralRejectionsAreAcknowledged() {
        // A reading the server refused for its own content can never succeed; replaying it
        // forever would pin the queue.
        let r = response(inserted: 1, rejected: [rejection(.valueOutOfBounds), rejection(.systolicNotGreater, "Y")])
        XCTAssertEqual(DrainReconciliation.verdict(sent: 3, response: r), .acknowledge)
        let only = response(rejected: [rejection(.valueOutOfBounds)])
        XCTAssertEqual(DrainReconciliation.verdict(sent: 1, response: only), .acknowledge)
    }

    func testEnvironmentalRejectionOfEveryRowKeepsTheRows() {
        for reason in [RejectionReason.unknownCode, .unitMismatch, .malformedTimestamp] {
            let r = response(rejected: [rejection(reason), rejection(reason, "Y")])
            XCTAssertEqual(DrainReconciliation.verdict(sent: 2, response: r), .environmentFault(reason: reason.rawValue))
        }
    }

    func testEnvironmentalRejectionWithSomethingLandedStillAcknowledges() {
        // If any row landed the definitions exist and the units match; the rejected one is
        // the reading's own problem.
        let r = response(inserted: 1, rejected: [rejection(.unknownCode)])
        XCTAssertEqual(DrainReconciliation.verdict(sent: 2, response: r), .acknowledge)
    }

    func testUnaccountedRowsAreAMismatch() {
        XCTAssertEqual(DrainReconciliation.verdict(sent: 3, response: response(inserted: 1)), .mismatch)
        XCTAssertEqual(DrainReconciliation.verdict(sent: 1, response: response(inserted: 2)), .mismatch)
    }

    // MARK: Timezone identifiers that may travel to Postgres

    func testFixedOffsetIdentifiersAreNotSentButTheOffsetIs() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: "GMT+10:00"))
        XCTAssertNil(Mapper.ianaIdentifier(tz), "Foundation normalises this to GMT+1000, which Postgres rejects")
        XCTAssertEqual(tz.secondsFromGMT() / 60, 600, "the offset is still known and still carried")
    }

    func testIanaIdentifiersPassThrough() throws {
        let tz = try XCTUnwrap(TimeZone(identifier: "Australia/Sydney"))
        XCTAssertEqual(Mapper.ianaIdentifier(tz), "Australia/Sydney")
    }

    func testMappedReadingCarriesOffsetWithoutABadIdentifier() throws {
        let at = Date(timeIntervalSince1970: 1_720_000_000)
        let sys = HKQuantitySample(type: HKQuantityType(.bloodPressureSystolic), quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 120), start: at, end: at)
        let dia = HKQuantitySample(type: HKQuantityType(.bloodPressureDiastolic), quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 80), start: at, end: at)
        let corr = HKCorrelation(type: HKCorrelationType(.bloodPressure), start: at, end: at, objects: [sys, dia],
                                 metadata: [HKMetadataKeyTimeZone: "GMT+10:00"])
        let mapped = try XCTUnwrap(Mapper.map(corr))
        XCTAssertNil(mapped.tzIdentifier)
        XCTAssertEqual(mapped.tzOffsetMinutes, 600)
    }

    // MARK: Every date on the wire carries a zone

    func testRpcParameterEncoderWritesUTCDesignator() throws {
        struct Body: Encodable { let at: Date }
        let data = try SupabaseFactory.paramEncoder.encode(Body(at: Date(timeIntervalSince1970: 1_700_000_000.5)))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("2023-11-14T22:13:20.500Z"), text)
    }

    func testIngestPayloadThroughTheRealEncoderCarriesZones() throws {
        let reading = QueuedReading(
            itemId: ULID.generate(), hkUuid: "C", systolicUuid: "S", diastolicUuid: "D",
            enrolmentRef: "e", systolic: 121, diastolic: 79,
            takenAt: Date(timeIntervalSince1970: 1_720_000_000), tzIdentifier: nil, tzOffsetMinutes: nil,
            sourceBundleId: "b", sourceName: "n", deviceModel: nil,
            receivedAt: Date(timeIntervalSince1970: 1_720_000_100))
        let data = try SupabaseFactory.paramEncoder.encode(PayloadBuilder.healthKit([reading]))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"effective_time\":\"2024-07-03T09:46:40.000Z\""), text)
    }
}

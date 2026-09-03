import XCTest
@testable import BPReset

/// The development seed: deterministic, in bounds, in the past, and tagged for removal.
final class DemoSeedTests: XCTestCase {
    func testSeedIsDeterministicInBoundsAndTagged() throws {
        let end = Date(timeIntervalSince1970: 1_756_900_000)
        let a = DemoSeed.observations(endingOn: end)
        let b = DemoSeed.observations(endingOn: end)
        XCTAssertEqual(a, b, "the same end date must produce the same rows, so a replay is a no-op")
        XCTAssertGreaterThan(a.count, 50)
        XCTAssertEqual(Set(a.map(\.sourceUuid)).count, a.count, "source ids are the dedup key")

        let floor = end.addingTimeInterval(-Double(DemoSeed.days) * 86_400)
        for o in a {
            XCTAssertTrue(o.sourceUuid.hasPrefix(DemoSeed.sourceUuidPrefix))
            XCTAssertLessThanOrEqual(o.effectiveTime, end)
            XCTAssertGreaterThanOrEqual(o.effectiveTime, floor)
            XCTAssertTrue(o.sourceUserEntered)
            let sys = try XCTUnwrap(o.components.first { $0.code == LOINC.systolic }).valueQuantity
            let dia = try XCTUnwrap(o.components.first { $0.code == LOINC.diastolic }).valueQuantity
            XCTAssertTrue(Bounds.systolic.contains(sys))
            XCTAssertTrue(Bounds.diastolic.contains(dia))
            XCTAssertGreaterThan(sys, dia)
        }
        XCTAssertEqual(a, a.sorted { $0.effectiveTime < $1.effectiveTime }, "oldest first")
    }

    func testPayloadsAreManualAndBatched() {
        let rows = DemoSeed.observations(endingOn: Date(timeIntervalSince1970: 1_756_900_000))
        let payloads = DemoSeed.payloads(rows)
        XCTAssertEqual(payloads.reduce(0) { $0 + $1.observations.count }, rows.count)
        XCTAssertTrue(payloads.allSatisfy { $0.sourceType == .manual && $0.observations.count <= DemoSeed.batchSize })
    }
}

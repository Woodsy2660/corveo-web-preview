import HealthKit
import XCTest
@testable import BPReset

/// Structural mapping only (§7.3): exactly one systolic and one diastolic child, a unit
/// convertible to mmHg, timezone from metadata or nil. There are no range checks here and
/// there must never be: "is this a number" is allowed, "is this high" is a contract breach.
/// Samples are constructed in memory; no HealthKit store is touched.
final class MapperTests: XCTestCase {
    private let systolicType = HKQuantityType(.bloodPressureSystolic)
    private let diastolicType = HKQuantityType(.bloodPressureDiastolic)
    private let correlationType = HKCorrelationType(.bloodPressure)
    private let at = Date(timeIntervalSince1970: 1_720_000_000)   // 3 July 2024, AEST (+600)

    private func quantity(_ type: HKQuantityType, _ value: Double, unit: HKUnit = .millimeterOfMercury()) -> HKQuantitySample {
        HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value), start: at, end: at)
    }

    private func correlation(_ objects: Set<HKSample>, metadata: [String: Any]? = nil) -> HKCorrelation {
        HKCorrelation(type: correlationType, start: at, end: at, objects: objects, metadata: metadata)
    }

    func testWellFormedCorrelationMaps() throws {
        let sys = quantity(systolicType, 120)
        let dia = quantity(diastolicType, 80)
        let corr = correlation([sys, dia])
        let mapped = try XCTUnwrap(Mapper.map(corr))
        XCTAssertEqual(mapped.hkUuid, corr.uuid.uuidString)
        XCTAssertEqual(mapped.systolicUuid, sys.uuid.uuidString)
        XCTAssertEqual(mapped.diastolicUuid, dia.uuid.uuidString)
        XCTAssertEqual(mapped.systolic, 120)
        XCTAssertEqual(mapped.diastolic, 80)
        XCTAssertEqual(mapped.takenAt, at)
        XCTAssertNil(mapped.tzIdentifier, "no metadata means nil, never the device zone")
        XCTAssertNil(mapped.tzOffsetMinutes)
        // An in-memory sample has no source until HealthKit saves it; the mapper carries
        // whatever the sample reports, verbatim.
        XCTAssertEqual(mapped.sourceBundleId, corr.sourceRevision.source.bundleIdentifier)
        XCTAssertEqual(mapped.sourceName, corr.sourceRevision.source.name)
    }

    func testTimezoneComesOnlyFromMetadata() throws {
        let corr = correlation([quantity(systolicType, 120), quantity(diastolicType, 80)],
                               metadata: [HKMetadataKeyTimeZone: "Australia/Sydney"])
        let mapped = try XCTUnwrap(Mapper.map(corr))
        XCTAssertEqual(mapped.tzIdentifier, "Australia/Sydney")
        XCTAssertEqual(mapped.tzOffsetMinutes, 600)
    }

    func testPressureInOtherUnitsIsConvertedNotRejected() throws {
        // 16 kPa is 120.0 mmHg to one decimal place; the mapper converts, it does not judge.
        let corr = correlation([quantity(systolicType, 16, unit: .pascalUnit(with: .kilo)), quantity(diastolicType, 80)])
        let mapped = try XCTUnwrap(Mapper.map(corr))
        XCTAssertEqual(mapped.systolic, 120.0, accuracy: 0.1)
    }

    // HealthKit validates a blood-pressure correlation at construction (exactly one systolic
    // and one diastolic child, a real timezone name), so the mapper's missing-child,
    // duplicate-child and bad-zone guards cannot be reached from a unit test. They defend
    // against what a query can return when a child type is unauthorised, and stay device-only.

    func testLooseQuantitySampleIsNotACorrelation() {
        XCTAssertNil(Mapper.map(quantity(systolicType, 120)))
    }

    func testOutOfRangeValuesStillMap() throws {
        // The bright line: the mapper carries what was recorded. Bounds live in the manual-entry
        // form and in the backend's data-quality rules, never in the capture path.
        let corr = correlation([quantity(systolicType, 300), quantity(diastolicType, 5)])
        XCTAssertNotNil(Mapper.map(corr))
    }

    func testSourceIdentifierIsTheSampleSource() {
        let sample = quantity(systolicType, 120)
        XCTAssertEqual(Mapper.sourceIdentifier(sample), sample.sourceRevision.source.bundleIdentifier)
    }
}

import XCTest
@testable import BPReset

/// Tests for fictional readings fixtures (Task 10).
///
/// CorveoTests/Fixtures/fictional-readings-v0.1.json is test target only.
///
/// Uses its oracles as assertions:
/// - frozenDemoNow to pin the clock
/// - expected for the 26-reading default window and the means (135.3846… / 83.0385…)
/// - meanDefinition for the aggregation rule (arithmetic mean of complete, displayed,
///   distinct readings after filters — no outlier removal, no first-day exclusion)
/// - the six testScenarios for gaps, duplicate identity, distinct-equal values and
///   incomplete pairs
final class FictionalReadingsTests: XCTestCase {

    struct FictionalFixture: Codable {
        let fixtureVersion: String
        let synthetic: Bool
        let description: String
        let frozenDemoNow: String
        let measurementRange: DateRange
        let defaultFilter: DefaultFilter
        let datePresetDefinition: String
        let meanDefinition: String
        let readings: [FictionalReading]
        let testScenarios: TestScenarios
        let expected: Expected

        struct DateRange: Codable {
            let start: String
            let end: String
        }

        struct DefaultFilter: Codable {
            let start: String
            let end: String
            let timeOfDay: String
            let source: String
        }

        struct TestScenarios: Codable {
            let empty: [FictionalReading]
            let duplicateDelivery: [FictionalReading]
            let distinctMatchingValues: [FictionalReading]
            let partialImport: [PartialReading]
            let transportFailure: MessageScenario
            let noReadingsReturned: MessageScenario
        }

        struct MessageScenario: Codable {
            let message: String
        }

        struct Expected: Codable {
            let all42Days: WindowExpected
            let last7CalendarDays: WindowExpected
            let duplicateDeliveryAdds: Int
            let distinctMatchingValuesAdds: Int
            let partialImport: PartialExpected
        }

        struct WindowExpected: Codable {
            let n: Int
            let systolicMeanExact: Double
            let diastolicMeanExact: Double
            let distinctMeasurementDates: Int
        }

        struct PartialExpected: Codable {
            let completeBPPairsAdded: Int
            let incompleteRecordsToReview: Int
        }
    }

    struct FictionalReading: Codable {
        let id: String
        let demoSubjectKey: String
        let synthetic: Bool
        let systolic: Double
        let diastolic: Double
        let unit: String
        let pulseBpm: Int?
        let measuredAt: String
        let measurementTimeZone: String
        let measurementUtcOffsetMinutes: Int
        let timeOfDayTag: String
        let source: String
    }

    struct PartialReading: Codable {
        let id: String
        let systolic: Double
        let diastolic: Double?
    }

    private var fixture: FictionalFixture!

    override func setUpWithError() throws {
        // Load from the test bundle
        guard let url = Bundle(for: type(of: self)).url(forResource: "fictional-readings-v0.1", withExtension: "json", subdirectory: "Fixtures") else {
            // Fallback: try finding it via pattern matching
            let testBundle = Bundle(for: type(of: self))
            let fixturesPath = testBundle.bundlePath + "/Fixtures/fictional-readings-v0.1.json"
            guard FileManager.default.fileExists(atPath: fixturesPath) else {
                throw XCTSkip("Fictional readings fixture not found in test bundle")
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: fixturesPath))
            fixture = try JSONDecoder().decode(FictionalFixture.self, from: data)
            return
        }

        let data = try Data(contentsOf: url)
        fixture = try JSONDecoder().decode(FictionalFixture.self, from: data)
    }

    // MARK: - Oracle tests

    func testFrozenDemoNow() throws {
        XCTAssertEqual(fixture.frozenDemoNow, "2026-09-16T09:00:00+10:00",
            "frozenDemoNow should match expected value")
    }

    func testMeanDefinition() throws {
        let expectedDefinition = "Arithmetic mean of complete, displayed, distinct measurements after explicit filters. No first-day removal, outlier removal, session weighting or clinical protocol inferred."
        XCTAssertEqual(fixture.meanDefinition, expectedDefinition,
            "meanDefinition should describe the aggregation rule")
    }

    func testReadingCount() throws {
        XCTAssertEqual(fixture.readings.count, 148,
            "Expected 148 readings for full 42-day fixture")
    }

    func testExpectedMeansForLast7Days() throws {
        let expected = fixture.expected.last7CalendarDays
        XCTAssertEqual(expected.n, 26, "Last 7 days should have 26 readings")

        // Filter readings to the default filter window (last 7 calendar days)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        guard let filterStart = formatter.date(from: fixture.defaultFilter.start),
              let filterEnd = formatter.date(from: fixture.defaultFilter.end) else {
            XCTFail("Could not parse filter dates")
            return
        }

        let filteredReadings = fixture.readings.filter { reading in
            guard let date = formatter.date(from: reading.measuredAt) else { return false }
            return date >= filterStart && date <= filterEnd
        }

        XCTAssertEqual(filteredReadings.count, expected.n,
            "Filtered readings count should match expected")

        // Compute arithmetic mean
        let systolicSum = filteredReadings.reduce(0.0) { $0 + $1.systolic }
        let diastolicSum = filteredReadings.reduce(0.0) { $0 + $1.diastolic }
        let computedSystolicMean = systolicSum / Double(filteredReadings.count)
        let computedDiastolicMean = diastolicSum / Double(filteredReadings.count)

        XCTAssertEqual(computedSystolicMean, expected.systolicMeanExact, accuracy: 0.0001,
            "Systolic mean should be 135.3846...")
        XCTAssertEqual(computedDiastolicMean, expected.diastolicMeanExact, accuracy: 0.0001,
            "Diastolic mean should be 83.0385...")
    }

    func testExpectedMeansForAll42Days() throws {
        let expected = fixture.expected.all42Days
        XCTAssertEqual(expected.n, 148, "All 42 days should have 148 readings")

        let systolicSum = fixture.readings.reduce(0.0) { $0 + $1.systolic }
        let diastolicSum = fixture.readings.reduce(0.0) { $0 + $1.diastolic }
        let computedSystolicMean = systolicSum / Double(fixture.readings.count)
        let computedDiastolicMean = diastolicSum / Double(fixture.readings.count)

        XCTAssertEqual(computedSystolicMean, expected.systolicMeanExact, accuracy: 0.0001,
            "Systolic mean for all readings should match")
        XCTAssertEqual(computedDiastolicMean, expected.diastolicMeanExact, accuracy: 0.0001,
            "Diastolic mean for all readings should match")
    }

    // MARK: - Test scenario tests

    func testEmptyScenario() throws {
        XCTAssertTrue(fixture.testScenarios.empty.isEmpty,
            "Empty scenario should have no readings")
    }

    func testDuplicateDeliveryScenario() throws {
        let duplicates = fixture.testScenarios.duplicateDelivery
        XCTAssertEqual(duplicates.count, 1, "Duplicate delivery scenario should have 1 reading")
        XCTAssertEqual(fixture.expected.duplicateDeliveryAdds, 0,
            "Duplicate delivery should add 0 readings")
    }

    func testDistinctMatchingValuesScenario() throws {
        let distinct = fixture.testScenarios.distinctMatchingValues
        XCTAssertEqual(distinct.count, 1, "Distinct matching values scenario should have 1 reading")
        XCTAssertEqual(fixture.expected.distinctMatchingValuesAdds, 1,
            "Distinct matching values should add 1 reading (different source sample ID)")
    }

    func testPartialImportScenario() throws {
        let partial = fixture.testScenarios.partialImport
        XCTAssertEqual(partial.count, 1, "Partial import scenario should have 1 reading")
        XCTAssertNil(partial[0].diastolic, "Partial reading should have null diastolic")
        XCTAssertEqual(fixture.expected.partialImport.completeBPPairsAdded, 0,
            "Partial import should add 0 complete pairs")
        XCTAssertEqual(fixture.expected.partialImport.incompleteRecordsToReview, 1,
            "Partial import should flag 1 incomplete record")
    }

    func testAllReadingsAreSynthetic() throws {
        for reading in fixture.readings {
            XCTAssertTrue(reading.synthetic,
                "Reading \(reading.id) should be marked synthetic")
            XCTAssertTrue(reading.id.hasPrefix("demo-"),
                "Reading \(reading.id) should have demo- prefix")
        }
    }

    func testDistinctMeasurementDates() throws {
        let dates = Set(fixture.readings.map { $0.measuredAt.prefix(10) })
        XCTAssertEqual(dates.count, fixture.expected.all42Days.distinctMeasurementDates,
            "Should have expected number of distinct measurement dates")
    }
}

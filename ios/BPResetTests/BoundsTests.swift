import XCTest
@testable import BPReset

/// Manual-entry validation is mechanical only. It mirrors the observation_definition seeds
/// by hand (the silent-failure watch in the tracker), so the numbers are pinned here.
final class BoundsTests: XCTestCase {
    private func errors(_ sys: String, _ dia: String) -> ManualEntryErrors {
        validateManualEntry(ManualEntryDraft(systolic: sys, diastolic: dia))
    }

    func testSeedBoundsArePinned() {
        XCTAssertEqual(Bounds.systolic, 60...260)
        XCTAssertEqual(Bounds.diastolic, 30...160)
    }

    func testTypicalEntryPasses() {
        XCTAssertTrue(errors("120", "80").isEmpty)
        XCTAssertTrue(errors(" 60 ", "30").isEmpty, "edges are inclusive and whitespace is tolerated")
        XCTAssertTrue(errors("260", "160").isEmpty)
    }

    func testOutOfBoundsIsATypoCheckNotAJudgement() {
        XCTAssertEqual(errors("900", "80").systolic, .outOfBounds)
        XCTAssertEqual(errors("120", "600").diastolic, .outOfBounds)
        XCTAssertEqual(errors("59", "80").systolic, .outOfBounds)
        XCTAssertEqual(errors("120", "29").diastolic, .outOfBounds)
    }

    func testMissingAndNonNumeric() {
        XCTAssertEqual(errors("", "80").systolic, .required)
        XCTAssertEqual(errors("120", "abc").diastolic, .required)
    }

    func testSystolicMustExceedDiastolic() {
        XCTAssertEqual(errors("80", "80").cross, .systolicNotGreater)
        XCTAssertEqual(errors("80", "120").cross, .systolicNotGreater)
        XCTAssertNil(errors("900", "80").cross, "the cross check only runs once both fields are in bounds")
    }
}

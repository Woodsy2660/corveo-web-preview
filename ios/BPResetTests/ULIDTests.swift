import XCTest
@testable import BPReset

final class ULIDTests: XCTestCase {
    private let alphabet = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    func testShape() {
        let id = ULID.generate()
        XCTAssertEqual(id.count, 26)
        XCTAssertTrue(id.allSatisfy { alphabet.contains($0) }, "Crockford base32 only")
    }

    func testMonotonicWithinAMillisecond() {
        let now = Date()
        let ids = (0..<200).map { _ in ULID.generate(now: now) }
        XCTAssertEqual(ids, ids.sorted(), "same-millisecond ids stay in generation order")
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testLaterTimeSortsLater() {
        let earlier = ULID.generate(now: Date(timeIntervalSince1970: 1_700_000_000))
        let later = ULID.generate(now: Date(timeIntervalSince1970: 1_700_000_001))
        XCTAssertLessThan(earlier, later)
    }
}

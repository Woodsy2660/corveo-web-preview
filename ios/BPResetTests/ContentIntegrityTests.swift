import XCTest
import CryptoKit
@testable import BPReset

/// Integrity verification for the education content (Task 2).
///
/// This test recomputes each chapter's body digest and asserts it matches the bodySHA256
/// field in the JSON. The recipe is confirmed against all six chapters:
///
/// SHA-256 over UTF-8 of every paragraph block's text and every list block's items,
/// in document order, section headings excluded, joined by a single space.
///
/// A mismatch fails the build. This is what makes "carried unchanged" verifiable rather
/// than asserted.
///
/// Note: Week 4's bodyWordCount says 328 but the text is 341 words. This is expected and
/// already reported to the client. The hash still verifies — the body is intact, the
/// metadata is stale. Do not alter the body to match the count.
final class ContentIntegrityTests: XCTestCase {

    /// Test that the education content JSON loads without error.
    func testContentLoadsSuccessfully() {
        let package = EducationContentLoader.load()
        XCTAssertEqual(package.chapters.count, 6, "Expected six chapters")
        XCTAssertEqual(package.program.title, "BP Reset: A six-week guide to understanding your blood pressure")
    }

    /// Test that all six chapters are present in week order.
    func testAllChaptersPresent() {
        let chapters = EducationContentLoader.chapters
        XCTAssertEqual(chapters.count, 6)
        for (index, chapter) in chapters.enumerated() {
            XCTAssertEqual(chapter.week, index + 1, "Chapter \(index + 1) should have week = \(index + 1)")
        }
    }

    /// Core integrity test: verify each chapter's body digest matches bodySHA256.
    func testBodyDigestIntegrity() {
        let mismatches = ContentIntegrity.verifyAllChapters()

        if !mismatches.isEmpty {
            for (week, expected, actual) in mismatches {
                XCTFail("Week \(week) digest mismatch.\n  Expected: \(expected)\n  Computed: \(actual)")
            }
        }

        // Also verify individually for clear test output
        for chapter in EducationContentLoader.chapters {
            let computed = ContentIntegrity.computeBodyDigest(for: chapter)
            XCTAssertEqual(computed, chapter.bodySHA256,
                "Week \(chapter.week) (\(chapter.title)) body digest mismatch")
        }
    }

    /// Test Week 1 digest specifically (as a reference).
    func testWeek1Digest() {
        guard let chapter = EducationContentLoader.chapter(week: 1) else {
            XCTFail("Week 1 chapter not found")
            return
        }
        let computed = ContentIntegrity.computeBodyDigest(for: chapter)
        XCTAssertEqual(computed, chapter.bodySHA256, "Week 1 digest should match")
    }

    /// Test Week 6 digest specifically (has null nextWeekTitle).
    func testWeek6Digest() {
        guard let chapter = EducationContentLoader.chapter(week: 6) else {
            XCTFail("Week 6 chapter not found")
            return
        }
        let computed = ContentIntegrity.computeBodyDigest(for: chapter)
        XCTAssertEqual(computed, chapter.bodySHA256, "Week 6 digest should match")
        XCTAssertNil(chapter.nextWeekTitle, "Week 6 should have null nextWeekTitle")
    }

    /// Verify that all chapters have publishable: false (draft state).
    func testAllChaptersAreDraft() {
        for chapter in EducationContentLoader.chapters {
            XCTAssertFalse(chapter.publishable,
                "Week \(chapter.week) should have publishable: false")
            XCTAssertEqual(chapter.clinicalReviewStatus, "Pending",
                "Week \(chapter.week) should have clinicalReviewStatus: Pending")
        }
    }

    /// Verify hasDraftContent returns true while any chapter is unpublishable.
    func testHasDraftContentFlag() {
        XCTAssertTrue(EducationContentLoader.hasDraftContent,
            "hasDraftContent should be true while any chapter has publishable: false")
    }

    /// Verify the preview banner is present.
    func testPreviewBannerPresent() {
        XCTAssertNotNil(EducationContentLoader.previewBanner,
            "Preview banner should be present while draft content exists")
    }

    /// Test editorial catalogue structure.
    func testEditorialCatalogueStructure() {
        let package = EducationContentLoader.load()
        XCTAssertEqual(package.editorialCatalogue.count, 10, "Expected 10 editorial entries (6 pulse + 4 in-focus)")

        let pulse = EducationContentLoader.pulseEntries
        let inFocus = EducationContentLoader.inFocusEntries
        XCTAssertEqual(pulse.count, 6, "Expected 6 pulse entries")
        XCTAssertEqual(inFocus.count, 4, "Expected 4 in-focus entries")

        // All should have body: null and doNotGenerateBody: true
        for entry in package.editorialCatalogue {
            XCTAssertNil(entry.body, "\(entry.title) should have body: null")
            XCTAssertEqual(entry.bodyAvailability, "not_supplied",
                "\(entry.title) should have bodyAvailability: not_supplied")
            XCTAssertTrue(entry.doNotGenerateBody,
                "\(entry.title) should have doNotGenerateBody: true")
        }
    }

    /// Test cross-links resolve correctly (Task 8).
    func testCrossLinksResolve() {
        for chapter in EducationContentLoader.chapters {
            for crossLink in chapter.crossLinks {
                let entry = EducationContentLoader.findEditorialEntry(byTitle: crossLink.title)
                XCTAssertNotNil(entry,
                    "Cross-link '\(crossLink.title)' from Week \(chapter.week) should resolve to editorial entry")
                if let entry = entry {
                    XCTAssertEqual(entry.collection, crossLink.collection,
                        "Cross-link collection should match")
                }
            }
        }
    }

    /// Test Week 4 has no cross-links (as specified).
    func testWeek4HasNoCrossLinks() {
        guard let chapter = EducationContentLoader.chapter(week: 4) else {
            XCTFail("Week 4 chapter not found")
            return
        }
        XCTAssertTrue(chapter.crossLinks.isEmpty, "Week 4 should have no cross-links")
    }

    /// Test review holds are present where expected.
    func testReviewHoldsPresent() {
        var chaptersWithHolds = 0
        for chapter in EducationContentLoader.chapters {
            if !chapter.reviewHolds.isEmpty {
                chaptersWithHolds += 1
            }
        }
        // Weeks 3 and 6 have review holds on takeaways
        XCTAssertGreaterThan(chaptersWithHolds, 0, "Some chapters should have review holds")
    }

    /// Test all chapters have canonicalAssetId: null (as specified).
    func testCanonicalAssetIdNull() {
        for chapter in EducationContentLoader.chapters {
            XCTAssertNil(chapter.canonicalAssetId,
                "Week \(chapter.week) should have canonicalAssetId: null")
        }
    }

    /// Test image status is consistent.
    func testImageStatus() {
        let expectedStatus = "Proposed concept; final asset, licence and review not supplied."
        for chapter in EducationContentLoader.chapters {
            XCTAssertEqual(chapter.imageStatus, expectedStatus,
                "Week \(chapter.week) should have expected imageStatus")
        }
    }
}

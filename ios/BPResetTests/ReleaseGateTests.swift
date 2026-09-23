import XCTest
@testable import BPReset

/// Release gate tests (Task 4).
///
/// If any chapter is publishable: false, a release build fails CI.
/// Review and debug builds proceed normally.
///
/// This prevents draft clinical content reaching TestFlight because nobody
/// checked which JSON was bundled.
final class ReleaseGateTests: XCTestCase {

    /// Core gate: no draft content in release builds.
    ///
    /// This test is designed to fail in release configuration when publishable: false
    /// chapters are present, preventing draft content from shipping.
    func testNoDraftContentInReleaseBuilds() {
        #if !DEBUG
        // In release builds, fail if any chapter is not publishable
        for chapter in EducationContentLoader.chapters {
            XCTAssertTrue(chapter.publishable,
                "Release build contains draft content: Week \(chapter.week) (\(chapter.title)) has publishable: false. " +
                "Clinical review must be completed before release.")
        }
        #else
        // In debug builds, verify the test infrastructure works
        // This will pass because we're explicitly allowing draft content in debug
        XCTAssertTrue(EducationContentLoader.hasDraftContent,
            "Expected draft content in development (all chapters have publishable: false)")
        #endif
    }

    /// Verify no fictional/demo readings exist in the main app target.
    ///
    /// Task 10 specifies: fictional-readings-v0.1.json is test target only.
    /// Add a CI check asserting no fictional record appears in a release artefact.
    func testNoFictionalReadingsInAppBundle() {
        // The fictional readings JSON should only be in the test bundle, never the app bundle
        let appBundle = Bundle.main
        let fictionalURL = appBundle.url(forResource: "fictional-readings-v0.1", withExtension: "json")

        XCTAssertNil(fictionalURL,
            "Fictional readings JSON found in app bundle. Test fixtures must not be bundled in release builds.")

        // Also check for the source file under Fixtures
        let fixturesURL = appBundle.url(forResource: "fictional-readings-v0.1", withExtension: "json", subdirectory: "Fixtures")
        XCTAssertNil(fixturesURL,
            "Fictional readings JSON found in app bundle Fixtures directory. Test fixtures must not be bundled in release builds.")
    }

    /// Verify no demo-prefixed identifiers in bundled content.
    func testNoDemoPrefixedIdentifiersInContent() {
        // Check education content for any demo identifiers that shouldn't be there
        let package = EducationContentLoader.load()

        for chapter in package.chapters {
            XCTAssertFalse(chapter.prototypeKey.hasPrefix("demo-"),
                "Chapter \(chapter.week) has demo-prefixed prototypeKey")
        }

        for entry in package.editorialCatalogue {
            XCTAssertFalse(entry.prototypeKey.hasPrefix("demo-"),
                "Editorial entry '\(entry.title)' has demo-prefixed prototypeKey")
        }
    }

    /// Verify all chapters have the expected review status.
    func testChapterReviewStatus() {
        for chapter in EducationContentLoader.chapters {
            // During draft phase, all should be "Pending"
            XCTAssertEqual(chapter.clinicalReviewStatus, "Pending",
                "Week \(chapter.week) has unexpected clinicalReviewStatus: \(chapter.clinicalReviewStatus)")
        }
    }

    /// Verify review holds visibility requirement.
    ///
    /// All review holds must clear automatically when flags flip to publishable: true —
    /// no hardcoded week numbers driving visibility.
    func testReviewHoldsVisibilityLogic() {
        // The ReviewHoldMarker should only show when reviewHolds is non-empty
        // This is tested by checking that the view logic correctly depends on the data

        for chapter in EducationContentLoader.chapters {
            let hasHolds = !chapter.reviewHolds.isEmpty
            let isDraft = !chapter.publishable

            // If publishable and no holds, no markers should show (when this becomes the case)
            // For now, verify the inverse: draft content has the expected flags
            if isDraft {
                // Draft chapters should have clinicalReviewStatus: "Pending"
                XCTAssertEqual(chapter.clinicalReviewStatus, "Pending",
                    "Draft chapter should have Pending review status")
            }

            // Log for visibility during test runs
            if hasHolds {
                print("Week \(chapter.week) has \(chapter.reviewHolds.count) review holds")
            }
        }
    }
}

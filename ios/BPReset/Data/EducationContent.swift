import Foundation
import CryptoKit

/*
 Education content model — mirrors 02_CONTENT_ALL_SIX_WEEKS.json exactly.

 GOVERNING RULE: The content is the client's and must be carried byte-identical. You render
 it; you never edit it. No re-wrapping, no smart-quote substitution, no trimming, no
 sentence-case corrections, no paraphrasing to fit a layout, no truncation for small screens.
 If text does not fit, change the layout.

 Every field from the JSON is preserved: publishable, clinicalReviewStatus, reviewHolds,
 claimsNeedingCitation, bodySHA256 and canonicalAssetId. The integrity verification test
 (ContentIntegrityTests) recomputes each chapter's body digest and asserts it matches
 bodySHA256 — a mismatch fails the build.
 */

// MARK: - Program metadata

struct EducationPackage: Codable {
    let packageName: String
    let packageVersion: String
    let preparedDate: String
    let status: String
    let schemaStatus: String
    let sourceHierarchy: [String]
    let program: EducationProgramMeta
    let typography: TypographyMeta
    let chapters: [EducationChapter]
    let editorialCatalogue: [EditorialCatalogueEntry]
    let knownGaps: [String]
}

struct EducationProgramMeta: Codable {
    let title: String
    let shortName: String
    let chapterCount: Int
    let description: String
    let descriptionStatus: String
    let primaryEntry: String
    let allChaptersAccessibleInPreview: Bool
    let releaseUnlockSchedule: String?
    let previewBanner: String
    let week4Notice: String
    let byline: String
    let clinicalReviewStatus: String
}

struct TypographyMeta: Codable {
    let fontStatus: String
    let priorSource: String
    let serif: String
    let sans: String
    let mono: String
    let application: String
    let fontFilesIncluded: Bool
}

// MARK: - Chapter model (mirrors JSON exactly)

struct EducationChapter: Codable, Identifiable {
    var id: String { prototypeKey }

    let prototypeKey: String
    let canonicalAssetId: String?
    let week: Int
    let title: String
    let verb: String
    let cardSummary: String
    let standfirst: String
    let readingTimeMinutes: Int
    let readingTimeStatus: String
    let byline: String
    let bylineStatus: String
    let clinicalReviewStatus: String
    let clinicalReviewer: String?
    let clinicalReviewDate: String?
    let source: String
    let sections: [EducationSection]
    let keyTakeaway: String
    let nextWeekTitle: String?
    let imageBrief: ImageBrief
    let imageStatus: String
    let referenceStatus: String
    let claimsNeedingCitation: [String]
    let reviewHolds: [String]
    let publishable: Bool
    let crossLinks: [CrossLink]
    let sourceTextNormalisation: String
    let bodyWordCount: Int
    let bodySHA256: String
}

struct EducationSection: Codable, Hashable {
    let heading: String
    let blocks: [ContentBlock]
}

enum ContentBlock: Codable, Hashable {
    case paragraph(text: String)
    case list(items: [String])

    enum CodingKeys: String, CodingKey {
        case type, text, items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "paragraph":
            let text = try container.decode(String.self, forKey: .text)
            self = .paragraph(text: text)
        case "list":
            let items = try container.decode([String].self, forKey: .items)
            self = .list(items: items)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                debugDescription: "Unknown block type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let text):
            try container.encode("paragraph", forKey: .type)
            try container.encode(text, forKey: .text)
        case .list(let items):
            try container.encode("list", forKey: .type)
            try container.encode(items, forKey: .items)
        }
    }
}

struct ImageBrief: Codable, Hashable {
    let primary: String
    let alternative: String
    let thumbnail: String
    let wide: String
    let altDraft: String
}

struct CrossLink: Codable, Hashable {
    let title: String
    let collection: String
    let prototypeTargetKey: String
}

// MARK: - Editorial catalogue entry (Pulse and In Focus)

struct EditorialCatalogueEntry: Codable, Identifiable {
    var id: String { prototypeKey }

    let prototypeKey: String
    let canonicalAssetId: String?
    let collection: String
    let title: String
    let linkedFromWeeks: [Int]
    let sourceStatus: String
    let cardSummary: String?
    let summaryProvenance: String?
    let referenceScreenReadingTimeMinutes: Int?
    let displayReadingTime: Bool
    let body: String?
    let bodyAvailability: String
    let byline: String?
    let clinicalReviewStatus: String
    let emptyReaderMessage: String
    let doNotGenerateBody: Bool
    let publishable: Bool
}

// MARK: - Content loading and integrity

enum EducationContentLoader {
    private static var cachedPackage: EducationPackage?

    /// Loads the education content package from the bundled JSON.
    /// Fatal error if the file is missing or malformed — this is a build-time guarantee.
    static func load() -> EducationPackage {
        if let cached = cachedPackage { return cached }

        guard let url = Bundle.main.url(forResource: "02_CONTENT_ALL_SIX_WEEKS", withExtension: "json") else {
            fatalError("Education content JSON not found in bundle")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let package = try decoder.decode(EducationPackage.self, from: data)
            cachedPackage = package
            return package
        } catch {
            fatalError("Failed to decode education content: \(error)")
        }
    }

    /// Returns true if any chapter has publishable: false.
    static var hasDraftContent: Bool {
        load().chapters.contains { !$0.publishable }
    }

    /// The preview banner to show when any chapter is unpublishable.
    static var previewBanner: String? {
        hasDraftContent ? load().program.previewBanner : nil
    }

    /// Week 4 interstitial notice.
    static var week4Notice: String {
        load().program.week4Notice
    }

    /// Find a chapter by week number.
    static func chapter(week: Int) -> EducationChapter? {
        load().chapters.first { $0.week == week }
    }

    /// All chapters in week order.
    static var chapters: [EducationChapter] {
        load().chapters.sorted { $0.week < $1.week }
    }

    /// Editorial catalogue entries (Pulse collection).
    static var pulseEntries: [EditorialCatalogueEntry] {
        load().editorialCatalogue.filter { $0.collection == "pulse" }
    }

    /// Editorial catalogue entries (In Focus collection).
    static var inFocusEntries: [EditorialCatalogueEntry] {
        load().editorialCatalogue.filter { $0.collection == "in-focus" }
    }

    /// Find an editorial entry by exact title.
    static func findEditorialEntry(byTitle title: String) -> EditorialCatalogueEntry? {
        load().editorialCatalogue.first { $0.title == title }
    }

    /// Find an editorial entry by prototype key.
    static func findEditorialEntry(byKey key: String) -> EditorialCatalogueEntry? {
        load().editorialCatalogue.first { $0.prototypeKey == key }
    }
}

// MARK: - Integrity verification (Task 2)

enum ContentIntegrity {
    /// Computes the body digest for a chapter using the confirmed recipe:
    /// SHA-256 over UTF-8 of every paragraph block's text and every list block's items,
    /// in document order, section headings excluded, joined by a single space.
    static func computeBodyDigest(for chapter: EducationChapter) -> String {
        var parts: [String] = []

        for section in chapter.sections {
            for block in section.blocks {
                switch block {
                case .paragraph(let text):
                    parts.append(text)
                case .list(let items):
                    parts.append(contentsOf: items)
                }
            }
        }

        let joined = parts.joined(separator: " ")
        let data = Data(joined.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Verifies that all chapters have matching body digests.
    /// Returns an array of (week, expected, actual) for any mismatches.
    static func verifyAllChapters() -> [(week: Int, expected: String, actual: String)] {
        var mismatches: [(Int, String, String)] = []

        for chapter in EducationContentLoader.chapters {
            let computed = computeBodyDigest(for: chapter)
            if computed != chapter.bodySHA256 {
                mismatches.append((chapter.week, chapter.bodySHA256, computed))
            }
        }

        return mismatches
    }
}

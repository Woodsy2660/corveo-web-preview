import SwiftUI

/*
 Review hold rendering (Task 3).

 Surfaces    Requirement
 App-wide banner    program.previewBanner while any chapter is publishable: false
 Week card    Visible marker where reviewHolds is non-empty
 Before opening Week 4    Interstitial notice using program.week4Notice
 While reading    Persistent notice for any chapter with holds
 Beside takeaway, Weeks 3 and 6    Editorial-review note adjacent to the flagged takeaway

 Neutral, factual, no status colour. All of it must clear automatically when the flags
 flip to publishable: true — no hardcoded week numbers driving visibility.
 */

// MARK: - App-wide preview banner

/// Shows the program.previewBanner while any chapter has publishable: false.
/// Neutral, factual styling — no warning colours.
struct PreviewBanner: View {
    var body: some View {
        if let banner = EducationContentLoader.previewBanner {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: CIcon.info)
                    .font(.system(size: 14))
                Text(banner)
                    .cText(TypeScale.bodySm)
            }
            .foregroundStyle(CColor.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(CColor.neutralLightest)
        }
    }
}

// MARK: - Week card review marker

/// Shows a visible marker on week cards where reviewHolds is non-empty.
/// Neutral styling, no status colour.
struct ReviewHoldMarker: View {
    let holds: [String]

    var body: some View {
        if !holds.isEmpty {
            HStack(spacing: Spacing.xxxs) {
                Image(systemName: CIcon.info)
                    .font(.system(size: 11))
                Text("Editorial review pending")
                    .cText(TypeScale.label)
            }
            .foregroundStyle(CColor.inkTertiary)
        }
    }
}

// MARK: - Week 4 interstitial notice

/// Interstitial notice shown before opening Week 4.
/// Uses program.week4Notice from the content package.
/// Only shown when Week 4 has reviewHolds or publishable: false.
struct Week4InterstitialView: View {
    @Environment(Router.self) private var router
    let onContinue: () -> Void

    var body: some View {
        if let chapter = EducationContentLoader.chapter(week: 4),
           (!chapter.publishable || !chapter.reviewHolds.isEmpty) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Before you continue")
                    .cText(TypeScale.headingXL, weight: .medium)
                    .foregroundStyle(CColor.heading)

                Text(EducationContentLoader.week4Notice)
                    .cText(TypeScale.bodyBase)
                    .foregroundStyle(CColor.ink)
                    .lineSpacing(4)

                HStack(spacing: Spacing.sm) {
                    CButton(title: "Continue", variant: .primary) {
                        onContinue()
                    }
                    CButton(title: "Go back", variant: .secondary) {
                        router.pop()
                    }
                }
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.md)
            .background(CColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }
}

// MARK: - Chapter reading notice

/// Persistent notice shown while reading any chapter with holds.
/// Neutral styling, factual wording.
struct ChapterHoldsNotice: View {
    let chapter: EducationChapter

    var body: some View {
        if !chapter.reviewHolds.isEmpty || !chapter.publishable {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: CIcon.info)
                        .font(.system(size: 12))
                    Text("Editorial review pending")
                        .cText(TypeScale.label, weight: .medium)
                }
                .foregroundStyle(CColor.inkTertiary)

                if !chapter.reviewHolds.isEmpty {
                    ForEach(chapter.reviewHolds, id: \.self) { hold in
                        Text("• \(hold)")
                            .cText(TypeScale.bodySm)
                            .foregroundStyle(CColor.inkTertiary)
                    }
                }

                if !chapter.publishable {
                    Text("This chapter is in draft. Clinical review is pending.")
                        .cText(TypeScale.bodySm)
                        .foregroundStyle(CColor.inkTertiary)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CColor.neutralLightest)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
    }
}

// MARK: - Takeaway editorial review note

/// Editorial-review note shown adjacent to the flagged takeaway.
/// Currently flagged for Weeks 3 and 6 per reviewHolds content.
struct TakeawayReviewNote: View {
    let chapter: EducationChapter

    /// Returns true if any review hold mentions the takeaway.
    private var hasTakeawayHold: Bool {
        chapter.reviewHolds.contains { hold in
            hold.lowercased().contains("takeaway")
        }
    }

    var body: some View {
        if hasTakeawayHold {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: CIcon.info)
                    .font(.system(size: 11))
                Text("This takeaway is under editorial review")
                    .cText(TypeScale.label)
            }
            .foregroundStyle(CColor.inkTertiary)
            .padding(.top, Spacing.xxxs)
        }
    }
}

// MARK: - Copy extensions for program content

extension AppCopy {
    enum reviewHold {
        static let cardMarker = "Editorial review pending"
        static let chapterNotice = "This chapter is in draft. Clinical review is pending."
        static let takeawayNote = "This takeaway is under editorial review"
    }
}

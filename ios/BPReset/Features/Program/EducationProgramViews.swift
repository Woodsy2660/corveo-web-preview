import SwiftUI

/*
 Education program views — renders the six-week content from EducationContentLoader.

 GOVERNING RULE: The content is the client's and must be carried byte-identical. You render
 it; you never edit it. If text does not fit, change the layout.

 Tasks addressed:
 - Task 5: Programme index with six cards in week order
 - Task 6: Chapter reader with standfirst, byline, sections, takeaway, next-week pointer
 - Task 8: Cross-links resolve to catalogue entries by exact title
 - Task 9: Image placeholder handling
 */

// MARK: - Programme index (Task 5)

/// Six cards in week order showing exact title, cardSummary, verb, readingTimeMinutes.
/// All six open immediately (releaseUnlockSchedule is null).
struct EducationProgramIndex: View {
    @Environment(Router.self) private var router
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ForEach(EducationContentLoader.chapters) { chapter in
                EducationChapterCard(chapter: chapter,
                                     read: isChapterRead(chapter.week))
                if chapter.week < 6 { Hairline() }
            }
        }
    }

    private func isChapterRead(_ week: Int) -> Bool {
        guard let progress = model.progress else { return false }
        let key = Programs.stepKey(coreProgramSlug, week)
        return progress.completedSteps[key] == true ||
               progress.completedSteps["week-\(week)"] == true
    }
}

/// Single chapter card in the programme index.
struct EducationChapterCard: View {
    @Environment(Router.self) private var router
    @State private var showWeek4Notice = false

    let chapter: EducationChapter
    let read: Bool

    var body: some View {
        Button {
            // Week 4 interstitial notice check
            if chapter.week == 4 && (!chapter.publishable || !chapter.reviewHolds.isEmpty) {
                showWeek4Notice = true
            } else {
                router.push(.chapter(slug: coreProgramSlug, week: chapter.week))
            }
        } label: {
            HStack(alignment: .top, spacing: Spacing.xs) {
                // Placeholder image (Task 9)
                PlaceholderChapterImage(week: chapter.week)
                    .frame(width: 66, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    // Exact title from JSON
                    Text(chapter.title)
                        .cText(TypeScale.bodyLg, weight: .medium)
                        .foregroundStyle(CColor.heading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Exact cardSummary from JSON
                    Text(chapter.cardSummary)
                        .cText(TypeScale.bodySm)
                        .foregroundStyle(CColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    Spacer(minLength: Spacing.xxxs)

                    // Meta line: Week number, verb, reading time
                    HStack(spacing: Spacing.xxs) {
                        Text("Week \(chapter.week)")
                        Text("·")
                        HStack(spacing: Spacing.xxxs) {
                            Image(systemName: CIcon.clock).font(.system(size: 11))
                            Text("\(chapter.readingTimeMinutes) min \(chapter.verb)")
                        }
                        if read {
                            Text("·")
                            HStack(spacing: Spacing.xxxs) {
                                Image(systemName: CIcon.check).font(.system(size: 11))
                                Text("Read")
                            }
                        }
                    }
                    .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                    // Review hold marker (Task 3)
                    if !chapter.reviewHolds.isEmpty {
                        ReviewHoldMarker(holds: chapter.reviewHolds)
                            .padding(.top, Spacing.xxxs)
                    }
                }
                .frame(minHeight: 96)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week \(chapter.week): \(chapter.title)")
        .sheet(isPresented: $showWeek4Notice) {
            Week4InterstitialSheet(chapter: chapter)
        }
    }
}

// MARK: - Week 4 interstitial sheet

struct Week4InterstitialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router
    let chapter: EducationChapter

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Before you continue")
                    .cText(TypeScale.headingXL, weight: .medium)
                    .foregroundStyle(CColor.heading)

                Text(EducationContentLoader.week4Notice)
                    .cText(TypeScale.bodyBase)
                    .foregroundStyle(CColor.ink)
                    .lineSpacing(4)

                Spacer()

                VStack(spacing: Spacing.sm) {
                    CButton(title: "Continue") {
                        dismiss()
                        router.push(.chapter(slug: coreProgramSlug, week: chapter.week))
                    }
                    CButton(title: "Go back", variant: .secondary) {
                        dismiss()
                    }
                }
            }
            .padding(Spacing.md)
            .background(CColor.page)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Chapter reader (Task 6)

/// Full chapter reader: standfirst, byline with draft status, sections with headings,
/// paragraphs and lists, key takeaway, next-week pointer.
struct EducationChapterReader: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let slug: String
    let week: Int
    @State private var marking = false

    private var chapter: EducationChapter? {
        EducationContentLoader.chapter(week: week)
    }

    private var done: Bool {
        guard let progress = model.progress else { return false }
        let key = Programs.stepKey(slug, week)
        return progress.completedSteps[key] == true ||
               progress.completedSteps["week-\(week)"] == true
    }

    var body: some View {
        if let chapter {
            Screen(
                overline: "Week \(chapter.week)",
                title: chapter.title,
                withTabBar: false,  // Final card clears tab bar per spec
                action: AnyView(HeaderBack { router.pop() }),
                footer: AnyView(footerButton)
            ) {
                // Standfirst (exact from JSON)
                Text(chapter.standfirst)
                    .cText(TypeScale.bodyLg)
                    .lineSpacing(4)
                    .foregroundStyle(CColor.inkSecondary)
                    .padding(.bottom, Spacing.sm)

                // Read status chip
                if done {
                    Chip(text: "Read")
                        .padding(.bottom, Spacing.sm)
                }

                // Review hold notice (Task 3)
                ChapterHoldsNotice(chapter: chapter)
                    .padding(.bottom, Spacing.sm)

                // Meta strip: week, reading time, clinical review status
                VStack(alignment: .leading, spacing: 0) {
                    Hairline()
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        MetaPair(label: "Week", value: "\(chapter.week) of 6")
                        MetaPair(label: "Estimated read time", value: "\(chapter.readingTimeMinutes) minutes")
                        MetaPair(label: "Clinical review", value: chapter.clinicalReviewStatus)
                    }
                    .padding(.vertical, Spacing.sm)
                    Hairline()
                }

                // Byline with draft status (exact from JSON)
                Text(chapter.byline)
                    .cText(TypeScale.bodySm)
                    .foregroundStyle(CColor.inkTertiary)
                    .padding(.top, Spacing.sm)

                // Article body: sections with headings and blocks
                EducationArticleBody(chapter: chapter)

                // Key takeaway
                if !chapter.keyTakeaway.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Hairline()
                        Text("Key takeaway")
                            .cText(TypeScale.bodySm, weight: .medium)
                            .foregroundStyle(CColor.inkTertiary)
                            .padding(.top, Spacing.sm)
                        Text(chapter.keyTakeaway)
                            .cText(TypeScale.bodyLg)
                            .lineSpacing(4)
                            .foregroundStyle(CColor.ink)

                        // Takeaway review note (Task 3 — beside takeaway, Weeks 3 and 6)
                        TakeawayReviewNote(chapter: chapter)
                    }
                    .padding(.top, Spacing.md)
                }

                // Cross-links (Task 8)
                if !chapter.crossLinks.isEmpty {
                    CrossLinksSection(crossLinks: chapter.crossLinks)
                        .padding(.top, Spacing.md)
                }

                // Next-week pointer (handle Week 6's null)
                if let nextTitle = chapter.nextWeekTitle {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Hairline()
                        Text("Next week")
                            .cText(TypeScale.bodySm, weight: .medium)
                            .foregroundStyle(CColor.inkTertiary)
                            .padding(.top, Spacing.sm)
                        Text(nextTitle)
                            .cText(TypeScale.bodyBase)
                            .foregroundStyle(CColor.ink)
                    }
                    .padding(.top, Spacing.md)
                }

                // Education disclaimer
                VStack(alignment: .leading, spacing: 0) {
                    Hairline()
                    Text(SafetyCopy.educationNote)
                        .cText(TypeScale.bodySm)
                        .foregroundStyle(CColor.inkTertiary)
                        .padding(.top, Spacing.sm)
                }
                .padding(.top, Spacing.md)

                // Navigation links
                navigationLinks
                    .padding(.top, Spacing.md)
            }
        } else {
            Screen(title: "Chapter not available", withTabBar: true,
                   action: AnyView(HeaderBack { router.pop() })) {
                CButton(title: "Back to program") { router.pop() }
            }
        }
    }

    @ViewBuilder
    private var footerButton: some View {
        if done {
            CButton(title: chapter?.nextWeekTitle != nil ? "Next chapter" : "Back to program") {
                if let chapter, chapter.nextWeekTitle != nil {
                    router.path[router.path.count - 1] = .chapter(slug: slug, week: week + 1)
                } else {
                    router.pop()
                }
            }
        } else {
            CButton(title: marking ? "…" : "Mark as read", disabled: marking) {
                Task {
                    marking = true
                    defer { marking = false }
                    await model.updateProgress(completedSteps: [Programs.stepKey(slug, week): true])
                }
            }
        }
    }

    @ViewBuilder
    private var navigationLinks: some View {
        let hasPrevious = week > 1
        let hasNext = chapter?.nextWeekTitle != nil

        HStack {
            if hasPrevious {
                Button("Previous chapter") {
                    router.path[router.path.count - 1] = .chapter(slug: slug, week: week - 1)
                }
                .buttonStyle(.plain)
                .cText(TypeScale.bodySm)
                .underline()
                .foregroundStyle(CColor.inkSecondary)
            }
            Spacer()
            if hasNext {
                Button("Next chapter") {
                    router.path[router.path.count - 1] = .chapter(slug: slug, week: week + 1)
                }
                .buttonStyle(.plain)
                .cText(TypeScale.bodySm)
                .underline()
                .foregroundStyle(CColor.inkSecondary)
            }
        }
    }
}

// MARK: - Article body (sections, paragraphs, lists)

struct EducationArticleBody: View {
    let chapter: EducationChapter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(chapter.sections.indices, id: \.self) { index in
                let section = chapter.sections[index]
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SectionHeading(text: section.heading)
                        .padding(.top, index == 0 ? Spacing.md : 0)

                    ForEach(section.blocks.indices, id: \.self) { blockIndex in
                        renderBlock(section.blocks[blockIndex])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: ContentBlock) -> some View {
        switch block {
        case .paragraph(let text):
            // Body text 16px minimum per spec
            Text(text)
                .cText(TypeScale.bodyLg)
                .lineSpacing(5)
                .foregroundStyle(CColor.ink)
                .fixedSize(horizontal: false, vertical: true)

        case .list(let items):
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: Spacing.xxs) {
                        Text("•")
                            .cText(TypeScale.bodyLg)
                            .foregroundStyle(CColor.ink)
                        Text(item)
                            .cText(TypeScale.bodyLg)
                            .lineSpacing(5)
                            .foregroundStyle(CColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Cross-links section (Task 8)

struct CrossLinksSection: View {
    @Environment(Router.self) private var router
    let crossLinks: [CrossLink]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Hairline()
            Text("Related reads")
                .cText(TypeScale.bodySm, weight: .medium)
                .foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.sm)

            ForEach(crossLinks, id: \.title) { link in
                Button {
                    // Resolve by exact title
                    if let entry = EducationContentLoader.findEditorialEntry(byTitle: link.title) {
                        if link.collection == "pulse" {
                            router.push(.editorialPulse(key: entry.prototypeKey))
                        } else {
                            router.push(.editorialInFocus(key: entry.prototypeKey))
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.title)
                                .cText(TypeScale.bodyBase)
                                .foregroundStyle(CColor.ink)
                            Text(link.collection == "pulse" ? "The Pulse" : "In Focus")
                                .cText(TypeScale.label)
                                .foregroundStyle(CColor.inkTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(CColor.inkTertiary)
                    }
                    .padding(.vertical, Spacing.xxs)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Image placeholder (Task 9)

/// Neutral placeholder for chapter images.
/// "Proposed concept; final asset, licence and review not supplied."
struct PlaceholderChapterImage: View {
    let week: Int

    var body: some View {
        ZStack {
            // Try to load the existing photo asset first
            Image(Art.chapter(week))
                .resizable()
                .scaledToFill()
        }
        .background(CColor.neutralLighter)
        .overlay(alignment: .bottomTrailing) {
            // Subtle indicator that this is a placeholder
            Text("W\(week)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(CColor.textTertiary)
                .padding(4)
        }
    }
}

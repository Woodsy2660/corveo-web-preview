import SwiftUI

/*
 Education Learn catalogue views — renders editorial content from EducationContentLoader.

 Task 7 — Learn catalogue:
 Ten entries — six pulse, four in-focus. All have body: null, bodyAvailability: "not_supplied",
 doNotGenerateBody: true.

 Build the catalogue with exact titles. Opening an entry shows its emptyReaderMessage.

 Do not generate, infer, summarise, paraphrase or placeholder any article body. The absence
 is the correct state, not a gap to fill.

 No reading time — displayReadingTime is false throughout. No editorial-to-programme upsell module.
 */

// MARK: - Learn catalogue view (Task 7)

struct EducationLearnCatalogue: View {
    @Environment(Router.self) private var router

    private var pulseEntries: [EditorialCatalogueEntry] {
        EducationContentLoader.pulseEntries
    }

    private var inFocusEntries: [EditorialCatalogueEntry] {
        EducationContentLoader.inFocusEntries
    }

    var body: some View {
        Screen(title: AppCopy.education.title, withTabBar: true,
               action: AnyView(ProfileLink { router.push(.settings) })) {
            Text(AppCopy.education.intro)
                .cText(TypeScale.bodySm)
                .foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            // The Pulse section (six entries)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                SectionHeading(text: AppCopy.education.pulseHeading)
                Text(AppCopy.education.pulseSub).eyebrow()
            }
            .padding(.bottom, Spacing.xxs)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.xxs) {
                    ForEach(pulseEntries) { entry in
                        Button {
                            router.push(.editorialPulse(key: entry.prototypeKey))
                        } label: {
                            EditorialPulseCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppCopy.education.openPulseAria(entry.title))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Spacing.md)

            // In Focus section (four entries)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                SectionHeading(text: AppCopy.education.inFocusHeading)
                Text(AppCopy.education.inFocusSub).eyebrow()
            }

            VStack(spacing: 0) {
                ForEach(inFocusEntries) { entry in
                    Button {
                        router.push(.editorialInFocus(key: entry.prototypeKey))
                    } label: {
                        EditorialInFocusRow(entry: entry)
                    }
                    .buttonStyle(.plain)

                    if entry.prototypeKey != inFocusEntries.last?.prototypeKey {
                        Hairline()
                    }
                }
            }
        }
    }
}

// MARK: - Pulse card

struct EditorialPulseCard: View {
    let entry: EditorialCatalogueEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
            Text(entry.title)
                .cDisplay(TypeScale.bodyBase)
                .foregroundStyle(CColor.textHeadingInverse)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.xs)
        }
        .frame(width: 112)
        .frame(minHeight: 152)
        .background {
            // Placeholder background
            CColor.neutralLighter
                .overlay(Color.black.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - In Focus row

struct EditorialInFocusRow: View {
    let entry: EditorialCatalogueEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            // Placeholder thumbnail
            Rectangle()
                .fill(CColor.neutralLighter)
                .frame(width: 66, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                // Exact title from JSON
                Text(entry.title)
                    .cText(TypeScale.bodyLg, weight: .medium)
                    .foregroundStyle(CColor.heading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Card summary if present
                if let summary = entry.cardSummary {
                    Text(summary)
                        .cText(TypeScale.bodySm)
                        .foregroundStyle(CColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Spacer(minLength: Spacing.xxxs)

                // No reading time per spec (displayReadingTime is false throughout)
            }
            .frame(minHeight: 96)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - Editorial empty reader (shows emptyReaderMessage)

struct EditorialEmptyReader: View {
    @Environment(Router.self) private var router
    let entry: EditorialCatalogueEntry

    var body: some View {
        Screen(
            overline: entry.collection == "pulse" ? "The Pulse" : "In Focus",
            title: entry.title,
            withTabBar: true,
            action: AnyView(HeaderBack { router.pop() })
        ) {
            // Body is intentionally absent — show emptyReaderMessage
            Card {
                Text(entry.emptyReaderMessage)
                    .cText(TypeScale.bodyBase)
                    .foregroundStyle(CColor.inkSecondary)
                    .lineSpacing(4)
            }
            .padding(.top, Spacing.sm)

            // Linked from weeks info
            if !entry.linkedFromWeeks.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Related to")
                        .cText(TypeScale.bodySm, weight: .medium)
                        .foregroundStyle(CColor.inkTertiary)

                    let weekStrings = entry.linkedFromWeeks.map { "Week \($0)" }.joined(separator: ", ")
                    Text(weekStrings)
                        .cText(TypeScale.bodySm)
                        .foregroundStyle(CColor.inkSecondary)
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
        }
    }
}

// MARK: - Pulse viewer (full-screen swipe-through)

struct EditorialPulseViewer: View {
    @Environment(Router.self) private var router
    let startKey: String
    @State private var position: String?

    private var entries: [EditorialCatalogueEntry] {
        EducationContentLoader.pulseEntries
    }

    private var index: Int {
        entries.firstIndex { $0.prototypeKey == position } ?? 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            CColor.action.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        EditorialPulseSlide(entry: entry)
                            .containerRelativeFrame(.vertical)
                            .id(entry.prototypeKey)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()

            // Header bar
            HStack {
                Text("\(AppCopy.education.pulseHeading) · \(AppCopy.pulse.counter(index + 1, entries.count))")
                    .eyebrow()
                    .foregroundStyle(CColor.textSecondaryInverse)
                Spacer()
                Button { router.pop() } label: {
                    Image(systemName: CIcon.close)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CColor.actionInk)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppCopy.pulse.closeAria)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .zIndex(2)

            if index < entries.count - 1 {
                VStack {
                    Spacer()
                    VStack(spacing: Spacing.xxxs) {
                        Image(systemName: CIcon.chevronUp).font(.system(size: 14))
                        Text(AppCopy.pulse.swipeHint).cText(TypeScale.label)
                    }
                    .foregroundStyle(CColor.inkTertiary)
                    .padding(.bottom, Spacing.sm)
                }
                .allowsHitTesting(false)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { position = startKey }
    }
}

struct EditorialPulseSlide: View {
    let entry: EditorialCatalogueEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Spacer()

            // Title
            Text(entry.title)
                .cDisplay(TypeScale.heading2XL)
                .foregroundStyle(CColor.textHeadingInverse)
                .fixedSize(horizontal: false, vertical: true)

            // Body is intentionally absent — show emptyReaderMessage
            Text(entry.emptyReaderMessage)
                .cText(TypeScale.bodyLg)
                .lineSpacing(5)
                .foregroundStyle(CColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Education disclaimer
            Text(SafetyCopy.educationNote)
                .cText(TypeScale.label)
                .foregroundStyle(CColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.top, 72)
        .padding(.bottom, 96)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - In Focus reader

struct EditorialInFocusReader: View {
    @Environment(Router.self) private var router
    let key: String

    private var entry: EditorialCatalogueEntry? {
        EducationContentLoader.findEditorialEntry(byKey: key)
    }

    var body: some View {
        if let entry {
            EditorialEmptyReader(entry: entry)
        } else {
            Screen(title: AppCopy.inFocus.notFound, withTabBar: true,
                   action: AnyView(HeaderBack { router.pop() })) {
                CButton(title: AppCopy.inFocus.back) { router.pop() }
            }
        }
    }
}

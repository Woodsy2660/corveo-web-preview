import SwiftUI

// MARK: - Learn tab (change-request scope, CR-1)

/// The publication's two collections, in the app. The Pulse (short reads) is a horizontal
/// rail of portrait cards opening the full-screen swipe viewer; In Focus (long reads) is a
/// list opening the article template. Built for IA review, behind placeholder content.
struct LearnView: View {
    @Environment(Router.self) private var router

    var body: some View {
        Screen(title: AppCopy.education.title, withTabBar: true,
               action: AnyView(ProfileLink { router.push(.settings) })) {
            Text(AppCopy.education.intro)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                SectionHeading(text: AppCopy.education.pulseHeading)
                Text(AppCopy.education.pulseSub).eyebrow()
            }
            .padding(.bottom, Spacing.xxs)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.xxs) {
                    ForEach(pulseItems) { item in
                        // A photograph with the title over it. One even scrim, no gradient,
                        // keeps the white serif legible on any picture.
                        Button { router.push(.pulse(slug: item.slug)) } label: {
                            // The card grows with its title rather than clipping it; the
                            // photograph fills whatever height the rail settles on.
                            ZStack(alignment: .bottomLeading) {
                                Color.clear
                                Text(item.title)
                                    .cDisplay(TypeScale.bodyBase)
                                    .foregroundStyle(CColor.textHeadingInverse)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(Spacing.xs)
                            }
                            .frame(width: 112)
                            .frame(minHeight: 152)
                            .background {
                                Image(Art.pulse(item.slug)).resizable().scaledToFill()
                                    .overlay(Color.black.opacity(0.4))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppCopy.education.openPulseAria(item.title))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Spacing.md)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                SectionHeading(text: AppCopy.education.inFocusHeading)
                Text(AppCopy.education.inFocusSub).eyebrow()
            }

            VStack(spacing: 0) {
                ForEach(inFocusArticles) { article in
                    // On the chapter-row pattern: every row the same height, photograph left,
                    // title and excerpt at the top, the read time as a quiet line at the bottom.
                    Button { router.push(.inFocus(slug: article.slug)) } label: {
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(Art.article(article.slug)).resizable().scaledToFill()
                                .frame(width: 66, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(article.title)
                                    .cText(TypeScale.bodyLg, weight: .medium).foregroundStyle(CColor.heading)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(article.excerpt).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                                Spacer(minLength: Spacing.xxxs)
                                HStack(spacing: Spacing.xxxs) {
                                    Image(systemName: CIcon.clock).font(.system(size: 11))
                                    Text(AppCopy.program.duration(article.readMinutes, .read))
                                }
                                .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                            }
                            .frame(minHeight: 96)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if article.slug != inFocusArticles.last?.slug { Hairline() }
                }
            }

        }
    }
}

// MARK: - In Focus article

struct InFocusArticleView: View {
    @Environment(Router.self) private var router
    let slug: String

    var body: some View {
        if let article = inFocusArticles.first(where: { $0.slug == slug }) {
            Screen(overline: AppCopy.inFocus.overline, title: article.title, withTabBar: true,
                   action: AnyView(HeaderBack { router.pop() })) {
                if let deck = article.deck {
                    Text(deck).cText(TypeScale.bodyLg).lineSpacing(4).foregroundStyle(CColor.inkSecondary)
                        .padding(.bottom, Spacing.sm)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Hairline()
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        MetaPair(label: AppCopy.chapter.metaReadTime, value: AppCopy.chapter.metaReadTimeValue(article.readMinutes))
                        MetaPair(label: AppCopy.chapter.metaReview, value: article.reviewStatus)
                    }
                    .padding(.vertical, Spacing.sm)
                    Hairline()
                }
                if article.sections == nil {
                    Card { Text(AppCopy.education.contentPendingNotice).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary) }
                        .padding(.top, Spacing.md)
                }
                ArticleBody(sections: article.sections ?? [])
            }
        } else {
            Screen(title: AppCopy.inFocus.notFound, withTabBar: true, action: AnyView(HeaderBack { router.pop() })) {
                CButton(title: AppCopy.inFocus.back) { router.pop() }
            }
        }
    }
}

// MARK: - The Pulse viewer

/// Full-screen swipe-through viewer for the short reads: one read per screen, swiped
/// vertically, on the model of short-form video feeds. Native paging does the gesture work.
struct PulseViewerView: View {
    @Environment(Router.self) private var router
    let slug: String
    @State private var position: String?

    private var index: Int { pulseItems.firstIndex { $0.slug == position } ?? 0 }

    var body: some View {
        ZStack(alignment: .top) {
            CColor.action.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(pulseItems) { item in
                        PulseSlide(item: item)
                            .containerRelativeFrame(.vertical)
                            .id(item.slug)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()

            // The bar with the close sits above the pages and takes the whole tap.
            HStack {
                Text("\(AppCopy.education.pulseHeading) · \(AppCopy.pulse.counter(index + 1, pulseItems.count))")
                    .eyebrow().foregroundStyle(CColor.textSecondaryInverse)
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

            if index < pulseItems.count - 1 {
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
        .onAppear { position = slug }
    }
}

struct PulseSlide: View {
    let item: PulseItem
    var body: some View {
        let pending = item.body == nil
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Spacer()
            Text(item.title)
                .cDisplay(TypeScale.heading2XL)
                .foregroundStyle(CColor.textHeadingInverse)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(item.body ?? [AppCopy.pulse.pendingBody], id: \.self) { paragraph in
                Text(paragraph)
                    .cText(TypeScale.bodyLg).lineSpacing(5)
                    .foregroundStyle(pending ? CColor.textTertiary : CColor.textSecondaryInverse)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(SafetyCopy.educationNote).cText(TypeScale.label).foregroundStyle(CColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.top, 72)
        .padding(.bottom, 96)                                // clears the swipe hint
        .accessibilityElement(children: .combine)
    }
}

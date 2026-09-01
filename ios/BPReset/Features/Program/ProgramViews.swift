import SwiftUI

// MARK: - Program tab (Deliverable 7)

/// Opens on the program you are following, under a fixed title: the program's own name is
/// the subheading. Content is authored and clinically reviewed by Corveo and is static: it
/// never varies with the reader's readings. The core program releases a chapter a week, a
/// calendar rhythm, not a response to anything recorded.
struct ProgramView: View {
    @Environment(AppModel.self) private var model
    @Environment(FollowState.self) private var follow
    @Environment(Router.self) private var router

    var body: some View {
        Group {
            if let program = Programs.find(follow.active), !follow.following.isEmpty {
                let read = Programs.readCount(model.progress, program)
                let total = program.chapters.count
                Screen(title: AppCopy.program.title, withTabBar: true,
                       action: AnyView(ProfileLink { router.push(.settings) }),
                       scrollKey: program.slug) {
                    SegmentedProgress(read: read, total: total, label: AppCopy.program.progressAria(read, total))

                    SectionHeading(text: program.title, size: TypeScale.heading2XL)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.xxxs)
                    Text(program.description)
                        .cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                        .padding(.bottom, Spacing.sm)

                    ChapterList(program: program, progress: model.progress)

                    ProgramRail(active: follow.active, following: follow.following,
                                onToggleFollow: { slug in follow.isFollowing(slug) ? follow.unfollow(slug) : follow.follow(slug) },
                                onSwitch: { slug in follow.setActive(slug) })
                }
            } else {
                Screen(title: AppCopy.programIndex.title, withTabBar: true,
                       action: AnyView(ProfileLink { router.push(.settings) })) {
                    ProgramIndex(embedded: true)
                }
            }
        }
        .task { await model.loadProgress() }
    }
}

// MARK: - Chapter list

struct ChapterList: View {
    let program: ProgramSummary
    let progress: ProgramProgressRow?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(program.chapters) { chapter in
                ChapterRow(program: program, chapter: chapter,
                           open: Programs.isAvailable(progress, program, chapter.week),
                           done: Programs.isRead(progress, program.slug, chapter.week))
                if chapter.week != program.chapters.last?.week { Hairline() }
            }
        }
    }
}

/// One chapter row on the site's programs pattern: thumbnail, unit tag, duration with a
/// clock, title, excerpt, trailing-arrow CTA. Chapter artwork is a Corveo asset that has not
/// been supplied, so the tile carries the chapter number.
struct ChapterRow: View {
    @Environment(Router.self) private var router
    let program: ProgramSummary
    let chapter: ProgramChapter
    let open: Bool
    let done: Bool

    private var pending: Bool { chapter.sections == nil }

    var body: some View {
        Button {
            if open { router.push(.chapter(slug: program.slug, week: chapter.week)) }
        } label: {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Text("\(chapter.week)")
                    .cDisplay(TypeScale.headingXL)
                    .foregroundStyle(CColor.textHeadingInverse)
                    .frame(width: 72, height: 72)
                    .background(CColor.neutralLighter, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .opacity(open ? 1 : 0.5)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xxs) {
                        Chip(text: "\(program.unitLabel) \(chapter.week)")
                        if open {
                            HStack(spacing: Spacing.xxxs) {
                                Image(systemName: CIcon.clock).font(.system(size: 12))
                                Text(AppCopy.program.duration(chapter.readMinutes, chapter.medium))
                            }
                            .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                        }
                        if done {
                            HStack(spacing: Spacing.xxxs) {
                                Image(systemName: CIcon.check).font(.system(size: 12))
                                Text(AppCopy.program.readLabel)
                            }
                            .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                        }
                    }
                    SectionHeading(text: chapter.title)
                    Text(open ? chapter.excerpt : AppCopy.program.lockedNote)
                        .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                    if open {
                        HStack(spacing: Spacing.xxs) {
                            Text(pending ? AppCopy.program.contentPending : ctaLabel)
                            if !pending { Image(systemName: CIcon.arrowRight).font(.system(size: 12, weight: .medium)) }
                        }
                        .cText(TypeScale.bodySm, weight: .medium)
                        .foregroundStyle(pending ? CColor.inkTertiary : CColor.heading)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .overlay(Capsule().stroke(CColor.hairline, lineWidth: 1))
                        .padding(.top, Spacing.xxxs)
                    }
                }
                .opacity(open ? 1 : 0.6)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .accessibilityLabel(AppCopy.program.openChapterAria(chapter.week, chapter.title))
    }

    private var ctaLabel: String {
        switch chapter.medium {
        case .read: return "Read article"
        case .watch: return "Watch video"
        case .listen: return "Listen podcast"
        }
    }
}

// MARK: - Chapter reading view

/// Structure follows the shipped Corveo article template: content-type label, serif title,
/// standfirst, label/value meta pairs, sans section headings, body, disclaimer, previous and
/// next. The education disclaimer sits at the point of reading, not only in Settings.
struct ChapterView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let slug: String
    let week: Int
    @State private var marking = false

    var body: some View {
        let program = Programs.find(slug)
        let chapter = Programs.chapter(slug, week)
        if let program, let chapter, Programs.isAvailable(model.progress, program, week) {
            let done = Programs.isRead(model.progress, program.slug, week)
            let previous = Programs.chapter(program.slug, week - 1)
            let next = Programs.chapter(program.slug, week + 1)
            let nextOpen = next.map { Programs.isAvailable(model.progress, program, $0.week) } ?? false

            Screen(
                overline: "\(program.unitLabel) \(chapter.week)",
                title: chapter.title,
                action: AnyView(HeaderLink(title: program.title) { router.pop() }),
                footer: AnyView(
                    done
                    ? CButton(title: nextOpen ? AppCopy.chapter.next : AppCopy.chapter.back) {
                        if nextOpen, let next { router.path[router.path.count - 1] = .chapter(slug: program.slug, week: next.week) }
                        else { router.pop() }
                    }
                    : CButton(title: marking ? AppCopy.common.busy : AppCopy.chapter.markRead, disabled: marking) {
                        Task {
                            marking = true
                            defer { marking = false }
                            await model.updateProgress(completedSteps: [Programs.stepKey(program.slug, week): true])
                        }
                    })
            ) {
                if let deck = chapter.deck {
                    Text(deck).cText(TypeScale.bodyLg).lineSpacing(4).foregroundStyle(CColor.inkSecondary)
                        .padding(.bottom, Spacing.sm)
                }
                if done { Chip(text: AppCopy.chapter.markedRead).padding(.bottom, Spacing.sm) }

                VStack(alignment: .leading, spacing: 0) {
                    Hairline()
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        MetaPair(label: program.unitLabel, value: AppCopy.chapter.metaWeekValue(chapter.week, program.chapters.count))
                        MetaPair(label: AppCopy.chapter.metaReadTime, value: AppCopy.chapter.metaReadTimeValue(chapter.readMinutes))
                        MetaPair(label: AppCopy.chapter.metaReview, value: chapter.reviewStatus)
                    }
                    .padding(.vertical, Spacing.sm)
                    Hairline()
                }

                if chapter.sections == nil {
                    Card { Text(AppCopy.education.contentPendingNotice).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary) }
                        .padding(.top, Spacing.md)
                }

                ArticleBody(sections: chapter.sections ?? [])

                HStack {
                    if let previous {
                        Button(AppCopy.chapter.previous) { router.path[router.path.count - 1] = .chapter(slug: program.slug, week: previous.week) }
                            .buttonStyle(.plain).cText(TypeScale.bodySm).underline().foregroundStyle(CColor.inkSecondary)
                    }
                    Spacer()
                    if let next, nextOpen {
                        Button(AppCopy.chapter.next) { router.path[router.path.count - 1] = .chapter(slug: program.slug, week: next.week) }
                            .buttonStyle(.plain).cText(TypeScale.bodySm).underline().foregroundStyle(CColor.inkSecondary)
                    }
                }
                .padding(.top, Spacing.md)
            }
        } else {
            Screen(title: AppCopy.chapter.notFound, action: AnyView(HeaderLink(title: AppCopy.chapter.back) { router.pop() })) {
                CButton(title: AppCopy.chapter.back) { router.pop() }
            }
        }
    }
}

/// Shared long-form body: sans section headings, relaxed body, education note at the foot.
struct ArticleBody: View {
    let sections: [ProgramSection]
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(sections, id: \.heading) { section in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SectionHeading(text: section.heading)
                    ForEach(section.body, id: \.self) { paragraph in
                        Text(paragraph).cText(TypeScale.bodyLg).lineSpacing(5).foregroundStyle(CColor.ink)
                    }
                }
            }
        }
        .padding(.top, Spacing.md)

        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            Text(SafetyCopy.educationNote)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.sm)
        }
        .padding(.top, Spacing.md)
    }
}

// MARK: - Programs library (change-request scope, CR-1)

struct ProgramBrowseView: View {
    @Environment(Router.self) private var router
    var body: some View {
        Screen(title: AppCopy.programIndex.title,
               action: AnyView(HeaderLink(title: AppCopy.chapter.back) { router.pop() })) {
            ProgramIndex(embedded: false)
        }
    }
}

/// Only the core six-week program is inside Deliverable 7. The rest are the website's
/// programs, shown so the browse-and-follow IA can be judged.
struct ProgramIndex: View {
    @Environment(FollowState.self) private var follow
    @Environment(Router.self) private var router
    let embedded: Bool

    var body: some View {
        Text(embedded ? AppCopy.programIndex.emptyIntro : AppCopy.programIndex.intro)
            .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
            .padding(.bottom, Spacing.md)

        VStack(spacing: Spacing.sm) {
            ForEach(Programs.all) { program in
                let following = follow.isFollowing(program.slug)
                let core = program.slug == coreProgramSlug
                Card {
                    Button { router.push(.programDetail(slug: program.slug)) } label: {
                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(AppCopy.programIndex.chapterCount(program.chapters.count, program.unitLabel)).eyebrow()
                            SectionHeading(text: program.title)
                            Text(program.description).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Group {
                        if core {
                            Text("Your program")
                                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                                .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xxs)
                                .overlay(Capsule().stroke(CColor.hairline, lineWidth: 1))
                        } else {
                            Button {
                                following ? follow.unfollow(program.slug) : follow.follow(program.slug)
                            } label: {
                                Text(following ? AppCopy.programIndex.following : AppCopy.programIndex.follow)
                                    .cText(TypeScale.bodySm, weight: .medium)
                                    .foregroundStyle(following ? CColor.heading : CColor.actionInk)
                                    .padding(.horizontal, Spacing.md)
                                    .frame(minHeight: 44)
                                    .background(following ? .clear : CColor.action, in: Capsule())
                                    .overlay(Capsule().stroke(following ? CColor.hairline : .clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Spacing.sm)
                }
            }
        }

        Text(AppCopy.programIndex.scopeNote)
            .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
            .padding(.top, Spacing.md)
    }
}

struct ProgramDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(FollowState.self) private var follow
    @Environment(Router.self) private var router
    let slug: String

    var body: some View {
        if let program = Programs.find(slug) {
            let following = follow.isFollowing(program.slug)
            let core = program.slug == coreProgramSlug
            let read = Programs.readCount(model.progress, program)
            Screen(
                overline: AppCopy.programIndex.chapterCount(program.chapters.count, program.unitLabel),
                title: program.title,
                action: AnyView(HeaderLink(title: AppCopy.program.browseAll) { router.pop() }),
                footer: core ? nil : AnyView(
                    CButton(title: following ? AppCopy.programIndex.following : AppCopy.programIndex.follow,
                            variant: following ? .secondary : .primary) {
                        if following {
                            follow.unfollow(program.slug)
                        } else {
                            follow.follow(program.slug)
                            follow.setActive(program.slug)
                            router.popToRoot()
                            router.tab = .program
                        }
                    })
            ) {
                Text(program.description).cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                Text(AppCopy.program.progress(read, program.chapters.count))
                    .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                    .padding(.top, Spacing.xxs).padding(.bottom, Spacing.sm)
                ChapterList(program: program, progress: model.progress)
            }
        } else {
            Screen(title: AppCopy.chapter.notFound, action: AnyView(HeaderLink(title: AppCopy.program.browseAll) { router.pop() })) {
                CButton(title: AppCopy.program.browseAll) { router.pop() }
            }
        }
    }
}

/// The other programs, as a rail at the foot of the Program tab. `+` follows a program;
/// tapping one you already follow makes it the program the tab opens on.
struct ProgramRail: View {
    @Environment(Router.self) private var router
    let active: String
    let following: [String]
    let onToggleFollow: (String) -> Void
    let onSwitch: (String) -> Void

    var body: some View {
        let rest = Programs.all.filter { $0.slug != active }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                SectionHeading(text: AppCopy.program.rail.heading)
                Text(AppCopy.program.rail.sub).eyebrow()
            }
            .padding(.bottom, Spacing.sm)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    ForEach(rest) { program in
                        let followed = following.contains(program.slug)
                        let core = program.slug == coreProgramSlug
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .bottomTrailing) {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(CColor.neutralLighter)
                                    .frame(width: 150, height: 96)
                                if !core {
                                    Button { onToggleFollow(program.slug) } label: {
                                        Image(systemName: followed ? CIcon.check : CIcon.plus)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(followed ? CColor.heading : CColor.actionInk)
                                            .frame(width: 44, height: 44)
                                            .background(followed ? CColor.card : CColor.action, in: Circle())
                                            .overlay(Circle().stroke(followed ? CColor.hairline : .clear, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(y: 14)
                                    .accessibilityLabel(followed ? AppCopy.program.rail.unfollowAria(program.title) : AppCopy.program.rail.followAria(program.title))
                                }
                            }
                            Button {
                                if followed { onSwitch(program.slug) } else { router.push(.programDetail(slug: program.slug)) }
                            } label: {
                                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                    Text(program.title).cText(TypeScale.bodyBase).foregroundStyle(CColor.heading)
                                        .multilineTextAlignment(.leading)
                                    Text(followed ? AppCopy.programIndex.following : AppCopy.programIndex.chapterCount(program.chapters.count, program.unitLabel)).eyebrow()
                                }
                                .frame(width: 150, alignment: .leading)
                                .padding(.top, Spacing.sm)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(followed ? AppCopy.program.rail.switchAria(program.title) : AppCopy.program.rail.openAria(program.title))
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Spacing.md)
        }
        .padding(.top, Spacing.lg)
    }
}

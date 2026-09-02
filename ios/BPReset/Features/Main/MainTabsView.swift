import SwiftUI

/// The app after the journey: three tab roots under one navigation stack, with the floating
/// tab bar over the roots only. Stack screens (settings, cuffs, add, chapter, library,
/// articles) push over the tabs and hide the bar.
struct MainTabsView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            NavigationStack(path: $router.path) {
                Group {
                    switch router.tab {
                    case .program: ProgramView()
                    case .record: RecordView()
                    case .education: LearnView()
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .settings: SettingsView()
                    case .settingsAppleHealth: AppleHealthSettingsView()
                    case .settingsAbout: AboutView()
                    case .settingsData: YourDataView()
                    case .settingsReminders: RemindersView()
                    case .settingsAccount: AccountView()
                    case .cuffs: ValidatedCuffsView()
                case .addReading: ManualEntryView()
                case .chapter(let slug, let week): ChapterView(slug: slug, week: week)
                case .programBrowse: ProgramBrowseView()
                case .programDetail(let slug): ProgramDetailView(slug: slug)
                    case .inFocus(let slug): InFocusArticleView(slug: slug)
                    case .pulse(let slug): PulseViewerView(slug: slug)
                    }
                }
            }
            if router.showsTabBar {
                TabBarFade()
                FloatingTabBar(selection: Binding(get: { router.tab }, set: { router.select($0) }))
            }
        }
        .animation(Motion.brand, value: router.showsTabBar)
    }
}

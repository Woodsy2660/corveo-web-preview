import SwiftUI
import Observation

/// Native launch path. Observers are per-process and a HealthKit background relaunch must
/// re-register them before any UI exists, so this is the one place the engine is armed.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        HealthKitEngine.shared.loadAtLaunch()
        HealthKitEngine.shared.armAtLaunchIfConfigured()
        return true
    }
}

@main
struct BPResetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var appState = AppState()
    @State private var model: AppModel
    @State private var health: HealthModel
    @State private var session: SessionModel
    @State private var router = Router()
    @State private var follow = FollowState()
    @State private var reminders = ReminderModel()

    init() {
        let state = AppState()
        // Backend when configured (Secrets.xcconfig), the synthetic mock otherwise.
        let client = SupabaseFactory.makeClient()
        let api: CorveoAPI = client.map { SupabaseAPI(client: $0) } ?? MockAPI()
        let model = AppModel(api: api)
        _appState = State(initialValue: state)
        _model = State(initialValue: model)
        _health = State(initialValue: HealthModel(app: model, appState: state))
        _session = State(initialValue: SessionModel(client: client, appState: state))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(model)
                .environment(health)
                .environment(session)
                .environment(router)
                .environment(follow)
                .environment(reminders)
                .preferredColorScheme(.light)
                .tint(CColor.heading)
                .onChange(of: scenePhase) { _, phase in
                    // Unconditional drain on every foreground activation (§12 P4).
                    if phase == .active { Task { await health.handleForeground() } }
                }
        }
    }
}

// MARK: - Journey (onboarding) state

enum ConnectChoice: String { case healthkit, manual, none }
enum CadenceChoice: String, CaseIterable { case twiceDaily = "twice_daily", daily, fewWeekly = "few_weekly" }

/// App state only, never health data. Persisted to UserDefaults so a half-finished journey
/// resumes where it left off.
@MainActor
@Observable
final class AppState {
    private static let key = "corveo.journey.v1"

    var journeyComplete: Bool { didSet { save() } }
    var connectChoice: ConnectChoice? { didSet { save() } }
    var cadence: CadenceChoice? { didSet { save() } }
    /// Stand-in for `app_user.created_at` until the Supabase session supplies it (P3).
    /// It bounds every HealthKit query forever, so it is set once and never moved.
    private(set) var programStartedAt: Date? { didSet { save() } }
    /// Stand-in for `app_user.id` until P3. Opaque, persisted, no health content.
    private(set) var enrolmentRef: String { didSet { save() } }
    /// True once the tuple came from the server (or the mock's enrolment). The engine is only
    /// ever configured from a bound tuple, and sign-out clears it (§6.2).
    private(set) var enrolmentBound: Bool { didSet { save() } }

    init() {
        let d = UserDefaults.standard
        journeyComplete = d.bool(forKey: Self.key + ".complete")
        connectChoice = d.string(forKey: Self.key + ".connect").flatMap(ConnectChoice.init(rawValue:))
        cadence = d.string(forKey: Self.key + ".cadence").flatMap(CadenceChoice.init(rawValue:))
        programStartedAt = d.object(forKey: Self.key + ".startedAt") as? Date
        if let ref = d.string(forKey: Self.key + ".enrolmentRef") {
            enrolmentRef = ref
        } else {
            let fresh = UUID().uuidString.lowercased()
            enrolmentRef = fresh
            d.set(fresh, forKey: Self.key + ".enrolmentRef")
        }
        // States written before the flag existed: a start date meant a bound enrolment.
        enrolmentBound = (d.object(forKey: Self.key + ".bound") as? Bool) ?? (d.object(forKey: Self.key + ".startedAt") != nil)
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(journeyComplete, forKey: Self.key + ".complete")
        d.set(connectChoice?.rawValue, forKey: Self.key + ".connect")
        d.set(cadence?.rawValue, forKey: Self.key + ".cadence")
        d.set(programStartedAt, forKey: Self.key + ".startedAt")
        d.set(enrolmentRef, forKey: Self.key + ".enrolmentRef")
        d.set(enrolmentBound, forKey: Self.key + ".bound")
    }

    /// Mock mode only: the enrolment moment without a server.
    func markEnrolled() {
        if programStartedAt == nil { programStartedAt = Date() }
        enrolmentBound = true
    }

    /// Sign-out: the tuple no longer describes who is signed in. A fresh, unbound reference
    /// means any reading still stamped with the old one fails the drain's binding check and
    /// is held rather than uploaded under the next account.
    func clearEnrolment() {
        enrolmentBound = false
        programStartedAt = nil
        enrolmentRef = UUID().uuidString.lowercased()
    }

    /// Backend mode: the tuple from the `app_user` row. The server clock wins, and the pair is
    /// immutable once set (a different pair is a different enrolment, §6.2).
    func setEnrolment(ref: String, start: Date) {
        if enrolmentRef != ref { enrolmentRef = ref }
        if programStartedAt != start { programStartedAt = start }
        if !enrolmentBound { enrolmentBound = true }
    }

    func completeJourney() { journeyComplete = true }

    func resetJourney() {
        journeyComplete = false
        connectChoice = nil
        cadence = nil
        clearEnrolment()
    }
}

// MARK: - Navigation

enum AppRoute: Hashable {
    case settings
    case cuffs
    case addReading
    case chapter(slug: String, week: Int)
    case programBrowse
    case programDetail(slug: String)
    case inFocus(slug: String)
    case pulse(slug: String)
}

@MainActor
@Observable
final class Router {
    var tab: MainTab = .record
    var path: [AppRoute] = []

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}

// MARK: - Root

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionModel.self) private var session

    var body: some View {
        Group {
            if !session.restored {
                CColor.page.ignoresSafeArea()
            } else if appState.journeyComplete && session.hasBackend && !session.isSignedIn {
                SignInView()
            } else if appState.journeyComplete {
                MainTabsView()
            } else {
                JourneyFlow()
            }
        }
        .animation(Motion.brand, value: appState.journeyComplete)
        .animation(Motion.brand, value: session.isSignedIn)
        .task { await session.restore() }
    }
}

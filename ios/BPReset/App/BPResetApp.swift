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
    @State private var router = Router()
    @State private var follow = FollowState()

    init() {
        let state = AppState()
        let model = AppModel(api: MockAPI())
        _appState = State(initialValue: state)
        _model = State(initialValue: model)
        _health = State(initialValue: HealthModel(app: model, appState: state))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(model)
                .environment(health)
                .environment(router)
                .environment(follow)
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
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(journeyComplete, forKey: Self.key + ".complete")
        d.set(connectChoice?.rawValue, forKey: Self.key + ".connect")
        d.set(cadence?.rawValue, forKey: Self.key + ".cadence")
        d.set(programStartedAt, forKey: Self.key + ".startedAt")
        d.set(enrolmentRef, forKey: Self.key + ".enrolmentRef")
    }

    /// The enrolment moment. In P3 this becomes `enrol_patient()`; the server clock wins.
    func markEnrolled() {
        if programStartedAt == nil { programStartedAt = Date() }
    }

    func completeJourney() { journeyComplete = true }

    func resetJourney() {
        journeyComplete = false
        connectChoice = nil
        cadence = nil
        programStartedAt = nil
        enrolmentRef = UUID().uuidString.lowercased()
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

    var body: some View {
        Group {
            if appState.journeyComplete {
                MainTabsView()
            } else {
                JourneyFlow()
            }
        }
        .animation(Motion.brand, value: appState.journeyComplete)
    }
}

import SwiftUI

// MARK: - Settings (Deliverable 12, plus the Apple Health status and the safety surface)

/// Settings, which is as much the patient's page as the app's: it opens on who they are in
/// the program (week, how readings arrive, the rhythm they chose), then a short menu, each
/// row a page: Apple Health, about this app (the safety surface), your data (export,
/// deletion, the consent receipt), the validated monitors, reminders and the account.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppState.self) private var appState
    @Environment(HealthModel.self) private var health
    @Environment(FollowState.self) private var follow
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router

    private var c: AppCopy.settings.profile.Type { AppCopy.settings.profile.self }

    private var profileRows: [(String, String)] {
        let program = Programs.find(coreProgramSlug)
        let week = model.progress?.currentWeek ?? 1
        let followed = follow.following.filter { $0 != coreProgramSlug }.compactMap { Programs.find($0)?.title }
        let source: String
        switch appState.connectChoice {
        case .healthkit: source = AppCopy.settings.profile.readingsHealth
        case .manual: source = AppCopy.settings.profile.readingsManual
        default: source = AppCopy.settings.profile.readingsNone
        }
        // The list arrives newest first; the record began with the last of it.
        let began = model.readings.last.map { Format.fullDate($0.effectiveTime) } ?? AppCopy.settings.profile.beganNone
        let rhythm: String
        switch appState.cadence {
        case .twiceDaily: rhythm = JourneyCopy.cadence.twiceDailyTitle
        case .daily: rhythm = JourneyCopy.cadence.dailyTitle
        case .fewWeekly: rhythm = JourneyCopy.cadence.fewWeeklyTitle
        case nil: rhythm = AppCopy.settings.profile.rhythmUnset
        }
        let consent: String
        if let cs = model.consent, cs.hasActiveConsent, let v = cs.version, let at = cs.lastEventAt {
            consent = AppCopy.settings.profile.consentGiven(Format.fullDate(at), v)
        } else {
            consent = AppCopy.settings.profile.consentNone
        }
        return [
            (AppCopy.settings.profile.programLabel, program.map { AppCopy.settings.profile.program(week, $0.chapters.count) } ?? ""),
            (AppCopy.settings.profile.followingLabel, followed.isEmpty ? AppCopy.settings.profile.followingNone : followed.joined(separator: ", ")),
            (AppCopy.settings.profile.readingsLabel, "\(source) · \(AppCopy.settings.profile.readingCount(model.readings.count))"),
            (AppCopy.settings.profile.beganLabel, began),
            (AppCopy.settings.profile.rhythmLabel, rhythm),
            (AppCopy.settings.profile.consentLabel, consent),
        ]
    }

    var body: some View {
        Screen(
            title: AppCopy.settings.title,
            action: AnyView(ProfileLink(pressed: true) { router.pop() }),
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            // You: the facts the patient set on the way in, as a quiet list.
            Text(AppCopy.settings.profile.title).eyebrow().padding(.bottom, Spacing.xxs)
            VStack(spacing: 0) {
                ForEach(profileRows, id: \.0) { row in FactRow(label: row.0, value: row.1) }
            }
            .padding(.bottom, Spacing.sm)

            // The menu: each row is a page of its own; the whole row is the tap.
            VStack(spacing: 0) {
                MenuRow(title: AppCopy.settings.menu.appleHealth) { router.push(.settingsAppleHealth) }
                MenuRow(title: AppCopy.settings.menu.reminders) { router.push(.settingsReminders) }
                MenuRow(title: AppCopy.settings.menu.about) { router.push(.settingsAbout) }
                MenuRow(title: AppCopy.settings.menu.data) { router.push(.settingsData) }
                MenuRow(title: AppCopy.settings.menu.monitors) { router.push(.cuffs) }
                if session.hasBackend {
                    MenuRow(title: AppCopy.settings.menu.account) { router.push(.settingsAccount) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(AppCopy.settings.menuAria)
        }
        .task {
            await model.loadConsent()
            await model.loadProgress()
            if model.readings.isEmpty { await model.loadReadings() }
            health.refresh()
        }
    }
}

// MARK: - Apple Health

/// Apple Health on its own page: whether it is connected, when the app last looked, a way
/// to look now, and a way to pause and resume the looking. It never says permission was
/// refused: the app is not told, so "connected" means the request was made and an empty
/// record reads as empty. Access itself is managed in iOS Settings, which is where it points.
struct AppleHealthSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(HealthModel.self) private var health
    @Environment(Router.self) private var router
    @State private var busy = false
    @State private var syncDone = false
    @State private var confirmingDiscardHeld = false

    var body: some View {
        Screen(
            title: AppCopy.settings.appleHealth.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            if health.connected {
                VStack(spacing: 0) {
                    FactRow(label: AppCopy.settings.appleHealth.statusLabel,
                            value: health.paused ? AppCopy.settings.appleHealth.paused : AppCopy.settings.appleHealth.connected)
                    FactRow(label: AppCopy.settings.appleHealth.lastLookedLabel, value: lastLooked)
                }
                .padding(.bottom, Spacing.md)

                Text(AppCopy.settings.appleHealth.readsOnly).cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                    .padding(.bottom, Spacing.md)

                VStack(spacing: Spacing.xxs) {
                    CButton(title: health.draining ? HealthSyncCopy.card.sync.busy : syncDone ? HealthSyncCopy.card.sync.done : HealthSyncCopy.card.sync.idle,
                            variant: .secondary, disabled: busy || health.draining || health.paused) {
                        Task {
                            await health.drain(trigger: .manual)
                            withAnimation(Motion.brand) { syncDone = true }
                            try? await Task.sleep(nanoseconds: 2_200_000_000)
                            withAnimation(Motion.brand) { syncDone = false }
                        }
                    }
                    CButton(title: health.paused ? AppCopy.settings.appleHealth.resumeCta : AppCopy.settings.appleHealth.pauseCta,
                            variant: .ghost, disabled: busy) {
                        Task {
                            busy = true
                            defer { busy = false }
                            if health.paused { await health.resume() } else { await health.pause() }
                        }
                    }
                }

                if health.paused {
                    Text(AppCopy.settings.appleHealth.pauseNote).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        .padding(.top, Spacing.sm)
                }
                if !health.samplesEverReceived {
                    // Neutral nudge: absence of data is indistinguishable from denial, and the
                    // app never implies denial.
                    Text(JourneyCopy.healthAuth.noSamplesNudge).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        .padding(.top, Spacing.sm)
                }
                if let problem = health.problemText {
                    Text(problem).cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                        .padding(.top, Spacing.sm)
                }
                if let rejected = health.rejectedText {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(rejected).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        Spacer(minLength: Spacing.xs)
                        Button(HealthSyncCopy.card.dismissRejected) { health.dismissRejected() }
                            .cText(TypeScale.bodySm, weight: .medium).foregroundStyle(CColor.inkSecondary)
                            .buttonStyle(.plain)
                    }
                    .padding(.top, Spacing.sm)
                }
                if health.status.heldCount > 0 {
                    Text(HealthSyncCopy.card.held(health.status.heldCount))
                        .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        .padding(.top, Spacing.sm)
                }
                if !health.foreignHeld.isEmpty {
                    Text(HealthSyncCopy.card.heldNote).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                        .padding(.top, Spacing.xxxs)
                    if confirmingDiscardHeld {
                        HStack(spacing: Spacing.xxs) {
                            CButton(title: HealthSyncCopy.card.discardHeldCta) {
                                health.discardForeignHeld()
                                confirmingDiscardHeld = false
                            }
                            CButton(title: AppCopy.common.cancel, variant: .secondary) { confirmingDiscardHeld = false }
                        }
                        .padding(.top, Spacing.xxs)
                    } else {
                        CButton(title: HealthSyncCopy.card.discardHeldCta, variant: .ghost) { confirmingDiscardHeld = true }
                            .padding(.top, Spacing.xxxs)
                    }
                }
            } else {
                Text(AppCopy.settings.appleHealth.notConnected).cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                    .padding(.bottom, Spacing.md)
                if let problem = health.problemText {
                    Text(problem).cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                        .padding(.bottom, Spacing.sm)
                }
                if health.isAvailable {
                    CButton(title: busy ? AppCopy.common.busy : AppCopy.settings.appleHealth.connectCta, disabled: busy) {
                        Task {
                            busy = true
                            defer { busy = false }
                            if await health.connect() { appState.connectChoice = .healthkit }
                        }
                    }
                }
            }

            Text(AppCopy.settings.appleHealth.manageHint).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.md)
            CButton(title: HealthSyncCopy.openSettings, variant: .ghost) { health.openSystemSettings() }
        }
        .task { health.refresh() }
    }

    private var lastLooked: String {
        if health.lastArrived > 0 { return HealthSyncCopy.card.arrived(health.lastArrived) }
        if let at = health.lastDrainAt { return Format.time(at) }
        return HealthSyncCopy.card.waiting
    }
}

// MARK: - About (the safety surface, Deliverable 12)

struct AboutView: View {
    @Environment(Router.self) private var router

    var body: some View {
        Screen(
            overline: AppCopy.settings.menu.about,
            title: SafetyCopy.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            Text(SafetyCopy.doesTitle).eyebrow().padding(.bottom, Spacing.xxxs)
            bulletList(SafetyCopy.does).padding(.bottom, Spacing.sm)

            Text(SafetyCopy.doesNotTitle).eyebrow().padding(.bottom, Spacing.xxxs)
            bulletList(SafetyCopy.doesNot).padding(.bottom, Spacing.sm)

            Text(SafetyCopy.seekAdvice).cText(TypeScale.bodyBase).foregroundStyle(CColor.ink).padding(.bottom, Spacing.xxs)
            Text(SafetyCopy.disclaimer).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
        }
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Spacing.xxs) {
                    Text("•").cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                    Text(item).cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                }
            }
        }
    }
}

// MARK: - Your data (export, deletion, consent; the development reset)

struct YourDataView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppState.self) private var appState
    @Environment(HealthModel.self) private var health
    @Environment(FollowState.self) private var follow
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router
    @Environment(ReminderModel.self) private var reminders

    @State private var confirmingDelete = false
    #if DEBUG
    @State private var seeding = false
    @State private var seedResult: String?
    #endif
    @State private var exporting = false
    @State private var exportItems: [URL] = []
    @State private var exportDir: URL? = nil
    @State private var showShare = false
    @State private var deleteError: String? = nil
    @State private var consentBusy = false

    var body: some View {
        Screen(
            title: AppCopy.settings.yourData.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            Text(AppCopy.settings.yourData.body).cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)

            VStack(spacing: Spacing.xxs) {
                CButton(title: exporting ? AppCopy.common.busy : AppCopy.settings.yourData.exportCta, variant: .secondary, disabled: exporting) {
                    Task { await exportRecord() }
                }
                Text(AppCopy.settings.yourData.exportNote).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Spacing.xs)

                if confirmingDelete {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        SectionHeading(text: AppCopy.settings.yourData.deleteConfirmTitle)
                        Text(AppCopy.settings.yourData.deleteConfirmBody)
                            .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                            .padding(.bottom, Spacing.xxs)
                        CButton(title: AppCopy.settings.yourData.deleteConfirmCta) { Task { await requestDeletion() } }
                        CButton(title: AppCopy.settings.yourData.deleteCancelCta, variant: .secondary) { confirmingDelete = false }
                    }
                    .padding(Spacing.sm)
                    .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(CColor.hairline, lineWidth: 1))
                } else {
                    CButton(title: AppCopy.settings.yourData.deleteCta, variant: .secondary) { confirmingDelete = true }
                }
                if let deleteError {
                    Text(deleteError).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let consent = model.consent, !consent.hasActiveConsent {
                // The route back to consent when it was never recorded or was withdrawn:
                // without it every save fails with no way forward.
                Text(AppCopy.settings.yourData.consentMissing).cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                    .padding(.top, Spacing.md)
                CButton(title: consentBusy ? AppCopy.common.busy : AppCopy.settings.yourData.giveConsentCta, variant: .secondary, disabled: consentBusy) {
                    Task {
                        consentBusy = true
                        defer { consentBusy = false }
                        try? await model.recordConsent()
                        await model.loadConsent()
                    }
                }
                .padding(.top, Spacing.xxs)
            }
            if let consent = model.consent, consent.hasActiveConsent, let version = consent.version, let at = consent.lastEventAt {
                Text(AppCopy.settings.yourData.consentReceipt(version, Format.fullDate(at)))
                    .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                    .padding(.top, Spacing.md)
            }

            #if DEBUG
            developmentSection
            #endif
        }
        .task { await model.loadConsent() }
        .sheet(isPresented: $showShare, onDismiss: { cleanUpExport() }) {
            ShareSheet(items: exportItems, onFinish: { cleanUpExport() })
        }
    }

    #if DEBUG
    private var developmentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(AppCopy.settings.demo.title).eyebrow().padding(.top, Spacing.lg)
            CButton(title: AppCopy.settings.demo.resetCta, variant: .secondary) {
                Task {
                    await model.resetSynthetic()
                    await Teardown.run(.developmentReset, health: health, session: session, reminders: reminders,
                                       follow: follow, appState: appState, router: router)
                }
            }
            Text(AppCopy.settings.demo.note).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
            CButton(title: ReminderCopy.settings.testCta, variant: .secondary) {
                Task { await reminders.sendTestReminder() }
            }
            .padding(.top, Spacing.xs)
            CButton(title: seeding ? AppCopy.settings.demo.seedBusy : AppCopy.settings.demo.seedCta,
                    variant: .secondary, disabled: seeding) {
                Task {
                    seeding = true
                    defer { seeding = false }
                    if let r = await model.seedDemoReadings() {
                        seedResult = AppCopy.settings.demo.seedDone(inserted: r.inserted, duplicates: r.duplicates, rejected: r.rejected)
                    } else {
                        seedResult = AppCopy.settings.demo.seedFailed
                    }
                }
            }
            .padding(.top, Spacing.xs)
            Text(seedResult ?? AppCopy.settings.demo.seedNote).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
            // Engine diagnostics: states, counts and reason codes only (guide §7.3).
            let st = health.status
            let reasons = st.rejectionReasons.sorted { $0.key < $1.key }
                .map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
            Text("Engine: \(st.state). Pending \(st.pendingCount), held \(st.heldCount), rejected by backend \(st.rejectedCount)\(reasons.isEmpty ? "" : " (\(reasons))"), malformed in HealthKit \(st.malformedCount).")
                .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.xxs)
                .textSelection(.enabled)
        }
    }
    #endif

    /// Export: the server's CSV and FHIR JSON, verbatim, written file-protected into a fresh
    /// temporary directory for the share sheet, and removed on every exit: a failed write, the
    /// sheet finishing, or the sheet being dismissed.
    private func exportRecord() async {
        exporting = true
        defer { exporting = false }
        guard let result = try? await model.export() else { return }
        cleanUpExport()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let csv = dir.appendingPathComponent("corveo-my-heart-record.csv")
        let json = dir.appendingPathComponent("corveo-my-heart-record.fhir.json")
        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            try Data(result.csv.utf8).write(to: csv, options: [.atomic, .completeFileProtection])
            try Data(result.fhirBundleJSON.utf8).write(to: json, options: [.atomic, .completeFileProtection])
            exportDir = dir
            exportItems = [csv, json]
            showShare = true
        } catch {
            try? FileManager.default.removeItem(at: dir)
            exportItems = []
        }
    }

    private func cleanUpExport() {
        if let dir = exportDir { try? FileManager.default.removeItem(at: dir) }
        exportDir = nil
        exportItems = []
    }

    /// Deletion is the server's act. Nothing local is touched until it has succeeded.
    private func requestDeletion() async {
        deleteError = nil
        do {
            try await model.requestAccountDeletion()
        } catch {
            deleteError = AppCopy.settings.yourData.deleteFailed
            return
        }
        confirmingDelete = false
        await Teardown.run(.deletion, health: health, session: session, reminders: reminders,
                           follow: follow, appState: appState, router: router)
    }
}

// MARK: - Reminders (rhythm only; the scheduler never sees a reading)

struct RemindersView: View {
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @Environment(ReminderModel.self) private var reminders

    var body: some View {
        Screen(
            title: ReminderCopy.settings.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            Text(ReminderCopy.settings.body).cText(TypeScale.bodyBase).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)
            Segmented(
                options: CadenceChoice.allCases.map { (value: $0, label: ReminderCopy.settings.short($0)) },
                selection: Binding(
                    get: { appState.cadence ?? .daily },
                    set: { choice in
                        appState.cadence = choice
                        Task { await reminders.reschedule(cadence: choice) }
                    }),
                ariaLabel: ReminderCopy.settings.rhythmAria)
            Text(ReminderModel.scheduleNote(for: appState.cadence))
                .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.xxs)
            CheckRow(
                checked: Binding(
                    get: { reminders.enabled },
                    set: { on in
                        Task {
                            if on { await reminders.enable(cadence: appState.cadence) } else { reminders.disable() }
                        }
                    }),
                label: ReminderCopy.settings.toggle)
                .padding(.top, Spacing.md)
            if reminders.enabled && reminders.isDeniedByiOS {
                Text(ReminderCopy.settings.deniedNote).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                    .padding(.top, Spacing.xxs)
                CButton(title: ReminderCopy.settings.openSettings, variant: .ghost) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .padding(.top, Spacing.xxs)
            }
        }
        .task { await reminders.refresh() }
    }
}

// MARK: - Account

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(HealthModel.self) private var health
    @Environment(FollowState.self) private var follow
    @Environment(SessionModel.self) private var session
    @Environment(Router.self) private var router
    @Environment(ReminderModel.self) private var reminders

    var body: some View {
        Screen(
            title: AppCopy.settings.account.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            if let email = session.email {
                Text(AppCopy.settings.account.signedInAs(email)).cText(TypeScale.bodyBase).foregroundStyle(CColor.ink)
                    .padding(.bottom, Spacing.md)
            }
            CButton(title: AppCopy.settings.account.signOutCta, variant: .secondary) {
                Task {
                    await Teardown.run(.signOut, health: health, session: session, reminders: reminders,
                                       follow: follow, appState: appState, router: router)
                }
            }
            Text(AppCopy.settings.account.signOutNote).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.xxs)
        }
    }
}

// MARK: - Teardown (one definition for the three exits)

/// Sign-out drains first and keeps the engine running for the next sign-in of the same
/// person (§6.3): readings stay on the phone, the binding leaves with the account. Deletion
/// and the development reset discard the queue and restart the journey.
enum Teardown {
    enum Mode { case signOut, deletion, developmentReset }

    @MainActor
    static func run(_ mode: Mode, health: HealthModel, session: SessionModel, reminders: ReminderModel,
                    follow: FollowState, appState: AppState, router: Router) async {
        switch mode {
        case .signOut:
            await health.drain(trigger: .manual)
        case .deletion, .developmentReset:
            await health.disconnect(.confirmedDiscard)
        }
        await session.signOut()
        reminders.disable()                                 // a different person may sign in next
        follow.reset()
        if mode != .signOut { appState.resetJourney() }
        router.popToRoot()
    }
}

/// UIActivityViewController wrapper. Reports completion so the caller can remove the files.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    var onFinish: () -> Void = {}
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Validated cuffs (Deliverable 8)

/// The cited source is part of what gets accepted: keep the reference visible on screen.
struct ValidatedCuffsView: View {
    @Environment(Router.self) private var router

    var body: some View {
        Screen(
            title: ValidatedCuffsCopy.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            Text(ValidatedCuffsCopy.intro).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.md)
            VStack(spacing: Spacing.xs) {
                ForEach(ValidatedCuffsCopy.devices, id: \.model) { d in
                    Card {
                        SectionHeading(text: "\(d.brand) \(d.model)").padding(.bottom, Spacing.xxxs)
                        Text(d.connectivity).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    }
                }
            }
            Text(ValidatedCuffsCopy.sourceNote).cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.md)
        }
    }
}

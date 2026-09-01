import SwiftUI

// MARK: - Settings (Deliverable 12, plus the Apple Health status and the safety surface)

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppState.self) private var appState
    @Environment(HealthModel.self) private var health
    @Environment(FollowState.self) private var follow
    @Environment(Router.self) private var router

    @State private var confirmingDelete = false
    @State private var confirmingDisconnect = false
    @State private var exporting = false
    @State private var exportItems: [URL] = []
    @State private var showShare = false

    var body: some View {
        Screen(
            eyebrow: AppCopy.settings.eyebrow,
            title: AppCopy.settings.title,
            footer: AnyView(CButton(title: AppCopy.common.back, variant: .ghost) { router.pop() })
        ) {
            VStack(spacing: Spacing.sm) {
                appleHealthCard
                yourDataCard
                aboutCard
                cuffsCard
                #if DEBUG
                developmentCard
                #endif
            }
        }
        .task {
            await model.loadConsent()
            health.refresh()
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: exportItems)
        }
    }

    // MARK: Apple Health

    private var appleHealthCard: some View {
        Card(label: AppCopy.settings.appleHealth.title) {
            Text(health.connected ? AppCopy.settings.appleHealth.readsOnly : AppCopy.settings.appleHealth.notConnected)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
            if health.connected && !health.samplesEverReceived {
                // Neutral nudge: absence of data is indistinguishable from denial, and the app
                // never implies denial.
                Text(JourneyCopy.healthAuth.noSamplesNudge)
                    .cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                    .padding(.top, Spacing.xxs)
            }
            if health.status.heldCount > 0 {
                Text(HealthSyncCopy.card.pending(health.status.heldCount))
                    .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    .padding(.top, Spacing.xxs)
            }
            Text(AppCopy.settings.appleHealth.manageHint)
                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.xxxs)

            VStack(spacing: Spacing.xxs) {
                if health.connected {
                    if confirmingDisconnect {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(AppCopy.settings.appleHealth.disconnectNote)
                                .cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                            CButton(title: AppCopy.settings.appleHealth.disconnectCta) {
                                Task {
                                    await health.disconnect(.holdForReauth)
                                    appState.connectChoice = .manual
                                    confirmingDisconnect = false
                                }
                            }
                            CButton(title: AppCopy.common.cancel, variant: .secondary) { confirmingDisconnect = false }
                        }
                        .padding(Spacing.sm)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(CColor.hairline, lineWidth: 1))
                    } else {
                        CButton(title: AppCopy.settings.appleHealth.disconnectCta, variant: .secondary) { confirmingDisconnect = true }
                    }
                } else if health.isAvailable {
                    CButton(title: AppCopy.settings.appleHealth.connectCta, variant: .secondary) {
                        Task {
                            await health.connect()
                            appState.connectChoice = .healthkit
                        }
                    }
                }
                CButton(title: HealthSyncCopy.openSettings, variant: .ghost) { health.openSystemSettings() }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: Your data

    private var yourDataCard: some View {
        Card(label: AppCopy.settings.yourData.title) {
            Text(AppCopy.settings.yourData.body).cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                .padding(.bottom, Spacing.sm)
            VStack(spacing: Spacing.xxs) {
                CButton(title: exporting ? AppCopy.common.busy : AppCopy.settings.yourData.exportCta, variant: .secondary, disabled: exporting) {
                    Task { await exportRecord() }
                }
                Text(AppCopy.settings.yourData.exportNote).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            }
            if let consent = model.consent, consent.hasActiveConsent, let version = consent.version, let at = consent.lastEventAt {
                Text(AppCopy.settings.yourData.consentReceipt(version, Format.fullDate(at)))
                    .cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                    .padding(.top, Spacing.sm)
            }
        }
    }

    // MARK: About (the safety surface, Deliverable 12)

    private var aboutCard: some View {
        Card(label: AppCopy.settings.aboutTitle) {
            SectionHeading(text: SafetyCopy.title).padding(.bottom, Spacing.xxs)

            Text(SafetyCopy.doesTitle).eyebrow().padding(.bottom, Spacing.xxxs)
            bulletList(SafetyCopy.does).padding(.bottom, Spacing.xs)

            Text(SafetyCopy.doesNotTitle).eyebrow().padding(.bottom, Spacing.xxxs)
            bulletList(SafetyCopy.doesNot).padding(.bottom, Spacing.xs)

            Text(SafetyCopy.seekAdvice).cText(TypeScale.bodySm).foregroundStyle(CColor.ink).padding(.bottom, Spacing.xxs)
            Text(SafetyCopy.disclaimer).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
        }
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Spacing.xxs) {
                    Text("•").cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    Text(item).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                }
            }
        }
    }

    // MARK: Cuffs (Deliverable 8 entry)

    private var cuffsCard: some View {
        Card(label: AppCopy.settings.cuffsTitle) {
            Text(ValidatedCuffsCopy.intro).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                .padding(.bottom, Spacing.xs)
            Button { router.push(.cuffs) } label: {
                Text(ValidatedCuffsCopy.title).cText(TypeScale.bodySm).underline().foregroundStyle(CColor.ink)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Development

    private var developmentCard: some View {
        Card(label: AppCopy.settings.demo.title) {
            CButton(title: AppCopy.settings.demo.resetCta, variant: .secondary) {
                Task {
                    await model.resetSynthetic()
                    await health.disconnect(.confirmedDiscard)
                    follow.reset()
                    appState.resetJourney()
                    router.popToRoot()
                }
            }
            Text(AppCopy.settings.demo.note).cText(TypeScale.label).foregroundStyle(CColor.inkTertiary)
                .padding(.top, Spacing.xxs)
        }
    }

    // MARK: Actions

    /// Export: files go to the iOS share sheet from the cache directory, and are removed
    /// afterwards. The CSV and FHIR JSON are the server's output verbatim.
    private func exportRecord() async {
        exporting = true
        defer { exporting = false }
        guard let result = try? await model.export() else { return }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let csv = dir.appendingPathComponent("corveo-my-heart-record.csv")
        let json = dir.appendingPathComponent("corveo-my-heart-record.fhir.json")
        do {
            try result.csv.write(to: csv, atomically: true, encoding: .utf8)
            try result.fhirBundleJSON.write(to: json, atomically: true, encoding: .utf8)
            exportItems = [csv, json]
            showShare = true
        } catch {
            exportItems = []
        }
    }

    private func requestDeletion() async {
        try? await model.requestAccountDeletion()
        await health.disconnect(.confirmedDiscard)
        follow.reset()
        appState.resetJourney()
        router.popToRoot()
    }
}

/// UIActivityViewController wrapper. Cleans the exported files up when the sheet closes.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            for url in items { try? FileManager.default.removeItem(at: url) }
        }
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
            eyebrow: ValidatedCuffsCopy.eyebrow,
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

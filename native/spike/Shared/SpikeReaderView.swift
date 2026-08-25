import SwiftUI

/// §11 run-sheet order, top to bottom. Nothing on this screen is a reading value.
struct SpikeReaderView: View {
    @StateObject private var model = SpikeReaderModel()

    var body: some View {
        NavigationStack {
            List {
                environmentSection
                configureSection
                spk3Section
                spk1Section
                spk4Section
                storeSection
                logSection
            }
            .navigationTitle("BP spike · \(SpikeAuthSet.variant)")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(model.busy)
            .refreshable { model.refresh() }
        }
    }

    // MARK: - Step 0

    private var environmentSection: some View {
        Section("Step 0 · environment (ADR-0004)") {
            evidenceBanner
            row("Bundle ID", SpikeEnvironment.bundleIdentifier)
            row("Device class", SpikeEnvironment.deviceClass)
            row("Device model", SpikeEnvironment.deviceModelIdentifier)
            row("OS", SpikeEnvironment.osShortVersion)
            row("Build", SpikeEnvironment.osBuildNumber)
            row("Frozen baseline >= 26.6",
                SpikeEnvironment.meetsFrozenBaseline ? "met" : "NOT MET — results void (§3.5)")
            row("HealthKit available", SpikeEnvironment.healthDataAvailable ? "yes" : "no")
            row("Auth set", model.authVariant)
            Button("Copy environment block for ADR-0004") { model.copyEnvironmentBlock() }
        }
    }

    /// §9.4 / §3.5 / pitfall 1. The screen states what this host's results are worth before
    /// anything is run on it, so a long day cannot end in an ADR filled from a sidecar.
    @ViewBuilder
    private var evidenceBanner: some View {
        let cls = SpikeEnvironment.evidenceClass
        VStack(alignment: .leading, spacing: 4) {
            Text(cls.rawValue)
                .font(.headline)
                .foregroundStyle(cls == .evidential ? Color.green : Color.orange)
            Text(cls.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Configuration

    private var configureSection: some View {
        Section("Configure (§6.2 tuple)") {
            row("enrolmentRef", Log.prefix8(model.enrolmentRef))
            Stepper("importStart: \(model.importStartDaysBack) d back",
                    value: $model.importStartDaysBack, in: 1...365)
            Text("importStart must precede the backdated insert SPK-1 asks for, or the production predicate excludes it.")
                .font(.caption).foregroundStyle(.secondary)
            Button("configure()") { model.configure() }
            Button("configure() again — expect CONFIG_CONFLICT") { model.configureAgainSameTuple() }
            row("state", model.readout.engineState)
        }
    }

    // MARK: - SPK-3

    private var spk3Section: some View {
        Section("SPK-3 · authorisation set") {
            Button("statusForAuthorizationRequest") { model.authStatusBefore() }
            Button("requestAuthorization()") { model.requestAuthorization() }
            Button("startObserving() — both quantity observers + delivery") { model.startObserving() }
            Button("stopObserving() — full teardown (B4)") { model.stopObserving() }
            row("lastArm", model.readout.lastArm)
        }
    }

    // MARK: - SPK-1

    private var spk1Section: some View {
        Section("SPK-1 · resumable correlation anchor") {
            Button("runCatchUp() — anchored query, production predicate") { model.runCatchUp() }
            Button("getPendingSnapshot()") { model.showSnapshot() }
            Button("acknowledge(snapshot)") { model.acknowledgeAll() }
            Button("acknowledge(stale) — expect SNAPSHOT_STALE") { model.acknowledgeStale() }
            row("bootstrapComplete", model.readout.bootstrapComplete ? "true" : "false")
            row("anchor persisted", model.readout.anchorPresent ? "yes" : "no")
            row("pending", "\(model.readout.pendingCount)")
            row("snapshotId", model.readout.snapshotId)
            row("malformed", "\(model.readout.malformedTotal) across \(model.readout.malformedSources) source(s)")
            Button("TERMINATE PROCESS (step 4)", role: .destructive) { model.terminateProcess() }
        }
    }

    // MARK: - SPK-4

    private var spk4Section: some View {
        Section("SPK-4 · state store & anchor survival") {
            Button("Inject corrupt anchorData") { model.inject(.corruptAnchorData) }
            Button("Nil-anchor probe → anchor-only reset") { model.anchorResetProbe() }
            Button("Corrupt NEWEST generation (M17)") { model.inject(.corruptNewestGeneration) }
            Button("Corrupt BOTH generations (expect INTERNAL)") { model.inject(.corruptBothGenerations) }
            Button("Destroy store — spike recovery only", role: .destructive) {
                model.destroyStoreForRecovery()
            }
            row("anchorResets", "\(model.readout.anchorResets)")
            row("anchorResetReason", model.readout.anchorResetReason ?? "-")
            row("generationFallbacks", "\(model.readout.generationFallbacks)")
        }
    }

    // MARK: - Store

    private var storeSection: some View {
        Section("Store (§10)") {
            row("commitSeq", "\(model.readout.commitSeq)")
            row("active slot", model.readout.activeSlot)
            row("load", model.readout.loadNote)
            ForEach(model.readout.generations, id: \.self) { g in
                Text(g).font(.system(.caption, design: .monospaced))
            }
            if let fault = model.lastFault {
                Text("last error: \(fault)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Log

    private var logSection: some View {
        Section("Log — counts, codes, UUID prefixes only (§4.2)") {
            Button("Copy log") { model.copyLog() }
            ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(.caption2, design: .monospaced))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

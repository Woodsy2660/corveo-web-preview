import SwiftUI

/// Synthetic-source generator. Nothing on this screen renders a magnitude — the writer's
/// readouts are UUID prefixes, counts and error codes, so a screenshot of it is safe to
/// retain without redaction (§4.2, T-EV).
struct WriterView: View {
    @StateObject private var writer = WriterEngine.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Environment") {
                    row("Bundle ID", Bundle.main.bundleIdentifier ?? "unknown")
                    row("HealthKit available", writer.isAvailable ? "yes" : "no")
                    Button("requestAuthorization() — share + read") {
                        Task { await writer.requestAuthorization() }
                    }
                }

                Section("SPK-1 · the two inserts") {
                    Button("Save one NOW") { Task { await writer.saveNow() } }
                    Button("Save one BACKDATED 7 d") { Task { await writer.saveBackdated7d() } }
                }

                Section("SPK-2 / SPK-close") {
                    Button("Delete last written correlation", role: .destructive) {
                        Task { await writer.deleteLastWritten() }
                    }
                }

                Section("T5a · delayed save") {
                    Picker("Delay", selection: $writer.pendingDelaySeconds) {
                        ForEach([10, 20, 30, 45, 60, 90], id: \.self) { Text("\($0) s").tag($0) }
                    }
                    Button("Schedule save") { writer.saveAfterDelay() }
                    Text("Background execution is granted at iOS's discretion; the log records whether the write fired or the assertion expired.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("§12 P3b · the rest of the button set") {
                    Button("10 across last week") { Task { await writer.saveTenAcrossLastWeek() } }
                    Button("Duplicate of last, +90 s") { Task { await writer.saveDuplicateOfLastPlus90s() } }
                    Button("T8b chain — +0:00 / +2:50 / +5:40") { Task { await writer.saveT8bChain() } }
                    Button("Future-dated +1 d") { Task { await writer.saveFutureDated1d() } }
                    Button("No timezone metadata") { Task { await writer.saveWithoutTimeZoneMetadata() } }
                    Button("Bare systolic (no correlation)") { Task { await writer.saveBareSystolic() } }
                }

                Section("Written this session") {
                    row("count", "\(writer.written.count)")
                    ForEach(writer.written.suffix(20).reversed(), id: \.self) { uuid in
                        Text(Log.prefix8(uuid)).font(.system(.caption, design: .monospaced))
                    }
                    if let e = writer.lastError {
                        Text("last error: \(e)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }

                Section("Log") {
                    ForEach(Array(Log.lines().suffix(80).reversed().enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption2, design: .monospaced))
                    }
                }
            }
            .navigationTitle("BP writer · synthetic")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(writer.busy)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}

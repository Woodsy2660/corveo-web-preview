import SwiftUI

/// Reader **C** — `dev.lucab.bpspikec`, correlation-inclusive authorisation set (§11 SPK-3).
/// A second clean permission identity: one app's Health permission state contaminates the
/// A/B, so the two readers are never collapsed into one target.
/// Read-only: no `NSHealthUpdateUsageDescription`, no write path, by design.
@main
struct BPSpikeCApp: App {
    init() {
        if StoreSelfTest.environmentReportRequested {
            StoreSelfTest.reportEnvironment()
            exit(0)
        }
        if StoreSelfTest.requested {
            StoreSelfTest.runAndReport()
            exit(0)
        }
        SpikeEngine.shared.loadAtLaunch()
        // -spikeNoAutoArm: observers fire on registration, and their catch-ups race an
        // explicit one. A measurement run needs exactly one catch-up path.
        if !CommandLine.arguments.contains("-spikeNoAutoArm") {
            SpikeEngine.shared.armAtLaunchIfConfigured()
        }
    }

    var body: some Scene {
        WindowGroup {
            if SpikeCommandLine.requested {
                SpikeCommandLineView()
            } else {
                SpikeReaderView()
            }
        }
    }
}

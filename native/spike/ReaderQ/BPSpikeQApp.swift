import SwiftUI

/// Reader **Q** — `dev.lucab.bpspike`, quantity-only authorisation set (§11 SPK-3).
/// Read-only: no `NSHealthUpdateUsageDescription`, no write path, by design.
@main
struct BPSpikeQApp: App {
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

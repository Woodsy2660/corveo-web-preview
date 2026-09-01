import SwiftUI

/// `dev.lucab.bpwriter` — the throwaway synthetic writer. The **only** target carrying
/// `NSHealthUpdateUsageDescription`. Never ships; never embedded in the harness or the
/// product (§4.3, §9.3, §17.4 step 3).
@main
struct BPWriterApp: App {
    var body: some Scene {
        WindowGroup {
            if WriterCommandLine.requested {
                WriterCommandLineView()
            } else {
                WriterView()
            }
        }
    }
}

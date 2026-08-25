import Foundation
import SwiftUI

/// Launch-argument driver for the writer, so the §11 sequence is one script rather than a
/// remembered order of taps. `requestAuthorization` stays interactive — the share sheet is
/// a UI interaction.
enum WriterCommandLine {

    private static var args: [String] { CommandLine.arguments }

    static var requested: Bool {
        args.contains { $0.hasPrefix("-writer") }
    }

    private static func stringValue(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @MainActor
    static func run() async {
        let writer = WriterEngine.shared
        if let v = stringValue(after: "-writerShareCorrelation") {
            WriterTypes.shareIncludesCorrelation = (v == "1")
        }
        if let v = stringValue(after: "-writerReadCorrelation") {
            WriterTypes.readIncludesCorrelation = (v == "1")
        }
        print("WRITER-CLI begin authSet=\(WriterTypes.variantLabel)")
        print("  healthDataAvailable=\(writer.isAvailable)")

        if args.contains("-writerRequestAuth") {
            print("  requestAuthorization: about to call "
                  + "share=\(WriterTypes.share.count) read=\(WriterTypes.read.count)")
            await writer.requestAuthorization()
            print("  requestAuthorization=\(writer.lastError.map { "FAILED code=\($0)" } ?? "returned")")
        }

        if args.contains("-writerSaveNow") {
            await writer.saveNow()
            report(writer, "saveNow")
        }
        if args.contains("-writerSaveBackdated7d") {
            await writer.saveBackdated7d()
            report(writer, "saveBackdated7d")
        }
        if args.contains("-writerSaveBareSystolic") {
            await writer.saveBareSystolic()
            report(writer, "saveBareSystolic")
        }
        if args.contains("-writerDeleteLast") {
            await writer.deleteLastWritten()
            if let e = writer.lastError {
                print("  deleteLast=FAILED code=\(e)")
            } else {
                print("  deleteLast=ok deletedCorrelationUuid="
                      + "\(writer.lastDeleted.map(Log.prefix8) ?? "-")")
            }
        }
        if args.contains("-writerList") {
            print("  writtenCount=\(writer.written.count)")
            for u in writer.written { print("    correlationUuid=\(Log.prefix8(u))") }
        }
        print("WRITER-CLI end")
    }

    @MainActor
    private static func report(_ writer: WriterEngine, _ step: String) {
        if let e = writer.lastError {
            print("  \(step)=FAILED code=\(e)")
        } else {
            print("  \(step)=ok correlationUuid=\(writer.written.last.map(Log.prefix8) ?? "-")")
        }
    }
}

struct WriterCommandLineView: View {
    var body: some View {
        Text("running writer step…")
            .task {
                await WriterCommandLine.run()
                UserDefaults.standard.synchronize()   // exit(0) must not race the write
                exit(0)
            }
    }
}

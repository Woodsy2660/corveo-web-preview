import Foundation
import HealthKit
import os

/// Guide §4.2 binding rule (1): the log wrapper accepts event names, counts, type
/// identifiers, error codes and truncated opaque IDs — and has **no overload accepting a
/// reading**. A stray value in any build is a severity-1 privacy defect.
///
/// The prohibition is enforced by the compiler, not by discipline:
///   * the event name is `StaticString`, so no interpolated runtime string can be passed;
///   * every overload that could carry a value is declared `unavailable`, which makes the
///     call a compile error rather than a code-review finding.
enum Log {
    private static let logger = Logger(subsystem: "dev.aiplease.bpreset", category: "engine")

    /// In-memory ring for the on-screen readout. Counts, codes and truncated opaque IDs
    /// only — the same alphabet as the durable log.
    private static let lock = NSLock()
    private static var ring: [String] = []
    private static let ringLimit = 400

    static func event(
        _ name: StaticString,
        count: Int? = nil,
        code: String? = nil,
        id8: String? = nil,
        type: String? = nil
    ) {
        var line = "\(name)"
        if let count { line += " count=\(count)" }
        if let code  { line += " code=\(code)" }
        if let type  { line += " type=\(type)" }
        if let id8   { line += " id=\(id8)" }
        logger.info("\(line, privacy: .public)")
        lock.lock()
        ring.append("\(Self.stamp()) \(line)")
        if ring.count > ringLimit { ring.removeFirst(ring.count - ringLimit) }
        lock.unlock()
    }

    static func lines() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return ring
    }

    static func clear() {
        lock.lock(); ring.removeAll(); lock.unlock()
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func stamp() -> String { stampFormatter.string(from: Date()) }

    // MARK: - Structurally impossible overloads (§4.2 binding rule 1)

    @available(*, unavailable, message: "Log takes counts, codes and truncated opaque IDs. Readings never enter a log line (guide §4.2).")
    static func event(_ name: StaticString, reading: MappedReading) {}

    @available(*, unavailable, message: "Log takes counts, codes and truncated opaque IDs. Readings never enter a log line (guide §4.2).")
    static func event(_ name: StaticString, reading: QueuedReading) {}

    @available(*, unavailable, message: "Log takes counts, codes and truncated opaque IDs. A quantity is a value (guide §4.2).")
    static func event(_ name: StaticString, quantity: HKQuantity) {}

    @available(*, unavailable, message: "Log takes counts, codes and truncated opaque IDs. A sample carries values (guide §4.2).")
    static func event(_ name: StaticString, sample: HKSample) {}

    @available(*, unavailable, message: "Counts are Int. A Double here is a value (guide §4.2).")
    static func event(_ name: StaticString, count: Double) {}

    // MARK: - Opaque-ID truncation

    /// The only shape in which an identifier is ever recorded: first 8 characters.
    /// Evidence carries UUID prefixes, counts and error codes — never values (§4.2, §11).
    static func prefix8(_ id: String) -> String { String(id.prefix(8)) }
}

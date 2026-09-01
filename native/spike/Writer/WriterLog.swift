import Foundation
import HealthKit
import os

/// The writer's own copy of the §4.2 log wrapper. Deliberately not shared with the reader
/// targets: the writer is the one binary allowed to write, and keeping its sources separate
/// is what makes "the readers contain no write path" a structural fact rather than a claim.
///
/// Same rule, same enforcement: counts, error codes and truncated opaque IDs only, and the
/// value-carrying overloads are `unavailable` so a slip is a compile error.
enum Log {
    private static let logger = Logger(subsystem: "dev.lucab.bpwriter", category: "writer")
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
        ring.append("\(stamp()) \(line)")
        if ring.count > ringLimit { ring.removeFirst(ring.count - ringLimit) }
        lock.unlock()
    }

    static func lines() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return ring
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func stamp() -> String { stampFormatter.string(from: Date()) }

    static func prefix8(_ id: String) -> String { String(id.prefix(8)) }

    @available(*, unavailable, message: "Log takes counts, codes and truncated opaque IDs. A quantity is a value (guide 4.2).")
    static func event(_ name: StaticString, quantity: HKQuantity) {}

    @available(*, unavailable, message: "Log takes counts, codes and truncated opaque IDs. A sample carries values (guide 4.2).")
    static func event(_ name: StaticString, sample: HKSample) {}

    @available(*, unavailable, message: "Counts are Int. A Double here is a value (guide 4.2).")
    static func event(_ name: StaticString, count: Double) {}

    @available(*, unavailable, message: "Synthetic or not, magnitudes do not enter a log line (guide 4.2).")
    static func event(_ name: StaticString, pair: SyntheticPair) {}
}

import Foundation

/// Guide §10 — the one logical state document. Two alternating checksummed generation
/// files on disk; this is what they contain.
///
/// Nothing in this file interprets a reading. `systolic`/`diastolic` are carried as
/// recorded, with no rounding, no derived field, no category, no flag (§4.1).

struct ArmResult: Codable, Equatable {
    var ok: Bool
    var at: Date
    var errorCode: String?

    static func ok(_ at: Date) -> ArmResult { ArmResult(ok: true, at: at, errorCode: nil) }
    static func failed(_ at: Date, code: String) -> ArmResult {
        ArmResult(ok: false, at: at, errorCode: code)
    }
}

/// Mapper output: structurally valid, not yet durable. `itemId`/`receivedAt` are NOT set
/// here — `StateStore.commit` assigns both exactly once at first enqueue (§12 P1).
struct MappedReading: Equatable {
    let hkUuid: String
    let systolic: Double
    let diastolic: Double
    let takenAt: Date
    let tzOffsetMinutes: Int?
    let sourceBundleId: String
    let sourceName: String
    let deviceModel: String?
}

/// One durably committed reading. Field-for-field the `BPReading` of §7.1.
struct QueuedReading: Codable, Equatable {
    let itemId: String            // native queue identity — the ACK key (ULID)
    let hkUuid: String            // HealthKit CORRELATION UUID — backend idempotency key
    let enrolmentRef: String      // binding stamped at commit (§6.1)
    let systolic: Double          // mmHg, as recorded; no rounding, no evaluation
    let diastolic: Double         // mmHg
    let takenAt: Date
    let tzOffsetMinutes: Int?     // ONLY from HKMetadataKeyTimeZone; null when absent
    let sourceBundleId: String
    let sourceName: String
    let deviceModel: String?
    let receivedAt: Date          // set ONCE at first durable commit; persisted
}

/// §6.3 `holdForReauth`: pending items parked under the previous enrolmentRef. Survives
/// reset and any subsequent `configure()`.
struct HeldBucket: Codable, Equatable {
    let enrolmentRef: String
    var items: [QueuedReading]
}

/// Counts and identifiers, NEVER values (§4.1, §7.3).
struct Diagnostics: Codable, Equatable {
    var armedAt: Date?
    var lastWakeAt: Date?
    var lastErrorCode: String?
    var malformedBySource: [String: Int] = [:]
    var generationFallbacks: Int = 0
    var anchorResets: Int = 0
    var consecutiveQueryFailures: Int = 0
    var lastQueryFailureCode: String?
}

struct EngineConfig: Equatable {
    let enrolmentRef: String
    let importStart: Date
}

struct EngineState: Codable, Equatable {
    static let currentSchemaVersion = 3

    var schemaVersion = EngineState.currentSchemaVersion
    var enrolmentRef: String?
    var importStart: Date?
    var desiredObservationEnabled = false
    var lastArm: ArmResult?
    var bootstrapComplete = false          // §5.3 bootstrap rule
    var anchorData: Data?                  // HKQueryAnchor via NSKeyedArchiver(secure)
    var anchorResetReason: String?         // last recovery reason code, if any
    var queue: [QueuedReading] = []
    var held: [HeldBucket] = []
    var recentUuids: [String] = []         // bounded ring; convenience only
    var snapshotSeq: UInt64 = 0            // generation: bumped by EVERY queue/held mutation
    var diagnostics = Diagnostics()

    // MARK: - Derived

    var config: EngineConfig? {
        guard let enrolmentRef, let importStart else { return nil }
        return EngineConfig(enrolmentRef: enrolmentRef, importStart: importStart)
    }

    /// Generation token. Pure reads never bump it; every queue/held mutation does (B2).
    var snapshotToken: String { "gen-\(snapshotSeq)" }

    var heldCount: Int { held.reduce(0) { $0 + $1.items.count } }

    // MARK: - Mutations (all called from inside StateStore.commit, i.e. on the executor)

    private static let recentUuidRingLimit = 512

    /// Assigns `itemId` and `receivedAt` exactly once, here and nowhere else (§12 P1).
    mutating func enqueue(_ readings: [MappedReading], enrolmentRef: String, now: Date = Date()) {
        for r in readings {
            queue.append(QueuedReading(
                itemId: ULID.generate(now: now),
                hkUuid: r.hkUuid,
                enrolmentRef: enrolmentRef,
                systolic: r.systolic,
                diastolic: r.diastolic,
                takenAt: r.takenAt,
                tzOffsetMinutes: r.tzOffsetMinutes,
                sourceBundleId: r.sourceBundleId,
                sourceName: r.sourceName,
                deviceModel: r.deviceModel,
                receivedAt: now))
            recentUuids.append(r.hkUuid)
        }
        if recentUuids.count > Self.recentUuidRingLimit {
            recentUuids.removeFirst(recentUuids.count - Self.recentUuidRingLimit)
        }
    }

    mutating func mergeMalformedCounts(_ counts: [String: Int]) {
        for (source, n) in counts {
            diagnostics.malformedBySource[source, default: 0] += n
        }
    }

    /// Resolves each itemId in the active queue OR any held bucket, by ULID (§12 P2).
    mutating func removeEverywhere(_ itemIds: [String]) -> (removed: Int, alreadyAbsent: Int) {
        let wanted = Set(itemIds)
        var removed = 0
        let before = queue.count
        queue.removeAll { wanted.contains($0.itemId) }
        removed += before - queue.count
        for i in held.indices {
            let b = held[i].items.count
            held[i].items.removeAll { wanted.contains($0.itemId) }
            removed += b - held[i].items.count
        }
        held.removeAll { $0.items.isEmpty }
        return (removed, wanted.count - removed)
    }
}

/// What actually hits disk (§10).
struct Envelope: Codable {
    let commitSeq: UInt64      // strictly monotonic
    let sha256: String         // of the canonical encoding of `state`
    let state: EngineState
}

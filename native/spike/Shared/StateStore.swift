import CryptoKit
import Foundation

/// Guide §10 — two-generation atomic store. Used ONLY from the engine executor.
///
/// Files: `Application Support/BPEngine/state.a.json` and `state.b.json` (alternating).
///
/// COMMIT: encode -> checksum -> atomic write to the OLDER generation with
///   `.completeFileProtectionUntilFirstUserAuthentication` -> re-assert directory backup
///   exclusion -> swap in memory.
/// LOAD (strict, ship-gate 13): decode both files; verify checksum + schemaVersion
///   migration; adopt the highest valid `commitSeq`; if only one is valid, adopt it and log
///   a generation-fallback diagnostic; if files exist but NEITHER is valid -> surface
///   `INTERNAL` and stop — NEVER silently initialise empty state over existing files.
final class StateStore {

    enum Slot: String, CaseIterable {
        case a = "state.a.json"
        case b = "state.b.json"
        var other: Slot { self == .a ? .b : .a }
    }

    struct GenerationReport {
        let slot: Slot
        let exists: Bool
        let bytes: Int
        let commitSeq: UInt64?
        let valid: Bool
        let reason: String?
    }

    private(set) var current = EngineState()
    private(set) var commitSeq: UInt64 = 0
    private(set) var activeSlot: Slot?
    private(set) var lastLoadNote: String?
    private var loaded = false

    let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BPEngine", isDirectory: true)
    }

    // MARK: - Load

    @discardableResult
    func loadStrict() throws -> EngineState {
        try prepareDirectory()

        var candidates: [(slot: Slot, env: Envelope)] = []
        var present = 0
        var rejections: [String] = []

        for slot in Slot.allCases {
            let url = directory.appendingPathComponent(slot.rawValue)
            guard let data = try? Data(contentsOf: url) else { continue }
            present += 1
            do {
                let env = try Self.decoder().decode(Envelope.self, from: data)
                guard env.state.schemaVersion <= EngineState.currentSchemaVersion else {
                    rejections.append("\(slot.rawValue):SCHEMA_AHEAD"); continue
                }
                let recomputed = try Self.sha256Hex(Self.encoder().encode(env.state))
                guard recomputed == env.sha256 else {
                    rejections.append("\(slot.rawValue):CHECKSUM"); continue
                }
                candidates.append((slot, env))
            } catch {
                rejections.append("\(slot.rawValue):DECODE")
            }
        }

        if present == 0 {
            // Legitimate first run: no files exist. This is the ONLY path that starts empty.
            current = EngineState()
            commitSeq = 0
            activeSlot = nil
            loaded = true
            lastLoadNote = "fresh"
            Log.event("store.load.fresh")
            return current
        }

        guard let winner = candidates.max(by: { $0.env.commitSeq < $1.env.commitSeq }) else {
            // Files exist and none is valid. Hard INTERNAL — never silent re-init (§10, M17).
            let reason = rejections.joined(separator: ",")
            Log.event("store.load.allGenerationsInvalid", count: present, code: reason)
            throw BPError.internalFault("BOTH_GENERATIONS_INVALID:\(reason)")
        }

        current = try migrate(winner.env.state)
        commitSeq = winner.env.commitSeq
        activeSlot = winner.slot
        loaded = true

        if present == 2 && candidates.count == 1 {
            // M17: newest generation undecodable -> previous valid generation loads.
            current.diagnostics.generationFallbacks += 1
            lastLoadNote = "generationFallback"
            Log.event("store.load.generationFallback", count: 1, code: rejections.joined(separator: ","))
        } else {
            lastLoadNote = "ok:\(winner.slot.rawValue)"
            Log.event("store.load.ok", count: current.queue.count, code: winner.slot.rawValue)
        }
        return current
    }

    private func migrate(_ state: EngineState) throws -> EngineState {
        // schemaVersion 3 is the initial shape (§10). Older versions do not exist in the
        // field; a future migration lands here and M15 covers it.
        guard state.schemaVersion == EngineState.currentSchemaVersion else {
            throw BPError.internalFault("SCHEMA_UNSUPPORTED:\(state.schemaVersion)")
        }
        return state
    }

    // MARK: - Commit

    @discardableResult
    func commit<T>(_ mutate: (inout EngineState) throws -> T) throws -> T {
        guard loaded else { throw BPError.internalFault("STORE_NOT_LOADED") }
        var next = current
        let result = try mutate(&next)

        let payload: Data
        let envelopeBytes: Data
        do {
            payload = try Self.encoder().encode(next)
            let env = Envelope(commitSeq: commitSeq + 1,
                               sha256: Self.sha256Hex(payload),
                               state: next)
            envelopeBytes = try Self.encoder().encode(env)
        } catch {
            throw BPError.internalFault("ENCODE_FAILED")
        }

        let target = activeSlot?.other ?? .a
        do {
            try envelopeBytes.write(
                to: directory.appendingPathComponent(target.rawValue),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // M6: protected-write failure. Nothing swapped in memory, anchor unmoved.
            Log.event("store.commit.writeFailed", code: target.rawValue)
            throw BPError.internalFault("WRITE_FAILED")
        }

        // §10: the resource value lives on filesystem items and must survive replacement
        // [R26] — re-assert on the containing directory after every commit.
        assertBackupExclusion()

        current = next
        commitSeq += 1
        activeSlot = target
        return result
    }

    // MARK: - Directory posture

    private func prepareDirectory() throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }
        assertBackupExclusion()
    }

    /// Idempotent; reads the current resource value first so the diagnostic is honest.
    @discardableResult
    func assertBackupExclusion() -> Bool {
        var url = directory
        let excluded = (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]))?
            .isExcludedFromBackup ?? false
        if excluded { return true }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
            return true
        } catch {
            Log.event("store.backupExclusion.failed")
            return false
        }
    }

    // MARK: - Inspection (counts, codes and slot names only — never values)

    func generationReport() -> [GenerationReport] {
        Slot.allCases.map { slot in
            let url = directory.appendingPathComponent(slot.rawValue)
            guard let data = try? Data(contentsOf: url) else {
                return GenerationReport(slot: slot, exists: false, bytes: 0,
                                        commitSeq: nil, valid: false, reason: "absent")
            }
            do {
                let env = try Self.decoder().decode(Envelope.self, from: data)
                let recomputed = try Self.sha256Hex(Self.encoder().encode(env.state))
                let ok = recomputed == env.sha256
                return GenerationReport(slot: slot, exists: true, bytes: data.count,
                                        commitSeq: env.commitSeq, valid: ok,
                                        reason: ok ? nil : "CHECKSUM")
            } catch {
                return GenerationReport(slot: slot, exists: true, bytes: data.count,
                                        commitSeq: nil, valid: false, reason: "DECODE")
            }
        }
    }

    // MARK: - SPK-4 fault injection (spike targets only)

    enum Injection: String {
        case corruptAnchorData       // trigger (c) for the §5.3 anchor-only reset
        case corruptNewestGeneration // M17
        case corruptBothGenerations  // hard INTERNAL
    }

    func inject(_ injection: Injection) throws {
        switch injection {
        case .corruptAnchorData:
            try commit { $0.anchorData = Data("not-a-keyed-archive".utf8) }
            Log.event("spk4.inject.corruptAnchorData")
        case .corruptNewestGeneration:
            guard let slot = activeSlot else { throw BPError.internalFault("NO_GENERATION") }
            try scribble(slot)
            Log.event("spk4.inject.corruptNewestGeneration", code: slot.rawValue)
        case .corruptBothGenerations:
            for slot in Slot.allCases where FileManager.default
                .fileExists(atPath: directory.appendingPathComponent(slot.rawValue).path) {
                try scribble(slot)
            }
            Log.event("spk4.inject.corruptBothGenerations")
        }
    }

    private func scribble(_ slot: Slot) throws {
        let url = directory.appendingPathComponent(slot.rawValue)
        guard var data = try? Data(contentsOf: url), data.count > 8 else {
            throw BPError.internalFault("NO_GENERATION")
        }
        // Flip bytes in the middle so the file stays plausible and fails the checksum.
        for i in (data.count / 2)..<min(data.count / 2 + 8, data.count) { data[i] = 0x5A }
        try data.write(to: url, options: [.atomic])
    }

    /// Spike-only recovery after `corruptBothGenerations`. The product has no such path:
    /// §10 requires a hard `INTERNAL` and never a silent re-init.
    func destroyStoreForSpikeRecovery() {
        for slot in Slot.allCases {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(slot.rawValue))
        }
        current = EngineState(); commitSeq = 0; activeSlot = nil; loaded = false
        Log.event("spk4.storeDestroyed.spikeOnly")
    }

    // MARK: - Canonical coding

    /// Deterministic by construction: sorted keys, fixed date shape, base64 data. The
    /// checksum is computed over `encoder().encode(state)` and verified on load by
    /// re-encoding the decoded state with the same configuration.
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dataEncodingStrategy = .base64
        e.nonConformingFloatEncodingStrategy = .throw
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(isoFormatter.string(from: date))
        }
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dataDecodingStrategy = .base64
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            guard let date = isoFormatter.date(from: s) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "date")
            }
            return date
        }
        return d
    }

    /// Millisecond ISO-8601 in UTC. Encoding is idempotent after the first round trip,
    /// which is what makes the checksum reproducible.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

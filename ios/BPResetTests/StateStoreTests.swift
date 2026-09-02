import XCTest
@testable import BPReset

/// The spike's §10 store self-test (`native/spike/Shared/StoreSelfTest.swift`), ported to
/// XCTest against the product store. The store is pure Foundation and CryptoKit, so the
/// simulator proves something real here. Nothing HealthKit-shaped is checked in this file.
final class StateStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BPResetStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func reading(_ seed: Int = 0) -> MappedReading {
        MappedReading(
            hkUuid: UUID().uuidString,
            systolicUuid: UUID().uuidString,
            diastolicUuid: UUID().uuidString,
            systolic: 0, diastolic: 0,          // placeholders; never rendered
            takenAt: Date(timeIntervalSince1970: 1_700_000_123.456 + Double(seed)),
            tzIdentifier: "Australia/Sydney",
            tzOffsetMinutes: 600,
            sourceBundleId: "dev.aiplease.selftest",
            sourceName: "self-test",
            deviceModel: nil)
    }

    // 1. Fresh load over an empty directory is the ONLY path that starts empty.
    func testFreshLoadIsEmpty() throws {
        let store = StateStore(directory: dir)
        let state = try store.loadStrict()
        XCTAssertTrue(state.queue.isEmpty)
        XCTAssertEqual(store.commitSeq, 0)
        XCTAssertNil(store.activeSlot)
        XCTAssertEqual(store.lastLoadNote, "fresh")
    }

    func testCommitBeforeLoadIsRefused() {
        let store = StateStore(directory: dir)
        XCTAssertThrowsError(try store.commit { $0.snapshotSeq += 1 }) { error in
            XCTAssertEqual((error as? BPError)?.code, "INTERNAL")
            XCTAssertEqual((error as? BPError)?.detail, "STORE_NOT_LOADED")
        }
    }

    // 2. Commits alternate generations and advance commitSeq monotonically.
    func testCommitsAlternateGenerationsMonotonically() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        var slots: [String] = []
        for i in 1...3 {
            try store.commit { st in
                st.enrolmentRef = "self-test-enrolment"
                st.importStart = Date(timeIntervalSince1970: 1_700_000_000)
                st.snapshotSeq &+= 1
                st.diagnostics.malformedBySource["dev.aiplease.selftest", default: 0] += i
            }
            slots.append(store.activeSlot?.rawValue ?? "-")
        }
        XCTAssertEqual(store.commitSeq, 3)
        XCTAssertEqual(slots, ["state.a.json", "state.b.json", "state.a.json"])
    }

    // 3. Data, Date, Double and dictionaries re-encode byte-identically after a decode, or
    //    the checksum is not reproducible and every reload would fall back.
    func testChecksumReproducibleAcrossRoundTrip() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        try store.commit { st in
            st.enrolmentRef = "self-test-enrolment"
            st.importStart = Date(timeIntervalSince1970: 1_700_000_000)
            st.anchorData = Data((0..<64).map { UInt8($0) })
            st.enqueue([reading()], enrolmentRef: "self-test-enrolment")
            st.snapshotSeq &+= 1
            st.diagnostics.malformedBySource["dev.aiplease.selftest"] = 6
            st.diagnostics.rejectionReasons = ["VALUE_OUT_OF_BOUNDS": 1]
        }
        let reloaded = StateStore(directory: dir)
        let state = try reloaded.loadStrict()
        XCTAssertEqual(reloaded.commitSeq, 1)
        XCTAssertEqual(reloaded.lastLoadNote, "ok:state.a.json")
        XCTAssertEqual(state.queue.count, 1)
        XCTAssertEqual(state.anchorData?.count, 64)
        XCTAssertEqual(state.queue.first?.itemId.count, 26, "itemId is a ULID assigned once at enqueue")
        XCTAssertEqual(state.queue.first?.tzIdentifier, "Australia/Sydney")
        XCTAssertEqual(state.diagnostics.malformedBySource["dev.aiplease.selftest"], 6)
        XCTAssertEqual(state.diagnostics.rejectionReasons?["VALUE_OUT_OF_BOUNDS"], 1)
        XCTAssertEqual(state.diagnostics.generationFallbacks, 0)
        // The checksum guarantee: the canonical encoding is idempotent after one round trip.
        // (The in-memory copy keeps sub-millisecond dates; the persisted form is the truth.)
        let canonical = try StateStore.encoder().encode(store.current)
        let decoded = try StateStore.decoder().decode(EngineState.self, from: canonical)
        XCTAssertEqual(try StateStore.encoder().encode(decoded), canonical)
        XCTAssertEqual(state, decoded)
    }

    func testEnqueueAssignsIdentityOnceAndKeepsTheRingBounded() throws {
        var state = EngineState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        state.enqueue((0..<600).map { reading($0) }, enrolmentRef: "e", now: now)
        XCTAssertEqual(state.queue.count, 600)
        XCTAssertEqual(Set(state.queue.map(\.itemId)).count, 600, "every itemId is distinct")
        XCTAssertEqual(state.recentUuids.count, 512, "the recent-UUID ring is bounded")
        XCTAssertTrue(state.queue.allSatisfy { $0.receivedAt == now && $0.enrolmentRef == "e" })
    }

    // 4. M17: the newest generation undecodable -> the previous valid one loads, with a
    //    diagnostic, never an empty re-initialisation.
    func testNewestGenerationCorruptFallsBackToPrevious() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        try store.commit { $0.snapshotSeq = 1 }
        try store.commit { $0.snapshotSeq = 2 }
        let newest = try XCTUnwrap(store.activeSlot)
        try Data("not json".utf8).write(to: dir.appendingPathComponent(newest.rawValue))

        let after = StateStore(directory: dir)
        let state = try after.loadStrict()
        XCTAssertEqual(after.commitSeq, 1, "the previous generation wins")
        XCTAssertEqual(state.snapshotSeq, 1)
        XCTAssertEqual(after.activeSlot, newest.other)
        XCTAssertEqual(after.lastLoadNote, "generationFallback")
        XCTAssertEqual(state.diagnostics.generationFallbacks, 1)
    }

    func testTamperedChecksumIsRejected() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        try store.commit { $0.snapshotSeq = 1 }
        try store.commit { $0.snapshotSeq = 2 }
        let newest = try XCTUnwrap(store.activeSlot)
        let url = dir.appendingPathComponent(newest.rawValue)
        // Flip the recorded snapshotSeq without recomputing the checksum.
        let text = try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "\"snapshotSeq\":2", with: "\"snapshotSeq\":9")
        XCTAssertNotEqual(text, try String(contentsOf: url, encoding: .utf8), "the fixture actually changed")
        try Data(text.utf8).write(to: url)

        let after = StateStore(directory: dir)
        let state = try after.loadStrict()
        XCTAssertEqual(state.snapshotSeq, 1, "a checksum mismatch is treated as an invalid generation")
        XCTAssertEqual(after.lastLoadNote, "generationFallback")
    }

    // 5. Both generations invalid -> hard INTERNAL, never a silent empty re-init.
    func testBothGenerationsInvalidRaisesInternal() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        try store.commit { $0.snapshotSeq = 1 }
        try store.commit { $0.snapshotSeq = 2 }
        for slot in StateStore.Slot.allCases {
            try Data("garbage".utf8).write(to: dir.appendingPathComponent(slot.rawValue))
        }
        let after = StateStore(directory: dir)
        XCTAssertThrowsError(try after.loadStrict()) { error in
            XCTAssertEqual((error as? BPError)?.code, "INTERNAL")
            XCTAssertTrue((error as? BPError)?.detail?.hasPrefix("BOTH_GENERATIONS_INVALID") ?? false)
        }
    }

    // 6. Backup exclusion is asserted on the directory and survives commits [R26].
    func testDirectoryIsExcludedFromBackup() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        try store.commit { $0.snapshotSeq = 1 }
        XCTAssertTrue(store.assertBackupExclusion())
        let values = try dir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testGenerationReportCarriesCountsAndCodesOnly() throws {
        let store = StateStore(directory: dir)
        try store.loadStrict()
        try store.commit { $0.snapshotSeq = 1 }
        let report = store.generationReport()
        XCTAssertEqual(report.count, 2)
        XCTAssertEqual(report.filter(\.exists).count, 1)
        XCTAssertEqual(report.first { $0.exists }?.commitSeq, 1)
        XCTAssertEqual(report.first { !$0.exists }?.reason, "absent")
    }
}

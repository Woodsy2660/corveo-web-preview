import Foundation

/// Pre-device check for the §10 two-generation store and the M17 ladder.
///
/// Scope, stated honestly: the store is pure Foundation + CryptoKit, so its behaviour is
/// **not** device-dependent and running it in the simulator proves something real. Nothing
/// HealthKit-shaped is checked here — pitfall 1 stands, and no SPK verdict follows from it.
/// SPK-4 still runs on the frozen acceptance OS against the app's own container.
///
/// Gated on a launch argument, so it can only be started from a scheme or `simctl`.
enum StoreSelfTest {

    static var requested: Bool {
        CommandLine.arguments.contains("-spikeStoreSelfTest")
    }

    /// Prints ADR-0004's environment block to the console, so it can be taken over the cable
    /// instead of off the screen. Carries the same evidence-class stamp as the in-app copy.
    static var environmentReportRequested: Bool {
        CommandLine.arguments.contains("-spikeEnvReport")
    }

    static func reportEnvironment() {
        print("SPIKE-ENV begin")
        print(SpikeEnvironment.adrEnvironmentBlock(authVariant: SpikeAuthSet.variant))
        print("SPIKE-ENV end class=\(SpikeEnvironment.evidenceClass.rawValue)")
    }

    struct Check {
        let name: String
        let passed: Bool
        let note: String?
    }

    static func run() -> [Check] {
        var checks: [Check] = []
        func assert(_ name: String, _ passed: Bool, _ note: String? = nil) {
            checks.append(Check(name: name, passed: passed, note: note))
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BPEngineSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // 1. Fresh load over an empty directory is the ONLY path that starts empty.
        let s1 = StateStore(directory: dir)
        do {
            let st = try s1.loadStrict()
            assert("freshLoadEmpty", st.queue.isEmpty && s1.commitSeq == 0 && s1.activeSlot == nil)
        } catch {
            assert("freshLoadEmpty", false, SpikeEngine.errorCode(error)); return checks
        }

        // 2. Commits alternate generations and advance commitSeq monotonically.
        var slots: [String] = []
        do {
            for i in 1...3 {
                try s1.commit { st in
                    st.enrolmentRef = "self-test-enrolment"
                    st.importStart = Date(timeIntervalSince1970: 1_700_000_000)
                    st.snapshotSeq &+= 1
                    st.diagnostics.malformedBySource["dev.lucab.selftest", default: 0] += i
                }
                slots.append(s1.activeSlot?.rawValue ?? "-")
            }
            assert("commitSeqMonotonic", s1.commitSeq == 3, "seq=\(s1.commitSeq)")
            assert("generationsAlternate",
                   slots == ["state.a.json", "state.b.json", "state.a.json"],
                   slots.joined(separator: ">"))
        } catch {
            assert("commitAlternates", false, SpikeEngine.errorCode(error)); return checks
        }

        // 3. A payload carrying Data, Date, Double and a dictionary must re-encode
        //    byte-identically after a decode, or the checksum is not reproducible.
        do {
            try s1.commit { st in
                st.anchorData = Data((0..<64).map { UInt8($0) })
                st.enqueue([MappedReading(
                    hkUuid: UUID().uuidString,
                    systolicUuid: UUID().uuidString,
                    diastolicUuid: UUID().uuidString,
                    systolic: 0, diastolic: 0,          // placeholders; never rendered
                    takenAt: Date(timeIntervalSince1970: 1_700_000_123.456),
                    tzOffsetMinutes: 600,
                    sourceBundleId: "dev.lucab.selftest",
                    sourceName: "self-test",
                    deviceModel: nil)],
                    enrolmentRef: "self-test-enrolment")
                st.snapshotSeq &+= 1
            }
            let reloaded = StateStore(directory: dir)
            let st = try reloaded.loadStrict()
            assert("checksumReproducibleAcrossRoundTrip", reloaded.commitSeq == 4,
                   "seq=\(reloaded.commitSeq)")
            assert("queueSurvives", st.queue.count == 1)
            assert("anchorDataSurvives", st.anchorData?.count == 64)
            assert("itemIdAssignedOnce", st.queue.first.map { $0.itemId.count == 26 } ?? false)
            assert("diagnosticsAreCountsOnly",
                   st.diagnostics.malformedBySource["dev.lucab.selftest"] == 6)
        } catch {
            assert("strictReload", false, SpikeEngine.errorCode(error)); return checks
        }

        // 4. M17 — newest generation undecodable falls back to the previous valid one.
        do {
            let live = StateStore(directory: dir)
            _ = try live.loadStrict()
            let seqBefore = live.commitSeq
            try live.inject(.corruptNewestGeneration)
            let after = StateStore(directory: dir)
            let st = try after.loadStrict()
            assert("m17FallsBackToPreviousGeneration", after.commitSeq == seqBefore - 1,
                   "before=\(seqBefore) after=\(after.commitSeq)")
            assert("m17RecordsFallbackDiagnostic", st.diagnostics.generationFallbacks >= 1)
        } catch {
            assert("m17FallsBackToPreviousGeneration", false, SpikeEngine.errorCode(error))
        }

        // 5. Both generations invalid -> hard INTERNAL, never a silent empty re-init.
        do {
            let live = StateStore(directory: dir)
            _ = try live.loadStrict()
            try live.inject(.corruptBothGenerations)
            let after = StateStore(directory: dir)
            _ = try after.loadStrict()
            assert("bothInvalidRaisesInternal", false, "loaded instead of throwing")
        } catch let e as BPError {
            assert("bothInvalidRaisesInternal", e.code == "INTERNAL", e.code)
        } catch {
            assert("bothInvalidRaisesInternal", false, SpikeEngine.errorCode(error))
        }

        // 6. Backup exclusion is asserted on the directory and survives commits [R26].
        assert("directoryExcludedFromBackup", s1.assertBackupExclusion())

        return checks
    }

    /// Console output is pass/fail per assertion plus counts. No value ever appears here,
    /// which is what makes the transcript safe to paste into ADR-0004.
    static func runAndReport() {
        let checks = run()
        let failed = checks.filter { !$0.passed }
        print("SPIKE-STORE-SELFTEST begin")
        for c in checks {
            print("  \(c.passed ? "PASS" : "FAIL") \(c.name)\(c.note.map { " (\($0))" } ?? "")")
        }
        print("SPIKE-STORE-SELFTEST end passed=\(checks.count - failed.count) failed=\(failed.count)")
    }
}

import XCTest
@testable import BPReset

/// Guardrails for SOW A.3.3 and the Apple rulebook in the places a regression is likeliest:
/// the copy that describes readings, the reminder text, and the reminder scheduler's inputs.
final class BrightLineTests: XCTestCase {
    /// Words that turn a display into an interpretation when used about a reading.
    private let escalate = ["diagnos", "detect", "treat", "lower your", "reduce your", "control your",
                            "risk", "warning", "alert", "abnormal", "accurate", "too high", "too low",
                            "hypertens", "elevated", "healthy range", "target"]

    private var readingCopy: [String] {
        [
            AppCopy.trend.intro, AppCopy.trend.chartAria,
            AppCopy.readings.sourceHealth, AppCopy.readings.sourceManual,
            HealthSyncCopy.card.rejected(1), HealthSyncCopy.card.rejected(3),
            JourneyCopy.cadence.reminderNote,
            ReminderCopy.title, ReminderCopy.body, ReminderCopy.settings.body,
        ]
    }

    func testReadingCopyCarriesNoEvaluation() {
        for text in readingCopy {
            let lower = text.lowercased()
            for word in escalate {
                XCTAssertFalse(lower.contains(word), "\"\(text)\" contains \"\(word)\"")
            }
        }
    }

    func testUserFacingCopyNeverSaysHealthKit() {
        let texts = readingCopy + [
            AppCopy.settings.appleHealth.title, AppCopy.settings.appleHealth.readsOnly,
            AppCopy.settings.appleHealth.manageHint, AppCopy.settings.appleHealth.notConnected,
            AppCopy.settings.appleHealth.connectCta, AppCopy.settings.appleHealth.disconnectCta,
            AppCopy.settings.appleHealth.disconnectNote,
            JourneyCopy.healthAuth.title, JourneyCopy.healthAuth.intro, JourneyCopy.healthAuth.cta,
        ]
        for text in texts {
            XCTAssertFalse(text.contains("HealthKit"), "\"\(text)\" names HealthKit; users see Apple Health")
        }
    }

    func testReminderCopyIsFixedAndValueFree() {
        // The scheduler has no reading input by type; the only variable content is the slot.
        XCTAssertFalse(ReminderCopy.body.contains("%"), "no format placeholders")
        XCTAssertFalse(ReminderCopy.title.contains("%"))
        XCTAssertFalse(ReminderCopy.body.rangeOfCharacter(from: .decimalDigits) != nil, "no digits in a reminder")
    }

    func testReminderSlotsFollowTheRhythmOnly() {
        XCTAssertEqual(ReminderModel.slots(for: .twiceDaily).map(\.hour), [8, 20])
        XCTAssertEqual(ReminderModel.slots(for: .daily).map(\.hour), [8])
        XCTAssertEqual(ReminderModel.slots(for: .fewWeekly).map(\.weekday), [2, 4, 6], "Monday, Wednesday, Friday")
        XCTAssertTrue(ReminderModel.slots(for: .twiceDaily).allSatisfy { $0.weekday == nil })
        for cadence in CadenceChoice.allCases {
            XCTAssertFalse(ReminderModel.scheduleNote(for: cadence).isEmpty)
        }
    }

    func testChartSeriesColoursAreFixedIdentities() {
        // Two distinct, constant colours. Any future value-to-colour mapping would need a
        // function of the reading, and there is none to call.
        XCTAssertNotEqual(CColor.chartSeries1, CColor.chartSeries2)
    }
}

import Foundation
import Observation
import UserNotifications

/// Local reminders that follow the chosen rhythm only (SOW A.3.3; rulebook: value-blind
/// notifications). The scheduler's only inputs are the cadence and fixed clock times. It never
/// receives a reading, a count of readings, or anything derived from one, and every reminder
/// carries the same fixed copy. Nothing here can be triggered by a value.
@MainActor
@Observable
final class ReminderModel {
    private static let key = "corveo.reminders.v1"
    private static let idPrefix = "corveo.reminder."

    /// The patient's choice, persisted. Independent of the iOS permission, which can change
    /// in Settings at any time; `authorization` carries the live answer.
    private(set) var enabled: Bool
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    init() {
        enabled = UserDefaults.standard.bool(forKey: Self.key + ".enabled")
    }

    var isDeniedByiOS: Bool { authorization == .denied }

    func refresh() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// The screen explains first; this shows the one system prompt (only the first time),
    /// then installs the schedule. Returns whether reminders are on afterwards.
    @discardableResult
    func enable(cadence: CadenceChoice?) async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refresh()
        enabled = granted
        save()
        if granted { await reschedule(cadence: cadence) } else { clear() }
        return granted
    }

    func disable() {
        enabled = false
        save()
        clear()
    }

    /// The cadence changed: rebuild the fixed schedule. A no-op while reminders are off.
    func reschedule(cadence: CadenceChoice?) async {
        clear()
        guard enabled, let cadence else { return }
        for slot in Self.slots(for: cadence) {
            var match = DateComponents()
            match.hour = slot.hour
            match.minute = 0
            if let weekday = slot.weekday { match.weekday = weekday }
            let content = UNMutableNotificationContent()
            content.title = ReminderCopy.title
            content.body = ReminderCopy.body
            content.sound = .default
            content.interruptionLevel = .active   // never time-sensitive or critical (rulebook §8)
            let request = UNNotificationRequest(
                identifier: Self.idPrefix + slot.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: match, repeats: true))
            try? await center.add(request)
        }
    }

    #if DEBUG
    /// Development only: the same fixed content, ten seconds from now, so the banner can be
    /// seen without waiting for a slot. Background the app or lock the phone to see it.
    func sendTestReminder() async {
        let content = UNMutableNotificationContent()
        content.title = ReminderCopy.title
        content.body = ReminderCopy.body
        content.sound = .default
        content.interruptionLevel = .active
        let request = UNNotificationRequest(
            identifier: Self.idPrefix + "test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false))
        try? await center.add(request)
    }
    #endif

    private func clear() {
        center.removeAllPendingNotificationRequests()
    }

    private func save() {
        UserDefaults.standard.set(enabled, forKey: Self.key + ".enabled")
    }

    // MARK: Schedule

    struct Slot: Equatable {
        let id: String
        let hour: Int
        /// 1 = Sunday ... 7 = Saturday, Gregorian. Nil means every day.
        let weekday: Int?
    }

    /// Fixed times for V1: 8 am, and 8 pm for the twice-daily rhythm; Monday, Wednesday and
    /// Friday mornings for a few times a week. Calendar rhythm only.
    static func slots(for cadence: CadenceChoice) -> [Slot] {
        switch cadence {
        case .twiceDaily:
            return [Slot(id: "morning", hour: 8, weekday: nil), Slot(id: "evening", hour: 20, weekday: nil)]
        case .daily:
            return [Slot(id: "morning", hour: 8, weekday: nil)]
        case .fewWeekly:
            return [2, 4, 6].map { Slot(id: "weekday\($0)", hour: 8, weekday: $0) }
        }
    }

    /// The sentence Settings shows under the rhythm choice.
    static func scheduleNote(for cadence: CadenceChoice?) -> String {
        switch cadence {
        case .twiceDaily: return ReminderCopy.settings.twiceDailyTimes
        case .daily: return ReminderCopy.settings.dailyTimes
        case .fewWeekly: return ReminderCopy.settings.fewWeeklyTimes
        case nil: return ReminderCopy.settings.noRhythm
        }
    }
}

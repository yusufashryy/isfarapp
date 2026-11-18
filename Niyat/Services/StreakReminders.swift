import Foundation
import UserNotifications

/// Reminders that protect the prayer streak:
/// - "at risk": in the evening, when today isn't fully logged yet;
/// - "bring it back": the next morning, when yesterday broke the streak;
/// - "last chance": that evening, if it still hasn't been brought back.
/// Each is keyed by the day it's about and removed once that day is complete.
enum StreakReminders {
    /// Settings toggle (on unless turned off).
    static let enabledKey = "streak.reminders"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Hour the "bring it back" reminder arrives the morning after a break.
    static let morningHour = 9
    /// Evening reminders come at this hour, or 45 minutes after Isha if later.
    static let eveningHour = 21
    static let minutesAfterIsha = 45
    /// Never later than this, so there's still time left in the day.
    static let latestEvening = (hour: 23, minute: 15)

    struct Planned: Equatable {
        let id: String
        let date: Date
        let title: String
        let body: String
    }

    /// What to schedule, given the journal. Pure, so it can be tested.
    static func plan(now: Date, records: [String: PrayerRecord], calendar: Calendar = .current,
                     isha: (Date) -> Date?) -> [Planned] {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        let todayKey = PrayerLog.dayKey(for: today)
        var result: [Planned] = []

        if let recovery = StreakRules.recovery(asOf: now, records: records, calendar: calendar) {
            // Yesterday broke it: remind this morning and this evening.
            let key = PrayerLog.dayKey(for: recovery.day)
            let morning = time(on: today, hour: morningHour, calendar: calendar)
            if morning > now {
                result.append(Planned(id: "streak.restore.\(key)", date: morning,
                                      title: "Bring back your \(recovery.lostStreak)-day streak",
                                      body: restoreBody(recovery.prayers)))
            }
            let evening = eveningTime(on: today, calendar: calendar, isha: isha)
            if evening > now {
                result.append(Planned(id: "streak.lastchance.\(key)", date: evening,
                                      title: "Last chance for your \(recovery.lostStreak)-day streak",
                                      body: "Log yesterday's prayers once you've made them up, before midnight."))
            }
        }

        // Today isn't complete yet: a nudge tonight, and a rescue tomorrow
        // morning in case today ends unfinished.
        let streak = StreakRules.current(asOf: now, records: records, calendar: calendar)
        if streak >= StreakRules.minimumWorthKeeping, !StreakRules.isComplete(today, records: records) {
            let evening = eveningTime(on: today, calendar: calendar, isha: isha)
            if evening > now {
                result.append(Planned(id: "streak.risk.\(todayKey)", date: evening,
                                      title: "Your \(streak)-day streak is on the line",
                                      body: "Log today's prayers to make it \(streak + 1). Even a late prayer keeps it going."))
            }
            result.append(Planned(id: "streak.restore.\(todayKey)",
                                  date: time(on: tomorrow, hour: morningHour, calendar: calendar),
                                  title: "Bring back your \(streak)-day streak",
                                  body: "Yesterday wasn't fully logged. Make up what you missed and log it today to keep your streak."))
        }
        return result
    }

    static func requests(now: Date, records: [String: PrayerRecord],
                         isha: (Date) -> Date?) -> [(date: Date, request: UNNotificationRequest)] {
        guard isEnabled else { return [] }
        return plan(now: now, records: records, isha: isha).map { item in
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = "streak"
            content.userInfo = [NotificationScheduler.UserInfoKey.kind: "streak"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.date.fixedDateComponents(), repeats: false)
            return (item.date, UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    /// A day was completed: its streak reminders are no longer needed.
    static func dayCompleted(dayKey: String) {
        let identifiers = ["risk", "restore", "lastchance"].map { "streak.\($0).\(dayKey)" }
        // Off the main thread: this waits for iOS's notification service.
        DispatchQueue.global(qos: .utility).async {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    // MARK: Helpers

    private static func restoreBody(_ prayers: [PrayerName]) -> String {
        let names = ListFormatter.localizedString(byJoining: prayers.map(\.englishName))
        return "Make up \(names) as qada, or log what you prayed, today to keep your streak."
    }

    private static func time(on day: Date, hour: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    static func eveningTime(on day: Date, calendar: Calendar = .current, isha: (Date) -> Date?) -> Date {
        let standard = time(on: day, hour: eveningHour, calendar: calendar)
        let latest = calendar.date(bySettingHour: latestEvening.hour, minute: latestEvening.minute, second: 0, of: day) ?? standard
        guard let isha = isha(day) else { return standard }
        let afterIsha = isha.addingTimeInterval(TimeInterval(minutesAfterIsha * 60))
        return min(max(standard, afterIsha), latest)
    }
}

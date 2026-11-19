import Foundation

/// A streak that broke yesterday and can still be brought back today, by
/// making up (qada) and logging the prayers that were missed or not logged.
struct StreakRecovery: Equatable {
    /// The day that broke the streak (yesterday).
    let day: Date
    /// How long the streak was before that day.
    let lostStreak: Int
    /// Yesterday's prayers that are missed or not logged yet.
    let prayers: [PrayerName]
}

/// The prayer streak's rules, kept apart from the UI so they can be tested.
/// A day counts when all five prayers are logged and none is missed
/// (excused prayers keep the streak).
enum StreakRules {
    /// Streaks shorter than this aren't worth a reminder or a rescue.
    static let minimumWorthKeeping = 2
    /// Upper bound on how far back a streak is counted.
    private static let maxDays = 10_000

    static func isComplete(_ day: Date, records: [String: PrayerRecord]) -> Bool {
        PrayerName.obligatory.allSatisfy { records[PrayerLog.key($0, on: day)]?.status.keepsStreak ?? false }
    }

    /// Prayers on a day that don't keep the streak yet (missed or not logged).
    static func missingPrayers(on day: Date, records: [String: PrayerRecord]) -> [PrayerName] {
        PrayerName.obligatory.filter { !(records[PrayerLog.key($0, on: day)]?.status.keepsStreak ?? false) }
    }

    /// Consecutive complete days ending on `day`.
    static func streak(endingOn day: Date, records: [String: PrayerRecord], calendar: Calendar = .current) -> Int {
        var current = calendar.startOfDay(for: day)
        var count = 0
        while count < maxDays, isComplete(current, records: records) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return count
    }

    /// The streak as of `date`: today counts once it's complete, but an
    /// unfinished today doesn't break it.
    static func current(asOf date: Date, records: [String: PrayerRecord], calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        if isComplete(today, records: records) { return streak(endingOn: today, records: records, calendar: calendar) }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        return streak(endingOn: yesterday, records: records, calendar: calendar)
    }

    /// A streak that broke yesterday and is still worth bringing back today.
    static func recovery(asOf date: Date, records: [String: PrayerRecord],
                         calendar: Calendar = .current) -> StreakRecovery? {
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: yesterday),
              !isComplete(yesterday, records: records) else { return nil }
        let lost = streak(endingOn: dayBefore, records: records, calendar: calendar)
        let prayers = missingPrayers(on: yesterday, records: records)
        guard lost >= minimumWorthKeeping, !prayers.isEmpty else { return nil }
        return StreakRecovery(day: yesterday, lostStreak: lost, prayers: prayers)
    }
}

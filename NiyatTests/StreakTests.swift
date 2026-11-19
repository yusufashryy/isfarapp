import XCTest
@testable import Niyat

final class StreakTests: XCTestCase {
    private let calendar = Calendar.current
    /// Noon, so day arithmetic never crosses a DST edge awkwardly.
    private lazy var now: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))!

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    /// Logs all five prayers on time for each day offset.
    private func complete(_ offsets: [Int], into records: inout [String: PrayerRecord]) {
        for offset in offsets {
            for prayer in PrayerName.obligatory {
                records[PrayerLog.key(prayer, on: day(offset))] = PrayerRecord(status: .onTime)
            }
        }
    }

    // MARK: Counting

    func testUnfinishedTodayDoesNotBreakTheStreak() {
        var records: [String: PrayerRecord] = [:]
        complete([-3, -2, -1], into: &records)
        XCTAssertEqual(StreakRules.current(asOf: now, records: records), 3)
    }

    func testCompleteTodayCounts() {
        var records: [String: PrayerRecord] = [:]
        complete([-2, -1, 0], into: &records)
        XCTAssertEqual(StreakRules.current(asOf: now, records: records), 3)
    }

    func testExcusedKeepsTheStreakButMissedBreaksIt() {
        var records: [String: PrayerRecord] = [:]
        complete([-2, -1], into: &records)
        records[PrayerLog.key(.asr, on: day(-1))] = PrayerRecord(status: .excused)
        XCTAssertEqual(StreakRules.current(asOf: now, records: records), 2)
        records[PrayerLog.key(.asr, on: day(-1))] = PrayerRecord(status: .missed)
        XCTAssertEqual(StreakRules.current(asOf: now, records: records), 0)
    }

    // MARK: Bringing it back

    func testRecoveryOffersYesterdaysMissingPrayers() {
        var records: [String: PrayerRecord] = [:]
        complete([-5, -4, -3, -2, -1], into: &records)
        records[PrayerLog.key(.isha, on: day(-1))] = PrayerRecord(status: .missed)
        records[PrayerLog.key(.asr, on: day(-1))] = nil

        let recovery = StreakRules.recovery(asOf: now, records: records)
        XCTAssertEqual(recovery?.lostStreak, 4)
        XCTAssertEqual(recovery?.prayers, [.asr, .isha])
        XCTAssertEqual(recovery?.day, day(-1))
    }

    func testMakingUpTheMissedPrayersRestoresTheStreak() {
        var records: [String: PrayerRecord] = [:]
        complete([-3, -2, -1], into: &records)
        records[PrayerLog.key(.fajr, on: day(-1))] = PrayerRecord(status: .missed)
        XCTAssertEqual(StreakRules.current(asOf: now, records: records), 0)

        records[PrayerLog.key(.fajr, on: day(-1))] = PrayerRecord(status: .late)
        XCTAssertNil(StreakRules.recovery(asOf: now, records: records))
        XCTAssertEqual(StreakRules.current(asOf: now, records: records), 3)
    }

    func testNoRecoveryForAShortStreakOrAnOldBreak() {
        var records: [String: PrayerRecord] = [:]
        complete([-2], into: &records)
        XCTAssertNil(StreakRules.recovery(asOf: now, records: records), "a 1-day streak isn't worth a rescue")

        records = [:]
        complete([-6, -5, -4], into: &records)
        XCTAssertNil(StreakRules.recovery(asOf: now, records: records), "only yesterday's break can be brought back")
    }

    // MARK: Tiers

    func testTiersGrowWithTheStreak() {
        XCTAssertEqual(StreakTier.forDays(0), .ember)
        XCTAssertEqual(StreakTier.forDays(1), .spark)
        XCTAssertEqual(StreakTier.forDays(3), .kindling)
        XCTAssertEqual(StreakTier.forDays(7), .blaze)
        XCTAssertEqual(StreakTier.forDays(29), .blaze)
        XCTAssertEqual(StreakTier.forDays(30), .radiant)
        XCTAssertEqual(StreakTier.forDays(365), .noor)
    }

    func testProgressToTheNextTier() {
        XCTAssertEqual(StreakTier.blaze.daysToNext(from: 10), 20)
        XCTAssertEqual(StreakTier.kindling.progress(for: 5), 0.5, accuracy: 0.001)
        XCTAssertNil(StreakTier.noor.daysToNext(from: 150))
        XCTAssertEqual(StreakTier.noor.progress(for: 150), 1)
    }

    // MARK: Reminders

    func testAtRiskAndMorningRescueWhenTodayIsUnfinished() {
        var records: [String: PrayerRecord] = [:]
        complete([-3, -2, -1], into: &records)
        let plan = StreakReminders.plan(now: now, records: records) { _ in nil }
        let todayKey = PrayerLog.dayKey(for: day(0))
        XCTAssertEqual(Set(plan.map(\.id)), ["streak.risk.\(todayKey)", "streak.restore.\(todayKey)"])
        XCTAssertTrue(plan.allSatisfy { $0.date > now })
    }

    func testNoRemindersOnceTodayIsComplete() {
        var records: [String: PrayerRecord] = [:]
        complete([-3, -2, -1, 0], into: &records)
        XCTAssertTrue(StreakReminders.plan(now: now, records: records) { _ in nil }.isEmpty)
    }

    func testLastChanceAfterABreak() {
        var records: [String: PrayerRecord] = [:]
        complete([-4, -3, -2], into: &records)
        let plan = StreakReminders.plan(now: now, records: records) { _ in nil }
        let key = PrayerLog.dayKey(for: day(-1))
        // 9am has passed at noon, so only the evening one is left.
        XCTAssertEqual(plan.map(\.id), ["streak.lastchance.\(key)"])
    }

    func testEveningWaitsForALateIsha() {
        let lateIsha = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day(0))!
        let evening = StreakReminders.eveningTime(on: day(0)) { _ in lateIsha }
        XCTAssertEqual(evening, lateIsha.addingTimeInterval(45 * 60))

        let veryLate = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day(0))!
        let capped = StreakReminders.eveningTime(on: day(0)) { _ in veryLate }
        XCTAssertEqual(calendar.component(.hour, from: capped), 23)
        XCTAssertEqual(calendar.component(.minute, from: capped), 15)
    }
}

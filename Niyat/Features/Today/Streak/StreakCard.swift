import SwiftUI

/// The prayer streak on Today, in the shared streak card design
/// (StreakDesigns.swift): the flame, the count (which counts up when it grew
/// since you last looked) and the level, a way to bring back yesterday's
/// broken streak, and the last seven days.
struct StreakCard: View {
    @Environment(AppModel.self) private var model
    let now: Date
    /// Opens the check-in sheet for a prayer (used to log made-up prayers).
    let onCheckIn: (PrayerSlot) -> Void

    /// The streak the last time Today was shown, to count up from.
    @AppStorage("streak.lastSeen") private var lastSeen = 0
    @State private var shown: Int?
    @State private var burst = 0
    @State private var newTier: StreakTier?

    var body: some View {
        let streak = model.streak(asOf: now)
        let displayed = shown ?? streak
        let tier = StreakTier.forDays(displayed)

        VStack(alignment: .leading, spacing: 18) {
            StreakHeader(title: "Prayer streak", days: displayed, tier: tier, newTier: newTier, burst: burst)
            if let recovery = model.streakRecovery(asOf: now) {
                StreakRecoveryBanner(recovery: recovery, onCheckIn: onCheckIn)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            WeekRow(now: now, accent: streakAccent(tier))
        }
        .streakCardBackground()
        .animation(.smooth, value: model.streakRecovery(asOf: now))
        .haptic(.success, trigger: burst)
        .onAppear { celebrateGrowth(to: streak) }
        .onChange(of: streak) { _, new in celebrateGrowth(to: new) }
        .accessibilityElement(children: .contain)
    }

    /// Counts up from the streak you last saw, makes the flame jump, and
    /// names a new level when one was reached.
    private func celebrateGrowth(to streak: Int) {
        let from = lastSeen
        lastSeen = streak
        guard streak > from else {
            shown = nil
            return
        }
        shown = from
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { shown = nil }
            burst += 1
            let reached = StreakTier.forDays(streak)
            guard reached > StreakTier.forDays(from) else { return }
            withAnimation(.bouncy) { newTier = reached }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.smooth) { newTier = nil }
        }
    }
}

/// "Your 12-day streak slipped yesterday": tap each prayer to log it once
/// you've made it up (qada) to bring the streak back.
private struct StreakRecoveryBanner: View {
    let recovery: StreakRecovery
    let onCheckIn: (PrayerSlot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your \(recovery.lostStreak)-day streak slipped yesterday", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.highlight)
            Text("Make up what you missed as qada, or log what you prayed, before midnight to bring it back.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(recovery.prayers) { prayer in
                        Button {
                            onCheckIn(PrayerSlot(prayer: prayer, day: recovery.day))
                        } label: {
                            Text(prayer.englishName)
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                        .accessibilityHint("Log yesterday's \(prayer.englishName)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.highlight.opacity(0.1), in: .rect(cornerRadius: 18))
    }
}

/// The last seven days as stars: filled when complete, outlined as far as
/// the prayers logged that day, in the card's accent colour.
private struct WeekRow: View {
    @Environment(AppModel.self) private var model
    let now: Date
    let accent: Color

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        HStack {
            ForEach(days, id: \.self) { day in
                let count = model.prayedCount(on: day)
                let isToday = calendar.isDate(day, inSameDayAs: today)
                VStack(spacing: 4) {
                    ZStack {
                        EightPointStar()
                            .fill(model.isComplete(day) ? accent : Color.white.opacity(0.07))
                        EightPointStar()
                            .trim(from: 0, to: CGFloat(count) / 5)
                            .stroke(accent.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    .frame(width: 22, height: 22)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(isToday ? .heavy : .regular))
                        .fitText()
                        .foregroundStyle(isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(count) of 5 prayers")
            }
        }
    }
}

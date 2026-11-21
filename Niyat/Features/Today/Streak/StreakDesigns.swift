import SwiftUI

// The streak cards' shared design (prayer on Today, Qur'an on the Qur'an
// tab), so both look the same: the flame, the count and the level on top,
// then each card's own details. The flame is the only colour; everything
// else stays neutral so it sits well in every theme.

/// The top of a streak card: flame, count and level.
struct StreakHeader: View {
    let title: String
    let days: Int
    let tier: StreakTier
    var newTier: StreakTier?
    var burst: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                StreakFlame(tier: tier, burst: burst, scalesWithTier: false)
                    .frame(width: 62, height: 84)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).sectionLabelStyle().fitText(0.7)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(days)")
                            .font(.display(48, weight: .heavy))
                            .monospacedDigit()
                            .streakGradient(tier)
                            .contentTransition(.numericText(value: Double(days)))
                        Text(days == 1 ? "day" : "days")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .fitText(0.7)
                }
                // The flame is drawn from the bottom of its frame, so it sits
                // low; drop the title and count to line up with it.
                .padding(.top, 14)
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            LevelTrack(days: days, tier: tier, newTier: newTier)
        }
    }
}

/// "Radiant · Noor in 70 days" over a thin track filling towards the next
/// level in the flames' colours.
struct LevelTrack: View {
    let days: Int
    let tier: StreakTier
    var newTier: StreakTier?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LevelLine(days: days, tier: tier, newTier: newTier)
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(colors: [tier.flameColors.rim, (tier.next ?? tier).flameColors.fill],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * tier.progress(for: days)))
                    }
                }
                .animation(.smooth, value: days)
                .accessibilityElement()
                .accessibilityLabel("Progress to the next level")
                .accessibilityValue("\(Int(tier.progress(for: days) * 100)) percent")
        }
    }
}

/// The level in its flame colour and how far away the next one is, named in
/// its own flame colour.
struct LevelLine: View {
    let days: Int
    let tier: StreakTier
    var newTier: StreakTier?

    var body: some View {
        HStack(spacing: 6) {
            if let newTier {
                Label("New level: \(newTier.title)", systemImage: "sparkles")
                    .foregroundStyle(newTier.flameColors.fill)
                    .transition(.scale.combined(with: .opacity))
            } else if days == 0 {
                Text("Start today to light your flame").foregroundStyle(.secondary)
            } else {
                Text(tier.title).foregroundStyle(tier.flameColors.fill)
                if let next = tier.next, let left = tier.daysToNext(from: days) {
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(Text(next.title).foregroundStyle(next.flameColors.fill)) in \(left) \(left == 1 ? "day" : "days")")
                        .foregroundStyle(.secondary)
                } else {
                    Text("· the top level").foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

extension View {
    /// The streak cards' surface.
    func streakCardBackground() -> some View {
        padding(20).surface(cornerRadius: 28)
    }
}

/// The colour for a streak card's details (stars, button): white, so the
/// flame stays the only colour; dimmer while there's no streak.
func streakAccent(_ tier: StreakTier) -> Color {
    tier == .ember ? .white.opacity(0.85) : .white
}

/// The Qur'an card's Read button: the user's theme colours flowing across the
/// capsule with a soft glow, the same treatment as the streak numbers.
/// Holds still with Reduce Motion.
struct StreakActionLabel: View {
    let title: String
    let systemImage: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for the bands to flow once across the button (as the streak numbers).
    private static let period = 2.2

    var body: some View {
        let light = Palette.highlight
        let deep = Palette.highlight.mix(with: Palette.accent, by: 0.45)
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.black)
            .badgeText()
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
                    let time = reduceMotion ? 0.35 * Self.period : context.date.timeIntervalSinceReferenceDate
                    let phase = (time / Self.period).truncatingRemainder(dividingBy: 1)
                    Capsule()
                        .fill(StreakGradient.flow(phase: phase, light: light, deep: deep))
                        // A tight glow and a wide one, like the streak numbers.
                        .shadow(color: light.opacity(0.75), radius: 4)
                        .shadow(color: deep.opacity(0.55), radius: 14)
                }
            }
    }
}

/// The streak in the top bar: a small flame and the count, in the flame's
/// colour. Today puts it next to the date so the streak shows on opening
/// while the prayers stay first.
struct StreakPill: View {
    let days: Int

    var body: some View {
        let tier = StreakTier.forDays(days)
        HStack(alignment: .center, spacing: 7) {
            // The clean, whole-flame frames with a close glow, its body lifted
            // to centre on the number (the sparks sit above it).
            StreakFlame(tier: tier, scalesWithTier: false, compact: true)
                .frame(width: 32 * StreakFlame.aspectRatio, height: 32)
                .shadow(color: tier.flameColors.rim.opacity(tier == .ember ? 0 : 0.6), radius: 5)
                .offset(y: -3)
            Text("\(days)")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .streakGradient(tier)
                .contentTransition(.numericText(value: Double(days)))
                // Level with the flame's body, which sits low in its frame.
                .offset(y: 2)
        }
        // Equal on both sides so the pair sits in the middle of the capsule.
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == 1 ? "1 day prayer streak" : "\(days) day prayer streak")
    }
}

/// A streak count's fill: diagonal bands of the flame's deep and light
/// shades flowing across the number in a seamless loop, with a soft glow so
/// it stands out. Grey with no streak; holds still
/// with Reduce Motion.
struct StreakGradient: ViewModifier {
    let tier: StreakTier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for the pattern to flow once across the number.
    private static let period = 2.2

    func body(content: Content) -> some View {
        if tier == .ember {
            content.foregroundStyle(.secondary)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
                let time = reduceMotion ? 0.35 * Self.period : context.date.timeIntervalSinceReferenceDate
                let phase = (time / Self.period).truncatingRemainder(dividingBy: 1)
                content
                    .foregroundStyle(flow(phase: phase))
                    // A tight glow and a wide one, so the number lights up.
                    .shadow(color: tier.flameColors.fill.opacity(0.9), radius: 4)
                    .shadow(color: tier.flameColors.rim.opacity(0.7), radius: 14)
            }
        }
    }

    /// Diagonal bands of the flame's deep and light shades (dark and light
    /// blue for Radiant). One band pair per period, laid out twice along the
    /// diagonal and slid by `phase`, so the end of the loop meets its start.
    private func flow(phase: Double) -> LinearGradient {
        let colors = tier.flameColors
        return Self.flow(phase: phase, light: colors.fill, deep: colors.fill.mix(with: colors.rim, by: 0.35))
    }

    /// The flowing diagonal bands, shared with the Qur'an card's Read button.
    static func flow(phase: Double, light: Color, deep: Color) -> LinearGradient {
        let pattern: [Color] = [deep, light, deep]
        var stops: [Gradient.Stop] = []
        for repeat_ in 0..<2 {
            for (index, color) in pattern.enumerated() {
                let location = (Double(repeat_) + Double(index) / Double(pattern.count - 1)) / 2
                stops.append(.init(color: color, location: location))
            }
        }
        // The diagonal: across and down at once.
        let step = (x: 1.0, y: 0.9)
        return LinearGradient(stops: stops,
                              startPoint: UnitPoint(x: -phase * step.x, y: -phase * step.y),
                              endPoint: UnitPoint(x: (2 - phase) * step.x, y: (2 - phase) * step.y))
    }
}

extension View {
    func streakGradient(_ tier: StreakTier) -> some View {
        modifier(StreakGradient(tier: tier))
    }
}

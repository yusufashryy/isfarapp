import SwiftUI

/// The streak's flame: a hand-traced flipbook (scripts/lottie_mask_frames.py)
/// smoothed with morphed in-betweens (scripts/morph_flame_frames.swift) into
/// two masks per frame, `StreakFlame/rim-NN` and `fill-NN`. It's drawn flat
/// and two-tone like the original art: a vivid rim with a lighter inside, in
/// the level's colours, over a faint glow. Longer streaks get a bigger flame;
/// with no streak it's a grey ember. Holds still with Reduce Motion.
struct StreakFlame: View {
    let tier: StreakTier
    /// Bumped to make the flame jump (a new day added, a new level).
    var burst: Int = 0
    /// Grow with the level (the card). Off where it's a small icon (badges).
    var scalesWithTier = true
    /// Icon size, next to text (pills, badges): no wide glow, which smears
    /// into a blob at this size.
    var compact = false

    static let frameCount = 78
    static let framesPerSecond = 48.0
    /// Width / height of a frame (from scripts/lottie_mask_frames.py).
    static let aspectRatio: CGFloat = 0.582

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Self.framesPerSecond, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let size = geo.size
                ZStack(alignment: .bottom) {
                    if !compact { glow(size: size) }
                    sprite(frame: frame(at: time), size: size)
                }
                .frame(width: size.width, height: size.height, alignment: .bottom)
            }
        }
        .scaleEffect(popped ? 1.2 : 1, anchor: .bottom)
        .onChange(of: burst) { _, _ in pop() }
        .animation(.smooth(duration: 0.6), value: tier)
        .accessibilityHidden(true)
    }

    private func frame(at time: Double) -> Int {
        Int(time * Self.framesPerSecond * tier.flickerSpeed) % Self.frameCount
    }

    private func sprite(frame: Int, size: CGSize) -> some View {
        let colors = tier.flameColors
        let height = size.height * (scalesWithTier ? tier.flameScale : 1)
        let index = String(format: "%02d", frame)
        return ZStack {
            Image("rim-\(index)").resizable().foregroundStyle(colors.rim)
            Image("fill-\(index)").resizable().foregroundStyle(colors.fill)
        }
        .frame(width: height * Self.aspectRatio, height: height)
        // A close glow hugging the flame's shape.
        .shadow(color: colors.rim.opacity(tier == .ember ? 0 : 0.8), radius: height * 0.09)
    }

    /// A wide soft glow behind the flame, stronger at higher levels.
    private func glow(size: CGSize) -> some View {
        Ellipse()
            .fill(tier.flameColors.rim.opacity(min(0.85, tier.glow * 1.6)))
            .frame(width: size.width * 1.1, height: size.height * 0.7)
            .blur(radius: size.width * 0.22)
            .offset(y: -size.height * 0.12)
    }

    private func pop() {
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.25, bounce: 0.5)) { popped = true }
        withAnimation(.spring(duration: 0.5, bounce: 0.4).delay(0.25)) { popped = false }
    }
}

/// "🔥 9 day streak" as a capsule in the level's flame colours: the live
/// flame, the count in the same flowing gradient as the streak cards, and
/// the label. Used wherever a streak is mentioned so they all match.
struct StreakBadge: View {
    let days: Int
    /// Follows the number: "day streak", or "day Qur'an streak".
    var label = "day streak"
    /// The label's point size; the flame, number and capsule scale with it.
    var size: CGFloat = 15
    var burst = 0

    var body: some View {
        let tier = StreakTier.forDays(days)
        let colors = tier.flameColors
        HStack(spacing: size * 0.55) {
            StreakFlame(tier: tier, burst: burst, scalesWithTier: false, compact: true)
                .frame(width: size * 1.9 * StreakFlame.aspectRatio, height: size * 1.9)
                .shadow(color: colors.rim.opacity(tier == .ember ? 0 : 0.6), radius: size * 0.3)
                // The flame's body is in the lower part of its frame (sparks
                // above); lift it so the body, not the frame, centres on the text.
                .offset(y: -size * 0.18)
            HStack(alignment: .firstTextBaseline, spacing: size * 0.35) {
                Text("\(days)")
                    .font(.system(size: size * 1.35, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .streakGradient(tier)
                    .contentTransition(.numericText(value: Double(days)))
                Text(label)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }
            // Sit the text a little lower, level with the flame's body.
            .offset(y: size * 0.14)
        }
        .padding(.leading, size * 0.8)
        .padding(.trailing, size * 1.0)
        .padding(.vertical, size * 0.4)
        .background {
            Capsule().fill(LinearGradient(colors: [colors.rim.opacity(0.3), colors.fill.opacity(0.07)],
                                          startPoint: .leading, endPoint: .trailing))
        }
        .overlay { Capsule().strokeBorder(colors.rim.opacity(0.45), lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) \(label)")
    }
}

/// The streak flame at the size it headlines a card: big, on its own.
struct StreakEmblem: View {
    let tier: StreakTier
    var burst: Int = 0
    var size: CGFloat = 66

    var body: some View {
        StreakFlame(tier: tier, burst: burst, scalesWithTier: false)
            .frame(width: size * 0.7, height: size)
            .accessibilityHidden(true)
    }
}

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
                    glow(size: size)
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

/// "9-day streak" with a small live flame, coloured by the streak's level,
/// so every streak in the app looks the same.
struct StreakBadge: View {
    let days: Int

    var body: some View {
        let tier = StreakTier.forDays(days)
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            // The flame stands on the text's baseline, never dipping below it.
            StreakFlame(tier: tier, scalesWithTier: false)
                .frame(width: 24, height: 34)
                .alignmentGuide(.lastTextBaseline) { $0[.bottom] }
            Text("\(days)-day streak")
                .font(.caption.weight(.bold))
                .foregroundStyle(tier.tint)
                .contentTransition(.numericText(value: Double(days)))
        }
        .accessibilityElement(children: .combine)
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

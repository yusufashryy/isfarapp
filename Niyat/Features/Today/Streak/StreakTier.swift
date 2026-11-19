import SwiftUI

/// How the streak's flame looks: it grows and changes colour the longer the
/// streak runs. Each tier starts at `minimumDays`.
enum StreakTier: Int, CaseIterable, Comparable {
    case ember, spark, kindling, blaze, radiant, noor

    static func < (lhs: StreakTier, rhs: StreakTier) -> Bool { lhs.rawValue < rhs.rawValue }

    static func forDays(_ days: Int) -> StreakTier {
        allCases.last { days >= $0.minimumDays } ?? .ember
    }

    var minimumDays: Int {
        switch self {
        case .ember: 0
        case .spark: 1
        case .kindling: 3
        case .blaze: 7
        case .radiant: 30
        case .noor: 100
        }
    }

    var title: String {
        switch self {
        case .ember: "Ember"
        case .spark: "Spark"
        case .kindling: "Kindling"
        case .blaze: "Blaze"
        case .radiant: "Radiant"
        case .noor: "Noor"
        }
    }

    var next: StreakTier? { StreakTier(rawValue: rawValue + 1) }

    /// Days still needed to reach the next tier, or nil at the top.
    func daysToNext(from days: Int) -> Int? {
        next.map { max(0, $0.minimumDays - days) }
    }

    /// 0...1 progress from this tier to the next (1 at the top tier).
    func progress(for days: Int) -> Double {
        guard let next else { return 1 }
        let span = Double(next.minimumDays - minimumDays)
        return min(1, max(0, Double(days - minimumDays) / span))
    }

    /// Size of the flame relative to its frame.
    var flameScale: CGFloat {
        switch self {
        case .ember: 0.5
        case .spark: 0.66
        case .kindling: 0.76
        case .blaze: 0.86
        case .radiant: 0.94
        case .noor: 1
        }
    }

    /// How fast the flame flickers (embers barely move).
    var flickerSpeed: Double {
        switch self {
        case .ember: 0.6
        case .spark, .kindling: 1
        case .blaze: 1.1
        case .radiant, .noor: 1.2
        }
    }

    /// How strongly the flame glows; it's the theme's colour at every
    /// level, so a longer streak shows as a bigger, brighter flame.
    var glow: Double {
        switch self {
        case .ember: 0
        case .spark: 0.2
        case .kindling: 0.28
        case .blaze: 0.38
        case .radiant: 0.48
        case .noor: 0.58
        }
    }

    /// Text and the progress bar follow the theme.
    var tint: Color { self == .ember ? .secondary : Palette.highlight }

    /// The flame's two colours, flat like the original art: a vivid rim and
    /// a lighter inside. Fixed per level (like the bookmark colours) so a
    /// level always looks the same, whatever the theme. Ember is grey: no
    /// streak yet.
    var flameColors: (rim: Color, fill: Color) {
        switch self {
        case .ember: (Self.rgb(0x6B6B73), Self.rgb(0xA3A3AB))
        case .spark: (Self.rgb(0xFFB300), Self.rgb(0xFFE14D))
        case .kindling: (Self.rgb(0xFF8A00), Self.rgb(0xFFBE2E))
        case .blaze: (Self.rgb(0xF23A1D), Self.rgb(0xFF8A3D))
        case .radiant: (Self.rgb(0x1F7BFF), Self.rgb(0x66CCFF))
        case .noor: (Self.rgb(0x8A3DFF), Self.rgb(0xB57CFF))
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }
}

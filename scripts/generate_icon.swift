#!/usr/bin/env swift
// Draws the Isfar app icon: the gold prayer dial (five points for the five
// prayers, the next one glowing) around an eight-pointed star, on the Onyx
// theme's background (soft black mesh with the app's Islamic pattern).
//
// Writes the default, dark and tinted iPhone icons and the Watch icon.
// Run on a Mac from the repo root: `swift scripts/generate_icon.swift`
// The star and pattern are copies of EightPointStar and IslamicPattern in
// Shared/Ornaments.swift, so the icon matches the app.
import AppKit
import SwiftUI

let size: CGFloat = 1024
let centre = size / 2
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconDir = root.appendingPathComponent("Niyat/Resources/Assets.xcassets/AppIcon.appiconset")
let watchDir = root.appendingPathComponent("Watch/App/Assets.xcassets/AppIcon.appiconset")

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: opacity)
    }
}

let gold = Color(hex: 0xDEB862)
let goldLight = Color(hex: 0xF6DEA0)
let goldShadow = Color(hex: 0x96732F)

// MARK: - Shapes (copied from Shared/Ornaments.swift)

func starPath(center: CGPoint, radius: CGFloat, innerRatio: CGFloat = 0.765, rotation: Double = 0) -> Path {
    var path = Path()
    for i in 0..<16 {
        let angle = Double(i) * .pi / 8 - .pi / 2 + rotation
        let r = i.isMultiple(of: 2) ? radius : radius * innerRatio
        let point = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
}

struct IslamicPattern: View {
    var tile: CGFloat
    var lineWidth: CGFloat
    var color: Color

    var body: some View {
        Canvas { context, canvas in
            let starRadius = tile * 0.40, innerRadius = tile * 0.20
            var path = Path()
            for row in -1..<(Int(canvas.height / tile) + 2) {
                for col in -1..<(Int(canvas.width / tile) + 2) {
                    let c = CGPoint(x: CGFloat(col) * tile + tile / 2, y: CGFloat(row) * tile + tile / 2)
                    path.addPath(starPath(center: c, radius: starRadius))
                    path.addPath(starPath(center: c, radius: innerRadius, innerRatio: 0.7, rotation: .pi / 8))
                    path.move(to: CGPoint(x: c.x + starRadius, y: c.y))
                    path.addLine(to: CGPoint(x: c.x + tile - starRadius, y: c.y))
                    path.move(to: CGPoint(x: c.x, y: c.y + starRadius))
                    path.addLine(to: CGPoint(x: c.x, y: c.y + tile - starRadius))
                    let corner = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile), d = tile * 0.1
                    path.move(to: CGPoint(x: corner.x, y: corner.y - d))
                    path.addLine(to: CGPoint(x: corner.x + d, y: corner.y))
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y + d))
                    path.addLine(to: CGPoint(x: corner.x - d, y: corner.y))
                    path.closeSubpath()
                }
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

// MARK: - Background

/// The Onyx theme's ambient background (AmbientBackground in Shared/Theme.swift).
struct OnyxBackground: View {
    var showsGlow = true

    var body: some View {
        ZStack {
            if showsGlow {
                MeshGradient(width: 3, height: 3,
                             points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.55, 0.42], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                             colors: [Color(hex: 0x1C1C1E), .black, Color(hex: 0x0E0E10),
                                      .black, Color(hex: 0x1C1C1E, opacity: 0.6), .black,
                                      Color(hex: 0x0E0E10), .black, Color(hex: 0x1C1C1E, opacity: 0.7)])
            } else {
                Color.black
            }
            IslamicPattern(tile: 146, lineWidth: 3, color: .white.opacity(0.06))
        }
    }
}

// MARK: - Art

/// Where a prayer sits on the dial: midnight at the bottom, noon at the top.
func dialPoint(_ fraction: CGFloat, radius: CGFloat) -> CGPoint {
    let angle = fraction * 2 * .pi + .pi / 2
    return CGPoint(x: centre + radius * cos(angle), y: centre + radius * sin(angle))
}

/// The dial ring, the five prayers (roughly Fajr, Dhuhr, Asr, Maghrib, Isha,
/// the second one glowing) and the star in the middle.
struct DialArt: View {
    var ink: Color = gold
    var showsGlow = true

    var body: some View {
        let ringRadius = size * 0.335
        let lineWidth = size * 0.012
        let prayers: [CGFloat] = [0.22, 0.53, 0.66, 0.78, 0.86]
        ZStack {
            if showsGlow {
                Circle().fill(goldLight.opacity(0.45))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .blur(radius: size * 0.04)
                    .position(dialPoint(prayers[1], radius: ringRadius))
            }
            Canvas { context, _ in
                var lines = Path(ellipseIn: CGRect(x: centre - ringRadius, y: centre - ringRadius,
                                                   width: ringRadius * 2, height: ringRadius * 2))
                lines.addPath(starPath(center: CGPoint(x: centre, y: centre), radius: size * 0.19))
                if showsGlow {
                    context.stroke(lines, with: .color(goldShadow.opacity(0.6)),
                                   style: StrokeStyle(lineWidth: lineWidth * 2.2, lineJoin: .round))
                }
                context.stroke(lines, with: .color(ink), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))

                var solid = starPath(center: CGPoint(x: centre, y: centre), radius: size * 0.085, rotation: .pi / 8)
                for (index, fraction) in prayers.enumerated() {
                    let point = dialPoint(fraction, radius: ringRadius)
                    let r = size * (index == 1 ? 0.03 : 0.02)
                    solid.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
                }
                context.fill(solid, with: .color(ink))
            }
        }
        .frame(width: size, height: size)
    }
}

struct Icon: View {
    enum Look { case standard, dark, tinted }
    var look: Look

    var body: some View {
        ZStack {
            switch look {
            case .standard: OnyxBackground(); DialArt()
            case .dark: OnyxBackground(showsGlow: false); DialArt()
            // Tinted icons are recoloured by iOS from their brightness: light art on black, no texture.
            case .tinted: Color.black; DialArt(ink: Color(white: 0.92), showsGlow: false)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

// MARK: - Output

@MainActor
func write(_ look: Icon.Look, to url: URL) throws {
    let renderer = ImageRenderer(content: Icon(look: look))
    renderer.scale = 1
    // App Store Connect rejects icons with an alpha channel, so flatten onto an opaque bitmap.
    let pixels = Int(size)
    guard let image = renderer.cgImage,
          let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }
    context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    guard let opaque = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: opaque).representation(using: .png, properties: [:])
    else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: url)
    print("Wrote", url.path)
}

do {
    try MainActor.assumeIsolated {
        try write(.standard, to: iconDir.appendingPathComponent("AppIcon.png"))
        try write(.dark, to: iconDir.appendingPathComponent("AppIcon-Dark.png"))
        try write(.tinted, to: iconDir.appendingPathComponent("AppIcon-Tinted.png"))
        try write(.standard, to: watchDir.appendingPathComponent("AppIcon.png"))
    }
} catch {
    FileHandle.standardError.write("Couldn't write the icons: \(error)\n".data(using: .utf8)!)
    exit(1)
}

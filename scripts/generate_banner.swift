#!/usr/bin/env swift
// Makes docs/images/banner.png, the 1280x640 picture used for the GitHub link
// preview (repo Settings › Social preview) and the top of the README.
// Run on a Mac from the repo root, after the icon: `swift scripts/generate_banner.swift`
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconURL = root.appendingPathComponent("Niyat/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let ruqaaURL = root.appendingPathComponent("Niyat/Resources/Fonts/ArefRuqaa-Bold.ttf")
let outURL = root.appendingPathComponent("docs/images/banner.png")

let gold = Color(red: 222 / 255, green: 186 / 255, blue: 98 / 255)

struct Banner: View {
    let icon: NSImage

    var body: some View {
        ZStack {
            Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255)
            RadialGradient(colors: [Color(red: 60 / 255, green: 50 / 255, blue: 25 / 255).opacity(0.7), .clear],
                           center: UnitPoint(x: 0.26, y: 0.5), startRadius: 0, endRadius: 420)
            HStack(spacing: 70) {
                Image(nsImage: icon).resizable()
                    .frame(width: 400, height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 90, style: .continuous))
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 28) {
                        Text("Isfar").font(.system(size: 110, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(white: 0.96))
                        Text("إسفار").font(.custom("ArefRuqaa-Bold", size: 84)).foregroundStyle(gold)
                    }
                    Text("THE FIRST LIGHT OF DAWN")
                        .font(.system(size: 22, weight: .semibold)).tracking(4)
                        .foregroundStyle(Color(white: 0.6))
                    Text("Prayer times, Qur'an and Qibla\nfor iPhone")
                        .font(.system(size: 40)).foregroundStyle(Color(white: 0.86))
                        .padding(.top, 14)
                    Text("Free forever · No ads · No tracking")
                        .font(.system(size: 30)).foregroundStyle(gold)
                        .padding(.top, 10)
                }
                .frame(width: 640, alignment: .leading)
            }
        }
        .frame(width: 1280, height: 640)
    }
}

guard let icon = NSImage(contentsOf: iconURL) else {
    FileHandle.standardError.write("Couldn't read the app icon at \(iconURL.path). Run generate_icon.swift first.\n".data(using: .utf8)!)
    exit(1)
}
CTFontManagerRegisterFontsForURL(ruqaaURL as CFURL, .process, nil)

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Banner(icon: icon))
    renderer.scale = 1
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Couldn't draw the banner.\n".data(using: .utf8)!)
        exit(1)
    }
    do {
        try png.write(to: outURL)
        print("Wrote", outURL.path)
    } catch {
        FileHandle.standardError.write("Couldn't write the banner: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

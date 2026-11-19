// Makes the streak flame smoother by morphing in-between frames.
//
//   swift scripts/morph_flame_frames.swift <svg frames folder> <output folder> [steps] [height] [outline]
//
// Reads flame-00.svg ... flame-NN.svg (the hand-traced silhouettes from
// scripts/lottie_mask_frames.py), and writes steps x N PNG masks
// (white flame on transparent), looping back to the first drawing:
// flame-NN.png (the flame) and outline-NN.png (the flame grown by
// `outline` pixels, drawn behind it in a darker colour for a cartoon edge).
// Each in-between is a true halfway shape, not two frames faded together:
// every drawing becomes a signed distance field (how far each pixel is from
// the flame's edge, negative inside), neighbouring fields are blended, and
// the blend's zero line is the new edge.

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: swift scripts/morph_flame_frames.swift <svg folder> <output folder> [steps=3] [height=600]")
    exit(1)
}
let input = args[1], output = args[2]
let steps = args.count > 3 ? Int(args[3]) ?? 3 : 3
let height = args.count > 4 ? Int(args[4]) ?? 600 : 600
let outline = args.count > 5 ? Float(args[5]) ?? 0 : 0

// MARK: Load and rasterise

func svgFiles() -> [String] {
    let files = (try? FileManager.default.contentsOfDirectory(atPath: input)) ?? []
    return files.filter { $0.hasPrefix("flame-") && $0.hasSuffix(".svg") }.sorted().map { "\(input)/\($0)" }
}

/// Coverage (0...1) of the flame at each pixel, row 0 at the top.
func rasterise(_ path: String, width: Int, height: Int) -> [Float] {
    guard let image = NSImage(contentsOfFile: path) else { fatalError("Can't read \(path)") }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: width * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.bitmapData!
    return (0..<(width * height)).map { Float(data[$0 * 4 + 3]) / 255 }
}

// MARK: Distance fields

/// 1D squared Euclidean distance transform (Felzenszwalb and Huttenlocher).
func distance1D(_ f: [Float]) -> [Float] {
    let n = f.count
    var d = [Float](repeating: 0, count: n)
    var v = [Int](repeating: 0, count: n)
    var z = [Float](repeating: 0, count: n + 1)
    var k = 0
    z[0] = -.infinity
    z[1] = .infinity
    for q in 1..<n {
        var s: Float
        repeat {
            let p = v[k]
            s = ((f[q] + Float(q * q)) - (f[p] + Float(p * p))) / Float(2 * q - 2 * p)
            if s <= z[k] { k -= 1 } else { break }
        } while k >= 0
        k += 1
        v[k] = q
        z[k] = s
        z[k + 1] = .infinity
    }
    k = 0
    for q in 0..<n {
        while z[k + 1] < Float(q) { k += 1 }
        let p = v[k]
        d[q] = Float((q - p) * (q - p)) + f[p]
    }
    return d
}

/// Distance (pixels) from each pixel to the nearest pixel where `isTarget`.
func distance(to isTarget: [Bool], width: Int, height: Int) -> [Float] {
    let big: Float = 1e12
    var grid = isTarget.map { $0 ? Float(0) : big }
    for x in 0..<width {
        let column = distance1D((0..<height).map { grid[$0 * width + x] })
        for y in 0..<height { grid[y * width + x] = column[y] }
    }
    for y in 0..<height {
        let row = distance1D(Array(grid[(y * width)..<((y + 1) * width)]))
        for x in 0..<width { grid[y * width + x] = row[x] }
    }
    return grid.map { $0.squareRoot() }
}

/// Signed distance: negative inside the flame, positive outside.
func signedDistance(_ coverage: [Float], width: Int, height: Int) -> [Float] {
    let inside = coverage.map { $0 >= 0.5 }
    let toInside = distance(to: inside, width: width, height: height)
    let toOutside = distance(to: inside.map { !$0 }, width: width, height: height)
    return zip(toInside, toOutside).map { $0 - $1 }
}

// MARK: Output

func writePNG(_ field: [Float], width: Int, height: Int, grow: Float = 0, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: width * 4, bitsPerPixel: 32)!
    let data = rep.bitmapData!
    for i in 0..<(width * height) {
        // A one-pixel soft edge from the distance itself: smooth, no jaggies.
        let alpha = UInt8(max(0, min(1, 0.5 + grow - field[i])) * 255)
        data[i * 4] = alpha       // premultiplied white
        data[i * 4 + 1] = alpha
        data[i * 4 + 2] = alpha
        data[i * 4 + 3] = alpha
    }
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let files = svgFiles()
guard let first = files.first, let probe = NSImage(contentsOfFile: first) else {
    print("No flame-NN.svg files in \(input)")
    exit(1)
}
let width = Int((Double(height) * Double(probe.size.width / probe.size.height)).rounded())
print("\(files.count) drawings -> \(files.count * steps) frames at \(width)x\(height)")

let fields = files.map { signedDistance(rasterise($0, width: width, height: height), width: width, height: height) }
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
var index = 0
for (i, a) in fields.enumerated() {
    let b = fields[(i + 1) % fields.count]
    for step in 0..<steps {
        let t = Float(step) / Float(steps)
        let blended = zip(a, b).map { (1 - t) * $0 + t * $1 }
        writePNG(blended, width: width, height: height, to: String(format: "%@/flame-%02d.png", output, index))
        if outline > 0 {
            writePNG(blended, width: width, height: height, grow: outline,
                     to: String(format: "%@/outline-%02d.png", output, index))
        }
        index += 1
    }
}
print("Wrote \(index) frames to \(output)")

#!/usr/bin/env swift
import AppKit

// Generates a modern macOS app icon for PresButan Reborn:
// a blue "squircle" with a white keycap and a return arrow (press-the-key motif).
// Renders the vector at each iconset size for crisp small sizes, then the
// caller runs `iconutil` to produce AppIcon.icns.

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/AppIcon.iconset"

// (name, pixelSize)
let variants: [(String, Int)] = [
    ("icon_16x16",      16),
    ("icon_16x16@2x",   32),
    ("icon_32x32",      32),
    ("icon_32x32@2x",   64),
    ("icon_128x128",   128),
    ("icon_128x128@2x",256),
    ("icon_256x256",   256),
    ("icon_256x256@2x",512),
    ("icon_512x512",   512),
    ("icon_512x512@2x",1024),
]

func draw(_ size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.cgContext.setAllowsAntialiasing(true)
    ctx.cgContext.interpolationQuality = .high

    let f = size / 1024.0
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * f, y: y * f, width: w * f, height: h * f)
    }
    func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * f, y: y * f) }

    // --- background squircle (Apple grid: 824 content in 1024, radius ~185) ---
    let bg = NSBezierPath(roundedRect: R(100, 100, 824, 824), xRadius: 185 * f, yRadius: 185 * f)
    let grad = NSGradient(colors: [
        NSColor(srgbRed: 0.16, green: 0.31, blue: 0.85, alpha: 1),   // deep blue (bottom)
        NSColor(srgbRed: 0.36, green: 0.62, blue: 1.00, alpha: 1),   // bright blue (top)
    ])!
    grad.draw(in: bg, angle: 90)

    // subtle top sheen
    let sheen = NSBezierPath(roundedRect: R(100, 540, 824, 384), xRadius: 185 * f, yRadius: 185 * f)
    NSColor(white: 1, alpha: 0.06).setFill()
    sheen.fill()

    // --- keycap (white rounded square, slight lift) with a thin base for depth ---
    // base (a touch darker, offset down) reads as the key's thickness
    let base = NSBezierPath(roundedRect: R(268, 250, 488, 488), xRadius: 116 * f, yRadius: 116 * f)
    NSColor(srgbRed: 0.80, green: 0.85, blue: 0.96, alpha: 1).setFill()
    base.fill()

    // soft shadow under the cap
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
    shadow.shadowBlurRadius = 42 * f
    shadow.shadowOffset = NSSize(width: 0, height: -14 * f)
    shadow.set()

    let cap = NSBezierPath(roundedRect: R(268, 274, 488, 488), xRadius: 116 * f, yRadius: 116 * f)
    NSColor(srgbRed: 0.98, green: 0.99, blue: 1.0, alpha: 1).setFill()
    cap.fill()

    // clear shadow for the glyph
    let noShadow = NSShadow()
    noShadow.shadowColor = .clear
    noShadow.set()

    // --- return arrow glyph on the cap (blue) ---
    // corner at top-right, riser down, bar left, arrowhead at the left tip.
    let arrow = NSBezierPath()
    arrow.lineWidth = 68 * f
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: P(648, 690))          // top of riser
    arrow.line(to: P(648, 520))          // down
    arrow.line(to: P(400, 520))          // left along the bar
    // arrowhead
    arrow.move(to: P(468, 578))          // upper barb
    arrow.line(to: P(398, 520))          // tip
    arrow.line(to: P(468, 462))          // lower barb
    NSColor(srgbRed: 0.16, green: 0.33, blue: 0.86, alpha: 1).setStroke()
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for (name, px) in variants {
    let rep = draw(CGFloat(px))
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("failed png for \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    let path = "\(outDir)/\(name).png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(px)px)")
}
print("done")

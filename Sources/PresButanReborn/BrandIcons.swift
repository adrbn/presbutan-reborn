import AppKit

/// Brand logos drawn at runtime from their official SVG path data.
/// SF Symbols doesn't ship third-party marks (GitHub, Ko-fi, …), so we render
/// them ourselves into template `NSImage`s that adapt to light/dark mode and
/// menu-item selection state, matching how SF Symbol menu icons behave.
enum BrandIcons {
    /// Official GitHub "Octocat" mark. Source: github.com/logos, 24×24 viewBox.
    private static let githubPath =
        "M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577" +
        " 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7" +
        "c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998" +
        ".108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22" +
        "-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405" +
        " 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22" +
        " 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57" +
        "C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"

    /// GitHub mark as a template `NSImage` sized for a menu item (~14pt).
    static func github(size: CGFloat = 14) -> NSImage {
        let viewBox: CGFloat = 24
        let path = SVGPathParser.parse(githubPath)
        // SVG uses y-down; AppKit (NSImage drawing) uses y-up. Flip vertically
        // and scale to the requested size by walking the parsed path elements.
        let scaled = SVGPathParser.transformed(path, scale: size / viewBox, viewBox: viewBox)

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.black.set()
        scaled.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

/// Minimal SVG path parser supporting the subset of commands needed by the
/// brand marks above (M/m, L/l, C/c, H/h, V/v, Z/z, plus implicit
/// continuations). Numbers, signs, decimals, and exponents are tolerated.
enum SVGPathParser {
    static func parse(_ d: String) -> NSBezierPath {
        let path = NSBezierPath()
        let tokens = tokenize(d)
        var i = 0
        var x: CGFloat = 0, y: CGFloat = 0
        var startX: CGFloat = 0, startY: CGFloat = 0
        var cmd: Character = " "

        func number() -> CGFloat {
            guard i < tokens.count, let n = Double(tokens[i]) else { return 0 }
            i += 1
            return CGFloat(n)
        }

        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter {
                cmd = c
                i += 1
                if cmd == "Z" || cmd == "z" {
                    path.close()
                    x = startX; y = startY
                    continue
                }
            }
            switch cmd {
            case "M":
                x = number(); y = number()
                path.move(to: NSPoint(x: x, y: y))
                startX = x; startY = y
                cmd = "L"   // subsequent pairs are implicit L
            case "m":
                x += number(); y += number()
                path.move(to: NSPoint(x: x, y: y))
                startX = x; startY = y
                cmd = "l"
            case "L":
                x = number(); y = number()
                path.line(to: NSPoint(x: x, y: y))
            case "l":
                x += number(); y += number()
                path.line(to: NSPoint(x: x, y: y))
            case "H":
                x = number(); path.line(to: NSPoint(x: x, y: y))
            case "h":
                x += number(); path.line(to: NSPoint(x: x, y: y))
            case "V":
                y = number(); path.line(to: NSPoint(x: x, y: y))
            case "v":
                y += number(); path.line(to: NSPoint(x: x, y: y))
            case "C":
                let x1 = number(), y1 = number()
                let x2 = number(), y2 = number()
                x = number(); y = number()
                path.curve(to: NSPoint(x: x, y: y),
                            controlPoint1: NSPoint(x: x1, y: y1),
                            controlPoint2: NSPoint(x: x2, y: y2))
            case "c":
                let x1 = x + number(), y1 = y + number()
                let x2 = x + number(), y2 = y + number()
                x += number(); y += number()
                path.curve(to: NSPoint(x: x, y: y),
                            controlPoint1: NSPoint(x: x1, y: y1),
                            controlPoint2: NSPoint(x: x2, y: y2))
            default:
                i += 1   // skip unsupported command
            }
        }
        return path
    }

    /// Splits SVG path data into command letters and numeric tokens, honoring
    /// SVG's implicit-delimiter rules (e.g. `0-12` → `["0", "-12"]` and
    /// `11.385.6` → `["11.385", ".6"]` — a sign or a second `.` after a digit
    /// begins a new number).
    private static func tokenize(_ d: String) -> [String] {
        let pattern = "[MLCZHVSTQmlczhvstq]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(d.startIndex..., in: d)
        return regex.matches(in: d, range: range).compactMap { match in
            guard let r = Range(match.range, in: d) else { return nil }
            return String(d[r])
        }
    }
}

private extension SVGPathParser {
    /// Returns a copy of `path` with each point mapped through
    /// `(scale * x, scale * (viewBox - y))` — i.e. uniformly scaled, and
    /// flipped vertically so an SVG (y-down) path renders upright in AppKit's
    /// y-up coordinate system. Implemented by walking path elements rather than
    /// going through `NSBezierPath.transform(using:)`, which has awkward
    /// `NSAffineTransform` ↔ `AffineTransform` bridging in modern Swift.
    static func transformed(_ path: NSBezierPath, scale: CGFloat, viewBox: CGFloat) -> NSBezierPath {
        let result = NSBezierPath()
        var pts = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<path.elementCount {
            let type = path.element(at: i, associatedPoints: &pts)
            let map = { (p: NSPoint) -> NSPoint in
                NSPoint(x: scale * p.x, y: scale * (viewBox - p.y))
            }
            switch type {
            case .moveTo:
                result.move(to: map(pts[0]))
            case .lineTo:
                result.line(to: map(pts[0]))
            case .curveTo:
                result.curve(to: map(pts[2]),
                              controlPoint1: map(pts[0]),
                              controlPoint2: map(pts[1]))
            case .closePath:
                result.close()
            default:
                break
            }
        }
        return result
    }
}

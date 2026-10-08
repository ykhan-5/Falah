import AppKit

/// Draws the menu bar symbol: sun, sunset or moon.
///
/// A template image, so macOS tints it to match light and dark menu bars like the
/// system's own icons. (The arc lives in the pop-out card instead.)
enum MenuBarIcon {
    static let size = NSSize(width: 16, height: 16)

    static func image(glyph: MenuBarGlyph?) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            switch glyph {
            case .sun: drawSun()
            case .sunset: drawSunset()
            case .moon: drawMoon()
            case nil: drawUnavailable()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = glyph.map { "Falah – \($0)" } ?? "Falah"
        return image
    }

    private static let center = CGPoint(x: 8, y: 8)

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// Filled disc with eight short rays.
    private static func drawSun() {
        circle(center, 3.4).fill()
        let rays = NSBezierPath()
        rays.lineWidth = 1.5
        rays.lineCapStyle = .round
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let (dx, dy) = (cos(angle), sin(angle))
            rays.move(to: CGPoint(x: center.x + 5.2 * dx, y: center.y + 5.2 * dy))
            rays.line(to: CGPoint(x: center.x + 7.0 * dx, y: center.y + 7.0 * dy))
        }
        rays.stroke()
    }

    /// A bit more than half a disc resting on a horizon line, with a small gap between them.
    private static func drawSunset() {
        let horizonY: CGFloat = 4.5
        let sunCenter = CGPoint(x: 8, y: horizonY + 1.8)
        let gap: CGFloat = 1.2

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 0, y: horizonY + gap, width: size.width, height: size.height)).addClip()
        circle(sunCenter, 5.6).fill()
        NSGraphicsContext.restoreGraphicsState()

        let horizon = NSBezierPath()
        horizon.lineWidth = 1.5
        horizon.lineCapStyle = .round
        horizon.move(to: CGPoint(x: 1, y: horizonY))
        horizon.line(to: CGPoint(x: 15, y: horizonY))
        horizon.stroke()
    }

    /// Crescent opening to the upper right.
    private static func drawMoon() {
        let r: CGFloat = 6.4
        let disc = circle(center, r)
        let bite = NSRect(x: center.x - r + 4.2, y: center.y - r + 2.4, width: r * 2, height: r * 2)

        NSGraphicsContext.saveGraphicsState()
        let clip = NSBezierPath(rect: NSRect(origin: .zero, size: size))
        clip.appendOval(in: bite)
        clip.windingRule = .evenOdd
        clip.addClip()
        disc.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Hollow circle when times can't be computed.
    private static func drawUnavailable() {
        let ring = circle(center, 5.5)
        ring.lineWidth = 1.5
        ring.stroke()
    }
}

extension NSColor {
    convenience init(_ rgb: RGB) {
        self.init(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

import SwiftUI

/// The sun's path: a half ellipse from sunrise (left) to sunset (right), with a shallow
/// dotted curve below the horizon for the night. Only sunrise and sunset are marked.
/// By day the traveled part is solid in the prayer's accent; at night the moon moves
/// along the lower curve.
struct ArcView: View {
    let snapshot: PrayerSnapshot
    let accent: Color

    private let labelHeight: CGFloat = 14
    private let nightDepth: CGFloat = 16
    private let horizonDot = Color(red: 0.60, green: 0.66, blue: 0.98)

    var body: some View {
        Canvas { context, size in
            let g = geometry(in: size)
            let schedule = snapshot.schedule

            // Horizon.
            var horizon = Path()
            horizon.move(to: flip(CGPoint(x: 0, y: g.horizonY), size))
            horizon.addLine(to: flip(CGPoint(x: size.width, y: g.horizonY), size))
            context.stroke(horizon, with: .color(.white.opacity(0.3)), lineWidth: 1)

            switch snapshot.arc {
            case .day(let f):
                stroke(&context, path(g, size, 0, f, night: false), color: accent, style: .solid)
                stroke(&context, path(g, size, f, 1, night: false), color: .white.opacity(0.35), style: .dashed)
                stroke(&context, path(g, size, 0, 1, night: true), color: .white.opacity(0.35), style: .dotted)
            case .night(let f):
                stroke(&context, path(g, size, 0, 1, night: false), color: .white.opacity(0.22), style: .solid)
                stroke(&context, path(g, size, 0, f, night: true), color: .white.opacity(0.7), style: .dotted)
                stroke(&context, path(g, size, f, 1, night: true), color: .white.opacity(0.3), style: .dotted)
            }

            // Sunrise and sunset.
            for end in [g.left, g.right] {
                let p = flip(end, size)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(horizonDot))
            }
            let baseline = size.height - labelHeight / 2
            context.draw(label("Sunrise", schedule.sunrise), at: CGPoint(x: flip(g.left, size).x - 8, y: baseline), anchor: .leading)
            context.draw(label("Sunset", schedule.maghrib), at: CGPoint(x: flip(g.right, size).x + 8, y: baseline), anchor: .trailing)

            // Sun or moon.
            let p = flip(g.point(for: snapshot.arc), size)
            if case .night = snapshot.arc {
                drawMoon(&context, at: p)
            } else {
                drawSun(&context, at: p)
            }
        }
        .accessibilityLabel("Path of the sun")
    }

    private func geometry(in size: CGSize) -> ArcGeometry {
        let horizonY = labelHeight + 6 + nightDepth
        return ArcGeometry(
            center: CGPoint(x: size.width / 2, y: horizonY),
            radiusX: size.width / 2 - 26,
            radiusY: size.height - horizonY - 14,
            nightDepth: nightDepth
        )
    }

    /// ArcGeometry is y-up; Canvas is y-down.
    private func flip(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x, y: size.height - p.y)
    }

    private func path(_ g: ArcGeometry, _ size: CGSize, _ a: Double, _ b: Double, night: Bool) -> Path {
        var path = Path()
        guard b > a else { return path }
        let steps = max(2, Int((b - a) * 80))
        for i in 0...steps {
            let f = a + (b - a) * Double(i) / Double(steps)
            let p = flip(g.point(for: night ? .night(f) : .day(f)), size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private enum LineStyle { case solid, dashed, dotted }

    private func stroke(_ context: inout GraphicsContext, _ path: Path, color: Color, style: LineStyle) {
        let stroke: StrokeStyle
        switch style {
        case .solid: stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .dashed: stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
        case .dotted: stroke = StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 6])
        }
        context.stroke(path, with: .color(color), style: stroke)
    }

    private func label(_ name: String, _ time: Date) -> Text {
        Text("\(name) \(time.formatted(date: .omitted, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
    }

    private func drawSun(_ context: inout GraphicsContext, at p: CGPoint) {
        let glow = CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36)
        context.fill(Path(ellipseIn: glow), with: .color(accent.opacity(0.28)))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(accent))
    }

    private func drawMoon(_ context: inout GraphicsContext, at p: CGPoint) {
        let glow = CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30)
        context.fill(Path(ellipseIn: glow), with: .color(.white.opacity(0.12)))
        let r: CGFloat = 7
        let crescent = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            .subtracting(Path(ellipseIn: CGRect(x: p.x - r + 4.5, y: p.y - r - 3, width: r * 2, height: r * 2)))
        context.fill(crescent, with: .color(.white.opacity(0.95)))
    }
}

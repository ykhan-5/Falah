import SwiftUI

/// The sun's path: sunrise on the left, Maghrib on the right, Dhuhr and Asr marked.
/// The traveled part is solid, the rest dashed. At night the arc dims and a moon moves
/// along a shallow curve below the horizon.
struct ArcView: View {
    let snapshot: PrayerSnapshot

    private let labelHeight: CGFloat = 14
    private let nightDepth: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let geometry = geometry(in: size)
            let schedule = snapshot.schedule
            let ink = GraphicsContext.Shading.color(.primary)

            // Horizon.
            var horizon = Path()
            horizon.move(to: flip(CGPoint(x: 0, y: geometry.horizonY), size))
            horizon.addLine(to: flip(CGPoint(x: size.width, y: geometry.horizonY), size))
            context.stroke(horizon, with: ink, style: StrokeStyle(lineWidth: 1))

            switch snapshot.arc {
            case .day(let f):
                stroke(&context, path(geometry, size, from: 0, to: f, night: false), opacity: 0.85, dashed: false)
                stroke(&context, path(geometry, size, from: f, to: 1, night: false), opacity: 0.45, dashed: true)
            case .night(let f):
                stroke(&context, path(geometry, size, from: 0, to: 1, night: false), opacity: 0.3, dashed: true)
                stroke(&context, path(geometry, size, from: 0, to: f, night: true), opacity: 0.6, dashed: false)
                stroke(&context, path(geometry, size, from: f, to: 1, night: true), opacity: 0.3, dashed: true)
            }

            // Dhuhr and Asr marks.
            for (name, date) in [("Dhuhr", schedule.dhuhr), ("Asr", schedule.asr)] {
                let p = flip(geometry.point(for: .day(schedule.dayFraction(of: date))), size)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.primary.opacity(0.6)))
                let label = Text("\(name) \(short(date))").font(.caption2).foregroundStyle(.secondary)
                // Dhuhr centered above its mark; Asr ends just right of its mark so it stays inside.
                let anchor: UnitPoint = name == "Dhuhr" ? .bottom : .bottomTrailing
                context.draw(label, at: CGPoint(x: p.x + (name == "Asr" ? 10 : 0), y: p.y - 6), anchor: anchor)
            }

            // Horizon labels, below the moon's path.
            let baseline = size.height - labelHeight
            context.draw(Text("Sunrise \(short(schedule.sunrise))").font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: geometry.left.x - 6, y: baseline), anchor: .topLeading)
            context.draw(Text("Maghrib \(short(schedule.maghrib))").font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: geometry.right.x + 6, y: baseline), anchor: .topTrailing)

            // Sun or moon.
            let body = flip(geometry.point(for: snapshot.arc), size)
            if case .night = snapshot.arc {
                drawMoon(&context, at: body)
            } else {
                drawSun(&context, at: body, color: Color(nsColor: NSColor(SkyPalette.accent(for: snapshot.phase))))
            }
        }
        .accessibilityLabel("Sun path")
    }

    private func geometry(in size: CGSize) -> ArcGeometry {
        let horizonY = labelHeight + 4 + nightDepth + 2
        return ArcGeometry(
            center: CGPoint(x: size.width / 2, y: horizonY),
            radiusX: size.width / 2 - 24,
            radiusY: size.height - horizonY - 18,
            nightDepth: nightDepth
        )
    }

    /// ArcGeometry is y-up; Canvas is y-down.
    private func flip(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x, y: size.height - p.y)
    }

    private func path(_ g: ArcGeometry, _ size: CGSize, from a: Double, to b: Double, night: Bool) -> Path {
        var path = Path()
        guard b > a else { return path }
        let steps = max(2, Int((b - a) * 64))
        for i in 0...steps {
            let f = a + (b - a) * Double(i) / Double(steps)
            let p = flip(g.point(for: night ? .night(f) : .day(f)), size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private func stroke(_ context: inout GraphicsContext, _ path: Path, opacity: Double, dashed: Bool) {
        context.stroke(
            path,
            with: .color(.primary.opacity(opacity)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: dashed ? [3, 4] : [])
        )
    }

    private func drawSun(_ context: inout GraphicsContext, at p: CGPoint, color: Color) {
        let glow = CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [color.opacity(0.55), color.opacity(0)]),
            center: p, startRadius: 2, endRadius: 22
        ))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(color))
    }

    private func drawMoon(_ context: inout GraphicsContext, at p: CGPoint) {
        let r: CGFloat = 6
        var crescent = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        crescent = crescent.subtracting(Path(ellipseIn: CGRect(x: p.x - r + 4, y: p.y - r - 2.5, width: r * 2, height: r * 2)))
        context.fill(crescent, with: .color(.primary.opacity(0.85)))
    }

    private func short(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

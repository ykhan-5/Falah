import CoreGraphics
import Foundation

/// Maps an `ArcPosition` onto the drawn arc: a half ellipse standing on a horizon line,
/// sunrise at the left end, Maghrib at the right, Dhuhr-ish at the top. At night the moon
/// travels back right → left along a shallow curve below the horizon.
///
/// Coordinates are y-up (AppKit default): `horizonY` is the baseline, the arc rises above it.
struct ArcGeometry: Equatable {
    var center: CGPoint
    var radiusX: CGFloat
    var radiusY: CGFloat
    var nightDepth: CGFloat

    var horizonY: CGFloat { center.y }
    var left: CGPoint { CGPoint(x: center.x - radiusX, y: center.y) }
    var right: CGPoint { CGPoint(x: center.x + radiusX, y: center.y) }

    func point(for position: ArcPosition) -> CGPoint {
        switch position {
        case .day(let f):
            let angle = Double.pi * (1 - clamp(f))
            return CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle))
        case .night(let f):
            let angle = Double.pi * clamp(f)
            return CGPoint(x: center.x + radiusX * cos(angle), y: center.y - nightDepth * sin(angle))
        }
    }

    private func clamp(_ f: Double) -> Double { max(0, min(1, f)) }
}

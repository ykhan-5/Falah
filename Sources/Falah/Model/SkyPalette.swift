import Foundation

/// Plain RGB color, kept free of AppKit so the palette is unit-testable.
struct RGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `0xRRGGBB`.
    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

/// Sky colors per phase. Card backgrounds and blending arrive in milestone 5.
enum SkyPalette {
    static func accent(for phase: SkyPhase) -> RGB {
        switch phase {
        case .fajr: RGB(hex: 0x3D5A8A)
        case .morning: RGB(hex: 0x8CC0EA)
        case .dhuhr: RGB(hex: 0xE0B84A)
        case .asr: RGB(hex: 0xE0902E)
        case .maghrib: RGB(hex: 0xD4607A)
        case .isha: RGB(hex: 0x2A3360)
        }
    }
}

import Foundation

/// Which symbol the menu bar shows for a sky phase.
enum MenuBarGlyph: Equatable {
    /// Fajr through Asr.
    case sun
    /// Maghrib: a sun sinking into the horizon.
    case sunset
    /// Isha.
    case moon

    init(phase: SkyPhase) {
        switch phase {
        case .fajr, .morning, .dhuhr, .asr: self = .sun
        case .maghrib: self = .sunset
        case .isha: self = .moon
        }
    }
}

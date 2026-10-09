import Adhan
import Foundation
import Observation

/// What the pop-out card shows. Updated by the AppDelegate on every refresh.
@Observable
final class CardModel {
    var snapshot: PrayerSnapshot?
    var problem: CardProblem?
    var locationName = ""
    var settings = PrayerSettings()
    var style: CardStyle = .sky

    /// Glass only where the system supports it.
    var usesGlass: Bool {
        if #available(macOS 26, *) { return style == .glass }
        return false
    }

    @ObservationIgnored var onSettings: () -> Void = {}
    @ObservationIgnored var onQuit: () -> Void = {}

    /// "Houston · ISNA · Asr: Standard"
    var footerText: String {
        "\(locationName) · \(settings.method.shortName) · Asr: \(settings.madhab == .hanafi ? "Hanafi" : "Standard")"
    }
}

/// Why the card can't show times.
enum CardProblem: Equatable {
    case locating
    case locationDenied
    case calculationFailed

    var title: String {
        switch self {
        case .locating: "Finding your location…"
        case .locationDenied: "Location is off"
        case .calculationFailed: "Prayer times unavailable"
        }
    }

    var message: String {
        switch self {
        case .locating: "Falah needs your location once to calculate prayer times. You can also set a city in Settings."
        case .locationDenied: "Allow Falah in System Settings → Privacy & Security → Location Services, or set your city in Falah Settings."
        case .calculationFailed: "Times can't be calculated for this location and date. Try a different high-latitude rule in Settings."
        }
    }
}

extension CalculationMethod {
    var shortName: String {
        switch self {
        case .muslimWorldLeague: "MWL"
        case .egyptian: "Egyptian"
        case .karachi: "Karachi"
        case .ummAlQura: "Umm al-Qura"
        case .dubai: "Dubai"
        case .moonsightingCommittee: "Moonsighting"
        case .northAmerica: "ISNA"
        case .kuwait: "Kuwait"
        case .qatar: "Qatar"
        case .singapore: "Singapore"
        case .tehran: "Tehran"
        case .turkey: "Turkey"
        case .other: "Custom"
        }
    }
}

extension PrayerName {
    /// The sky phase that starts with this prayer, for its list dot color.
    var phase: SkyPhase {
        switch self {
        case .fajr: .fajr
        case .dhuhr: .dhuhr
        case .asr: .asr
        case .maghrib: .maghrib
        case .isha: .isha
        }
    }
}

extension SkyPhase {
    /// Header title when no prayer is current (only the morning gap).
    var title: String {
        switch self {
        case .morning: "Morning"
        default: rawValue.capitalized
        }
    }
}

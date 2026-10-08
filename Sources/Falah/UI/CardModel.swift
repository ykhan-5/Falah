import Adhan
import Foundation
import Observation

/// What the pop-out card shows. Updated by the AppDelegate on every refresh.
@Observable
final class CardModel {
    var snapshot: PrayerSnapshot?
    var isUnavailable = false
    var locationName = "Houston"
    var settings = PrayerSettings()

    @ObservationIgnored var onSettings: () -> Void = {}
    @ObservationIgnored var onQuit: () -> Void = {}

    /// "Houston · ISNA · Asr: Standard"
    var footerText: String {
        "\(locationName) · \(settings.method.shortName) · Asr: \(settings.madhab == .hanafi ? "Hanafi" : "Standard")"
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

import Adhan
import Foundation
import Observation

enum LocationMode: String, CaseIterable {
    /// Location Services, cached; falls back to the typed city if unavailable.
    case automatic
    /// A typed city or coordinates.
    case manual
}

/// How the card is drawn. Liquid Glass needs macOS 26; older systems always use Sky.
enum CardStyle: String, CaseIterable {
    /// Opaque sky gradient.
    case sky
    /// macOS 26 Liquid Glass, tinted with the sky.
    case glass
}

struct SavedPlace: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinates: Coordinates { Coordinates(latitude: latitude, longitude: longitude) }
}

/// All user settings, persisted in UserDefaults. Every change is saved immediately and
/// reported through `onChange` so the menu bar and card update right away.
@Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onChange: (() -> Void)?

    var locationMode: LocationMode { didSet { set(locationMode.rawValue, Key.locationMode) } }
    /// Last fix from Location Services.
    var autoPlace: SavedPlace? { didSet { setCodable(autoPlace, Key.autoPlace) } }
    /// Typed city or coordinates.
    var manualPlace: SavedPlace? { didSet { setCodable(manualPlace, Key.manualPlace) } }

    var method: CalculationMethod { didSet { set(method.rawValue, Key.method) } }
    var madhab: Madhab { didSet { set(madhab.rawValue, Key.madhab) } }
    /// nil = automatic.
    var highLatitudeRule: HighLatitudeRule? { didSet { set(highLatitudeRule?.rawValue ?? "", Key.highLatitudeRule) } }

    /// The masjid-offset toggle: offsets only apply while this is on.
    var adjustmentsEnabled: Bool { didSet { set(adjustmentsEnabled, Key.adjustmentsEnabled) } }
    var adjustments: [PrayerName: Int] {
        didSet { set(Dictionary(uniqueKeysWithValues: adjustments.map { ($0.key.rawValue, $0.value) }), Key.adjustments) }
    }

    var showsCountdownText: Bool { didSet { set(showsCountdownText, Key.showsCountdownText) } }
    var notificationsEnabled: Bool { didSet { set(notificationsEnabled, Key.notificationsEnabled) } }
    /// 0 = no reminder.
    var reminderMinutes: Int { didSet { set(reminderMinutes, Key.reminderMinutes) } }
    /// Background flash at each prayer, "#RRGGBB".
    var momentColorHex: String { didSet { set(momentColorHex, Key.momentColorHex) } }
    var cardStyle: CardStyle { didSet { set(cardStyle.rawValue, Key.cardStyle) } }

    static let defaultMomentColorHex = "#FF9F0A" // system orange
    static let reminderChoices = [0, 5, 10, 15, 20, 30]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        locationMode = defaults.string(forKey: Key.locationMode).flatMap(LocationMode.init) ?? .automatic
        autoPlace = Self.decode(defaults.data(forKey: Key.autoPlace))
        manualPlace = Self.decode(defaults.data(forKey: Key.manualPlace))
        method = defaults.string(forKey: Key.method).flatMap(CalculationMethod.init) ?? .northAmerica
        madhab = (defaults.object(forKey: Key.madhab) as? Int).flatMap(Madhab.init) ?? .shafi
        highLatitudeRule = defaults.string(forKey: Key.highLatitudeRule).flatMap(HighLatitudeRule.init)
        adjustmentsEnabled = defaults.bool(forKey: Key.adjustmentsEnabled)
        let raw = defaults.dictionary(forKey: Key.adjustments) as? [String: Int] ?? [:]
        adjustments = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in PrayerName(rawValue: key).map { ($0, value) } })
        showsCountdownText = defaults.object(forKey: Key.showsCountdownText) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
        reminderMinutes = defaults.object(forKey: Key.reminderMinutes) as? Int ?? 0
        momentColorHex = defaults.string(forKey: Key.momentColorHex) ?? Self.defaultMomentColorHex
        cardStyle = defaults.string(forKey: Key.cardStyle).flatMap(CardStyle.init) ?? .glass
    }

    /// Where times are calculated for: the automatic fix, or the typed place. In automatic
    /// mode without a fix yet (or with Location Services denied), the typed place is used.
    var activePlace: SavedPlace? {
        switch locationMode {
        case .automatic: autoPlace ?? manualPlace
        case .manual: manualPlace
        }
    }

    var prayerSettings: PrayerSettings {
        var settings = PrayerSettings()
        settings.method = method
        settings.madhab = madhab
        settings.highLatitudeRule = highLatitudeRule
        settings.adjustments = adjustmentsEnabled ? adjustments : [:]
        return settings
    }

    // MARK: Persistence

    private enum Key {
        static let locationMode = "locationMode"
        static let autoPlace = "autoPlace"
        static let manualPlace = "manualPlace"
        static let method = "method"
        static let madhab = "madhab"
        static let highLatitudeRule = "highLatitudeRule"
        static let adjustmentsEnabled = "adjustmentsEnabled"
        static let adjustments = "adjustments"
        static let showsCountdownText = "showsCountdownText"
        static let notificationsEnabled = "notificationsEnabled"
        static let reminderMinutes = "reminderMinutes"
        static let momentColorHex = "momentColorHex"
        static let cardStyle = "cardStyle"
    }

    private func set(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }

    private func setCodable<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        onChange?()
    }

    private static func decode<T: Decodable>(_ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

extension RGB {
    /// Parses "#RRGGBB" or "RRGGBB".
    init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(hex: value)
    }

    var hexString: String {
        func byte(_ c: Double) -> Int { Int((max(0, min(1, c)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

extension CalculationMethod {
    /// Full name for the Settings picker.
    var displayName: String {
        switch self {
        case .northAmerica: "ISNA (North America)"
        case .muslimWorldLeague: "Muslim World League"
        case .egyptian: "Egyptian General Authority"
        case .karachi: "University of Islamic Sciences, Karachi"
        case .ummAlQura: "Umm al-Qura, Makkah"
        case .dubai: "Dubai"
        case .moonsightingCommittee: "Moonsighting Committee"
        case .kuwait: "Kuwait"
        case .qatar: "Qatar"
        case .singapore: "Singapore"
        case .tehran: "Institute of Geophysics, Tehran"
        case .turkey: "Diyanet, Turkey"
        case .other: "Custom"
        }
    }
}

extension HighLatitudeRule {
    var displayName: String {
        switch self {
        case .middleOfTheNight: "Middle of the night"
        case .seventhOfTheNight: "Seventh of the night"
        case .twilightAngle: "Twilight angle"
        }
    }
}

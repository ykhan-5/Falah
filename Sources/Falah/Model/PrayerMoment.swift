import Foundation

/// Detects the moment a prayer begins, and the wording of its notifications.
enum PrayerMoment {
    /// How recently a prayer must have started to count as "just began". Keeps a launch or
    /// wake in the middle of Asr from firing the Asr moment.
    static let freshness: TimeInterval = 120

    /// The prayer that has just begun between two refreshes, if any.
    static func justBegan(previous: PrayerSnapshot?, current: PrayerSnapshot) -> PrayerInterval? {
        guard let previous, let interval = current.current, interval != previous.current else { return nil }
        let age = current.now.timeIntervalSince(interval.start)
        return age >= 0 && age < freshness ? interval : nil
    }

    /// "It's time for Asr · 4:28 PM"
    static func title(for prayer: PrayerName, at start: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        "It's time for \(prayer.displayName) · \(MenuBarText.shortTime(start, timeZone: timeZone, locale: locale))"
    }

    /// "Asr in 10 min · 4:28 PM"
    static func reminderTitle(for prayer: PrayerName, at start: Date, minutesBefore: Int, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        "\(prayer.displayName) in \(minutesBefore) min · \(MenuBarText.shortTime(start, timeZone: timeZone, locale: locale))"
    }
}

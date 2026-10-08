import Foundation

/// The short text beside the menu bar icon: "Asr in 32m" under an hour, "Asr 4:30 PM" otherwise.
enum MenuBarText {
    static func text(
        for snapshot: PrayerSnapshot,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        text(prayer: snapshot.next.prayer, start: snapshot.next.start, now: snapshot.now, timeZone: timeZone, locale: locale)
    }

    static func text(
        prayer: PrayerName,
        start: Date,
        now: Date,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        let minutes = minutesUntil(start, from: now)
        if minutes < 60 {
            return "\(prayer.displayName) in \(minutes)m"
        }
        return "\(prayer.displayName) \(shortTime(start, timeZone: timeZone, locale: locale))"
    }

    /// Whole minutes remaining, rounded up so "in 1m" shows until the moment arrives.
    static func minutesUntil(_ date: Date, from now: Date) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    }

    /// "4:30 PM" in 12-hour locales, "16:30" in 24-hour locales.
    static func shortTime(_ date: Date, timeZone: TimeZone, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }
}

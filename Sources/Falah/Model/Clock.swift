import Foundation

/// Source of "now" for the whole app.
///
/// With `--debug-time "2026-10-08T16:29:00"` (local time) the clock starts at that
/// moment and keeps ticking in real time, so prayer moments can be tested without waiting.
struct AppClock {
    /// Seconds added to the real clock. Zero when not faking time.
    let offset: TimeInterval

    init(offset: TimeInterval = 0) {
        self.offset = offset
    }

    var isFaked: Bool { offset != 0 }

    func now() -> Date {
        Date().addingTimeInterval(offset)
    }

    /// Builds a clock from launch arguments. Falls back to the real clock if the
    /// argument is missing or unparseable.
    static func fromArguments(
        _ arguments: [String] = CommandLine.arguments,
        realNow: Date = Date(),
        timeZone: TimeZone = .current
    ) -> AppClock {
        guard let index = arguments.firstIndex(of: "--debug-time"),
              index + 1 < arguments.count,
              let fake = parseDebugTime(arguments[index + 1], timeZone: timeZone)
        else {
            return AppClock()
        }
        return AppClock(offset: fake.timeIntervalSince(realNow))
    }

    /// Parses "yyyy-MM-dd'T'HH:mm:ss" (seconds optional) as local wall-clock time.
    static func parseDebugTime(_ string: String, timeZone: TimeZone = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}

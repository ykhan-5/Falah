import Foundation

/// Source of "now" for the whole app.
///
/// With `--debug-time "2026-10-08T16:29:00"` (local time) the clock starts at that
/// moment and keeps ticking, so prayer moments can be tested without waiting.
/// `--debug-speed 300` makes it run 300× faster, to scrub through a day and watch the sky.
struct AppClock {
    /// Seconds added to the real clock at `anchor`. Zero when not faking time.
    let offset: TimeInterval
    /// Clock seconds per real second. 1 is real time.
    let speed: Double
    /// Real moment the clock started.
    let anchor: Date

    init(offset: TimeInterval = 0, speed: Double = 1, anchor: Date = Date()) {
        self.offset = offset
        self.speed = speed > 0 ? speed : 1
        self.anchor = anchor
    }

    var isFaked: Bool { offset != 0 || speed != 1 }

    func now(real: Date = Date()) -> Date {
        anchor.addingTimeInterval(offset + real.timeIntervalSince(anchor) * speed)
    }

    /// Real seconds to wait for `interval` seconds to pass on this clock.
    func realInterval(for interval: TimeInterval) -> TimeInterval {
        interval / speed
    }

    /// Builds a clock from launch arguments. Falls back to the real clock if the
    /// arguments are missing or unparseable.
    static func fromArguments(
        _ arguments: [String] = CommandLine.arguments,
        realNow: Date = Date(),
        timeZone: TimeZone = .current
    ) -> AppClock {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        let fake = value(after: "--debug-time").flatMap { parseDebugTime($0, timeZone: timeZone) }
        let speed = value(after: "--debug-speed").flatMap(Double.init) ?? 1
        return AppClock(offset: fake.map { $0.timeIntervalSince(realNow) } ?? 0, speed: speed, anchor: realNow)
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

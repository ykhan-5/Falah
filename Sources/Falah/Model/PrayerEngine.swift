import Adhan
import Foundation

// Pure prayer-time logic: date + location + settings in, times / current / next / arc out.
// No UI code here. All astronomy comes from Adhan.

/// The five daily prayers (sunrise is a boundary, not a prayer).
enum PrayerName: String, CaseIterable, Codable {
    case fajr, dhuhr, asr, maghrib, isha

    var displayName: String { rawValue.capitalized }
}

/// The six sky phases from the spec, used for coloring. Unlike prayers, phases cover
/// every moment of the day: `morning` is sunrise → Dhuhr, and `isha` runs to the next Fajr.
enum SkyPhase: String, CaseIterable {
    case fajr, morning, dhuhr, asr, maghrib, isha
}

struct PrayerSettings: Equatable {
    var method: CalculationMethod = .northAmerica
    /// Standard (Shafi'i, Maliki, Hanbali) by default; Hanafi is a setting.
    var madhab: Madhab = .shafi
    /// nil lets Adhan choose based on latitude.
    var highLatitudeRule: HighLatitudeRule? = nil
    /// Per-prayer minute offsets, -10...10, to match a local masjid.
    var adjustments: [PrayerName: Int] = [:]

    /// Real methods only: Adhan's `.other` is a blank template with zero angles.
    static let selectableMethods = CalculationMethod.allCases.filter { $0 != .other }

    var calculationParameters: CalculationParameters {
        var params = method.params
        params.madhab = madhab
        params.highLatitudeRule = highLatitudeRule
        func offset(_ prayer: PrayerName) -> Int { max(-10, min(10, adjustments[prayer] ?? 0)) }
        params.adjustments = PrayerAdjustments(
            fajr: offset(.fajr),
            dhuhr: offset(.dhuhr),
            asr: offset(.asr),
            maghrib: offset(.maghrib),
            isha: offset(.isha)
        )
        return params
    }
}

/// One prayer's window, used to decide the current prayer. Only start times are shown
/// in the UI. `day` is the local start of the day the prayer belongs to.
struct PrayerInterval: Equatable {
    let prayer: PrayerName
    let start: Date
    let end: Date
    let day: Date

    func contains(_ date: Date) -> Bool { start <= date && date < end }
}

/// All times for one local calendar day.
struct DaySchedule: Equatable {
    let day: Date
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    /// Start of the last third of the night (Maghrib → next Fajr), early the next morning.
    let lastThird: Date
    let nextFajr: Date

    func start(of prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr: fajr
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }

    /// Fajr ends at sunrise; every other prayer lasts until the next one starts.
    func end(of prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr: sunrise
        case .dhuhr: asr
        case .asr: maghrib
        case .maghrib: isha
        case .isha: nextFajr
        }
    }

    var intervals: [PrayerInterval] {
        PrayerName.allCases.map { PrayerInterval(prayer: $0, start: start(of: $0), end: end(of: $0), day: day) }
    }

    /// Where `date` falls between sunrise (0) and Maghrib (1), clamped. Used to place the
    /// Dhuhr and Asr marks on the card's arc.
    func dayFraction(of date: Date) -> Double {
        let total = maghrib.timeIntervalSince(sunrise)
        guard total > 0 else { return 0 }
        return max(0, min(1, date.timeIntervalSince(sunrise) / total))
    }

    /// Phase boundaries in order, each marking the start of a phase.
    var phaseStarts: [(phase: SkyPhase, start: Date)] {
        [(.fajr, fajr), (.morning, sunrise), (.dhuhr, dhuhr), (.asr, asr), (.maghrib, maghrib), (.isha, isha)]
    }
}

/// Where the sun (or moon) sits on the arc.
enum ArcPosition: Equatable {
    /// 0 at sunrise (left) → 1 at Maghrib (right), along the half ellipse.
    case day(Double)
    /// 0 at Maghrib → 1 at the next Fajr, below the horizon. Holds at 1 from Fajr to sunrise.
    case night(Double)
}

/// Everything the UI needs about one instant.
struct PrayerSnapshot: Equatable {
    let now: Date
    /// The day whose list the card should show: the current prayer's day, otherwise
    /// the next prayer's day. After midnight this stays on yesterday until Fajr.
    let schedule: DaySchedule
    /// The prayer whose window contains `now`; nil only between sunrise and Dhuhr.
    let current: PrayerInterval?
    let next: PrayerInterval
    let phase: SkyPhase
    let arc: ArcPosition

    var timeUntilNext: TimeInterval { next.start.timeIntervalSince(now) }
}

enum PrayerEngineError: Error, Equatable {
    /// Adhan couldn't compute times (e.g. extreme latitudes) for this local date.
    case calculationFailed(year: Int, month: Int, day: Int)
}

struct PrayerEngine {
    var coordinates: Coordinates
    var settings: PrayerSettings
    var timeZone: TimeZone

    init(coordinates: Coordinates, settings: PrayerSettings = PrayerSettings(), timeZone: TimeZone = .current) {
        self.coordinates = coordinates
        self.settings = settings
        self.timeZone = timeZone
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Times for the local day containing `date`.
    func schedule(for date: Date) throws -> DaySchedule {
        let calendar = self.calendar
        let day = calendar.startOfDay(for: date)
        let params = settings.calculationParameters
        let today = try prayerTimes(for: day, params: params)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let tomorrow = try prayerTimes(for: nextDay, params: params)
        guard let sunnah = SunnahTimes(from: today) else { throw failure(for: day) }

        return DaySchedule(
            day: day,
            fajr: today.fajr,
            sunrise: today.sunrise,
            dhuhr: today.dhuhr,
            asr: today.asr,
            maghrib: today.maghrib,
            isha: today.isha,
            lastThird: sunnah.lastThirdOfTheNight,
            nextFajr: tomorrow.fajr
        )
    }

    /// Current/next prayer, phase and arc position at `now`.
    ///
    /// Looks at yesterday, today and tomorrow so the edges just work: before Fajr the
    /// current prayer is yesterday's Isha, and after Isha the next one is tomorrow's Fajr.
    func snapshot(at now: Date) throws -> PrayerSnapshot {
        let calendar = self.calendar
        let today = calendar.startOfDay(for: now)
        let days = try [-1, 0, 1].map { offset in
            try schedule(for: calendar.date(byAdding: .day, value: offset, to: today)!)
        }

        let intervals = days.flatMap(\.intervals)
        let current = intervals.last { $0.contains(now) }
        guard let next = intervals.first(where: { $0.start > now }) else {
            throw failure(for: today)
        }
        let shownDay = current?.day ?? next.day
        let shownSchedule = days.first { $0.day == shownDay }!

        let phaseStarts = days.flatMap(\.phaseStarts)
        let phase = phaseStarts.last { $0.start <= now }?.phase ?? .isha

        return PrayerSnapshot(
            now: now,
            schedule: shownSchedule,
            current: current,
            next: next,
            phase: phase,
            arc: arcPosition(at: now, days: days)
        )
    }

    private func arcPosition(at now: Date, days: [DaySchedule]) -> ArcPosition {
        // Daytime: sunrise ≤ now < Maghrib of the same day.
        if let day = days.first(where: { $0.sunrise <= now && now < $0.maghrib }) {
            return .day(fraction(now, from: day.sunrise, to: day.maghrib))
        }
        // Night: from the latest Maghrib before now toward the following Fajr.
        if let evening = days.last(where: { $0.maghrib <= now }) {
            return .night(fraction(now, from: evening.maghrib, to: evening.nextFajr))
        }
        return .night(1)
    }

    private func fraction(_ now: Date, from start: Date, to end: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return max(0, min(1, now.timeIntervalSince(start) / total))
    }

    private func prayerTimes(for day: Date, params: CalculationParameters) throws -> PrayerTimes {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        guard let times = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else {
            throw failure(for: day)
        }
        return times
    }

    private func failure(for day: Date) -> PrayerEngineError {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return .calculationFailed(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }
}

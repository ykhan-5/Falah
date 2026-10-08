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

    static let white = RGB(red: 1, green: 1, blue: 1)

    /// Linear blend: `t = 0` is self, `t = 1` is `other`.
    func mixed(with other: RGB, _ t: Double) -> RGB {
        let t = max(0, min(1, t))
        return RGB(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, 1…21.
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (l1, l2) = (a.luminance, b.luminance)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}

/// The four skies the card background moves through.
enum SkyPeriod: String, CaseIterable {
    /// Fajr → 40 min after sunrise.
    case dawn
    /// Until 1 hr before Maghrib.
    case day
    /// Until Isha.
    case sunset
    /// Until Fajr.
    case night

    var next: SkyPeriod {
        switch self {
        case .dawn: .day
        case .day: .sunset
        case .sunset: .night
        case .night: .dawn
        }
    }
}

/// A vertical background gradient. All four skies are dark enough for white text.
struct SkyGradient: Equatable {
    var top: RGB
    var bottom: RGB
    /// 0…1, how visible the stars are.
    var stars: Double

    func mixed(with other: SkyGradient, _ t: Double) -> SkyGradient {
        SkyGradient(
            top: top.mixed(with: other.top, t),
            bottom: bottom.mixed(with: other.bottom, t),
            stars: stars + (other.stars - stars) * max(0, min(1, t))
        )
    }
}

enum SkyPalette {
    /// Each sky starts blending into the next this long before its boundary.
    static let blendDuration: TimeInterval = 20 * 60
    static let dawnLastsAfterSunrise: TimeInterval = 40 * 60
    static let sunsetStartsBeforeMaghrib: TimeInterval = 60 * 60

    static func gradient(for period: SkyPeriod) -> SkyGradient {
        switch period {
        case .dawn: SkyGradient(top: RGB(hex: 0x2C3566), bottom: RGB(hex: 0x7A5677), stars: 0.15)
        case .day: SkyGradient(top: RGB(hex: 0x2A65B0), bottom: RGB(hex: 0x4474AA), stars: 0)
        case .sunset: SkyGradient(top: RGB(hex: 0x222A4E), bottom: RGB(hex: 0x6E4636), stars: 0)
        case .night: SkyGradient(top: RGB(hex: 0x0B1029), bottom: RGB(hex: 0x1F2650), stars: 1)
        }
    }

    /// The four skies laid out over one prayer day (Fajr → next Fajr).
    static func periods(for s: DaySchedule) -> [(period: SkyPeriod, start: Date, end: Date)] {
        var dawnEnd = s.sunrise.addingTimeInterval(dawnLastsAfterSunrise)
        var dayEnd = s.maghrib.addingTimeInterval(-sunsetStartsBeforeMaghrib)
        if dayEnd < dawnEnd {
            // Very short days: split the difference rather than overlapping.
            let mid = Date(timeIntervalSince1970: (dawnEnd.timeIntervalSince1970 + dayEnd.timeIntervalSince1970) / 2)
            (dawnEnd, dayEnd) = (mid, mid)
        }
        let sunsetEnd = max(s.isha, dayEnd)
        return [
            (.dawn, s.fajr, dawnEnd),
            (.day, dawnEnd, dayEnd),
            (.sunset, dayEnd, sunsetEnd),
            (.night, sunsetEnd, s.nextFajr),
        ]
    }

    static func period(at now: Date, schedule: DaySchedule) -> SkyPeriod {
        periods(for: schedule).first { $0.start <= now && now < $0.end }?.period
            ?? (now < schedule.fajr ? .night : .dawn)
    }

    /// The background at `now`, blending smoothly into the next sky over the last
    /// `blendDuration` of each period so there's never a hard jump.
    static func sky(at now: Date, schedule: DaySchedule) -> SkyGradient {
        guard let current = periods(for: schedule).first(where: { $0.start <= now && now < $0.end }) else {
            return gradient(for: period(at: now, schedule: schedule))
        }
        let base = gradient(for: current.period)
        let remaining = current.end.timeIntervalSince(now)
        guard remaining < blendDuration else { return base }
        let t = 1 - remaining / blendDuration
        let eased = t * t * (3 - 2 * t)
        return base.mixed(with: gradient(for: current.period.next), eased)
    }

    /// Prayer accents, brightened from the spec's table so they read on the dark skies.
    static func accent(for phase: SkyPhase) -> RGB {
        switch phase {
        case .fajr: RGB(hex: 0x8EA6D8)
        case .morning: RGB(hex: 0x8CC0EA)
        case .dhuhr: RGB(hex: 0xE8C25A)
        case .asr: RGB(hex: 0xF0A040)
        case .maghrib: RGB(hex: 0xF07C98)
        case .isha: RGB(hex: 0x9AA4F0)
        }
    }
}

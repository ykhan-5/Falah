import CoreGraphics
import Foundation
import Testing
@testable import Falah

struct MenuBarTextTests {
    let chicago = TimeZone(identifier: "America/Chicago")!
    let us = Locale(identifier: "en_US")
    let start = Date(timeIntervalSinceReferenceDate: 813_190_080) // a whole minute

    func text(secondsBefore seconds: TimeInterval, locale: Locale? = nil) -> String {
        MenuBarText.text(prayer: .asr, start: start, now: start.addingTimeInterval(-seconds), timeZone: chicago, locale: locale ?? us)
    }

    @Test func underAnHourShowsCountdown() {
        #expect(text(secondsBefore: 32 * 60) == "Asr in 32m")
        #expect(text(secondsBefore: 59 * 60) == "Asr in 59m")
    }

    @Test func countdownRoundsUp() {
        #expect(text(secondsBefore: 31 * 60 + 1) == "Asr in 32m")
        #expect(text(secondsBefore: 1) == "Asr in 1m")
    }

    @Test func anHourOrMoreShowsTimeWithAMPM() {
        let s = MenuBarText.text(prayer: .asr, start: date("2026-10-08 16:28"), now: date("2026-10-08 13:00"), timeZone: chicago, locale: us)
        // ICU puts a narrow no-break space before AM/PM.
        #expect(s.replacingOccurrences(of: "\u{202F}", with: " ") == "Asr 4:28 PM")
        #expect(text(secondsBefore: 59 * 60 + 1).hasPrefix("Asr ") && !text(secondsBefore: 59 * 60 + 1).contains(" in "))
    }

    @Test func twentyFourHourLocale() {
        let s = MenuBarText.text(prayer: .maghrib, start: date("2026-10-08 18:59"), now: date("2026-10-08 13:00"), timeZone: chicago, locale: Locale(identifier: "en_GB"))
        #expect(s == "Maghrib 18:59")
    }

    func date(_ string: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = chicago
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: string)!
    }
}

struct ArcGeometryTests {
    let g = ArcGeometry(center: CGPoint(x: 11, y: 3), radiusX: 9, radiusY: 8, nightDepth: 2)

    func near(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < 1e-9 && abs(a.y - b.y) < 1e-9 }

    @Test func dayRunsLeftToRightOverTheTop() {
        #expect(near(g.point(for: .day(0)), CGPoint(x: 2, y: 3)))
        #expect(near(g.point(for: .day(0.5)), CGPoint(x: 11, y: 11)))
        #expect(near(g.point(for: .day(1)), CGPoint(x: 20, y: 3)))
    }

    @Test func nightRunsRightToLeftBelowTheHorizon() {
        #expect(near(g.point(for: .night(0)), CGPoint(x: 20, y: 3)))
        #expect(near(g.point(for: .night(0.5)), CGPoint(x: 11, y: 1)))
        #expect(near(g.point(for: .night(1)), CGPoint(x: 2, y: 3)))
    }

    @Test func fractionsAreClamped() {
        #expect(g.point(for: .day(1.5)) == g.point(for: .day(1)))
        #expect(g.point(for: .night(-1)) == g.point(for: .night(0)))
    }
}

struct SchedulerTests {
    @Test func delayLandsJustPastTheNextMinute() {
        let base = Date(timeIntervalSinceReferenceDate: 60 * 1000)
        #expect(abs(Scheduler.delayUntilNextMinute(from: base.addingTimeInterval(15)) - 45.05) < 1e-6)
        #expect(abs(Scheduler.delayUntilNextMinute(from: base.addingTimeInterval(59.9)) - 0.15) < 1e-6)
        // Exactly on a boundary: wait for the next one.
        #expect(abs(Scheduler.delayUntilNextMinute(from: base) - 60.05) < 1e-6)
    }
}


struct MenuBarGlyphTests {
    @Test(arguments: [
        (SkyPhase.fajr, MenuBarGlyph.sun),
        (.morning, .sun),
        (.dhuhr, .sun),
        (.asr, .sun),
        (.maghrib, .sunset),
        (.isha, .moon),
    ])
    func glyphForPhase(phase: SkyPhase, glyph: MenuBarGlyph) {
        #expect(MenuBarGlyph(phase: phase) == glyph)
    }
}

struct CardLogicTests {
    let now = Date(timeIntervalSinceReferenceDate: 813_190_080)

    @Test func longCountdown() {
        #expect(MenuBarText.longCountdown(to: now.addingTimeInterval(32 * 60), from: now) == "in 32 min")
        #expect(MenuBarText.longCountdown(to: now.addingTimeInterval(91 * 60), from: now) == "in 1 hr 31 min")
        #expect(MenuBarText.longCountdown(to: now.addingTimeInterval(120 * 60), from: now) == "in 2 hr")
        #expect(MenuBarText.longCountdown(to: now.addingTimeInterval(59 * 60 + 1), from: now) == "in 1 hr")
    }

    @Test func panelSitsUnderTheItemAndStaysOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 950)
        let size = CGSize(width: 360, height: 420)
        let centered = PopoverController.panelFrame(size: size, under: CGRect(x: 700, y: 950, width: 120, height: 24), in: visible)
        #expect(centered == CGRect(x: 580, y: 524, width: 360, height: 420))
        // Item near the right edge: clamp 8 pt inside.
        let clamped = PopoverController.panelFrame(size: size, under: CGRect(x: 1450, y: 950, width: 60, height: 24), in: visible)
        #expect(clamped.maxX == 1504)
    }

    @Test func hoverRegionIncludesCorridor() {
        let button = CGRect(x: 700, y: 950, width: 120, height: 24)
        let panel = CGRect(x: 580, y: 524, width: 360, height: 420)
        let region = PopoverController.hoverRegion(button: button, panel: panel)
        func inside(_ x: CGFloat, _ y: CGFloat) -> Bool { region.contains { $0.contains(CGPoint(x: x, y: y)) } }
        #expect(inside(760, 960))     // on the item
        #expect(inside(760, 947))     // gap between item and card
        #expect(inside(600, 600))     // on the card
        #expect(!inside(300, 960))    // elsewhere on the menu bar
        #expect(!inside(1000, 600))   // beside the card
    }
}

struct DayFractionTests {
    @Test func dhuhrSitsNearTheMiddleAndAsrOnTheRight() throws {
        let tz = TimeZone(identifier: "America/Chicago")!
        let engine = PrayerEngine(coordinates: .init(latitude: 29.7604, longitude: -95.3698), timeZone: tz)
        let s = try engine.schedule(for: Date(timeIntervalSince1970: 1_791_500_000))
        #expect(s.dayFraction(of: s.sunrise) == 0)
        #expect(s.dayFraction(of: s.maghrib) == 1)
        #expect(abs(s.dayFraction(of: s.dhuhr) - 0.5) < 0.02)
        #expect(s.dayFraction(of: s.asr) > 0.6)
        #expect(s.dayFraction(of: s.fajr) == 0)
    }
}

struct SkyTests {
    static let tz = TimeZone(identifier: "America/Chicago")!
    let engine = PrayerEngine(coordinates: .init(latitude: 29.7604, longitude: -95.3698), timeZone: tz)

    func at(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Self.tz
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    @Test(arguments: SkyPeriod.allCases.map(\.rawValue))
    func whiteTextMeetsContrastOnEverySky(period: String) {
        let g = SkyPalette.gradient(for: SkyPeriod(rawValue: period)!)
        #expect(RGB.contrast(.white, g.top) >= 4.5)
        #expect(RGB.contrast(.white, g.bottom) >= 4.5)
    }

    @Test func blendsStayReadable() throws {
        // Sample a whole prayer day, including every blend window.
        let s = try engine.schedule(for: at("2026-10-08 12:00"))
        var t = s.fajr
        while t < s.nextFajr {
            let sky = SkyPalette.sky(at: t, schedule: s)
            #expect(RGB.contrast(.white, sky.top) >= 4.5)
            #expect(RGB.contrast(.white, sky.bottom) >= 4.5)
            t = t.addingTimeInterval(5 * 60)
        }
    }

    @Test(arguments: [
        ("2026-10-08 06:30", SkyPeriod.dawn),
        ("2026-10-08 07:50", .dawn),
        ("2026-10-08 08:10", .day),
        ("2026-10-08 17:50", .day),
        ("2026-10-08 18:27", .sunset),
        ("2026-10-08 19:30", .sunset),
        ("2026-10-08 21:00", .night),
        ("2026-10-09 05:00", .night),
    ])
    func periodAtTime(time: String, period: SkyPeriod) throws {
        let s = try engine.schedule(for: at("2026-10-08 12:00"))
        #expect(SkyPalette.period(at: at(time), schedule: s) == period)
    }

    @Test func blendIsSmoothAndOnlyNearBoundaries() throws {
        let s = try engine.schedule(for: at("2026-10-08 12:00"))
        // Mid-day: pure day sky.
        #expect(SkyPalette.sky(at: at("2026-10-08 12:00"), schedule: s) == SkyPalette.gradient(for: .day))
        // Day ends at 17:59 (1 hr before Maghrib): 10 min before, halfway blended.
        let half = SkyPalette.sky(at: at("2026-10-08 17:49"), schedule: s)
        let expected = SkyPalette.gradient(for: .day).mixed(with: SkyPalette.gradient(for: .sunset), 0.5)
        #expect(abs(half.top.red - expected.top.red) < 1e-9)
        // No jump at the boundary: a minute either side differ only slightly.
        let before = SkyPalette.sky(at: at("2026-10-08 17:58"), schedule: s)
        let after = SkyPalette.sky(at: at("2026-10-08 18:00"), schedule: s)
        #expect(abs(before.top.blue - after.top.blue) < 0.01)
    }

    @Test(arguments: [
        (SkyPhase.fajr, SkyPeriod.dawn), (.morning, .day), (.dhuhr, .day),
        (.asr, .sunset), (.maghrib, .sunset), (.isha, .night),
    ])
    func accentsStandOutOnTheirSky(phase: SkyPhase, period: SkyPeriod) {
        // Large text / UI components: 3:1 against the top of the sky they appear on.
        #expect(RGB.contrast(SkyPalette.accent(for: phase), SkyPalette.gradient(for: period).top) >= 3)
    }

    @Test func timeRangeDropsSharedAMPM() {
        let us = Locale(identifier: "en_US")
        func norm(_ s: String) -> String { s.replacingOccurrences(of: "\u{202F}", with: " ") }
        #expect(norm(MenuBarText.timeRange(at("2026-10-08 16:28"), at("2026-10-08 18:59"), timeZone: Self.tz, locale: us)) == "4:28 – 6:59 PM")
        #expect(norm(MenuBarText.timeRange(at("2026-10-08 20:04"), at("2026-10-09 06:14"), timeZone: Self.tz, locale: us)) == "8:04 PM – 6:14 AM")
        #expect(MenuBarText.timeRange(at("2026-10-08 16:28"), at("2026-10-08 18:59"), timeZone: Self.tz, locale: Locale(identifier: "en_GB")) == "16:28 – 18:59")
    }
}

struct SkyPaletteTests {
    @Test func hexParsing() {
        #expect(RGB(hex: 0xFF8000) == RGB(red: 1, green: 128.0 / 255, blue: 0))
    }
}

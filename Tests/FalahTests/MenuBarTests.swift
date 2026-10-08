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

struct SkyPaletteTests {
    @Test func hexParsing() {
        #expect(RGB(hex: 0xFF8000) == RGB(red: 1, green: 128.0 / 255, blue: 0))
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

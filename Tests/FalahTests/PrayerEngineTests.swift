import Adhan
import Foundation
import Testing
@testable import Falah

/// Fixtures: Houston, ISNA. Values were generated with Adhan 1.5.0 and sanity-checked
/// against the published Houston sunrise/sunset for the date (7:19 AM / 6:58 PM CDT).
struct PrayerEngineTests {
    static let chicago = TimeZone(identifier: "America/Chicago")!
    static let houston = Coordinates(latitude: 29.7604, longitude: -95.3698)

    func engine(_ configure: (inout PrayerSettings) -> Void = { _ in }) -> PrayerEngine {
        var settings = PrayerSettings()
        configure(&settings)
        return PrayerEngine(coordinates: Self.houston, settings: settings, timeZone: Self.chicago)
    }

    /// Parses "yyyy-MM-dd HH:mm[:ss]" in Houston local time.
    func at(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Self.chicago
        formatter.dateFormat = string.count > 16 ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }

    // MARK: Schedule

    @Test func houstonDefaultsAreISNAStandard() throws {
        let s = try engine().schedule(for: at("2026-10-08 12:00"))
        #expect(s.day == at("2026-10-08 00:00"))
        #expect(s.fajr == at("2026-10-08 06:14"))
        #expect(s.sunrise == at("2026-10-08 07:19"))
        #expect(s.dhuhr == at("2026-10-08 13:10"))
        #expect(s.asr == at("2026-10-08 16:28"))
        #expect(s.maghrib == at("2026-10-08 18:59"))
        #expect(s.isha == at("2026-10-08 20:04"))
        #expect(s.lastThird == at("2026-10-09 02:29"))
        #expect(s.nextFajr == at("2026-10-09 06:14"))
    }

    @Test func standardAsrIsEarlierThanHanafi() throws {
        let standard = try engine { $0.madhab = .shafi }.schedule(for: at("2026-10-08 12:00"))
        let hanafi = try engine { $0.madhab = .hanafi }.schedule(for: at("2026-10-08 12:00"))
        #expect(standard.asr == at("2026-10-08 16:28"))
        #expect(hanafi.asr == at("2026-10-08 17:19"))
        // The Asr method moves only Asr (and Dhuhr's end with it).
        #expect(standard.dhuhr == hanafi.dhuhr)
        #expect(standard.maghrib == hanafi.maghrib)
        #expect(standard.end(of: .dhuhr) == standard.asr)
    }

    @Test func lastThirdIsTwoThirdsIntoTheNight() throws {
        let s = try engine().schedule(for: at("2026-10-08 12:00"))
        // Maghrib 18:59 → Fajr 06:14 is 675 minutes; two thirds is 450 → 02:29.
        let night = s.nextFajr.timeIntervalSince(s.maghrib)
        #expect(abs(s.lastThird.timeIntervalSince(s.maghrib) - night * 2 / 3) <= 60)
        #expect(s.isha < s.lastThird && s.lastThird < s.nextFajr)
    }

    @Test func prayerWindowsRunToTheNextPrayer() throws {
        let s = try engine().schedule(for: at("2026-10-08 12:00"))
        #expect(s.intervals.map(\.prayer) == PrayerName.allCases)
        #expect(s.end(of: .fajr) == s.sunrise)
        #expect(s.end(of: .dhuhr) == s.asr)
        #expect(s.end(of: .asr) == s.maghrib)
        #expect(s.end(of: .maghrib) == s.isha)
        #expect(s.end(of: .isha) == s.nextFajr)
    }

    @Test func perPrayerAdjustmentsShiftByMinutes() throws {
        let base = try engine().schedule(for: at("2026-10-08 12:00"))
        let adjusted = try engine { $0.adjustments = [.fajr: -3, .asr: 5, .isha: 10] }.schedule(for: at("2026-10-08 12:00"))
        #expect(adjusted.fajr == base.fajr.addingTimeInterval(-3 * 60))
        #expect(adjusted.asr == base.asr.addingTimeInterval(5 * 60))
        #expect(adjusted.isha == base.isha.addingTimeInterval(10 * 60))
        #expect(adjusted.dhuhr == base.dhuhr)
        #expect(adjusted.sunrise == base.sunrise)
    }

    @Test func adjustmentsAreClampedToTenMinutes() throws {
        let base = try engine().schedule(for: at("2026-10-08 12:00"))
        let adjusted = try engine { $0.adjustments = [.dhuhr: 45, .maghrib: -30] }.schedule(for: at("2026-10-08 12:00"))
        #expect(adjusted.dhuhr == base.dhuhr.addingTimeInterval(10 * 60))
        #expect(adjusted.maghrib == base.maghrib.addingTimeInterval(-10 * 60))
    }

    @Test(arguments: PrayerSettings.selectableMethods.map(\.rawValue))
    func everyMethodProducesOrderedTimes(method: String) throws {
        let s = try engine { $0.method = CalculationMethod(rawValue: method)! }.schedule(for: at("2026-10-08 12:00"))
        #expect(s.fajr < s.sunrise)
        #expect(s.sunrise < s.dhuhr)
        #expect(s.dhuhr < s.asr)
        #expect(s.asr < s.maghrib)
        #expect(s.maghrib <= s.isha)
        #expect(s.isha < s.lastThird)
        #expect(s.lastThird < s.nextFajr)
    }

    // MARK: DST

    @Test func dstEndShiftsWallClockTimesBackAnHour() throws {
        // US DST ends Sunday Nov 1, 2026.
        let before = try engine().schedule(for: at("2026-10-31 12:00"))
        let after = try engine().schedule(for: at("2026-11-01 12:00"))
        #expect(before.dhuhr == at("2026-10-31 13:06"))
        #expect(after.dhuhr == at("2026-11-01 12:06"))
        #expect(before.nextFajr == at("2026-11-01 05:28"))
        #expect(after.fajr == before.nextFajr)
    }

    @Test func dstStartShiftsWallClockTimesForwardAnHour() throws {
        // US DST starts Sunday Mar 8, 2026.
        let before = try engine().schedule(for: at("2026-03-07 12:00"))
        let after = try engine().schedule(for: at("2026-03-08 12:00"))
        #expect(before.dhuhr == at("2026-03-07 12:33"))
        #expect(after.dhuhr == at("2026-03-08 13:33"))
        #expect(after.fajr == at("2026-03-08 06:34"))
    }

    @Test func snapshotAcrossDSTNightFindsNextFajr() throws {
        let snap = try engine().snapshot(at: at("2026-11-01 02:30"))
        #expect(snap.next.prayer == .fajr)
        #expect(snap.next.start == at("2026-11-01 05:28"))
        #expect(snap.phase == .isha)
    }

    // MARK: Current / next

    @Test func asrBoundaryMinute() throws {
        let e = engine()
        let justBefore = try e.snapshot(at: at("2026-10-08 16:27:59"))
        #expect(justBefore.current?.prayer == .dhuhr)
        #expect(justBefore.next.prayer == .asr)
        #expect(justBefore.timeUntilNext == 1)

        let atStart = try e.snapshot(at: at("2026-10-08 16:28:00"))
        #expect(atStart.current?.prayer == .asr)
        #expect(atStart.current?.end == at("2026-10-08 18:59"))
        #expect(atStart.next.prayer == .maghrib)
        #expect(atStart.phase == .asr)
    }

    @Test func fajrEndsAtSunriseLeavingNoCurrentPrayer() throws {
        let e = engine()
        let duringFajr = try e.snapshot(at: at("2026-10-08 07:18"))
        #expect(duringFajr.current?.prayer == .fajr)

        let morning = try e.snapshot(at: at("2026-10-08 07:19"))
        #expect(morning.current == nil)
        #expect(morning.next.prayer == .dhuhr)
        #expect(morning.phase == .morning)
        #expect(morning.schedule.day == at("2026-10-08 00:00"))
    }

    @Test func countdownToNextPrayer() throws {
        let snap = try engine().snapshot(at: at("2026-10-08 15:56"))
        #expect(snap.next.prayer == .asr)
        #expect(snap.timeUntilNext == 32 * 60)
    }

    // MARK: After Isha → tomorrow

    @Test func afterIshaNextIsTomorrowsFajr() throws {
        let snap = try engine().snapshot(at: at("2026-10-08 23:30"))
        #expect(snap.current?.prayer == .isha)
        #expect(snap.current?.end == at("2026-10-09 06:14"))
        #expect(snap.next.prayer == .fajr)
        #expect(snap.next.start == at("2026-10-09 06:14"))
        #expect(snap.schedule.day == at("2026-10-08 00:00"))
    }

    @Test func ishaCarriesPastMidnightUntilFajr() throws {
        let snap = try engine().snapshot(at: at("2026-10-09 03:00"))
        #expect(snap.current?.prayer == .isha)
        #expect(snap.current?.day == at("2026-10-08 00:00"))
        #expect(snap.current?.end == at("2026-10-09 06:14"))
        #expect(snap.next.prayer == .fajr)
        #expect(snap.next.start == at("2026-10-09 06:14"))
        // Still yesterday's list, so tonight's last third (02:29) is on it.
        #expect(snap.schedule.day == at("2026-10-08 00:00"))
        #expect(snap.schedule.lastThird == at("2026-10-09 02:29"))
        #expect(snap.phase == .isha)
    }

    @Test func atFajrTheNewDayBegins() throws {
        let snap = try engine().snapshot(at: at("2026-10-09 06:14"))
        #expect(snap.current?.prayer == .fajr)
        #expect(snap.schedule.day == at("2026-10-09 00:00"))
        #expect(snap.next.prayer == .dhuhr)
    }

    // MARK: Phases

    @Test(arguments: [
        ("2026-10-08 06:30", SkyPhase.fajr),
        ("2026-10-08 09:00", .morning),
        ("2026-10-08 14:00", .dhuhr),
        ("2026-10-08 18:00", .asr),
        ("2026-10-08 19:30", .maghrib),
        ("2026-10-08 22:00", .isha),
        ("2026-10-09 03:00", .isha),
    ])
    func phaseAtTime(time: String, phase: SkyPhase) throws {
        #expect(try engine().snapshot(at: at(time)).phase == phase)
    }

    // MARK: Arc

    @Test func arcIsZeroAtSunriseAndHalfwayAtMidday() throws {
        let e = engine()
        #expect(try e.snapshot(at: at("2026-10-08 07:19")).arc == .day(0))
        // Sunrise 07:19 → Maghrib 18:59 is 700 minutes; halfway is 13:09.
        #expect(try e.snapshot(at: at("2026-10-08 13:09")).arc == .day(0.5))
    }

    @Test func arcSwitchesToNightAtMaghrib() throws {
        let e = engine()
        #expect(try e.snapshot(at: at("2026-10-08 18:58")).arc != .night(0))
        #expect(try e.snapshot(at: at("2026-10-08 18:59")).arc == .night(0))
        // Night runs Maghrib 18:59 → sunrise 07:20 (741 min); halfway is 01:09:30.
        guard case .night(let f) = try e.snapshot(at: at("2026-10-09 01:09:30")).arc else {
            Issue.record("expected night"); return
        }
        #expect(abs(f - 0.5) < 0.002)
    }

    @Test func moonKeepsMovingBetweenFajrAndSunrise() throws {
        let e = engine()
        guard case .night(let atFajr) = try e.snapshot(at: at("2026-10-09 06:14")).arc,
              case .night(let later) = try e.snapshot(at: at("2026-10-09 06:45")).arc else {
            Issue.record("expected night"); return
        }
        #expect(atFajr < later && later < 1)
        #expect(try e.snapshot(at: at("2026-10-09 07:20")).arc == .day(0))
    }

    @Test func nightFractionPlacesIshaLastThirdAndFajrInOrder() throws {
        let s = try engine().schedule(for: at("2026-10-08 12:00"))
        #expect(s.nextSunrise == at("2026-10-09 07:20"))
        let isha = s.nightFraction(of: s.isha)
        let lastThird = s.nightFraction(of: s.lastThird)
        let fajr = s.nightFraction(of: s.nextFajr)
        #expect(0 < isha && isha < lastThird && lastThird < fajr && fajr < 1)
        #expect(s.nightFraction(of: s.maghrib) == 0)
        #expect(s.nightFraction(of: s.nextSunrise) == 1)
    }

    // MARK: Errors

    @Test func polarDayFailsCleanly() {
        // Svalbard in midsummer: the sun never sets, so Adhan returns nil.
        let svalbard = PrayerEngine(
            coordinates: Coordinates(latitude: 78.22, longitude: 15.65),
            timeZone: TimeZone(identifier: "Arctic/Longyearbyen")!
        )
        #expect(throws: PrayerEngineError.self) {
            try svalbard.snapshot(at: at("2026-06-21 12:00"))
        }
    }
}

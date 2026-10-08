import Foundation
import Testing
@testable import Falah

struct ClockTests {
    private let houston = TimeZone(identifier: "America/Chicago")!

    @Test func parsesDebugTimeAsLocalTime() throws {
        let date = try #require(AppClock.parseDebugTime("2026-10-08T16:29:00", timeZone: houston))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = houston
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        #expect(parts == DateComponents(year: 2026, month: 10, day: 8, hour: 16, minute: 29, second: 0))
    }

    @Test func parsesWithoutSeconds() {
        #expect(AppClock.parseDebugTime("2026-10-08T16:29", timeZone: houston) != nil)
    }

    @Test func offsetFromArguments() throws {
        let realNow = Date(timeIntervalSince1970: 1_000_000)
        let clock = AppClock.fromArguments(["Falah", "--debug-time", "2026-10-08T16:29:00"], realNow: realNow, timeZone: houston)
        let expected = try #require(AppClock.parseDebugTime("2026-10-08T16:29:00", timeZone: houston))
        #expect(clock.isFaked)
        #expect(abs(clock.offset - expected.timeIntervalSince(realNow)) < 0.001)
    }

    @Test func noArgumentMeansRealClock() {
        let clock = AppClock.fromArguments(["Falah"])
        #expect(!clock.isFaked)
        #expect(abs(clock.now().timeIntervalSinceNow) < 1)
    }

    @Test func badInputFallsBackToRealClock() {
        #expect(!AppClock.fromArguments(["Falah", "--debug-time", "yesterday"]).isFaked)
        #expect(!AppClock.fromArguments(["Falah", "--debug-time"]).isFaked)
    }
}

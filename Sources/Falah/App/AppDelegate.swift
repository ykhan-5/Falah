import Adhan
import AppKit

@main
enum FalahMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clock = AppClock.fromArguments()
    // Houston until location + settings land (milestone 7).
    private var engine = PrayerEngine(coordinates: Coordinates(latitude: 29.7604, longitude: -95.3698))
    private var statusItemController: StatusItemController?
    private var scheduler: Scheduler?
    private var lastScheduleDay: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if clock.isFaked {
            Log.clock.notice("Debug time active: now = \(self.clock.now().formatted(date: .abbreviated, time: .standard), privacy: .public)")
        }
        statusItemController = StatusItemController()
        Log.app.notice("Falah launched")

        scheduler = Scheduler(clock: clock) { [weak self] reason in
            self?.refresh(reason: reason)
        }
        scheduler?.start()
    }

    private func refresh(reason: Scheduler.Reason) {
        // Pick up time zone changes (Scheduler resets the cached system zone first).
        engine.timeZone = .current
        let now = clock.now()

        do {
            let snap = try engine.snapshot(at: now)
            statusItemController?.update(with: snap)

            let text = MenuBarText.text(for: snap)
            Log.app.notice("Refresh (\(reason.rawValue, privacy: .public)) at \(now.formatted(date: .omitted, time: .standard), privacy: .public) \(TimeZone.current.identifier, privacy: .public): \(text, privacy: .public)")
            if snap.schedule.day != lastScheduleDay {
                lastScheduleDay = snap.schedule.day
                logSchedule(snap)
            }
        } catch {
            statusItemController?.showUnavailable()
            Log.engine.error("Prayer times unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    private func logSchedule(_ snap: PrayerSnapshot) {
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        let list = (snap.schedule.intervals.map { "\($0.prayer.displayName) \($0.start.formatted(time))" }
            + ["Last third \(snap.schedule.lastThird.formatted(time))"])
            .joined(separator: ", ")
        Log.engine.notice("Schedule: \(list, privacy: .public)")
    }
}

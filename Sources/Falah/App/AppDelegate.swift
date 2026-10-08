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
    private let cardModel = CardModel()
    private var statusItemController: StatusItemController?
    private var scheduler: Scheduler?
    private var lastScheduleDay: Date?
    private var lastSnapshot: PrayerSnapshot?
    private let notifier = Notifier()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if clock.isFaked {
            Log.clock.notice("Debug time active: now = \(self.clock.now().formatted(date: .abbreviated, time: .standard), privacy: .public)")
        }
        cardModel.settings = engine.settings
        cardModel.onQuit = { NSApp.terminate(nil) }
        cardModel.onSettings = { [weak self] in
            // Settings window arrives in milestone 7.
            Log.app.notice("Settings tapped (not built yet)")
            self?.statusItemController?.hideCard()
        }
        statusItemController = StatusItemController(cardModel: cardModel)
        notifier.requestAuthorization()
        Log.app.notice("Falah launched")

        scheduler = Scheduler(clock: clock) { [weak self] reason in
            self?.refresh(reason: reason)
        }
        scheduler?.start()

        // Hidden: open the card at launch, for screenshots and testing.
        if CommandLine.arguments.contains("--show-card") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItemController?.showCard()
            }
        }
    }

    private func refresh(reason: Scheduler.Reason) {
        // Pick up time zone changes (Scheduler resets the cached system zone first).
        engine.timeZone = .current
        let now = clock.now()

        do {
            let snap = try engine.snapshot(at: now)
            cardModel.snapshot = snap
            cardModel.isUnavailable = false
            statusItemController?.update(with: snap)

            let text = MenuBarText.text(for: snap)
            Log.app.notice("Refresh (\(reason.rawValue, privacy: .public)) at \(now.formatted(date: .omitted, time: .standard), privacy: .public) \(TimeZone.current.identifier, privacy: .public): \(text, privacy: .public)")
            if snap.schedule.day != lastScheduleDay {
                lastScheduleDay = snap.schedule.day
                logSchedule(snap)
            }

            if let moment = PrayerMoment.justBegan(previous: lastSnapshot, current: snap) {
                Log.app.notice("Prayer moment: \(moment.prayer.displayName, privacy: .public)")
                statusItemController?.flash()
                // The system can't see the debug clock, so post the alert ourselves.
                if clock.isFaked { notifier.postNow(for: moment) }
            }
            lastSnapshot = snap
            if !clock.isFaked {
                notifier.schedule(engine.upcomingPrayers(after: now))
            }
        } catch {
            cardModel.isUnavailable = true
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

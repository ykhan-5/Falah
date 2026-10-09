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
    private let settings = SettingsStore()
    private let location = LocationService()
    private let notifier = Notifier()
    private let cardModel = CardModel()
    private let settingsEnvironment = SettingsEnvironment()
    private var statusItemController: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var scheduler: Scheduler?
    private var lastScheduleDay: Date?
    private var lastSnapshot: PrayerSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if clock.isFaked {
            Log.clock.notice("Debug time active: now = \(self.clock.now().formatted(date: .abbreviated, time: .standard), privacy: .public)")
        }

        settingsWindow = SettingsWindowController(store: settings, environment: settingsEnvironment)
        // Closing Settings returns to the card it was opened from.
        settingsWindow?.onClose = { [weak self] in
            DispatchQueue.main.async { self?.statusItemController?.showCard() }
        }
        cardModel.onQuit = { NSApp.terminate(nil) }
        cardModel.onSettings = { [weak self] in
            self?.statusItemController?.hideCard()
            self?.settingsWindow?.show()
        }
        settingsEnvironment.previewFlash = { [weak self] in self?.statusItemController?.flash() }

        statusItemController = StatusItemController(cardModel: cardModel)
        notifier.requestAuthorization()
        Log.app.notice("Falah launched")

        settings.onChange = { [weak self] in self?.settingsChanged() }
        location.onPlace = { [weak self] place in
            self?.settings.autoPlace = place
        }
        location.onStatus = { [weak self] status in
            self?.settingsEnvironment.locationStatus = status
            self?.refresh(reason: .locationChanged)
        }
        updateLocationService()

        scheduler = Scheduler(clock: clock) { [weak self] reason in
            if reason == .wake { self?.location.refresh() }
            self?.refresh(reason: reason)
        }
        scheduler?.start()

        if CommandLine.arguments.contains("--show-settings") {
            settingsWindow?.show()
        }
        // Hidden: open the card at launch, for screenshots and testing.
        if CommandLine.arguments.contains("--show-card") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItemController?.showCard()
            }
        }
    }

    private func settingsChanged() {
        updateLocationService()
        // A settings change can move the current prayer; that isn't a prayer moment.
        lastSnapshot = nil
        refresh(reason: .settingsChanged)
    }

    private func updateLocationService() {
        if settings.locationMode == .automatic {
            location.start(lastKnown: settings.autoPlace)
        } else {
            location.stop()
        }
    }

    private func refresh(reason: Scheduler.Reason) {
        statusItemController?.showsText = settings.showsCountdownText
        statusItemController?.momentColor = RGB(hexString: settings.momentColorHex).map(NSColor.init) ?? .systemOrange
        notifier.isEnabled = settings.notificationsEnabled
        notifier.reminderMinutes = settings.reminderMinutes > 0 ? settings.reminderMinutes : nil
        cardModel.settings = settings.prayerSettings

        guard let place = settings.activePlace else {
            cardModel.problem = location.status == .denied ? .locationDenied : .locating
            cardModel.snapshot = nil
            statusItemController?.showUnavailable()
            notifier.schedule([])
            Log.app.notice("Refresh (\(reason.rawValue, privacy: .public)): no location yet")
            return
        }
        cardModel.locationName = place.name

        // Picks up time zone changes (Scheduler resets the cached system zone first).
        let engine = PrayerEngine(coordinates: place.coordinates, settings: settings.prayerSettings, timeZone: .current)
        let now = clock.now()

        do {
            let snap = try engine.snapshot(at: now)
            cardModel.snapshot = snap
            cardModel.problem = nil
            statusItemController?.update(with: snap)

            let text = MenuBarText.text(for: snap)
            Log.app.notice("Refresh (\(reason.rawValue, privacy: .public)) at \(now.formatted(date: .omitted, time: .standard), privacy: .public) \(TimeZone.current.identifier, privacy: .public): \(text, privacy: .public)")
            if snap.schedule.day != lastScheduleDay || reason == .settingsChanged || reason == .locationChanged {
                lastScheduleDay = snap.schedule.day
                logSchedule(snap, place: place)
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
            cardModel.problem = .calculationFailed
            statusItemController?.showUnavailable()
            notifier.schedule([])
            Log.engine.error("Prayer times unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    private func logSchedule(_ snap: PrayerSnapshot, place: SavedPlace) {
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        let list = (snap.schedule.intervals.map { "\($0.prayer.displayName) \($0.start.formatted(time))" }
            + ["Last third \(snap.schedule.lastThird.formatted(time))"])
            .joined(separator: ", ")
        Log.engine.notice("Schedule for \(place.name, privacy: .public) (\(self.cardModel.footerText, privacy: .public)): \(list, privacy: .public)")
    }
}

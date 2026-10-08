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
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if clock.isFaked {
            Log.clock.notice("Debug time active: now = \(self.clock.now().formatted(date: .abbreviated, time: .standard), privacy: .public)")
        }
        statusItemController = StatusItemController()
        Log.app.notice("Falah launched")
        logSnapshot()
    }

    // Houston until location + settings land (milestone 7).
    private let engine = PrayerEngine(coordinates: Coordinates(latitude: 29.7604, longitude: -95.3698))

    private func logSnapshot() {
        let time = Date.FormatStyle(date: .omitted, time: .shortened)
        do {
            let snap = try engine.snapshot(at: clock.now())
            let list = (snap.schedule.intervals.map { "\($0.prayer.displayName) \($0.start.formatted(time))" }
                + ["Last third \(snap.schedule.lastThird.formatted(time))"])
                .joined(separator: ", ")
            Log.engine.notice("Today: \(list, privacy: .public)")
            Log.engine.notice("Current: \(snap.current?.prayer.displayName ?? "none", privacy: .public) · next: \(snap.next.prayer.displayName, privacy: .public) at \(snap.next.start.formatted(time), privacy: .public) (in \(Int(snap.timeUntilNext / 60)) min) · phase: \(snap.phase.rawValue, privacy: .public) · arc: \(String(describing: snap.arc), privacy: .public)")
        } catch {
            Log.engine.error("Prayer times unavailable: \(String(describing: error), privacy: .public)")
        }
    }
}

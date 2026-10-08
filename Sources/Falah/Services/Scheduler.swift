import AppKit

/// Calls `onTick` once per minute, aligned to the minute of the app clock, and right away
/// whenever something may have made the current state stale: wake from sleep, the local
/// day changing, a time zone change, or the system clock being set.
///
/// Uses one-shot timers re-armed after every tick, so a long sleep or clock jump can't
/// leave a repeating timer out of phase.
final class Scheduler {
    enum Reason: String {
        case start, minute, wake, dayChanged, timeZoneChanged, clockChanged
    }

    private let clock: AppClock
    private let onTick: (Reason) -> Void
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(clock: AppClock, onTick: @escaping (Reason) -> Void) {
        self.clock = clock
        self.onTick = onTick
    }

    deinit {
        stop()
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default
        observe(workspace, NSWorkspace.didWakeNotification, .wake)
        observe(center, .NSCalendarDayChanged, .dayChanged)
        observe(center, .NSSystemTimeZoneDidChange, .timeZoneChanged)
        observe(center, .NSSystemClockDidChange, .clockChanged)
        fire(.start)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ reason: Reason) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            if reason == .timeZoneChanged {
                NSTimeZone.resetSystemTimeZone()
            }
            self?.fire(reason)
        }
        observers.append((center, token))
    }

    private func fire(_ reason: Reason) {
        onTick(reason)
        armTimer()
    }

    private func armTimer() {
        timer?.invalidate()
        let delay = Self.delayUntilNextMinute(from: clock.now())
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.fire(.minute)
        }
        timer.tolerance = 0.2
        // .common so ticks keep coming while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Seconds from `now` to just past the next minute boundary. The small margin makes the
    /// tick land after the boundary, so a prayer starting at that minute counts as started.
    static func delayUntilNextMinute(from now: Date, margin: TimeInterval = 0.05) -> TimeInterval {
        let t = now.timeIntervalSinceReferenceDate
        let next = (t / 60).rounded(.down) * 60 + 60
        return next - t + margin
    }
}

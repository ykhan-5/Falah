import Foundation
import UserNotifications

/// Prayer-time alerts through Notification Center. Silent by default.
///
/// On the real clock, upcoming prayers are scheduled with the system ahead of time, so
/// they fire on time even if the app's own timer runs late. With `--debug-time` the
/// system can't know the fake clock, so the app posts the alert itself at the moment.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var scheduledSignature: [String] = []

    /// Notifications on/off. Becomes a setting in milestone 7.
    var isEnabled = true
    /// Optional reminder before each prayer (default off). Setting in milestone 7.
    var reminderMinutes: Int?

    func requestAuthorization() {
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { granted, error in
            if let error {
                Log.notify.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.notify.notice("Notification permission \(granted ? "granted" : "denied", privacy: .public)")
            }
        }
    }

    /// Replaces pending alerts with these prayers. Cheap no-op if nothing changed.
    func schedule(_ prayers: [PrayerInterval]) {
        let signature = isEnabled ? prayers.map(identifier) + ["reminder:\(reminderMinutes ?? 0)"] : []
        guard signature != scheduledSignature else { return }
        scheduledSignature = signature

        center.removeAllPendingNotificationRequests()
        guard isEnabled else { return }
        let now = Date()
        for prayer in prayers {
            add(id: identifier(prayer), title: PrayerMoment.title(for: prayer.prayer, at: prayer.start), at: prayer.start)
            if let minutes = reminderMinutes, minutes > 0 {
                let reminderTime = prayer.start.addingTimeInterval(-Double(minutes) * 60)
                if reminderTime > now {
                    add(id: "reminder-" + identifier(prayer),
                        title: PrayerMoment.reminderTitle(for: prayer.prayer, at: prayer.start, minutesBefore: minutes),
                        at: reminderTime)
                }
            }
        }
        Log.notify.notice("Scheduled \(prayers.count) prayer alerts, next: \(prayers.first.map { "\($0.prayer.displayName) \($0.start.formatted(date: .abbreviated, time: .shortened))" } ?? "none", privacy: .public)")
    }

    /// Posts an alert immediately (debug clock).
    func postNow(for prayer: PrayerInterval) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = PrayerMoment.title(for: prayer.prayer, at: prayer.start)
        center.add(UNNotificationRequest(identifier: "now-" + identifier(prayer), content: content, trigger: nil))
        Log.notify.notice("Posted alert now: \(content.title, privacy: .public)")
    }

    private func add(id: String, title: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        center.add(request) { error in
            if let error {
                Log.notify.error("Couldn't schedule \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func identifier(_ prayer: PrayerInterval) -> String {
        "prayer-\(prayer.prayer.rawValue)-\(Int(prayer.start.timeIntervalSince1970))"
    }

    // Show banners even if Falah happens to be the active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

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
    }
}

import AppKit

final class StatusItemController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Falah"

        // Temporary until the pop-out card (milestone 4): there is no Dock icon to quit from.
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Falah", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}

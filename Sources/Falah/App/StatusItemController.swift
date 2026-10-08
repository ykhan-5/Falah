import AppKit

final class StatusItemController {
    private let statusItem: NSStatusItem

    /// Hides the "Asr in 32m" text, leaving only the icon. Becomes a setting in milestone 7.
    var showsText = true

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.image = MenuBarIcon.image(glyph: nil)
        }

        // Temporary until the pop-out card (milestone 4): there is no Dock icon to quit from.
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Falah", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func update(with snapshot: PrayerSnapshot) {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(glyph: MenuBarGlyph(phase: snapshot.phase))
        setTitle(showsText ? MenuBarText.text(for: snapshot) : "")
        button.toolTip = "Next: \(snapshot.next.prayer.displayName) at \(snapshot.next.start.formatted(date: .omitted, time: .shortened))"
    }

    func showUnavailable() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(glyph: nil)
        setTitle(showsText ? "–" : "")
        button.toolTip = "Prayer times unavailable"
    }

    private func setTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        // Monospaced digits so the item doesn't jiggle as the countdown changes.
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.attributedTitle = NSAttributedString(string: text.isEmpty ? "" : " \(text)", attributes: [.font: font])
    }
}

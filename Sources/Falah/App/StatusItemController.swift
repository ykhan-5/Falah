import AppKit
import SwiftUI

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let cardModel: CardModel
    private var popover: PopoverController?

    /// Hides the "Asr in 32m" text, leaving only the icon (Settings).
    var showsText = true

    init(cardModel: CardModel) {
        self.cardModel = cardModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        guard let button = statusItem.button else { return }
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.image = MenuBarIcon.image(glyph: nil)
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let hosting = NSHostingView(rootView: SkyCardView(model: cardModel))
        popover = PopoverController(button: button, content: hosting)
    }

    func update(with snapshot: PrayerSnapshot) {
        setGlyph(MenuBarGlyph(phase: snapshot.phase))
        setTitle(showsText ? MenuBarText.text(for: snapshot) : "")
        popover?.refreshLayout()
    }

    func showUnavailable() {
        setGlyph(nil)
        setTitle(showsText ? "–" : "")
        popover?.refreshLayout()
    }

    // Only touch the button when something changed, so a routine tick doesn't redraw it.
    private var currentGlyph: MenuBarGlyph??
    private var currentTitle: String?

    private func setGlyph(_ glyph: MenuBarGlyph?) {
        guard currentGlyph != .some(glyph), let button = statusItem.button else { return }
        currentGlyph = .some(glyph)
        button.image = MenuBarIcon.image(glyph: glyph)
    }

    /// Background color for the prayer-moment flash, from Settings.
    var momentColor = NSColor.systemOrange

    /// Prayer moment: the item's background flashes `momentColor` three times, like the
    /// menu bar's own highlight but in color.
    func flash() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        guard let layer = button.layer else { return }
        layer.cornerRadius = 5
        layer.masksToBounds = true

        let on = momentColor.withAlphaComponent(0.9).cgColor
        let off = momentColor.withAlphaComponent(0).cgColor
        let animation = CAKeyframeAnimation(keyPath: "backgroundColor")
        animation.values = [off, on, off, on, off, on, off]
        animation.keyTimes = (0...6).map { NSNumber(value: Double($0) / 6) }
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 6)
        animation.duration = 2.6
        layer.add(animation, forKey: "momentFlash")
    }

    func showCard() {
        if popover?.isShown != true { popover?.handleClick() }
    }

    func hideCard() {
        popover?.hide(reason: "action")
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            popover?.handleClick()
        }
    }

    /// Right-click: a small menu, mainly so Quit is always reachable.
    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        popover?.hide(reason: "context menu")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Falah", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func setTitle(_ text: String) {
        guard text != currentTitle, let button = statusItem.button else { return }
        currentTitle = text
        // Monospaced digits so the item doesn't jiggle as the countdown changes.
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.attributedTitle = NSAttributedString(string: text.isEmpty ? "" : " \(text)", attributes: [.font: font])
    }
}

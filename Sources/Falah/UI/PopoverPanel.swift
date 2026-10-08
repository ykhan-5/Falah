import AppKit

/// Borderless, non-activating, floating panel that hosts the card. Showing it never
/// activates Falah or pulls focus from the app you're in.
final class CardPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = content
    }

    // Key only when opened by a click (so Esc works); hover never makes it key.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Opens the card under the status item on hover (0.3 s) or click, and closes it when the
/// pointer leaves the item, card and the corridor between them for 0.4 s, on a click
/// outside, or on Esc. A click pins the card open until the next click, outside click or Esc.
final class PopoverController: NSResponder {
    static let openDelay: TimeInterval = 0.3
    static let closeGrace: TimeInterval = 0.4

    private let button: NSStatusBarButton
    private let hostingView: NSView
    private lazy var panel = CardPanel(content: hostingView)

    private var openTimer: Timer?
    private var pointerWatch: Timer?
    private var outsideSince: Date?
    private var pinned = false
    private var clickMonitor: Any?
    private var keyMonitor: Any?

    var isShown: Bool { panel.isVisible }

    init(button: NSStatusBarButton, content: NSView) {
        self.button = button
        self.hostingView = content
        super.init()
        button.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    // MARK: Hover

    override func mouseEntered(with event: NSEvent) {
        guard !isShown else { return }
        openTimer?.invalidate()
        openTimer = Timer.scheduledTimer(withTimeInterval: Self.openDelay, repeats: false) { [weak self] _ in
            self?.show(pinned: false, reason: "hover")
        }
    }

    override func mouseExited(with event: NSEvent) {
        openTimer?.invalidate()
        openTimer = nil
    }

    // MARK: Click

    /// First click opens (or pins a hover-opened card); the next click closes.
    func handleClick() {
        openTimer?.invalidate()
        if !isShown {
            show(pinned: true, reason: "click")
        } else if !pinned {
            pin()
        } else {
            hide(reason: "click")
        }
    }

    // MARK: Show / hide

    private func show(pinned: Bool, reason: String) {
        position()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        panel.invalidateShadow()
        installMonitors()
        self.pinned = false
        if pinned {
            pin()
        } else {
            startPointerWatch()
        }
        Log.card.notice("Card shown (\(reason, privacy: .public))")
    }

    private func pin() {
        pinned = true
        stopPointerWatch()
        panel.makeKey()
    }

    func hide(reason: String) {
        guard isShown else { return }
        stopPointerWatch()
        removeMonitors()
        pinned = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.panel.alphaValue == 0 else { return }
            self.panel.orderOut(nil)
        })
        Log.card.notice("Card hidden (\(reason, privacy: .public))")
    }

    /// Re-fit and re-anchor while open (e.g. content height changed).
    func refreshLayout() {
        guard isShown else { return }
        position()
        panel.invalidateShadow()
    }

    // MARK: Positioning

    private var buttonFrameOnScreen: CGRect? {
        guard let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func position() {
        guard let anchor = buttonFrameOnScreen else { return }
        let screen = button.window?.screen ?? NSScreen.main
        let size = hostingView.fittingSize
        panel.setContentSize(size)
        let frame = Self.panelFrame(size: size, under: anchor, in: screen?.visibleFrame ?? .infinite)
        panel.setFrame(frame, display: true)
    }

    /// Centered under the status item, 6 pt below it, kept 8 pt inside the visible frame.
    static func panelFrame(size: CGSize, under anchor: CGRect, in visible: CGRect) -> CGRect {
        let margin: CGFloat = 8
        var x = anchor.midX - size.width / 2
        var y = anchor.minY - 6 - size.height
        if !visible.isInfinite {
            x = min(max(x, visible.minX + margin), visible.maxX - margin - size.width)
            y = max(y, visible.minY + margin)
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Where the pointer may be without starting the close countdown: the item, the card,
    /// and a corridor between them so a diagonal move doesn't close it.
    static func hoverRegion(button: CGRect, panel: CGRect) -> [CGRect] {
        let corridor = CGRect(
            x: button.minX - 16,
            y: panel.maxY,
            width: button.width + 32,
            height: max(0, button.minY - panel.maxY) + 1
        )
        return [button.insetBy(dx: -4, dy: -4), panel.insetBy(dx: -8, dy: -8), corridor]
    }

    // MARK: Pointer watch (only while a hover-opened card is visible)

    private func startPointerWatch() {
        stopPointerWatch()
        outsideSince = nil
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.checkPointer() }
        RunLoop.main.add(timer, forMode: .common)
        pointerWatch = timer
    }

    private func stopPointerWatch() {
        pointerWatch?.invalidate()
        pointerWatch = nil
        outsideSince = nil
    }

    private func checkPointer() {
        guard let anchor = buttonFrameOnScreen else { return }
        let mouse = NSEvent.mouseLocation
        let inside = Self.hoverRegion(button: anchor, panel: panel.frame).contains { $0.contains(mouse) }
        if inside {
            outsideSince = nil
        } else if let since = outsideSince {
            if Date().timeIntervalSince(since) >= Self.closeGrace {
                hide(reason: "pointer left")
            }
        } else {
            outsideSince = Date()
        }
    }

    // MARK: Event monitors

    private func installMonitors() {
        removeMonitors()
        // Clicks in other apps (no special permission needed for mouse events).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.hide(reason: "click outside")
        }
        // Esc while the card is key.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.hide(reason: "escape")
            return nil
        }
    }

    private func removeMonitors() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        keyMonitor = nil
    }
}

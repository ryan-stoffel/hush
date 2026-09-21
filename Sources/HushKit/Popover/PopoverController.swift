import AppKit
import SwiftUI

@MainActor
public final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private weak var statusItem: NSStatusItem?
    private let model: PopoverViewModel
    // On macOS 26 a popover anchored straight to the status item button lands well below the
    // menu bar, so the popover anchors to an invisible window laid over the button instead.
    private let anchor: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.isReleasedWhenClosed = false
        return window
    }()

    public init(statusItem: NSStatusItem, model: PopoverViewModel) {
        self.statusItem = statusItem
        self.model = model
        super.init()
        popover.behavior = .transient
        popover.animates = false
        let hosting = NSHostingController(rootView: PopoverView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.delegate = self
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle(_:))
    }

    public var isShown: Bool {
        popover.isShown
    }

    public func close() {
        popover.performClose(nil)
    }

    @objc public func toggle(_: Any?) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show()
        }
    }

    public func show() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        model.refreshPermissions()
        let screenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        anchor.setFrame(screenRect, display: false)
        anchor.orderFrontRegardless()
        guard let anchorView = anchor.contentView, let content = popover.contentViewController?.view else { return }
        // Size the content before showing, otherwise the popover is placed for a stale, taller size.
        content.layoutSubtreeIfNeeded()
        popover.contentSize = content.fittingSize
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    /// The button's window exists only once the menu bar has laid it out, which takes a moment after launch.
    public var canShow: Bool {
        statusItem?.button?.window.map { $0.frame.origin.y > 0 } ?? false
    }

    /// Demo mode: the status item may need a few run loop turns before a popover can anchor to it,
    /// and a transient popover would close as soon as the UI test runner takes focus.
    public func showForDemo(attemptsLeft: Int = 40) {
        popover.behavior = .applicationDefined
        if canShow {
            show()
        }
        guard !popover.isShown, attemptsLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showForDemo(attemptsLeft: attemptsLeft - 1)
        }
    }

    public func popoverDidClose(_: Notification) {
        anchor.orderOut(nil)
    }
}

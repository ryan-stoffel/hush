import AppKit
import SwiftUI

@MainActor
public final class PopoverController: NSObject {
    private let popover = NSPopover()
    private weak var statusItem: NSStatusItem?
    private let model: PopoverViewModel

    public init(statusItem: NSStatusItem, model: PopoverViewModel) {
        self.statusItem = statusItem
        self.model = model
        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle(_:))
    }

    public var isShown: Bool {
        popover.isShown
    }

    @objc public func toggle(_: Any?) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show()
        }
    }

    public func show() {
        guard let button = statusItem?.button else { return }
        model.refreshPermissions()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// Demo mode: the status item may need a few run loop turns before a popover can anchor to it,
    /// and a transient popover would close as soon as the UI test runner takes focus.
    public func showForDemo(attemptsLeft: Int = 40) {
        popover.behavior = .applicationDefined
        show()
        guard !popover.isShown, attemptsLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showForDemo(attemptsLeft: attemptsLeft - 1)
        }
    }
}

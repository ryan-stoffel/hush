import AppKit
import SwiftUI

/// One reusable History window.
@MainActor
public final class HistoryWindowController {
    public static let windowIdentifier = "history.window"

    private let model: HistoryViewModel
    private var window: NSWindow?

    public init(model: HistoryViewModel) {
        self.model = model
    }

    public func show(selecting id: UUID? = nil) {
        let window = window ?? makeWindow()
        self.window = window
        model.refresh()
        if let id {
            model.selectedID = id
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.identifier = NSUserInterfaceItemIdentifier(Self.windowIdentifier)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: HistoryView(model: model))
        window.center()
        return window
    }
}

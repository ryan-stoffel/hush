import AppKit
import SwiftUI

/// A panel that can never become key or main, so showing it leaves the frontmost app and its caret alone.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
public final class OverlayPanelController {
    public static let accessibilityIdentifier = "overlay.panel"
    static let bottomMargin: CGFloat = 48
    static let fallbackSize = CGSize(width: 220, height: 52)

    public let model: OverlayViewModel
    private let panel: OverlayPanel
    private var timer: Timer?
    private var startedAt: Date?
    private var hideWorkItem: DispatchWorkItem?

    public init(model: OverlayViewModel? = nil) {
        let model = model ?? OverlayViewModel()
        self.model = model
        // The non-activating style has to be part of the initial style mask to take effect.
        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.setAccessibilityIdentifier(Self.accessibilityIdentifier)
        let hosting = NSHostingView(rootView: OverlayView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentView = hosting
    }

    public var isVisible: Bool {
        panel.isVisible
    }

    public func showListening() {
        hideWorkItem?.cancel()
        model.resetForNewDictation()
        startedAt = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.model.elapsed = Date().timeIntervalSince(startedAt)
            }
        }
        present()
    }

    public func showTranscribing() {
        hideWorkItem?.cancel()
        stopTimer()
        model.mode = .transcribing
        present()
    }

    public func showError(_ message: String, duration: TimeInterval) {
        stopTimer()
        model.mode = .error(message)
        present()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem?.cancel()
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    public func hide() {
        hideWorkItem?.cancel()
        stopTimer()
        panel.orderOut(nil)
    }

    /// Shows a fixed state for screenshots. No timer runs.
    public func showStatic(mode: OverlayViewModel.Mode) {
        model.mode = mode
        present()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
    }

    private func present() {
        panel.contentView?.layoutSubtreeIfNeeded()
        let fitting = panel.contentView?.fittingSize ?? .zero
        let size = fitting.width > 1 && fitting.height > 1 ? fitting : Self.fallbackSize
        let screen = Self.screenWithMouse() ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let origin = Self.origin(forPanelOf: size, in: visible)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    static func origin(forPanelOf size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(x: (visibleFrame.midX - size.width / 2).rounded(), y: visibleFrame.minY + bottomMargin)
    }

    private static func screenWithMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
    }
}

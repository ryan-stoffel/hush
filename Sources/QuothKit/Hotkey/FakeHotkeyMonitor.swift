import QuothCore

/// Used by tests. Demo mode never creates a hotkey monitor at all.
public final class FakeHotkeyMonitor: HotkeyMonitoring {
    public var onEvent: ((HotkeyEvent) -> Void)?
    public private(set) var isStarted = false
    public var startError: Error?

    public init() {}

    public func start() throws {
        if let startError {
            throw startError
        }
        isStarted = true
    }

    public func stop() {
        isStarted = false
    }

    public func send(_ event: HotkeyEvent) {
        onEvent?(event)
    }
}

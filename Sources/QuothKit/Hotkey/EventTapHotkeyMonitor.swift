import CoreGraphics
import Foundation
import QuothCore

/// Watches the keyboard with a listen-only event tap. Listen-only is deliberate: the tap can
/// never swallow or delay input, and an active tap can hang the system if its permission is revoked.
public final class EventTapHotkeyMonitor: HotkeyMonitoring {
    public var onEvent: ((HotkeyEvent) -> Void)?

    private var stateMachine: HotkeyStateMachine
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init(stateMachine: HotkeyStateMachine = HotkeyStateMachine()) {
        self.stateMachine = stateMachine
    }

    deinit {
        stop()
    }

    public var isRunning: Bool {
        tap != nil
    }

    public func start() throws {
        guard tap == nil else { return }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let monitor = Unmanaged<EventTapHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.receive(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HotkeyError.eventTapUnavailable
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        guard let input = Self.keyInput(type: type, event: event) else { return }
        if let output = stateMachine.handle(input) {
            onEvent?(output)
        }
    }

    static func keyInput(type: CGEventType, event: CGEvent) -> KeyInput? {
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let time = TimeInterval(event.timestamp) / 1_000_000_000
        switch type {
        case .flagsChanged:
            return .flagsChanged(keyCode: keyCode, modifiers: modifiers(from: event.flags), time: time)
        case .keyDown:
            return .keyDown(keyCode: keyCode, time: time)
        default:
            return nil
        }
    }

    static func modifiers(from flags: CGEventFlags) -> KeyModifiers {
        var modifiers: KeyModifiers = []
        if flags.contains(.maskSecondaryFn) {
            modifiers.insert(.function)
        }
        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        return modifiers
    }
}

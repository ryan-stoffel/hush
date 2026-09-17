import Foundation

public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let function = KeyModifiers(rawValue: 1 << 0)
    public static let shift = KeyModifiers(rawValue: 1 << 1)
    public static let control = KeyModifiers(rawValue: 1 << 2)
    public static let option = KeyModifiers(rawValue: 1 << 3)
    public static let command = KeyModifiers(rawValue: 1 << 4)
}

public enum KeyInput: Equatable, Sendable {
    case flagsChanged(keyCode: UInt16, modifiers: KeyModifiers, time: TimeInterval)
    case keyDown(keyCode: UInt16, time: TimeInterval)
}

public enum HotkeyEvent: Equatable, Sendable {
    case pressed
    case released
    case cancelled
}

public enum HotkeyError: Error, Equatable {
    case eventTapUnavailable
}

public protocol HotkeyMonitoring: AnyObject {
    var onEvent: ((HotkeyEvent) -> Void)? { get set }
    func start() throws
    func stop()
}

/// Push-to-talk on a bare Fn hold.
///
/// `pressed` fires as soon as Fn goes down so capture starts without delay. The hold ends with
/// `released`, or with `cancelled` when it turns out the user was doing something else:
/// a quick tap, Fn plus another key (Fn+arrow, Fn+F5), or Fn plus another modifier.
public struct HotkeyStateMachine: Sendable {
    public static let functionKeyCode: UInt16 = 63

    public let minimumHold: TimeInterval
    private var holdStart: TimeInterval?
    private var isWaitingForRelease = false

    public init(minimumHold: TimeInterval = 0.15) {
        self.minimumHold = minimumHold
    }

    public var isHolding: Bool {
        holdStart != nil
    }

    public mutating func handle(_ input: KeyInput) -> HotkeyEvent? {
        switch input {
        case .keyDown:
            return cancelHold()
        case let .flagsChanged(keyCode, modifiers, time):
            let functionDown = modifiers.contains(.function)
            if isWaitingForRelease {
                if !functionDown {
                    isWaitingForRelease = false
                }
                return nil
            }
            if let start = holdStart {
                if !functionDown {
                    holdStart = nil
                    return time - start < minimumHold ? .cancelled : .released
                }
                return modifiers == .function ? nil : cancelHold()
            }
            guard keyCode == Self.functionKeyCode, modifiers == .function else { return nil }
            holdStart = time
            return .pressed
        }
    }

    private mutating func cancelHold() -> HotkeyEvent? {
        guard holdStart != nil else { return nil }
        holdStart = nil
        isWaitingForRelease = true
        return .cancelled
    }
}

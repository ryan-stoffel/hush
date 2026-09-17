import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

public protocol PasteKeystrokePosting: AnyObject {
    var isTrusted: Bool { get }
    func postPaste()
}

public final class SystemPasteKeystroke: PasteKeystrokePosting {
    public init() {}

    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func postPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = KeyCodeResolver.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}

/// Finds the key that types a character on the current keyboard layout, so Cmd+V still pastes on
/// Dvorak, Colemak, AZERTY and the rest.
public enum KeyCodeResolver {
    public static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let target = String(character).lowercased()
        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            for keyCode in UInt16(0) ..< 128 where string(for: keyCode, layout: layout) == target {
                return CGKeyCode(keyCode)
            }
            return nil
        }
    }

    private static func string(for keyCode: UInt16, layout: UnsafePointer<UCKeyboardLayout>) -> String? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).lowercased()
    }
}

import Foundation

/// Short, readable messages for everything that can go wrong in the dictation loop.
public enum DictationFailure {
    public static func message(for error: Error) -> String {
        switch error {
        case let error as AudioCaptureError: message(for: error)
        case let error as TranscriptionError: message(for: error)
        case let error as InsertionError: message(for: error)
        case HotkeyError.eventTapUnavailable: "Input Monitoring access is off"
        default: "Something went wrong"
        }
    }

    public static func message(forMissing permissions: [Permission]) -> String? {
        guard let first = permissions.first else { return nil }
        return "\(first.displayName) access is off"
    }

    private static func message(for error: AudioCaptureError) -> String {
        switch error {
        case .microphonePermissionMissing: "Microphone access is off"
        case .noInputDevice: "No microphone found"
        case .engineFailure: "Could not start recording"
        }
    }

    private static func message(for error: TranscriptionError) -> String {
        switch error {
        case .tooShort: "That was too short"
        case .unsupportedHardware: "On-device transcription needs Apple silicon"
        case .modelUnavailable: "The speech model is not available"
        case .failed: "Transcription failed"
        }
    }

    private static func message(for error: InsertionError) -> String {
        switch error {
        case .accessibilityNotGranted: "Accessibility access is off"
        case .emptyText: "Nothing to insert"
        case .failed: "Could not insert the text"
        }
    }
}

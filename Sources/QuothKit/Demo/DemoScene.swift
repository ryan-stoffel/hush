import Foundation
import QuothCore

/// Every scene the screenshot suite can open. Raw values are the screenshot file names.
public enum DemoScene: String, CaseIterable, Sendable {
    case popover
    case popoverPermissions = "popover-permissions"
    case overlayListening = "overlay-listening"
    case overlayTranscribing = "overlay-transcribing"
}

public enum DemoData {
    public static let lastDictation = "Send the report on Wednesday, and copy Priya on the thread."

    public static let elapsed: TimeInterval = 7
    public static let waveform = WaveformModel(levels: [
        0.10, 0.22, 0.35, 0.62, 0.80, 0.55, 0.30, 0.42, 0.75, 0.95, 0.70, 0.48,
        0.25, 0.18, 0.40, 0.66, 0.88, 0.60, 0.33, 0.20, 0.45, 0.72, 0.50, 0.28,
    ])

    public static func permissions(for scene: DemoScene?) -> FakePermissions {
        switch scene {
        case .popoverPermissions:
            FakePermissions(
                statuses: [.microphone: .notDetermined, .accessibility: .denied, .inputMonitoring: .granted],
                grantsOnRequest: false
            )
        default:
            .allGranted
        }
    }
}

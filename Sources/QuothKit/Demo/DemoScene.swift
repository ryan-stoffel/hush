import Foundation
import QuothCore

/// Every scene the screenshot suite can open. Raw values are the screenshot file names.
public enum DemoScene: String, CaseIterable, Sendable {
    case popover
    case popoverPermissions = "popover-permissions"
}

public enum DemoData {
    public static let lastDictation = "Send the report on Wednesday, and copy Priya on the thread."

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

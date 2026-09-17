import Foundation

public enum Permission: String, CaseIterable, Sendable {
    case microphone
    case accessibility
    case inputMonitoring

    public var displayName: String {
        switch self {
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        }
    }

    public var reason: String {
        switch self {
        case .microphone: "Records your voice while you hold the dictation key."
        case .accessibility: "Inserts the text at your cursor in other apps."
        case .inputMonitoring: "Notices the dictation key while another app is in front."
        }
    }

    /// Deep link into System Settings, Privacy and Security.
    public var settingsURL: URL? {
        let anchor = switch self {
        case .microphone: "Privacy_Microphone"
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
    }
}

public enum PermissionStatus: String, Sendable {
    case granted
    case notDetermined
    case denied
}

/// Mirrors AVAuthorizationStatus so the mapping can be tested without AVFoundation.
public enum MicrophoneAuthorization: Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

public extension PermissionStatus {
    init(microphone authorization: MicrophoneAuthorization) {
        switch authorization {
        case .authorized: self = .granted
        case .notDetermined: self = .notDetermined
        case .denied, .restricted: self = .denied
        }
    }

    /// Accessibility and Input Monitoring only report trusted or not trusted.
    init(isTrusted: Bool) {
        self = isTrusted ? .granted : .denied
    }
}

public protocol PermissionsProviding: Sendable {
    func status(of permission: Permission) -> PermissionStatus
    func request(_ permission: Permission) async -> PermissionStatus
    func openSettings(for permission: Permission)
}

public extension PermissionsProviding {
    func snapshot() -> [Permission: PermissionStatus] {
        Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0, status(of: $0)) })
    }
}

public enum PermissionSummary {
    /// Missing permissions in the order the user should grant them.
    public static func missing(in snapshot: [Permission: PermissionStatus]) -> [Permission] {
        Permission.allCases.filter { snapshot[$0, default: .notDetermined] != .granted }
    }

    public static func message(forMissing missing: [Permission]) -> String? {
        switch missing.count {
        case 0: nil
        case 1: "\(missing[0].displayName) access is needed."
        default: "\(missing.map(\.displayName).formatted(.list(type: .and))) access is needed."
        }
    }
}

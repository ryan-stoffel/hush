import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import HushCore

public struct SystemPermissionsService: PermissionsProviding {
    public init() {}

    public func status(of permission: Permission) -> PermissionStatus {
        switch permission {
        case .microphone:
            PermissionStatus(microphone: Self.authorization(from: AVCaptureDevice.authorizationStatus(for: .audio)))
        case .accessibility:
            PermissionStatus(isTrusted: AXIsProcessTrusted())
        case .inputMonitoring:
            PermissionStatus(isTrusted: CGPreflightListenEventAccess())
        }
    }

    public func request(_ permission: Permission) async -> PermissionStatus {
        switch permission {
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .inputMonitoring:
            _ = CGRequestListenEventAccess()
        }
        return status(of: permission)
    }

    public func openSettings(for permission: Permission) {
        guard let url = permission.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    static func authorization(from status: AVAuthorizationStatus) -> MicrophoneAuthorization {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}

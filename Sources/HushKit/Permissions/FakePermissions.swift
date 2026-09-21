import Foundation
import HushCore

/// Used by demo mode and tests. Never calls a system API.
public final class FakePermissions: PermissionsProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var statuses: [Permission: PermissionStatus]
    private var requestedPermissions: [Permission] = []
    private var openedPermissions: [Permission] = []
    private let grantsOnRequest: Bool

    public init(statuses: [Permission: PermissionStatus] = [:], grantsOnRequest: Bool = true) {
        self.statuses = statuses
        self.grantsOnRequest = grantsOnRequest
    }

    public static var allGranted: FakePermissions {
        FakePermissions(statuses: Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0, .granted) }))
    }

    public var requested: [Permission] {
        lock.withLock { requestedPermissions }
    }

    public var openedSettings: [Permission] {
        lock.withLock { openedPermissions }
    }

    public func status(of permission: Permission) -> PermissionStatus {
        lock.withLock { statuses[permission, default: .notDetermined] }
    }

    public func request(_ permission: Permission) async -> PermissionStatus {
        lock.withLock {
            requestedPermissions.append(permission)
            if grantsOnRequest {
                statuses[permission] = .granted
            }
            return statuses[permission, default: .notDetermined]
        }
    }

    public func openSettings(for permission: Permission) {
        lock.withLock { openedPermissions.append(permission) }
    }
}

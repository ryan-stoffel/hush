import Foundation

/// The app was called Quoth until 2026-09-20. Its models and history move to the new folder once,
/// so users keep their history and skip the 630 MB model download.
public enum LegacyDataMigration {
    public static let legacyName = "Quoth"

    @discardableResult
    public static func migrateIfNeeded(fileManager: FileManager = .default) -> Bool {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let old = base.appendingPathComponent(legacyName, isDirectory: true)
        let new = base.appendingPathComponent(AppInfo.name, isDirectory: true)
        guard fileManager.fileExists(atPath: old.path), !fileManager.fileExists(atPath: new.path) else {
            return false
        }
        do {
            try fileManager.moveItem(at: old, to: new)
            return true
        } catch {
            return false
        }
    }
}

import XCTest
@testable import HushCore

final class LegacyDataMigrationTests: XCTestCase {
    func testMovesTheOldFolderOnceAndLeavesAnExistingNewFolderAlone() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("hush-migration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appendingPathComponent("Library/Application Support")
        let old = support.appendingPathComponent(LegacyDataMigration.legacyName)
        try FileManager.default.createDirectory(
            at: old.appendingPathComponent("Models"),
            withIntermediateDirectories: true
        )
        try Data("x".utf8).write(to: old.appendingPathComponent("history.json"))

        let fileManager = SandboxedFileManager(support: support)
        XCTAssertTrue(LegacyDataMigration.migrateIfNeeded(fileManager: fileManager))
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default
            .fileExists(atPath: support.appendingPathComponent("\(AppInfo.name)/history.json").path))
        XCTAssertFalse(LegacyDataMigration.migrateIfNeeded(fileManager: fileManager))
    }
}

/// Points Application Support at a temporary folder.
private final class SandboxedFileManager: FileManager {
    let support: URL

    init(support: URL) {
        self.support = support
    }

    override func urls(for directory: SearchPathDirectory, in _: SearchPathDomainMask) -> [URL] {
        directory == .applicationSupportDirectory ? [support] : []
    }
}

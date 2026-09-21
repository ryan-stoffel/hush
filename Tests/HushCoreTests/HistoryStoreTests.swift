import XCTest
@testable import HushCore

final class HistoryStoreTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_789_660_800)

    private func entry(_ minutesAgo: Double, _ text: String = "hello") -> HistoryEntry {
        HistoryEntry(
            date: base.addingTimeInterval(-minutesAgo * 60),
            rawTranscript: text,
            cleanedText: text.capitalized,
            backendID: "fake",
            audioDuration: 1,
            insertionStrategy: .clipboardPaste
        )
    }

    private func makeStore(
        _ persistence: HistoryPersisting = InMemoryHistoryPersistence(),
        settings: SettingsStore = .inMemory()
    ) -> HistoryStore {
        HistoryStore(persistence: persistence, settings: settings, now: { [base] in base })
    }

    func testAppendKeepsNewestFirstAndPersists() {
        let persistence = InMemoryHistoryPersistence()
        let store = makeStore(persistence)
        store.append(entry(10, "older"))
        store.append(entry(1, "newer"))
        XCTAssertEqual(store.entries.map(\.rawTranscript), ["newer", "older"])
        XCTAssertEqual(persistence.entries.map(\.rawTranscript), ["newer", "older"])
    }

    func testPrunesByCount() {
        let settings = SettingsStore.inMemory()
        settings.set(SettingKeys.historyMaxCount, to: 2)
        let store = makeStore(settings: settings)
        for minutes in [3.0, 2, 1] {
            store.append(entry(minutes))
        }
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.date, base.addingTimeInterval(-60))
    }

    func testPrunesByAgeWithInjectedClock() {
        let settings = SettingsStore.inMemory()
        settings.set(SettingKeys.historyMaxAgeDays, to: 7)
        let persistence = InMemoryHistoryPersistence([entry(60 * 24 * 10, "old"), entry(60, "recent")])
        let store = makeStore(persistence, settings: settings)
        XCTAssertEqual(store.entries.map(\.rawTranscript), ["recent"])

        settings.set(SettingKeys.historyMaxAgeDays, to: 0)
        store.append(entry(60 * 24 * 400, "ancient"))
        XCTAssertEqual(store.entries.count, 2)
    }

    func testDisabledHistoryWritesNothing() {
        let settings = SettingsStore.inMemory()
        settings.set(SettingKeys.historyEnabled, to: false)
        let persistence = InMemoryHistoryPersistence()
        let store = makeStore(persistence, settings: settings)
        store.append(entry(1))
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(persistence.saveCount, 1) // the initial prune, with nothing in it
        XCTAssertTrue(persistence.entries.isEmpty)
    }

    func testDeleteAndClearAll() {
        let persistence = InMemoryHistoryPersistence()
        let store = makeStore(persistence)
        let first = entry(2, "first")
        store.append(first)
        store.append(entry(1, "second"))
        var changes = 0
        store.observe { changes += 1 }
        store.delete(ids: [first.id])
        XCTAssertEqual(store.entries.map(\.rawTranscript), ["second"])
        store.clearAll()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(persistence.entries.isEmpty)
        XCTAssertEqual(changes, 2)
    }

    func testFileRoundTripPermissionsAndCorruptionRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hush-history-\(UUID().uuidString)")
        let url = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = JSONFileStore<HistoryEntry>(url: url)
        let store = makeStore(file)
        store.append(entry(1, "persisted"))
        XCTAssertEqual(makeStore(JSONFileStore<HistoryEntry>(url: url)).entries.map(\.rawTranscript), ["persisted"])
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)

        try Data("not json".utf8).write(to: url)
        XCTAssertTrue(makeStore(JSONFileStore<HistoryEntry>(url: url)).entries.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path))
    }

    func testEntryReportsInsertion() {
        XCTAssertTrue(entry(1).wasInserted)
        let failed = HistoryEntry(
            date: base,
            rawTranscript: "x",
            cleanedText: "x",
            backendID: "b",
            audioDuration: 1,
            insertionStrategy: nil
        )
        XCTAssertFalse(failed.wasInserted)
    }

    func testDefaultsMatchTheRetentionOptions() {
        let settings = SettingsStore.inMemory()
        XCTAssertTrue(settings.get(SettingKeys.historyEnabled))
        XCTAssertTrue(HistoryRetention.countOptions.contains(settings.get(SettingKeys.historyMaxCount)))
        XCTAssertTrue(HistoryRetention.ageOptions.contains(settings.get(SettingKeys.historyMaxAgeDays)))
    }
}

import HushCore
import XCTest
@testable import HushKit

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_789_660_800)

    private struct Fixture {
        let model: HistoryViewModel
        let store: HistoryStore
    }

    private func makeModel(entries: [HistoryEntry] = DemoData.historyEntries, enabled: Bool = true) -> Fixture {
        let settings = SettingsStore.inMemory()
        settings.set(SettingKeys.historyEnabled, to: enabled)
        let store = HistoryStore(
            persistence: InMemoryHistoryPersistence(entries),
            settings: settings,
            now: { [now] in now }
        )
        let model = HistoryViewModel(
            store: store,
            settings: settings,
            calendar: calendar,
            now: { [now] in now },
            copyText: { _ in }
        )
        return Fixture(model: model, store: store)
    }

    func testGroupsSeededEntriesAcrossTwoDays() {
        let model = makeModel().model
        XCTAssertEqual(model.groups.map(\.title), ["Today", "Yesterday"])
        XCTAssertEqual(model.groups[0].entries.count, 3)
        XCTAssertEqual(model.groups[1].entries.count, 2)
        XCTAssertTrue(model.isEnabled)
    }

    func testSearchFiltersAndClearsAnInvisibleSelection() {
        let model = makeModel().model
        model.selectedID = DemoData.historyEntries[0].id
        model.query = "shopping"
        XCTAssertEqual(model.visibleEntries.count, 1)
        XCTAssertNil(model.selectedID)
        model.query = ""
        XCTAssertEqual(model.visibleEntries.count, 5)
    }

    func testDeleteMovesSelectionAndUpdatesStore() {
        let fixture = makeModel()
        let model = fixture.model
        let store = fixture.store
        let ids = DemoData.historyEntries.map(\.id)
        model.selectedID = ids[1]
        model.deleteSelected()
        XCTAssertEqual(model.selectedID, ids[2])
        XCTAssertEqual(store.entries.count, 4)
        XCTAssertEqual(model.visibleEntries.count, 4)
    }

    func testClearAllEmptiesEverything() {
        let fixture = makeModel()
        let model = fixture.model
        let store = fixture.store
        model.selectedID = DemoData.historyEntries[0].id
        model.clearAll()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertNil(model.selectedID)
    }

    func testCopyUsesTheSelectedEntry() {
        let settings = SettingsStore.inMemory()
        let store = HistoryStore(persistence: InMemoryHistoryPersistence(DemoData.historyEntries), settings: settings)
        var copied: [String] = []
        let model = HistoryViewModel(store: store, settings: settings, copyText: { copied.append($0) })
        model.copyCleaned()
        XCTAssertTrue(copied.isEmpty)
        model.selectedID = DemoData.historyEntries[1].id
        model.copyCleaned()
        model.copyRaw()
        XCTAssertEqual(copied, [DemoData.historyEntries[1].cleanedText, DemoData.historyEntries[1].rawTranscript])
    }

    func testDisabledHistoryCanBeTurnedBackOn() {
        let model = makeModel(entries: [], enabled: false).model
        XCTAssertFalse(model.isEnabled)
        model.enableHistory()
        XCTAssertTrue(model.isEnabled)
    }

    func testSeededDemoEntriesHaveStableIDsAndDates() {
        let ids = DemoData.historyEntries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(DemoData.historyEntries.map(\.date), DemoData.historyEntries.map(\.date).sorted(by: >))
    }

    func testPopoverOpensHistory() {
        var opened = 0
        let model = PopoverViewModel(
            appState: AppState(),
            permissions: FakePermissions.allGranted,
            version: "1",
            copyText: { _ in },
            quitApp: {},
            openHistory: { opened += 1 }
        )
        model.showHistory()
        XCTAssertEqual(opened, 1)
    }
}

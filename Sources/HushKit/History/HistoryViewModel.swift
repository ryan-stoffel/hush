import AppKit
import Combine
import Foundation
import HushCore

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var query = "" {
        didSet { refresh() }
    }

    @Published public private(set) var groups: [HistoryBrowsing.DayGroup] = []
    @Published public var selectedID: UUID?
    @Published public private(set) var isEnabled: Bool

    private let store: HistoryStore
    private let settings: SettingsStore
    private let calendar: Calendar
    private let now: () -> Date
    private let copyText: (String) -> Void
    private var observation: UUID?

    public init(
        store: HistoryStore,
        settings: SettingsStore,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        copyText: @escaping (String) -> Void = GeneralPasteboard.copy
    ) {
        self.store = store
        self.settings = settings
        self.calendar = calendar
        self.now = now
        self.copyText = copyText
        isEnabled = store.isEnabled
        refresh()
        observation = store.observe { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        if let observation {
            store.removeObserver(observation)
        }
    }

    public var visibleEntries: [HistoryEntry] {
        groups.flatMap(\.entries)
    }

    public var selectedEntry: HistoryEntry? {
        visibleEntries.first { $0.id == selectedID }
    }

    public var totalCount: Int {
        store.entries.count
    }

    public func refresh() {
        isEnabled = store.isEnabled
        groups = HistoryBrowsing.groupByDay(
            HistoryBrowsing.filter(store.entries, query: query),
            calendar: calendar,
            now: now()
        )
        if let selectedID, !visibleEntries.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
    }

    public func delete(_ ids: Set<UUID>) {
        selectedID = HistoryBrowsing.selectionAfterDeleting(ids, from: visibleEntries, selected: selectedID)
        store.delete(ids: ids)
        refresh()
    }

    public func deleteSelected() {
        guard let selectedID else { return }
        delete([selectedID])
    }

    public func clearAll() {
        selectedID = nil
        store.clearAll()
        refresh()
    }

    public func copyCleaned() {
        if let text = selectedEntry?.cleanedText {
            copyText(text)
        }
    }

    public func copyRaw() {
        if let text = selectedEntry?.rawTranscript {
            copyText(text)
        }
    }

    public func enableHistory() {
        settings.set(SettingKeys.historyEnabled, to: true)
        refresh()
    }
}

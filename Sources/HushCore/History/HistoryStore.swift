import Foundation

public protocol HistoryPersisting: AnyObject {
    func load() -> [HistoryEntry]
    func save(_ entries: [HistoryEntry]) throws
    func remove()
}

extension JSONFileStore<HistoryEntry>: HistoryPersisting {}

public final class InMemoryHistoryPersistence: HistoryPersisting {
    public private(set) var entries: [HistoryEntry]
    public private(set) var saveCount = 0

    public init(_ entries: [HistoryEntry] = []) {
        self.entries = entries
    }

    public func load() -> [HistoryEntry] {
        entries
    }

    public func save(_ entries: [HistoryEntry]) throws {
        self.entries = entries
        saveCount += 1
    }

    public func remove() {
        entries = []
    }
}

public enum HistoryRetention {
    public static let countOptions = [100, 500, 1000, 5000]
    /// Days. Zero means forever.
    public static let ageOptions = [1, 7, 30, 0]
}

/// Recent dictations, newest first, capped by count and age. Local only, and off when the user says so.
public final class HistoryStore: @unchecked Sendable {
    private let persistence: HistoryPersisting
    private let settings: SettingsStore
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var cached: [HistoryEntry]
    private var observers: [UUID: () -> Void] = [:]

    public init(
        persistence: HistoryPersisting,
        settings: SettingsStore,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.persistence = persistence
        self.settings = settings
        self.now = now
        cached = persistence.load().sorted { $0.date > $1.date }
        prune()
    }

    public static func onDisk(settings: SettingsStore) -> HistoryStore {
        let file = JSONFileStore<HistoryEntry>(url: JSONFileStore<HistoryEntry>
            .applicationSupportURL(fileName: "history.json"))
        return HistoryStore(persistence: file, settings: settings)
    }

    public var isEnabled: Bool {
        settings.get(SettingKeys.historyEnabled)
    }

    public var entries: [HistoryEntry] {
        lock.withLock { cached }
    }

    public func append(_ entry: HistoryEntry) {
        guard isEnabled else { return }
        lock.withLock {
            cached.insert(entry, at: 0)
            cached.sort { $0.date > $1.date }
        }
        prune()
    }

    public func delete(ids: Set<UUID>) {
        lock.withLock { cached.removeAll { ids.contains($0.id) } }
        persist()
    }

    /// Empties the file as well as the memory.
    public func clearAll() {
        lock.withLock { cached = [] }
        persistence.remove()
        notify()
    }

    public func prune() {
        let maxCount = settings.get(SettingKeys.historyMaxCount)
        let maxAgeDays = settings.get(SettingKeys.historyMaxAgeDays)
        let cutoff = maxAgeDays > 0 ? now().addingTimeInterval(-Double(maxAgeDays) * 86400) : Date.distantPast
        lock.withLock {
            cached = Array(cached.filter { $0.date >= cutoff }.prefix(max(maxCount, 0)))
        }
        persist()
    }

    @discardableResult
    public func observe(_ onChange: @escaping () -> Void) -> UUID {
        let token = UUID()
        lock.withLock { observers[token] = onChange }
        return token
    }

    public func removeObserver(_ token: UUID) {
        lock.withLock { observers[token] = nil }
    }

    private func persist() {
        let snapshot = entries
        try? persistence.save(snapshot)
        notify()
    }

    private func notify() {
        let callbacks = lock.withLock { Array(observers.values) }
        callbacks.forEach { $0() }
    }
}

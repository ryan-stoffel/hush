import Foundation

public struct SettingKey<Value: Codable & Equatable & Sendable>: Sendable {
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public protocol KeyValueStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public final class InMemoryKeyValueStore: KeyValueStoring {
    private var storage: [String: Data]

    public init(_ storage: [String: Data] = [:]) {
        self.storage = storage
    }

    public func data(forKey key: String) -> Data? {
        storage[key]
    }

    public func set(_ data: Data?, forKey key: String) {
        storage[key] = data
    }
}

public final class UserDefaultsKeyValueStore: KeyValueStoring {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Values written with `defaults write <bundle id> <key> '[value]'` arrive as strings and are accepted too.
    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key) ?? defaults.string(forKey: key).map { Data($0.utf8) }
    }

    public func set(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Typed settings over a key-value store. Values are stored as JSON so every Codable type works
/// the same way. Credentials never belong here; they go to the Keychain.
public final class SettingsStore {
    public typealias ObservationToken = UUID

    private let storage: KeyValueStoring
    private let lock = NSRecursiveLock()
    private var observers: [String: [ObservationToken: () -> Void]] = [:]
    private var touchedNames: Set<String> = []

    public init(storage: KeyValueStoring) {
        self.storage = storage
    }

    public static func inMemory() -> SettingsStore {
        SettingsStore(storage: InMemoryKeyValueStore())
    }

    public func get<Value>(_ key: SettingKey<Value>) -> Value {
        guard let data = storage.data(forKey: key.name),
              let box = try? JSONDecoder().decode([Value].self, from: data),
              let value = box.first else {
            return key.defaultValue
        }
        return value
    }

    public func set<Value>(_ key: SettingKey<Value>, to value: Value) {
        guard get(key) != value else { return }
        // Wrapped in an array because JSONEncoder on older systems rejects top-level fragments.
        storage.set(try? JSONEncoder().encode([value]), forKey: key.name)
        lock.withLock { _ = touchedNames.insert(key.name) }
        notify(key.name)
    }

    public func reset(_ key: SettingKey<some Any>) {
        storage.set(nil, forKey: key.name)
        notify(key.name)
    }

    /// Restores every known key, and any key written through this store, to its default.
    public func resetAll() {
        let names = lock.withLock { touchedNames.union(SettingKeys.allNames) }
        for name in names {
            storage.set(nil, forKey: name)
            notify(name)
        }
    }

    @discardableResult
    public func observe(_ key: SettingKey<some Any>, onChange: @escaping () -> Void) -> ObservationToken {
        let token = ObservationToken()
        lock.withLock { observers[key.name, default: [:]][token] = onChange }
        return token
    }

    public func removeObserver(_ token: ObservationToken) {
        lock.withLock {
            for name in observers.keys {
                observers[name]?[token] = nil
            }
        }
    }

    private func notify(_ name: String) {
        let callbacks = lock.withLock { Array((observers[name] ?? [:]).values) }
        callbacks.forEach { $0() }
    }
}

import XCTest
@testable import HushCore

final class SettingsStoreTests: XCTestCase {
    private enum Mode: String, Codable { case hold, toggle }

    private let flag = SettingKey("test.flag", default: true)
    private let count = SettingKey("test.count", default: 3)
    private let label = SettingKey("test.label", default: "none")
    private let mode = SettingKey("test.mode", default: Mode.hold)
    private let list = SettingKey("test.list", default: ["a"])

    func testUnwrittenKeysReturnDefaults() {
        let store = SettingsStore.inMemory()
        XCTAssertTrue(store.get(flag))
        XCTAssertEqual(store.get(count), 3)
        XCTAssertEqual(store.get(list), ["a"])
    }

    func testRoundTrips() {
        let store = SettingsStore.inMemory()
        store.set(flag, to: false)
        store.set(count, to: 42)
        store.set(label, to: "hello")
        store.set(mode, to: .toggle)
        store.set(list, to: ["x", "y"])
        XCTAssertFalse(store.get(flag))
        XCTAssertEqual(store.get(count), 42)
        XCTAssertEqual(store.get(label), "hello")
        XCTAssertEqual(store.get(mode), .toggle)
        XCTAssertEqual(store.get(list), ["x", "y"])
    }

    func testUndecodableValueFallsBackToTheDefault() {
        let storage = InMemoryKeyValueStore(["test.count": Data("not json".utf8)])
        XCTAssertEqual(SettingsStore(storage: storage).get(count), 3)
        let wrongType = InMemoryKeyValueStore(["test.count": Data("[\"text\"]".utf8)])
        XCTAssertEqual(SettingsStore(storage: wrongType).get(count), 3)
    }

    func testObserversFireOnlyForTheirKeyAndOnlyOnChange() {
        let store = SettingsStore.inMemory()
        var flagChanges = 0
        let token = store.observe(flag) { flagChanges += 1 }
        store.set(flag, to: false)
        store.set(flag, to: false)
        store.set(count, to: 9)
        XCTAssertEqual(flagChanges, 1)
        store.removeObserver(token)
        store.set(flag, to: true)
        XCTAssertEqual(flagChanges, 1)
    }

    func testResetAllRestoresDefaults() {
        let store = SettingsStore.inMemory()
        store.set(flag, to: false)
        store.set(SettingKeys.cleanupEnabled, to: false)
        var notified = 0
        store.observe(SettingKeys.cleanupEnabled) { notified += 1 }
        store.resetAll()
        XCTAssertTrue(store.get(flag))
        XCTAssertTrue(store.get(SettingKeys.cleanupEnabled))
        XCTAssertEqual(notified, 1)
    }

    func testUserDefaultsBackedStore() throws {
        let suite = "hush.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(storage: UserDefaultsKeyValueStore(defaults: defaults))
        store.set(count, to: 7)
        XCTAssertEqual(SettingsStore(storage: UserDefaultsKeyValueStore(defaults: defaults)).get(count), 7)
        store.reset(count)
        XCTAssertNil(defaults.data(forKey: "test.count"))
    }

    func testNoKeyNameLooksLikeACredential() {
        XCTAssertEqual(Set(SettingKeys.allNames).count, SettingKeys.allNames.count)
        for name in SettingKeys.allNames {
            let parts = name.lowercased().split { !$0.isLetter }.map(String.init)
            for banned in ["key", "token", "secret", "password"] {
                XCTAssertFalse(parts.contains(banned), "\(name) looks like a credential; use the Keychain")
            }
        }
    }
}

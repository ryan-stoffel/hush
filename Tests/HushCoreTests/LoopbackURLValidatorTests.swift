import XCTest
@testable import HushCore

private final class StubCleaner: LLMCleaner, @unchecked Sendable {
    let id: String
    var displayName: String {
        id
    }

    let isLocal = true
    let available: LLMAvailability
    var calls = 0

    init(_ id: String, _ available: LLMAvailability) {
        self.id = id
        self.available = available
    }

    func availability() async -> LLMAvailability {
        available
    }

    func clean(_: LLMCleanupRequest) async throws -> String {
        calls += 1
        return "from \(id)"
    }
}

final class LoopbackURLValidatorTests: XCTestCase {
    func testLoopbackHostsAreAccepted() {
        for text in [
            "http://localhost:11434/v1",
            "http://127.0.0.1:1234/v1",
            "http://[::1]:11434/v1",
            "https://LOCALHOST/v1",
        ] {
            guard case .success = LoopbackURLValidator.validate(text) else { return XCTFail(text) }
        }
    }

    func testRemoteAndLookalikeHostsAreRejected() {
        for text in [
            "http://localhost.evil.com/v1",
            "http://127.0.0.1.nip.io/v1",
            "https://api.openai.com/v1",
            "http://10.0.0.5:11434/v1",
            "http://[2001:db8::1]/v1",
        ] {
            guard case let .failure(error) = LoopbackURLValidator.validate(text),
                  case .notLoopback = error else {
                return XCTFail(text)
            }
            XCTAssertTrue(error.message.contains("v0.3"))
        }
    }

    func testMalformedURLsAreRejected() {
        for text in ["", "localhost:11434", "ftp://localhost/v1", "not a url"] {
            XCTAssertEqual(LoopbackURLValidator.validate(text), .failure(.invalidURL), text)
        }
    }

    func testFirstAvailableCleanerSkipsUnavailableOnes() async throws {
        let off = StubCleaner("apple", .unavailable("Apple Intelligence is off"))
        let on = StubCleaner("ollama", .available)
        let cleaner = FirstAvailableCleaner([off, on])
        let awaited1 = await cleaner.availability()
        XCTAssertEqual(awaited1, .available)
        let output = try await cleaner.clean(LLMCleanupRequest(text: "hello there my friend"))
        XCTAssertEqual(output, "from ollama")
        XCTAssertEqual(off.calls, 0)
    }

    func testFirstAvailableCleanerReportsEveryReason() async {
        let cleaner = FirstAvailableCleaner([
            StubCleaner("apple", .unavailable("off")),
            StubCleaner("ollama", .unavailable("not running")),
        ])
        let awaited2 = await cleaner.availability()
        XCTAssertEqual(awaited2, .unavailable("apple: off. ollama: not running"))
        do {
            _ = try await cleaner.clean(LLMCleanupRequest(text: "hello there my friend"))
            XCTFail("expected unavailable")
        } catch {
            XCTAssertEqual(error as? LLMError, .unavailable("apple: off. ollama: not running"))
        }
        let awaited3 = await FirstAvailableCleaner([]).availability()
        XCTAssertEqual(awaited3, .unavailable("No cleanup model is configured"))
    }

    func testUserDefaultsStoreAcceptsStringValuesFromDefaultsWrite() throws {
        let suite = "hush.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("[true]", forKey: SettingKeys.localServerEnabled.name)
        defaults.set("[\"http://127.0.0.1:1234/v1\"]", forKey: SettingKeys.localServerBaseURL.name)
        let store = SettingsStore(storage: UserDefaultsKeyValueStore(defaults: defaults))
        XCTAssertTrue(store.get(SettingKeys.localServerEnabled))
        XCTAssertEqual(store.get(SettingKeys.localServerBaseURL), "http://127.0.0.1:1234/v1")
    }
}

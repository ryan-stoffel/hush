import QuothCore
import XCTest
@testable import QuothKit

/// Answers every request from the cleaner without a network.
class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var request = request
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                if read <= 0 {
                    break
                }
                data.append(buffer, count: read)
            }
            request.httpBody = data
        }
        Self.requests.append(request)
        do {
            guard let handler = Self.handler else { throw URLError(.cannotConnectToHost) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class LocalServerCleanerTests: XCTestCase {
    private let baseURL = URL(string: "http://localhost:11434/v1")!
    private let request = LLMCleanupRequest(text: "hello there my friend", language: "en")

    override func setUp() {
        super.setUp()
        StubURLProtocol.handler = nil
        StubURLProtocol.requests = []
    }

    private func makeCleaner(model: String = "llama3.2", timeout: TimeInterval = 5) -> LocalServerCleaner {
        LocalServerCleaner(baseURL: baseURL, model: model, timeout: timeout, protocolClasses: [StubURLProtocol.self])
    }

    private func respond(_ status: Int, _ json: String) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { [baseURL] request in
            let url = request.url ?? baseURL
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            guard let response else { throw URLError(.badServerResponse) }
            return (response, Data(json.utf8))
        }
    }

    func testEncodesAChatCompletionRequestAndDecodesTheReply() async throws {
        StubURLProtocol.handler = respond(
            200,
            #"{"choices":[{"message":{"role":"assistant","content":"Hello there, my friend."}}]}"#
        )
        let output = try await makeCleaner().clean(request)
        XCTAssertEqual(output, "Hello there, my friend.")

        let sent = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(sent.url?.absoluteString, "http://localhost:11434/v1/chat/completions")
        XCTAssertEqual(sent.httpMethod, "POST")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(sent.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "llama3.2")
        XCTAssertEqual(body?["temperature"] as? Double, 0)
        XCTAssertEqual(body?["stream"] as? Bool, false)
        let messages = body?["messages"] as? [[String: String]]
        XCTAssertEqual(messages?.first?["role"], "system")
        XCTAssertEqual(messages?.last?["role"], "user")
        XCTAssertEqual(messages?.last?["content"], "hello there my friend")
        // system, six example pairs for the format level, then the transcript
        XCTAssertEqual(messages?.count, 1 + 6 * 2 + 1)
    }

    func testHTTPErrorsAndMalformedJSONFail() async {
        StubURLProtocol.handler = respond(500, "boom")
        await assertThrows(.failed("The local server answered with HTTP 500"))
        StubURLProtocol.handler = respond(200, "{not json")
        await assertThrows(.failed("The local server sent a reply that could not be read"))
    }

    func testServerNotRunningIsUnavailable() async {
        StubURLProtocol.handler = nil
        await assertThrows(.unavailable("The local server is not running at http://localhost:11434/v1"))
        let awaited1 = await makeCleaner().testConnection()
        XCTAssertEqual(awaited1, .serverNotRunning)
    }

    func testTimeoutFails() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await assertThrows(.failed("The local server did not answer in time"))
    }

    func testConnectionTestListsModels() async {
        StubURLProtocol.handler = respond(200, #"{"data":[{"id":"llama3.2"},{"id":"mistral"}]}"#)
        let awaited2 = await makeCleaner().testConnection()
        XCTAssertEqual(awaited2, .ok(models: ["llama3.2", "mistral"]))
        let awaited3 = await makeCleaner(model: "phi").testConnection()
        XCTAssertEqual(awaited3, .modelNotFound(available: ["llama3.2", "mistral"]))
        XCTAssertEqual(StubURLProtocol.requests.last?.url?.path, "/v1/models")
    }

    func testRemoteBaseURLIsNeverCalled() async throws {
        let remote = try LocalServerCleaner(
            baseURL: XCTUnwrap(URL(string: "http://localhost.evil.com/v1")),
            model: "x",
            protocolClasses: [StubURLProtocol.self]
        )
        StubURLProtocol.handler = respond(200, "{}")
        let availability = await remote.availability()
        guard case .unavailable = availability else { return XCTFail("expected unavailable") }
        _ = try? await remote.clean(request)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testRedirectsOffTheMachineAreRefused() throws {
        let delegate = LoopbackSessionDelegate()
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: baseURL)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: baseURL,
            statusCode: 302,
            httpVersion: nil,
            headerFields: nil
        ))
        var followed: [URLRequest?] = []
        try delegate.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: XCTUnwrap(URL(string: "https://evil.com/v1")))
        ) { followed.append($0) }
        try delegate.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: XCTUnwrap(URL(string: "http://127.0.0.1:1234/v1")))
        ) { followed.append($0) }
        XCTAssertEqual(followed.count, 2)
        XCTAssertNil(followed[0])
        XCTAssertNotNil(followed[1])
    }

    func testSessionConfigurationKeepsNothing() {
        let configuration = LocalServerCleaner.configuration(timeout: 5, protocolClasses: nil)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(configuration.connectionProxyDictionary?.isEmpty, true)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 5)
    }

    func testAppBuildsTheLocalCleanerOnlyWhenEnabledAndLoopback() {
        let settings = SettingsStore.inMemory()
        XCTAssertTrue(AppDelegate.localServerCleaner(from: settings).isEmpty)
        settings.set(SettingKeys.localServerEnabled, to: true)
        XCTAssertEqual(AppDelegate.localServerCleaner(from: settings).count, 1)
        settings.set(SettingKeys.localServerBaseURL, to: "https://api.openai.com/v1")
        XCTAssertTrue(AppDelegate.localServerCleaner(from: settings).isEmpty)
    }

    private func assertThrows(_ expected: LLMError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await makeCleaner().clean(request)
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? LLMError, expected, file: file, line: line)
        }
    }
}

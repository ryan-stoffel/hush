import Foundation
import QuothCore

/// Cleanup through an OpenAI-compatible chat completions server on this Mac (Ollama, LM Studio).
/// The host must be loopback; that is what keeps this a local backend under the privacy rule.
public final class LocalServerCleaner: LLMCleaner, @unchecked Sendable {
    public enum ConnectionTest: Equatable {
        case ok(models: [String])
        case serverNotRunning
        case modelNotFound(available: [String])
        case failed(String)
    }

    public let id = "local-server"
    public let displayName = "Local server (Ollama, LM Studio)"
    public let isLocal = true

    public let baseURL: URL
    public let model: String
    private let session: URLSession

    public init(baseURL: URL, model: String, timeout: TimeInterval = 5, protocolClasses: [AnyClass]? = nil) {
        self.baseURL = baseURL
        self.model = model
        session = URLSession(
            configuration: Self.configuration(timeout: timeout, protocolClasses: protocolClasses),
            delegate: LoopbackSessionDelegate(),
            delegateQueue: nil
        )
    }

    /// Ephemeral, no cookies, no cache, and no proxy: nothing about these requests leaves the machine.
    static func configuration(timeout: TimeInterval, protocolClasses: [AnyClass]?) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return configuration
    }

    public func availability() async -> LLMAvailability {
        guard LoopbackURLValidator.isLoopback(baseURL) else {
            return .unavailable(LocalServerError.notLoopback(host: baseURL.host ?? "").message)
        }
        guard !model.isEmpty else { return .unavailable("Choose a model for the local server") }
        return .available
    }

    public func clean(_ request: LLMCleanupRequest) async throws -> String {
        if case let .unavailable(reason) = await availability() {
            throw LLMError.unavailable(reason)
        }
        var messages = [ChatRequest.Message(role: "system", content: PromptBuilder.instructions(for: request))]
        for example in PromptBuilder.examples(for: request.editLevel) {
            messages.append(.init(role: "user", content: example.transcript))
            messages.append(.init(role: "assistant", content: example.formatted))
        }
        messages.append(.init(role: "user", content: PromptBuilder.message(for: request)))
        let body = ChatRequest(model: model, messages: messages)
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await perform(urlRequest)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw LLMError.failed("The local server answered with HTTP \(response.statusCode)")
        }
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content else {
            throw LLMError.failed("The local server sent a reply that could not be read")
        }
        return content
    }

    public func testConnection() async -> ConnectionTest {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        do {
            let (data, response) = try await perform(request)
            guard (200 ..< 300).contains(response.statusCode) else {
                return .failed("HTTP \(response.statusCode)")
            }
            let models = (try? JSONDecoder().decode(ModelsResponse.self, from: data))?.data.map(\.id) ?? []
            return models.contains(model) ? .ok(models: models) : .modelNotFound(available: models)
        } catch let error as LLMError {
            if case .unavailable = error {
                return .serverNotRunning
            }
            return .failed("\(error)")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw LLMError.failed("Not an HTTP response") }
            return (data, http)
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .cannotFindHost {
            throw LLMError.unavailable("The local server is not running at \(baseURL.absoluteString)")
        } catch let error as URLError where error.code == .timedOut {
            throw LLMError.failed("The local server did not answer in time")
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.failed(error.localizedDescription)
        }
    }

    struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature = 0.0
        let stream = false
    }

    struct ChatReply: Decodable {
        let content: String
    }

    struct ChatChoice: Decodable {
        let message: ChatReply
    }

    struct ChatResponse: Decodable {
        let choices: [ChatChoice]
    }

    struct ModelsResponse: Decodable {
        struct Model: Decodable {
            let id: String
        }

        let data: [Model]
    }
}

/// Refuses redirects that would leave the machine.
final class LoopbackSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let url = request.url, LoopbackURLValidator.isLoopback(url) {
            completionHandler(request)
        } else {
            completionHandler(nil)
        }
    }
}

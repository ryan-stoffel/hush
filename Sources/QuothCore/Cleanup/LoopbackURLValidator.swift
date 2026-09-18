import Foundation

public enum LocalServerError: Error, Equatable {
    case invalidURL
    case notLoopback(host: String)

    public var message: String {
        switch self {
        case .invalidURL:
            "Enter a URL such as http://localhost:11434/v1"
        case let .notLoopback(host):
            "\(host) is not on this Mac. Remote servers arrive with the cloud backends in v0.3."
        }
    }
}

/// Only loopback hosts count as local under the privacy rule. Anything else is a cloud backend.
public enum LoopbackURLValidator {
    public static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]", "0:0:0:0:0:0:0:1"]

    public static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return false }
        return loopbackHosts.contains(host)
    }

    public static func validate(_ text: String) -> Result<URL, LocalServerError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host, !host.isEmpty else {
            return .failure(.invalidURL)
        }
        guard isLoopback(url) else { return .failure(.notLoopback(host: host)) }
        return .success(url)
    }
}

/// Uses the first cleaner that reports itself available, so Apple Intelligence wins when it is on
/// and a local server takes over when it is not.
public final class FirstAvailableCleaner: LLMCleaner {
    public let id = "first-available"
    public let displayName = "Automatic"
    public let isLocal: Bool
    private let cleaners: [any LLMCleaner]

    public init(_ cleaners: [any LLMCleaner]) {
        self.cleaners = cleaners
        isLocal = cleaners.allSatisfy(\.isLocal)
    }

    public func availability() async -> LLMAvailability {
        var reasons: [String] = []
        for cleaner in cleaners {
            switch await cleaner.availability() {
            case .available: return .available
            case let .unavailable(reason): reasons.append("\(cleaner.displayName): \(reason)")
            }
        }
        return .unavailable(reasons.isEmpty ? "No cleanup model is configured" : reasons.joined(separator: ". "))
    }

    public func clean(_ request: LLMCleanupRequest) async throws -> String {
        for cleaner in cleaners where await cleaner.availability().isAvailable {
            return try await cleaner.clean(request)
        }
        guard case let .unavailable(reason) = await availability() else { throw LLMError.failed("No cleaner") }
        throw LLMError.unavailable(reason)
    }
}

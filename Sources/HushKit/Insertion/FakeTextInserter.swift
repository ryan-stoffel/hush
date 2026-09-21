import Foundation
import HushCore

public final class FakeTextInserter: TextInserting, @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String] = []
    private var error: InsertionError?

    public init(error: InsertionError? = nil) {
        self.error = error
    }

    public var insertedTexts: [String] {
        lock.withLock { texts }
    }

    public func insert(_ text: String) async throws -> InsertionResult {
        try lock.withLock {
            if let error {
                throw error
            }
            texts.append(text)
        }
        return InsertionResult(strategy: .clipboardPaste, restoredClipboard: true)
    }
}

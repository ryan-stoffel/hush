import Combine
import Foundation
import HushCore

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var dictation: DictationState
    @Published public var lastDictation: String?
    @Published public var permissions: [Permission: PermissionStatus] = [:]

    public init(dictation: DictationState = .idle, lastDictation: String? = nil) {
        self.dictation = dictation
        self.lastDictation = lastDictation
    }

    /// Returns false and leaves the state untouched when the transition is not allowed.
    @discardableResult
    public func transition(to next: DictationState) -> Bool {
        guard dictation != next else { return true }
        guard dictation.canTransition(to: next) else { return false }
        dictation = next
        return true
    }
}

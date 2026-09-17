import Combine
import Foundation
import QuothCore

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var dictation: DictationState

    public init(dictation: DictationState = .idle) {
        self.dictation = dictation
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

import Foundation

/// Builds the text Whisper is primed with so that it prefers the listed words.
public enum VocabularyPrompt {
    /// WhisperKit keeps the last (maxTokenContext / 2 - 1) prompt tokens, 111 for the models it ships.
    public static let tokenBudget = 111

    /// Whisper treats the prompt as preceding transcript, so the words are written the way they
    /// should come out: comma separated, in the case the user wants.
    public static func text(for vocabulary: [String]) -> String? {
        let words = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let unique = words.filter { seen.insert($0.lowercased()).inserted }
        guard !unique.isEmpty else { return nil }
        return unique.joined(separator: ", ") + "."
    }

    /// Keeps the newest tokens, which is also what the decoder does, so nothing is silently dropped.
    public static func trim(_ tokens: [Int], to budget: Int = tokenBudget) -> [Int] {
        tokens.count > budget ? Array(tokens.suffix(budget)) : tokens
    }
}

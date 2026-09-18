import Foundation

/// Decides whether a model's output is a cleaned transcript or something else.
public enum LLMOutputGuard {
    public static let minimumLengthRatio = 0.5
    public static let maximumLengthRatio = 1.5
    public static let minimumWordOverlap = 0.6
    public static let minimumWordCount = 4

    public enum Rejection: Error, Equatable {
        case empty
        case lengthRatio(Double)
        case lowOverlap(Double)
        case preamble
        case delimiterLeak
        case missingTerm(String)
    }

    private static let preambles = [
        "sure",
        "here is",
        "here's",
        "here are",
        "i can",
        "i cannot",
        "i can't",
        "as an ai",
        "certainly",
        "of course",
    ]

    public static func shouldSkip(_ text: String) -> Bool {
        words(in: text).count < minimumWordCount
    }

    /// Strips wrapping quotes and code fences, then applies every rule. Throws on the first failure.
    public static func validate(output: String, input: String, dictionaryTerms: [String] = []) throws -> String {
        let cleaned = unwrap(output)
        guard !cleaned.isEmpty else { throw Rejection.empty }
        if cleaned.contains(PromptBuilder.openDelimiter) || cleaned.contains(PromptBuilder.closeDelimiter) {
            throw Rejection.delimiterLeak
        }
        let lowered = cleaned.lowercased()
        if preambles.contains(where: { lowered.hasPrefix($0) }) {
            throw Rejection.preamble
        }
        let ratio = Double(cleaned.count) / Double(max(input.count, 1))
        guard ratio >= minimumLengthRatio, ratio <= maximumLengthRatio else { throw Rejection.lengthRatio(ratio) }

        let inputWords = Set(words(in: input))
        if !inputWords.isEmpty {
            let outputWords = Set(words(in: cleaned))
            let overlap = Double(inputWords.intersection(outputWords).count) / Double(inputWords.count)
            guard overlap >= minimumWordOverlap else { throw Rejection.lowOverlap(overlap) }
        }
        for term in dictionaryTerms where input.localizedCaseInsensitiveContains(term) && !cleaned.contains(term) {
            throw Rejection.missingTerm(term)
        }
        return cleaned
    }

    static func unwrap(_ output: String) -> String {
        var text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: #"^```[a-zA-Z]*\n?"#, with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (open, close) in [("\"", "\""), ("\u{201C}", "\u{201D}"), ("'", "'")]
            where text.count > 1 && text.hasPrefix(open) && text.hasSuffix(close) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }
}

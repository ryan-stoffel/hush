import Foundation

/// Decides whether a model's output is a cleaned transcript or something else.
///
/// The model may fix spelling, punctuation, and casing, and may add structure around the words,
/// but the words must stay the same and in the same order. Anything else is an answer or a rewrite.
public enum LLMOutputGuard {
    public static let minimumLengthRatio = 0.5
    public static let maximumLengthRatio = 1.5
    /// Share of words that may differ, to leave room for spelling fixes. At least one word is always allowed.
    public static let maximumChangedWordShare = 0.2
    public static let minimumWordCount = 4

    public enum Rejection: Error, Equatable {
        case empty
        case lengthRatio(Double)
        case wordsChanged(missing: Int, added: Int)
        case lineBreaksDropped
        case markdown
        case preamble
        case missingTerm(String)
    }

    private static let preambles = [
        "sure", "here is", "here's", "here are", "i can", "i cannot", "i can't", "as an ai", "certainly", "of course",
    ]

    public static func shouldSkip(_ text: String) -> Bool {
        words(in: text).count < minimumWordCount
    }

    /// Strips wrapping quotes and code fences, then applies every rule. Throws on the first failure.
    public static func validate(output: String, input: String, dictionaryTerms: [String] = []) throws -> String {
        let cleaned = unwrap(output)
        guard !cleaned.isEmpty else { throw Rejection.empty }
        if cleaned.range(of: #"(?m)^\s*#{1,6}\s|\*\*|```"#, options: .regularExpression) != nil {
            throw Rejection.markdown
        }
        let lowered = cleaned.lowercased()
        if preambles.contains(where: { lowered.hasPrefix($0) }) {
            throw Rejection.preamble
        }
        let ratio = Double(cleaned.count) / Double(max(input.count, 1))
        guard ratio >= minimumLengthRatio, ratio <= maximumLengthRatio else { throw Rejection.lengthRatio(ratio) }
        if lineBreakCount(cleaned) < lineBreakCount(input) {
            throw Rejection.lineBreaksDropped
        }

        let inputWords = words(in: input)
        let outputWords = words(in: cleaned)
        let common = longestCommonSubsequence(inputWords, outputWords)
        let missing = inputWords.count - common
        let added = outputWords.count - common
        let allowed = max(1, Int((Double(inputWords.count) * maximumChangedWordShare).rounded(.down)))
        guard missing <= allowed, added <= allowed else {
            throw Rejection.wordsChanged(missing: missing, added: added)
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

    /// List markers and line breaks are structure, not words, so they never count as changes.
    static func words(in text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: #"(?m)^\s*(?:[-*]|\d+[.)])\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "'", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func lineBreakCount(_ text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0 == "\n" }.count
    }

    static func longestCommonSubsequence(_ left: [String], _ right: [String]) -> Int {
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: right.count + 1)
        var current = previous
        for word in left {
            for (index, other) in right.enumerated() {
                current[index + 1] = word == other ? previous[index] + 1 : max(previous[index + 1], current[index])
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }
}

import Foundation

/// Turns spoken formatting commands into the characters they name: punctuation, line breaks,
/// bullets, and numbered lists. English only. It keeps working when the global Cleanup toggle is
/// off, because "new line" should always produce a line break.
public struct SpokenFormatting: CleanupStage {
    public let id = "spokenFormatting"
    public let displayName = "Spoken punctuation and lists"
    public let followsGlobalToggle = false

    public init() {}

    public func process(_ text: String, context: CleanupContext) throws -> String {
        if let language = context.language, !language.lowercased().hasPrefix("en") {
            return text
        }
        let withCommands = SpokenCommandRewriter.rewrite(text)
        return withCommands
            .components(separatedBy: "\n")
            .map(SpokenListFormatter.format)
            .joined(separator: "\n")
    }
}

enum SpokenCommand: Equatable {
    case mark(String, endsSentence: Bool)
    case dash
    case open(String)
    case close(String)
    case lineBreak(count: Int)
    case bullet

    /// Longest phrases first so that "new paragraph" wins over "new".
    static let phrases: [(words: [String], command: SpokenCommand)] = [
        (["open", "parenthesis"], .open("(")),
        (["close", "parenthesis"], .close(")")),
        (["exclamation", "point"], .mark("!", endsSentence: true)),
        (["exclamation", "mark"], .mark("!", endsSentence: true)),
        (["question", "mark"], .mark("?", endsSentence: true)),
        (["new", "paragraph"], .lineBreak(count: 2)),
        (["new", "line"], .lineBreak(count: 1)),
        (["next", "line"], .lineBreak(count: 1)),
        (["full", "stop"], .mark(".", endsSentence: true)),
        (["open", "paren"], .open("(")),
        (["close", "paren"], .close(")")),
        (["open", "quote"], .open("\"")),
        (["close", "quote"], .close("\"")),
        (["end", "quote"], .close("\"")),
        (["bullet", "point"], .bullet),
        (["next", "bullet"], .bullet),
        (["newline"], .lineBreak(count: 1)),
        (["unquote"], .close("\"")),
        (["period"], .mark(".", endsSentence: true)),
        (["comma"], .mark(",", endsSentence: false)),
        (["colon"], .mark(":", endsSentence: false)),
        (["semicolon"], .mark(";", endsSentence: false)),
        (["dash"], .dash),
    ]
}

enum SpokenCommandRewriter {
    /// A command word that follows one of these is being talked about, not used:
    /// "the period of time", "a comma splice", "put a question mark after it".
    private static let determiners: Set<String> = [
        "a", "an", "the", "this", "that", "these", "those", "my", "your", "his", "her", "its", "our", "their",
        "some", "any", "each", "every", "no", "another", "which", "what",
    ]
    /// Words that can sit between a determiner and a command word: "a long period", "the trial period".
    private static let modifiers: Set<String> = [
        "long", "short", "brief", "new", "whole", "single", "little", "big", "quick", "trial", "grace", "time",
        "first", "last", "next", "same", "extra", "missing", "final",
    ]
    private static let blockingFollowers: Set<String> = [
        "of", "splice", "splices", "key", "symbol", "character", "sign", "cancer", "separated",
    ]
    private static let droppablePunctuation = CharacterSet(charactersIn: ",.;:")

    private struct Token {
        let raw: String
        let core: String
        let trailing: String

        init(_ raw: String) {
            self.raw = raw
            let trimmed = raw.trimmingCharacters(in: .punctuationCharacters)
            core = trimmed.lowercased()
            if let range = raw.range(of: trimmed), !trimmed.isEmpty {
                trailing = String(raw[range.upperBound...])
            } else {
                trailing = ""
            }
        }

        var hasLeadingPunctuation: Bool {
            guard let first = raw.unicodeScalars.first else { return false }
            return CharacterSet.punctuationCharacters.contains(first) && !core.isEmpty
        }
    }

    private struct Match {
        let command: SpokenCommand
        let length: Int
        let trailing: String
    }

    static func rewrite(_ text: String) -> String {
        let tokens = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).map { Token(String($0)) }
        var builder = Builder()
        var index = 0
        var lastWasCommand = false
        while index < tokens.count {
            if let match = match(at: index, in: tokens, previousWasCommand: lastWasCommand) {
                builder.apply(match.command, trailing: match.trailing)
                index += match.length
                lastWasCommand = true
            } else {
                builder.append(word: tokens[index].raw)
                index += 1
                lastWasCommand = false
            }
        }
        return builder.result
    }

    private static func match(
        at index: Int,
        in tokens: [Token],
        previousWasCommand: Bool
    ) -> Match? {
        for phrase in SpokenCommand.phrases {
            let end = index + phrase.words.count
            guard end <= tokens.count else { continue }
            let slice = Array(tokens[index ..< end])
            guard zip(slice, phrase.words).allSatisfy({ $0.core == $1 }) else { continue }
            // Punctuation inside the phrase ("new, line") means the words were not said together.
            guard slice.dropLast().allSatisfy(\.trailing.isEmpty),
                  slice.dropFirst().allSatisfy({ !$0.hasLeadingPunctuation }) else { continue }
            guard !isMention(at: index, end: end, in: tokens, previousWasCommand: previousWasCommand) else {
                return nil
            }
            return Match(command: phrase.command, length: phrase.words.count, trailing: slice[slice.count - 1].trailing)
        }
        return nil
    }

    private static func isMention(at index: Int, end: Int, in tokens: [Token], previousWasCommand: Bool) -> Bool {
        if !previousWasCommand {
            // A clause boundary between the determiner and the command breaks the link.
            if index >= 1, tokens[index - 1].trailing.isEmpty {
                if determiners.contains(tokens[index - 1].core) {
                    return true
                }
                if index >= 2, tokens[index - 2].trailing.isEmpty, modifiers.contains(tokens[index - 1].core),
                   determiners.contains(tokens[index - 2].core) {
                    return true
                }
            }
        }
        if end < tokens.count, tokens[end - 1].trailing.isEmpty, blockingFollowers.contains(tokens[end].core) {
            return true
        }
        return false
    }

    private struct Builder {
        private(set) var result = ""
        private var capitalizeNext = false
        private var suppressSpace = true
        /// True while the text ends in a symbol the speaker asked for, which later commands must keep.
        private var endsWithSpokenMark = false

        mutating func append(word: String) {
            var word = word
            if capitalizeNext, let first = word.first(where: \.isLetter), let position = word.firstIndex(of: first) {
                word.replaceSubrange(position ... position, with: String(first).uppercased())
            }
            if !suppressSpace {
                result += " "
            }
            result += word
            suppressSpace = false
            capitalizeNext = false
            endsWithSpokenMark = false
        }

        mutating func apply(_ command: SpokenCommand, trailing: String) {
            // The model often writes the symbol as well as the word: "question mark?".
            let kept = trailing.unicodeScalars.filter { !droppablePunctuation.contains($0) }
            switch command {
            case let .mark(symbol, endsSentence):
                stripTrailing(dropping: ",.;:!?")
                result += symbol
                for scalar in kept where String(scalar) != symbol {
                    result.unicodeScalars.append(scalar)
                }
                capitalizeNext = endsSentence
                suppressSpace = false
                endsWithSpokenMark = true
            case .dash:
                stripTrailing(dropping: ",")
                result += result.isEmpty ? "-" : " -"
                suppressSpace = false
            case let .open(symbol):
                if !suppressSpace {
                    result += " "
                }
                result += symbol
                suppressSpace = true
            case let .close(symbol):
                stripTrailing(dropping: "")
                result += symbol
                result.unicodeScalars.append(contentsOf: trailing.unicodeScalars)
                suppressSpace = false
            case let .lineBreak(count):
                stripTrailing(dropping: ",;:")
                guard !result.isEmpty else { return }
                let existing = result.reversed().prefix { $0 == "\n" }.count
                result += String(repeating: "\n", count: max(count - existing, 0))
                capitalizeNext = true
                suppressSpace = true
            case .bullet:
                stripTrailing(dropping: ",;")
                if !result.isEmpty, !result.hasSuffix("\n") {
                    result += "\n"
                }
                result += "- "
                capitalizeNext = true
                suppressSpace = true
            }
        }

        private mutating func stripTrailing(dropping characters: String) {
            let characters = endsWithSpokenMark ? "" : characters
            while let last = result.last, last == " " || characters.contains(last) {
                result.removeLast()
            }
        }
    }
}

enum SpokenListFormatter {
    private static let markers: [[String]] = [
        ["one", "first", "firstly", "1"],
        ["two", "second", "secondly", "2"],
        ["three", "third", "thirdly", "3"],
        ["four", "fourth", "4"],
        ["five", "fifth", "5"],
        ["six", "sixth", "6"],
        ["seven", "seventh", "7"],
        ["eight", "eighth", "8"],
        ["nine", "ninth", "9"],
        ["ten", "tenth", "10"],
    ]

    /// Formats "one, apples. Two, bananas." as a numbered list. A marker only counts at the start
    /// of a clause, and the list needs at least two markers in order starting from one.
    static func format(_ line: String) -> String {
        let words = line.split(separator: " ").map(String.init)
        var positions: [Int] = []
        for (index, word) in words.enumerated() where positions.count < markers.count {
            let core = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            guard markers[positions.count].contains(core), isClauseStart(index, in: words) else { continue }
            // "number one" style lead-ins are part of the marker.
            positions.append(index)
        }
        guard positions.count >= 2 else { return line }

        var lines: [String] = []
        let lead = words[..<positions[0]].joined(separator: " ")
        if !lead.isEmpty {
            lines.append(lead)
        }
        for (number, start) in positions.enumerated() {
            let end = number + 1 < positions.count ? positions[number + 1] : words.count
            let item = cleanItem(words[(start + 1) ..< end].joined(separator: " "))
            lines.append("\(number + 1). \(item)")
        }
        return lines.joined(separator: "\n")
    }

    private static func isClauseStart(_ index: Int, in words: [String]) -> Bool {
        guard index > 0 else { return true }
        guard let last = words[index - 1].last else { return false }
        return ".,:;!?".contains(last)
    }

    private static func cleanItem(_ item: String) -> String {
        var text = item.trimmingCharacters(in: .whitespaces)
        while let first = text.first, ",.:;)-".contains(first) || first == " " {
            text.removeFirst()
        }
        while let last = text.last, ",;".contains(last) || last == " " {
            text.removeLast()
        }
        let inner = text.dropLast()
        if text.hasSuffix("."), !inner.contains(where: { ".!?".contains($0) }) {
            text.removeLast()
        }
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}

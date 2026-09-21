import Foundation

/// Word-level difference between what was heard and what was inserted, for display.
public struct DiffSegment: Equatable, Sendable {
    public enum Kind: Sendable {
        case same
        case removed
        case added
    }

    public let text: String
    public let kind: Kind

    public init(_ text: String, _ kind: Kind) {
        self.text = text
        self.kind = kind
    }
}

public enum WordDiff {
    /// Tokens keep their trailing whitespace so the segments can be concatenated back into text.
    static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character.isWhitespace || character.isNewline {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    static func key(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    public static func segments(old: String, new: String) -> [DiffSegment] {
        let oldTokens = tokens(old)
        let newTokens = tokens(new)
        let oldKeys = oldTokens.map(key)
        let newKeys = newTokens.map(key)

        var table = [[Int]](repeating: [Int](repeating: 0, count: newKeys.count + 1), count: oldKeys.count + 1)
        for old in stride(from: oldKeys.count - 1, through: 0, by: -1) {
            for new in stride(from: newKeys.count - 1, through: 0, by: -1) {
                table[old][new] = oldKeys[old] == newKeys[new]
                    ? table[old + 1][new + 1] + 1
                    : max(table[old + 1][new], table[old][new + 1])
            }
        }

        var segments: [DiffSegment] = []
        var old = 0
        var new = 0
        while old < oldKeys.count, new < newKeys.count {
            if oldKeys[old] == newKeys[new] {
                segments.append(DiffSegment(newTokens[new], .same))
                old += 1
                new += 1
            } else if table[old + 1][new] >= table[old][new + 1] {
                segments.append(DiffSegment(oldTokens[old], .removed))
                old += 1
            } else {
                segments.append(DiffSegment(newTokens[new], .added))
                new += 1
            }
        }
        segments += oldTokens[old...].map { DiffSegment($0, .removed) }
        segments += newTokens[new...].map { DiffSegment($0, .added) }
        return merge(segments)
    }

    private static func merge(_ segments: [DiffSegment]) -> [DiffSegment] {
        var merged: [DiffSegment] = []
        for segment in segments {
            if let last = merged.last, last.kind == segment.kind {
                merged[merged.count - 1] = DiffSegment(last.text + segment.text, last.kind)
            } else {
                merged.append(segment)
            }
        }
        return merged
    }
}

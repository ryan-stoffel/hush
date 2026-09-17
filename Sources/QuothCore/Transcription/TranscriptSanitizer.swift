import Foundation

/// Whisper models emit markers for silence and non-speech sounds. None of them belong in inserted text.
public enum TranscriptSanitizer {
    private static let patterns = [
        #"<\|[^|>]*\|>"#,
        #"\[[A-Za-z_ ]{2,30}\]"#,
        #"\((?i:music|applause|laughter|laughs|silence|noise|inaudible|blank audio|background noise|sighs|coughs)\)"#,
    ]

    public static func clean(_ text: String) -> String {
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        result = result.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #" +([.,!?;:])"#, with: "$1", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation
import HushCore

/// Every scene the screenshot suite can open. Raw values are the screenshot file names.
public enum DemoScene: String, CaseIterable, Sendable {
    case popover
    case popoverPermissions = "popover-permissions"
    case overlayListening = "overlay-listening"
    case overlayTranscribing = "overlay-transcribing"
    case history
}

public enum DemoData {
    public static let lastDictation = "Send the report on Wednesday, and copy Priya on the thread."

    public static let elapsed: TimeInterval = 7
    public static let waveform = WaveformModel(levels: [
        0.10, 0.22, 0.35, 0.62, 0.80, 0.55, 0.30, 0.42, 0.75, 0.95, 0.70, 0.48,
        0.25, 0.18, 0.40, 0.66, 0.88, 0.60, 0.33, 0.20, 0.45, 0.72, 0.50, 0.28,
    ])

    /// Fixed dates so screenshots are stable. Two days, newest first.
    public static let historyEntries: [HistoryEntry] = {
        let base = Date(timeIntervalSince1970: 1_789_660_800) // 2026-09-17 08:00:00 UTC
        func entry(
            _ minutesAgo: Double,
            _ raw: String,
            _ cleaned: String,
            _ app: String,
            _ note: String? = nil
        ) -> HistoryEntry {
            HistoryEntry(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", Int(minutesAgo))) ?? UUID(),
                date: base.addingTimeInterval(-minutesAgo * 60),
                rawTranscript: raw,
                cleanedText: cleaned,
                appBundleIdentifier: "com.example.\(app.lowercased())",
                appName: app,
                language: "en",
                backendID: "whisperkit",
                audioDuration: 4.2,
                insertionStrategy: .clipboardPaste,
                cleanupNote: note
            )
        }
        return [
            entry(5, "send the report on wednesday comma and copy priya on the thread", lastDictation, "Mail"),
            entry(
                42,
                "shopping list colon new line one apples two bananas three cherries",
                "Shopping list:\n1. Apples\n2. Bananas\n3. Cherries",
                "Notes"
            ),
            entry(
                180,
                "what is the capital of france question mark",
                "What is the capital of France?",
                "Safari",
                "llm: wordsChanged(missing: 3, added: 6)"
            ),
            entry(
                1500,
                "hi sam comma new line thanks for the update period",
                "Hi Sam,\nThanks for the update.",
                "Slack"
            ),
            entry(
                1620,
                "okay so the plan is we ship on tuesday and let priya know",
                "Okay, so the plan is we ship on Tuesday and let Priya know.",
                "Messages"
            ),
        ]
    }()

    public static func permissions(for scene: DemoScene?) -> FakePermissions {
        switch scene {
        case .popoverPermissions:
            FakePermissions(
                statuses: [.microphone: .notDetermined, .accessibility: .denied, .inputMonitoring: .granted],
                grantsOnRequest: false
            )
        default:
            .allGranted
        }
    }
}

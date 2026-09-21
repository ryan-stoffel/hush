import Foundation

/// One dictation. Text only: audio is never stored.
public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let rawTranscript: String
    public let cleanedText: String
    public let appBundleIdentifier: String?
    public let appName: String?
    public let language: String?
    public let backendID: String
    public let audioDuration: TimeInterval
    /// Nil when the insertion failed.
    public let insertionStrategy: InsertionStrategy?
    /// For example, why a model result was rejected, or why insertion failed.
    public let cleanupNote: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        rawTranscript: String,
        cleanedText: String,
        appBundleIdentifier: String? = nil,
        appName: String? = nil,
        language: String? = nil,
        backendID: String,
        audioDuration: TimeInterval,
        insertionStrategy: InsertionStrategy?,
        cleanupNote: String? = nil
    ) {
        self.id = id
        self.date = date
        self.rawTranscript = rawTranscript
        self.cleanedText = cleanedText
        self.appBundleIdentifier = appBundleIdentifier
        self.appName = appName
        self.language = language
        self.backendID = backendID
        self.audioDuration = audioDuration
        self.insertionStrategy = insertionStrategy
        self.cleanupNote = cleanupNote
    }

    public var wasInserted: Bool {
        insertionStrategy != nil
    }
}

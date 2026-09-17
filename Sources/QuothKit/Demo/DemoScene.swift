import Foundation

/// Every scene the screenshot suite can open. Raw values are the screenshot file names.
public enum DemoScene: String, CaseIterable, Sendable {
    case popover
}

public enum DemoData {
    public static let lastDictation = "Send the report on Wednesday, and copy Priya on the thread."
}

import XCTest
@testable import HushCore

final class HistoryBrowsingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_789_660_800) // 2026-09-17 08:00 UTC

    private func entry(_ hoursAgo: Double, _ raw: String, cleaned: String? = nil, app: String? = nil) -> HistoryEntry {
        HistoryEntry(
            date: now.addingTimeInterval(-hoursAgo * 3600),
            rawTranscript: raw,
            cleanedText: cleaned ?? raw,
            appName: app,
            backendID: "fake",
            audioDuration: 1,
            insertionStrategy: .clipboardPaste
        )
    }

    func testGroupsByDayNewestFirstWithRelativeTitles() {
        let entries = [entry(1, "today late"), entry(30, "yesterday"), entry(3, "today early"), entry(24 * 10, "older")]
        let groups = HistoryBrowsing.groupByDay(entries, calendar: calendar, now: now)
        XCTAssertEqual(groups.map(\.title), ["Today", "Yesterday", "Monday, September 7"])
        XCTAssertEqual(groups[0].entries.map(\.rawTranscript), ["today late", "today early"])
        let lastYear = HistoryBrowsing.groupByDay([entry(24 * 400, "old")], calendar: calendar, now: now)
        XCTAssertEqual(lastYear.first?.title, "August 13, 2025")
    }

    func testSearchIsCaseAndDiacriticInsensitiveAcrossFields() {
        let entries = [
            entry(1, "send it to priya", cleaned: "Send it to Priya.", app: "Mail"),
            entry(2, "café order", app: "Notes"),
            entry(3, "unrelated", app: "Slack"),
        ]
        XCTAssertEqual(HistoryBrowsing.filter(entries, query: "PRIYA").count, 1)
        XCTAssertEqual(HistoryBrowsing.filter(entries, query: "cafe").count, 1)
        XCTAssertEqual(HistoryBrowsing.filter(entries, query: "slack").map(\.rawTranscript), ["unrelated"])
        XCTAssertEqual(HistoryBrowsing.filter(entries, query: "  ").count, 3)
        XCTAssertTrue(HistoryBrowsing.filter(entries, query: "zzz").isEmpty)
    }

    func testFirstLine() {
        XCTAssertEqual(HistoryBrowsing.firstLine("Shopping list:\n1. Apples"), "Shopping list:")
        XCTAssertEqual(HistoryBrowsing.firstLine("one line"), "one line")
    }

    func testSelectionAfterDelete() {
        let entries = [entry(1, "a"), entry(2, "b"), entry(3, "c")]
        let ids = entries.map(\.id)
        XCTAssertEqual(HistoryBrowsing.selectionAfterDeleting([ids[1]], from: entries, selected: ids[1]), ids[2])
        XCTAssertEqual(HistoryBrowsing.selectionAfterDeleting([ids[2]], from: entries, selected: ids[2]), ids[1])
        XCTAssertEqual(HistoryBrowsing.selectionAfterDeleting([ids[0]], from: entries, selected: ids[2]), ids[2])
        XCTAssertNil(HistoryBrowsing.selectionAfterDeleting(Set(ids), from: entries, selected: ids[0]))
    }

    func testWordDiffMarksChangedWords() {
        let segments = WordDiff.segments(old: "send it wenesday to priya", new: "Send it Wednesday to Priya.")
        XCTAssertEqual(segments.map(\.kind), [.same, .removed, .added, .same])
        XCTAssertEqual(segments[1].text, "wenesday ")
        XCTAssertEqual(segments[2].text, "Wednesday ")
        XCTAssertEqual(WordDiff.segments(old: "same text", new: "Same text."), [DiffSegment("Same text.", .same)])
        let added = WordDiff.segments(old: "apples bananas", new: "apples bananas cherries")
        XCTAssertEqual(added.last, DiffSegment("cherries", .added))
        XCTAssertEqual(WordDiff.segments(old: "", new: ""), [])
    }
}

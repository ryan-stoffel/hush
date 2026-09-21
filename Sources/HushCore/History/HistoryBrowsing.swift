import Foundation

/// Pure search and grouping over history entries, used by the History window.
public enum HistoryBrowsing {
    public struct DayGroup: Equatable, Sendable {
        public let day: Date
        public let title: String
        public let entries: [HistoryEntry]
    }

    public static func matches(_ entry: HistoryEntry, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return [entry.rawTranscript, entry.cleanedText, entry.appName ?? ""]
            .contains { $0.range(of: needle, options: options) != nil }
    }

    public static func filter(_ entries: [HistoryEntry], query: String) -> [HistoryEntry] {
        entries.filter { matches($0, query: query) }
    }

    /// Newest day first, entries newest first within each day.
    public static func groupByDay(
        _ entries: [HistoryEntry],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [DayGroup] {
        var order: [Date] = []
        var buckets: [Date: [HistoryEntry]] = [:]
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let day = calendar.startOfDay(for: entry.date)
            if buckets[day] == nil {
                order.append(day)
            }
            buckets[day, default: []].append(entry)
        }
        return order.map { day in
            DayGroup(day: day, title: title(for: day, calendar: calendar, now: now), entries: buckets[day] ?? [])
        }
    }

    static func title(for day: Date, calendar: Calendar, now: Date) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(
            day,
            inSameDayAs: yesterday
        ) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = calendar.component(.year, from: day) == calendar.component(.year, from: now)
            ? "EEEE, MMMM d"
            : "MMMM d, yyyy"
        return formatter.string(from: day)
    }

    public static func firstLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    }

    /// The entry to select after a deletion: the next one down, else the one above, else none.
    public static func selectionAfterDeleting(
        _ deleted: Set<UUID>,
        from visible: [HistoryEntry],
        selected: UUID?
    ) -> UUID? {
        guard let selected, deleted.contains(selected),
              let index = visible.firstIndex(where: { $0.id == selected }) else {
            return selected
        }
        let remaining = visible.enumerated().filter { !deleted.contains($0.element.id) }
        return remaining.first { $0.offset > index }?.element.id ?? remaining.last { $0.offset < index }?.element.id
    }
}

import HushCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryViewModel
    @State private var confirmingClear = false

    var body: some View {
        Group {
            if !model.isEnabled {
                disabledState
            } else if model.totalCount == 0 {
                emptyState("No dictations yet", "Hold Fn and speak. Each dictation shows up here.")
            } else {
                NavigationSplitView {
                    list
                } detail: {
                    detail
                }
            }
        }
        .frame(minWidth: 720, minHeight: 440)
        .accessibilityIdentifier("history.root")
    }

    private var list: some View {
        List(selection: $model.selectedID) {
            ForEach(model.groups, id: \.day) { group in
                Section(group.title) {
                    ForEach(group.entries) { entry in
                        HistoryRow(entry: entry).tag(entry.id)
                    }
                }
            }
        }
        .searchable(text: $model.query, placement: .sidebar, prompt: "Search dictations")
        .overlay {
            if model.visibleEntries.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        .toolbar {
            ToolbarItem {
                Button("Clear All") { confirmingClear = true }
                    .disabled(model.totalCount == 0)
                    .accessibilityIdentifier("history.clearAll")
            }
        }
        .confirmationDialog(
            "Clear all history?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { model.clearAll() }
        } message: {
            Text("This removes every dictation from this Mac. It cannot be undone.")
        }
    }

    @ViewBuilder private var detail: some View {
        if let entry = model.selectedEntry {
            HistoryDetail(entry: entry, model: model)
        } else {
            emptyState("Select a dictation", "What was heard and what was inserted appear here.")
        }
    }

    private var disabledState: some View {
        VStack(spacing: 12) {
            Text("History is off")
                .font(.title2)
            Text("Hush is not keeping a record of your dictations.")
                .foregroundStyle(.secondary)
            Button("Turn History On") { model.enableHistory() }
                .accessibilityIdentifier("history.enable")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title3)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let app = entry.appName {
                    Text(app)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !entry.wasInserted {
                    Text("Not inserted")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Text(HistoryBrowsing.firstLine(entry.cleanedText))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

private struct HistoryDetail: View {
    let entry: HistoryEntry
    @ObservedObject var model: HistoryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("Inserted", copy: model.copyCleaned, identifier: "history.copyCleaned") {
                    Text(entry.cleanedText)
                        .textSelection(.enabled)
                }
                section("Heard", copy: model.copyRaw, identifier: "history.copyRaw") {
                    diffText
                        .textSelection(.enabled)
                }
                metadata
                if let note = entry.cleanupNote {
                    Text("Note: \(note)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("history.note")
                }
                Button("Delete", role: .destructive) { model.deleteSelected() }
                    .accessibilityIdentifier("history.delete")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section(
        _ title: String,
        copy: @escaping () -> Void,
        identifier: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Copy", action: copy)
                    .accessibilityIdentifier(identifier)
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
        }
    }

    /// Words the cleanup changed are struck through in the transcript, so over-editing is visible at a glance.
    private var diffText: Text {
        WordDiff.segments(old: entry.rawTranscript, new: entry.cleanedText).reduce(Text("")) { result, segment in
            switch segment.kind {
            case .same: result + Text(segment.text)
            case .removed: result + Text(segment.text).strikethrough().foregroundColor(.red)
            case .added: result
            }
        }
    }

    private var metadata: some View {
        let items = [
            ("Language", entry.language ?? "auto"),
            ("Model", entry.backendID),
            ("Audio", String(format: "%.1f s", entry.audioDuration)),
            ("Insertion", entry.insertionStrategy?.rawValue ?? "failed"),
            ("App", entry.appName ?? "unknown"),
        ]
        return HStack(spacing: 16) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.1)
                        .font(.caption)
                }
            }
        }
    }
}

import QuothCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: PopoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            lastDictation
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .accessibilityIdentifier("popover.root")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.presentation.isError ? Color.red : Color.green)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(model.presentation.statusText)
                .font(.headline)
                .accessibilityIdentifier("popover.status")
            Spacer()
            Text(AppInfo.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var lastDictation: some View {
        if let text = model.presentation.lastDictation {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last dictation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.body)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("popover.lastDictation")
                Button("Copy") { model.copyLastDictation() }
                    .accessibilityIdentifier("popover.copy")
            }
        } else {
            Text(PopoverPresentation.emptyHint)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("popover.emptyHint")
        }
    }

    private var footer: some View {
        HStack {
            Text(model.presentation.versionText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit \(AppInfo.name)") { model.quit() }
                .accessibilityIdentifier("popover.quit")
        }
    }
}

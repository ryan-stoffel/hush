import HushCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: PopoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !model.presentation.missingPermissions.isEmpty {
                permissionWarnings
            }
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

    private var permissionWarnings: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.presentation.missingPermissions, id: \.self) { permission in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(permission.displayName) access needed")
                            .font(.subheadline.weight(.medium))
                        Text(permission.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Grant") {
                        Task { await model.grant(permission) }
                    }
                    .accessibilityIdentifier("popover.grant.\(permission.rawValue)")
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.15)))
        .accessibilityIdentifier("popover.permissions")
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
            Button("History") { model.showHistory() }
                .accessibilityIdentifier("popover.history")
            Button("Quit \(AppInfo.name)") { model.quit() }
                .accessibilityIdentifier("popover.quit")
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: "Settings",
                showBack: true,
                onBack: { appState.currentView = .list }
            ) {
                Button(action: { StatusBarController.shared?.closePopover() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project section
                    settingsSection("Project") {
                        settingsRow(
                            "Project Directory",
                            value: appState.projectDir?.path(percentEncoded: false) ?? "Not set"
                        )

                        Button("Change Project Directory") {
                            StatusBarController.shared?.pickProjectDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                    }

                    // Feature-Marker section
                    settingsSection("Feature-Marker") {
                        settingsRow(
                            "Installation Path",
                            value: appState.featureMarkerPath.path(percentEncoded: false)
                        )
                    }

                    // About section
                    settingsSection("About") {
                        settingsRow("Version", value: "2.0.0")
                        settingsRow("Runtime", value: "Native Swift/SwiftUI")
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
        }
    }

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 200, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

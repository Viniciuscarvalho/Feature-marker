import SwiftUI

struct ListView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(title: "Feature-Marker") {
                HStack(spacing: 8) {
                    Button(action: { appState.loadFeatures() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button(action: { appState.currentView = .settings }) {
                        Image(systemName: "gearshape")
                    }
                    Button(action: { StatusBarController.shared?.closePopover() }) {
                        Image(systemName: "xmark")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Divider()

            // Content
            if appState.features.isEmpty {
                emptyState
            } else {
                featureList
            }

            Divider()

            // Footer
            footer
        }
        .onAppear {
            appState.loadFeatures()
        }
    }

    private var featureList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(appState.features) { feature in
                    FeatureRowView(feature: feature)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.selectedFeature = feature.name
                            appState.currentView = .detail
                        }
                }
            }
            .padding(12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No features yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Start a new feature workflow to begin")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Start New Feature") {
                appState.currentView = .start
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(appState.projectDir?.lastPathComponent ?? "No project set")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .help(appState.projectDir?.path(percentEncoded: false) ?? "")

            Spacer()

            Button {
                appState.currentView = .start
            } label: {
                Label("New Feature", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

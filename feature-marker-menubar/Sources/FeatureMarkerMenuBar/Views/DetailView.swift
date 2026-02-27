import SwiftUI

struct DetailView: View {
    @Bindable var appState: AppState

    private var feature: FeatureSummary? {
        appState.features.first { $0.name == appState.selectedFeature }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: appState.selectedFeature ?? "Feature",
                showBack: true,
                onBack: {
                    appState.currentView = .list
                    appState.selectedFeature = nil
                }
            ) {
                Button(action: { StatusBarController.shared?.closePopover() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Divider()

            if let feature {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Status header
                        HStack {
                            StatusBadgeView(feature: feature)
                            Spacer()
                            Text("Updated \(feature.lastUpdated, style: .relative) ago")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Phase list
                        PhaseListView(feature: feature)

                        // Action buttons
                        actionButtons(for: feature)

                        // Output log
                        if feature.isRunning || !appState.outputLog.isEmpty {
                            outputSection(isRunning: feature.isRunning)
                        }
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "Feature not found",
                    systemImage: "questionmark.circle",
                    description: Text("The selected feature could not be loaded.")
                )
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for feature: FeatureSummary) -> some View {
        HStack(spacing: 8) {
            if feature.isRunning {
                Button("Stop") {
                    Task { await appState.cancelFeature() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            } else {
                Button("Resume") {
                    Task {
                        try? await appState.resumeFeature(name: feature.name)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

                Button("Open Directory") {
                    appState.openProjectInFinder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func outputSection(isRunning: Bool) -> some View {
        HStack {
            Text("Output")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if isRunning {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .opacity(0.8)
            }
            Spacer()
        }

        OutputLogView(lines: appState.outputLog)
    }
}

import SwiftUI

struct StartView: View {
    @Bindable var appState: AppState
    @State private var featureName = ""
    @State private var executionMode = "full"
    @State private var errorMessage: String?

    private let modes: [(String, String)] = [
        ("full", "Full Workflow"),
        ("tasks-only", "Tasks Only"),
        ("ralph-loop", "Ralph Loop (Autonomous)"),
        ("spec-driven", "Spec-Driven (Multi-agent)"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                title: "New Feature",
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

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Feature Name (slug)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("prd-user-authentication", text: $featureName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Execution Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $executionMode) {
                        ForEach(modes, id: \.0) { mode in
                            Text(mode.1).tag(mode.0)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Start Feature") {
                    startFeature()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
                .disabled(featureName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)

            Spacer()
        }
    }

    private func startFeature() {
        let name = featureName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        errorMessage = nil
        Task {
            do {
                try await appState.startFeature(name: name, mode: executionMode)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

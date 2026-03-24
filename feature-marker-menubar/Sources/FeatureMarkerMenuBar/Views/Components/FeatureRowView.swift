import SwiftUI

struct FeatureRowView: View {
    let feature: FeatureSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name + Status
            HStack {
                Text(feature.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                StatusBadgeView(feature: feature)
            }

            // Progress bar
            HStack(spacing: 8) {
                ProgressView(value: feature.progress)
                    .tint(progressColor)

                Text("Phase \(feature.currentPhase)/\(feature.totalPhases)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            // Phase dots
            HStack(spacing: 4) {
                ForEach(0..<PhaseInfo.count, id: \.self) { i in
                    Circle()
                        .fill(dotColor(for: i))
                        .frame(width: 7, height: 7)
                        .overlay {
                            if i == feature.currentPhase && !feature.hasError {
                                Circle()
                                    .fill(dotColor(for: i))
                                    .frame(width: 7, height: 7)
                                    .opacity(feature.isRunning ? 0.5 : 1)
                                    .animation(
                                        feature.isRunning
                                            ? .easeInOut(duration: 1.2).repeatForever()
                                            : .default,
                                        value: feature.isRunning
                                    )
                            }
                        }
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var progressColor: Color {
        if feature.isRunning { return .green }
        if feature.hasError { return .red }
        return .accentColor
    }

    private var borderColor: Color {
        if feature.isRunning { return .green.opacity(0.4) }
        if feature.hasError { return .red.opacity(0.4) }
        return .clear
    }

    private func dotColor(for index: Int) -> Color {
        if index < feature.currentPhase { return .green }
        if index == feature.currentPhase {
            if feature.hasError { return .red }
            return .accentColor
        }
        return .secondary.opacity(0.3)
    }
}

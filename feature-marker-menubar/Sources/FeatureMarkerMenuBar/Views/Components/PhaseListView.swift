import SwiftUI

struct PhaseListView: View {
    let feature: FeatureSummary

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<PhaseInfo.count, id: \.self) { index in
                phaseRow(index: index)
            }
        }
    }

    @ViewBuilder
    private func phaseRow(index: Int) -> some View {
        HStack(spacing: 12) {
            // Number circle
            ZStack {
                Circle()
                    .fill(circleColor(for: index))
                    .frame(width: 24, height: 24)
                Text("\(index)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(circleTextColor(for: index))
            }

            // Phase info
            VStack(alignment: .leading, spacing: 2) {
                Text(PhaseInfo.names[index])
                    .font(.subheadline.weight(.medium))
                Text(statusText(for: index))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.2), in: .rect(cornerRadius: 6))
    }

    private func circleColor(for index: Int) -> Color {
        if index < feature.currentPhase { return .green }
        if index == feature.currentPhase {
            if feature.hasError { return .red }
            return .accentColor
        }
        return .secondary.opacity(0.2)
    }

    private func circleTextColor(for index: Int) -> Color {
        if index < feature.currentPhase || index == feature.currentPhase { return .white }
        return .secondary
    }

    private func statusText(for index: Int) -> String {
        if index < feature.currentPhase { return "Completed" }
        if index == feature.currentPhase {
            if feature.isRunning { return "In Progress" }
            if feature.hasError { return "Error" }
            return "Pending"
        }
        return "Pending"
    }
}

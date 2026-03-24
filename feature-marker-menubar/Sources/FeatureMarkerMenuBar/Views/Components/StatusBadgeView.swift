import SwiftUI

struct StatusBadgeView: View {
    let feature: FeatureSummary

    var body: some View {
        Text(statusText)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(textColor)
            .background(backgroundColor, in: .capsule)
    }

    private var statusText: String {
        if feature.isRunning { return "Running" }
        if feature.hasError { return "Error" }
        if feature.paused { return "Paused" }
        return "Idle"
    }

    private var textColor: Color {
        if feature.isRunning { return .white }
        if feature.hasError { return .white }
        if feature.paused { return .black }
        return .secondary
    }

    private var backgroundColor: Color {
        if feature.isRunning { return .green }
        if feature.hasError { return .red }
        if feature.paused { return .yellow }
        return .secondary.opacity(0.2)
    }
}

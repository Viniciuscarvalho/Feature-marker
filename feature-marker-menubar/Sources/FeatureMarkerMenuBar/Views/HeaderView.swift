import SwiftUI

struct HeaderView<Trailing: View>: View {
    let title: String
    var showBack = false
    var onBack: (() -> Void)?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            if showBack {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

extension HeaderView where Trailing == EmptyView {
    init(title: String, showBack: Bool = false, onBack: (() -> Void)? = nil) {
        self.title = title
        self.showBack = showBack
        self.onBack = onBack
        self.trailing = EmptyView()
    }
}

import SwiftUI

struct OutputLogView: View {
    let lines: [OutputLine]
    private let maxVisible = 200

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(visibleLines) { line in
                        Text(line.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(lineColor(for: line))
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 200)
            .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
            .onChange(of: lines.count) {
                if let last = visibleLines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var visibleLines: [OutputLine] {
        Array(lines.suffix(maxVisible))
    }

    private func lineColor(for line: OutputLine) -> Color {
        if line.isStderr { return .red }
        if line.isSuccess { return .green }
        return .secondary
    }
}

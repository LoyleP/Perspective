import SwiftUI

/// A paragraph clamped to a few lines, with a small "voir plus" at the end of the last visible line
/// that reveals the rest. Nothing is shown when the text already fits.
struct ExpandableText: View {
    let text: String
    var style: TypeStyle = .standfirst
    var collapsedLines = 3
    var color: Color = AppColors.Adaptive.textBody

    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0

    private var isTruncated: Bool { fullHeight > shownHeight + 1 }

    var body: some View {
        Text(text)
            .typeStyle(style)
            .foregroundStyle(color)
            .lineLimit(expanded ? nil : collapsedLines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
            .background {
                // The same text without a line limit, only to know whether it is cut.
                Text(text)
                    .typeStyle(style)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
            }
            .overlay(alignment: .bottomTrailing) {
                if isTruncated && !expanded {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [AppColors.Adaptive.background.opacity(0), AppColors.Adaptive.background], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28)
                        Button {
                            withAnimation(.app) { expanded = true }
                        } label: {
                            Text("voir plus")
                                .typeStyle(.meta)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                                .underline()
                                .padding(.leading, 4)
                        }
                        .buttonStyle(.plain)
                        .background(AppColors.Adaptive.background)
                    }
                    .accessibilityLabel("Voir plus")
                }
            }
    }
}

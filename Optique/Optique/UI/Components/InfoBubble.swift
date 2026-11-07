import SwiftUI

/// A small "i" button that opens a speech bubble explaining the label it sits next to.
struct InfoBubble: View {
    let text: String
    var label = "Plus d'informations"
    @State private var isShown = false

    var body: some View {
        Button {
            Haptics.selection()
            isShown = true
        } label: {
            LucideIcon("info", size: 16)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .popover(isPresented: $isShown, arrowEdge: .top) {
            Text(text)
                .typeStyle(.body)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppSpacing.m)
                .frame(width: 280, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }
}

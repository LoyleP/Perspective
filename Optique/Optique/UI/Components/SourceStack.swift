import SwiftUI

/// Overlapping source logos with a "+N" overflow count.
struct SourceStack: View {
    let sources: [Source]
    var limit: Int = 3
    var size: CGFloat = 20
    /// Ring drawn around each logo to separate it from its neighbour; match the backdrop.
    var ringColor: Color = AppColors.Adaptive.background

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            HStack(spacing: -size * 0.3) {
                ForEach(sources.prefix(limit)) { source in
                    SourceAvatarView(source: source, size: size)
                        .overlay(Circle().stroke(ringColor, lineWidth: 1.5))
                }
            }
            if sources.count > limit {
                Text("+\(sources.count - limit)")
                    .font(.appFootnote)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sources.prefix(limit).map(\.name).joined(separator: ", ")
            + (sources.count > limit ? " et \(sources.count - limit) autres" : ""))
    }
}

#if DEBUG
#Preview("Stacks") {
    VStack(alignment: .leading, spacing: 16) {
        SourceStack(sources: Fixtures.sources)
        SourceStack(sources: Array(Fixtures.sources.prefix(2)), size: 28)
        SourceStack(sources: Array(Fixtures.sources.prefix(1)), size: 36)
    }
    .padding()
    .background(AppColors.Adaptive.background)
}
#endif

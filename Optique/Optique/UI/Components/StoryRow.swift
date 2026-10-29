import SwiftUI

/// Compact list row: meta, headline and spectrum line on the left; on the right a square photo
/// as tall as the text (so it fills the row's height without ever stretching).
struct StoryRow: View {
    let story: Story
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let showsImage = story.leadImageURL != nil && !dynamicTypeSize.isAccessibilitySize
        SquareTrailingLayout(spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(.appBodyStrong)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .multilineTextAlignment(.leading)
                if let dek = story.summary, !dek.isEmpty, !dynamicTypeSize.isAccessibilitySize {
                    Text(dek)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(story.metaLine)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                if let coverage = story.computedCoverage {
                    HStack(spacing: AppSpacing.s) {
                        SpectrumBar(coverage: coverage)
                            .frame(width: 72)
                        Text(coverage.verdict)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsImage {
                Color.clear
                    .overlay { RemoteImage(url: story.leadImageURL, maxPixel: 360) }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, AppSpacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Lays out a text block and an optional trailing photo. The photo is a square whose side
/// equals the text block's height (clamped), so it fills the row's height; the text takes the
/// remaining width. With one subview the text uses the full width.
private struct SquareTrailingLayout: Layout {
    var spacing: CGFloat
    private let minSide: CGFloat = 64
    private let maxSide: CGFloat = 120

    /// Finds the photo side and text height for a row `width` wide. Text height depends on the
    /// width left after the photo, which depends on the text height, so a few passes settle it.
    private func solve(width: CGFloat, text: LayoutSubview, hasImage: Bool) -> (side: CGFloat, textHeight: CGFloat) {
        guard hasImage else {
            return (0, text.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
        }
        var side: CGFloat = 88
        var height: CGFloat = 0
        for _ in 0..<4 {
            height = text.sizeThatFits(ProposedViewSize(width: max(width - side - spacing, 0), height: nil)).height
            let next = min(max(height, minSide), maxSide)
            if abs(next - side) < 0.5 { side = next; break }
            side = next
        }
        height = text.sizeThatFits(ProposedViewSize(width: max(width - side - spacing, 0), height: nil)).height
        return (side, height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let width = proposal.width ?? 320
        let (side, textHeight) = solve(width: width, text: text, hasImage: subviews.count > 1)
        return CGSize(width: width, height: max(textHeight, side))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        let hasImage = subviews.count > 1
        let (side, textHeight) = solve(width: bounds.width, text: text, hasImage: hasImage)
        let rowHeight = max(textHeight, side)
        let textWidth = hasImage ? bounds.width - side - spacing : bounds.width
        text.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + (rowHeight - textHeight) / 2),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: textWidth, height: textHeight)
        )
        if hasImage {
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY + (rowHeight - side) / 2),
                anchor: .topTrailing,
                proposal: ProposedViewSize(width: side, height: side)
            )
        }
    }
}

#if DEBUG
#Preview("Rows") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(Fixtures.stories) { story in
                StoryRow(story: story)
                Divider()
            }
        }
        .padding(.horizontal)
    }
    .background(AppColors.Adaptive.background)
}

#Preview("Accessibility text") {
    ScrollView { StoryRow(story: Fixtures.stories[3]).padding() }
        .background(AppColors.Adaptive.background)
        .dynamicTypeSize(.accessibility3)
}
#endif

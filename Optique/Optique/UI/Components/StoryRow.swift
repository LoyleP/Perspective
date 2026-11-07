import SwiftUI

/// Compact list card: headline and meta line on the left; on the right a photo that touches the
/// card's top, right and bottom edges, the same width on every card.
struct StoryRow: View {
    let story: Story
    /// Position in a ranked list ("L'essentiel"), shown left of the headline.
    var rank: Int? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let showsImage = story.leadImageURL != nil && !dynamicTypeSize.isAccessibilitySize
        PhotoTrailingLayout(padding: AppSpacing.m, photoWidth: 108) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                if let rank {
                    Text("\(rank)")
                        .typeStyle(.meta)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .frame(width: 14, alignment: .leading)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: AppSpacing.st) {
                    Text(story.title)
                        .typeStyle(.rowTitle)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    StoryMetaLine(story: story)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showsImage {
                Color.clear
                    .overlay { RemoteImage(url: story.leadImageURL, maxPixel: 360) }
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

/// Lays out a text block and an optional trailing photo that touches the card's top, right and
/// bottom edges. The photo has the same width on every card (`photoWidth`) and the row's full height;
/// the text is inset by `padding` and takes the width left, so it never runs under the photo.
private struct PhotoTrailingLayout: Layout {
    var padding: CGFloat
    var photoWidth: CGFloat
    private let minHeight: CGFloat = 96

    private func textWidth(_ width: CGFloat, hasImage: Bool) -> CGFloat {
        max(width - (hasImage ? photoWidth : 0) - 2 * padding, 0)
    }

    private func rowHeight(width: CGFloat, text: LayoutSubview, hasImage: Bool) -> (row: CGFloat, text: CGFloat) {
        let h = text.sizeThatFits(ProposedViewSize(width: textWidth(width, hasImage: hasImage), height: nil)).height
        return (max(h + 2 * padding, hasImage ? minHeight : 0), h)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let width = proposal.width ?? 320
        return CGSize(width: width, height: rowHeight(width: width, text: text, hasImage: subviews.count > 1).row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        let hasImage = subviews.count > 1
        let (row, textHeight) = rowHeight(width: bounds.width, text: text, hasImage: hasImage)
        text.place(
            at: CGPoint(x: bounds.minX + padding, y: bounds.minY + (row - textHeight) / 2),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: textWidth(bounds.width, hasImage: hasImage), height: textHeight)
        )
        if hasImage {
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY),
                anchor: .topTrailing,
                proposal: ProposedViewSize(width: photoWidth, height: row)
            )
        }
    }
}

/// The lines under a story card's text: the coverage bar (where the left/right lens means something) and the time.
struct StoryMetaLine: View {
    let story: Story
    var showsTag = true

    private var time: some View {
        Text(story.timeLine)
            .typeStyle(.meta)
            .foregroundStyle(AppColors.Adaptive.textMeta)
            .lineLimit(1)
    }

    var body: some View {
        if showsTag, let coverage = story.computedCoverage, story.hasPoliticalAngle {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SpectrumBar(coverage: coverage, barHeight: 6)
                time
            }
        } else {
            time
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

import SwiftUI

/// Compact list row: meta, headline, spectrum line, thumbnail on the right.
struct StoryRow: View {
    let story: Story
    @ScaledMetric(relativeTo: .headline) private var thumbnailSize: CGFloat = 84
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(story.metaLine)
                    .overlineStyle()
                Text(story.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .multilineTextAlignment(.leading)
                if let coverage = story.computedCoverage {
                    HStack(spacing: AppSpacing.s) {
                        SpectrumBar(coverage: coverage)
                            .frame(width: 88)
                        Text(coverage.verdict)
                            .font(.appCaption1)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if story.leadImageURL != nil && !dynamicTypeSize.isAccessibilitySize {
                Color.clear
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .overlay { RemoteImage(url: story.leadImageURL) }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, AppSpacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

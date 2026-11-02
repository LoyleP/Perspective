import SwiftUI

/// Big story card: photo on top; meta line, headline, sources and spectrum below it.
struct StoryHeroCard: View {
    let story: Story
    var size: Size = .large

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Size {
        case large   // 4:3, lead story
        case medium  // 16:9, feature breaks in the feed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Color.clear
                .aspectRatio(size == .large ? 4.0 / 3.0 : 16.0 / 9.0, contentMode: .fit)
                .overlay { RemoteImage(url: story.leadImageURL, tint: tint) }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.l).stroke(AppColors.stroke, lineWidth: 1))
                .accessibilityHidden(true)
            content
        }
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                Text(story.timeLine)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                Spacer(minLength: 0)
            }
            Text(story.title)
                .font(size == .large ? .appTitle : .appHeading)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            if let coverage = story.computedCoverage {
                HStack(spacing: AppSpacing.s) {
                    LeanTags(coverage: coverage)
                    SourceStack(sources: story.sources, size: 22, ringColor: AppColors.Adaptive.background)
                }
            }
        }
    }

    private var tint: Color? {
        story.computedCoverage.flatMap { PoliticalLean(rawValue: $0.dominantLean)?.spectrumColor }
    }
}

#if DEBUG
#Preview("Large") {
    StoryHeroCard(story: Fixtures.stories[0]).padding().background(AppColors.Adaptive.background)
}

#Preview("Medium") {
    StoryHeroCard(story: Fixtures.stories[3], size: .medium).padding().background(AppColors.Adaptive.background)
}

#Preview("Accessibility text") {
    ScrollView { StoryHeroCard(story: Fixtures.stories[1]).padding() }
        .background(AppColors.Adaptive.background)
        .dynamicTypeSize(.accessibility2)
}
#endif

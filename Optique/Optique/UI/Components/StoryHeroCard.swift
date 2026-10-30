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
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.stroke, lineWidth: 1))
                .accessibilityHidden(true)
            content
        }
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(story.metaLine)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
            Text(story.title)
                .font(size == .large ? .appTitle : .appHeading)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack(spacing: AppSpacing.st) {
                SourceStack(sources: story.sources, size: 22, ringColor: AppColors.Adaptive.background)
                if let coverage = story.computedCoverage {
                    SpectrumBar(coverage: coverage)
                        .frame(maxWidth: 140)
                }
                Spacer(minLength: 0)
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

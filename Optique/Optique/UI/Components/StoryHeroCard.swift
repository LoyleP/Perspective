import SwiftUI

/// Big story card: photo on top; meta line, headline, sources and spectrum below it.
struct StoryHeroCard: View {
    let story: Story
    var size: Size = .large

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Size {
        case large   // 340 pt tall, lead story (big headline)
        case medium  // 16:9, feature breaks in the feed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            cover
                .overlay { RemoteImage(url: story.leadImageURL, tint: tint) }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.l).stroke(AppColors.stroke, lineWidth: 1))
                .accessibilityHidden(true)
            content
        }
        .accessibilityElement(children: .combine)
    }

    /// The lead story's cover is as tall as the photo at the top of its own page (340 pt); the
    /// others are 16:9.
    @ViewBuilder
    private var cover: some View {
        if size == .large {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 340)
        } else {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
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
                .font(size == .large ? .appTitle : .geist(.heading, .medium))
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            if let standfirst = story.standfirst {
                Text(standfirst)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: AppSpacing.s) {
                // The coverage tag only where the left/right lens means something.
                if let coverage = story.computedCoverage, story.hasPoliticalAngle {
                    LeanTags(coverage: coverage)
                }
                SourceStack(sources: story.sources, size: 22, ringColor: AppColors.Adaptive.background)
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

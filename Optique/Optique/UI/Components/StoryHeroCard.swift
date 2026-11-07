import SwiftUI

/// Big story card: photo on top; meta line, headline, sources and spectrum below it.
struct StoryHeroCard: View {
    let story: Story
    var size: Size = .large
    /// Fills the height it is given and keeps the tag and time at the bottom (carousels of equal cards).
    var compact = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Size {
        case large   // 340 pt tall, lead story (big headline)
        case medium  // 16:9, feature breaks in the feed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The photo touches the card's top, left and right edges; the card's corners clip it.
            cover
                .overlay { RemoteImage(url: story.leadImageURL, tint: tint) }
                .clipped()
                .accessibilityHidden(true)
            // Apple Music: the text sits close under the artwork and the lines are tight.
            content
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.st)
                .padding(.bottom, AppSpacing.m)
                .frame(maxHeight: compact ? .infinity : nil, alignment: .top)
        }
        .frame(maxHeight: compact ? .infinity : nil, alignment: .top)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .padding(.vertical, 5)
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
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Text(story.title)
                .typeStyle(size == .large ? .display : .headline)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if compact { Spacer(minLength: 0) }
            StoryMetaLine(story: story)
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

import SwiftUI

/// Full-bleed image card for the lead story: headline over the photo,
/// with sources and a compact spectrum along the bottom.
struct StoryHeroCard: View {
    let story: Story
    var size: Size = .large

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Size {
        case large   // 4:5, lead story
        case medium  // 3:2, feature breaks in the feed
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Large text would not fit over a fixed-ratio photo: stack it below instead.
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .overlay { RemoteImage(url: story.leadImageURL, tint: tint) }
                        .clipped()
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(AppColors.Adaptive.cardSurface)
            } else {
                Color.clear
                    .aspectRatio(size == .large ? 4.0 / 5.0 : 3.0 / 2.0, contentMode: .fit)
                    .overlay { RemoteImage(url: story.leadImageURL, tint: tint) }
                    .overlay { AppColors.Adaptive.imageScrim }
                    .overlay(alignment: .bottomLeading) { content }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Text(story.metaLine)
                .font(.appCaption)
                .foregroundStyle(.white.opacity(0.75))
            Text(story.title)
                .font(size == .large ? .appTitle : .appHeading)
                .foregroundStyle(.white)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : (size == .large ? 4 : 3))
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
            HStack(spacing: AppSpacing.st) {
                SourceStack(sources: story.sources, size: 22, ringColor: .black)
                if let coverage = story.computedCoverage {
                    SpectrumBar(coverage: coverage)
                        .frame(maxWidth: 140)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(AppSpacing.ml)
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

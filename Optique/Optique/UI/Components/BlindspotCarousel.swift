import SwiftUI

/// "Angles morts": stories one side barely covers, as a row of equal cards. The home and Explorer
/// pages both use it; the caller wraps each card in its own link and zoom source.
/// The row spans the full screen width: inside a padded parent, bleed it with a negative padding.
struct BlindspotCarousel<Card: View>: View {
    let stories: [Story]
    let subtitle: String
    @ViewBuilder let card: (Story, StoryHeroCard) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Angles morts", subtitle: subtitle)
                .padding(.horizontal, AppSpacing.m)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(stories) { story in
                        card(story, StoryHeroCard(story: story, size: .medium, compact: true))
                            .containerRelativeFrame(.horizontal) { width, _ in width * 0.84 }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, AppSpacing.m, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

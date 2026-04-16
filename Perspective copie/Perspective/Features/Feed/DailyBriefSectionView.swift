import SwiftUI

struct DailyBriefSectionView: View {

    let stories: [Story]

    private var briefStories: [Story] { Array(stories.prefix(2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Brief journalier")
                .font(.appLargeTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)

            if !briefStories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppSpacing.st) {
                        ForEach(briefStories) { story in
                            NavigationLink(value: story) {
                                DailyBriefCardView(story: story)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

#if DEBUG
#Preview("DailyBriefSectionView") {
    DailyBriefSectionView(stories: [PreviewData.story, PreviewData.story])
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.feedBackground)
}
#endif

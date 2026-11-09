import SwiftUI

/// The real story row, blind-spot card and law row as the onboarding's moving backdrops show them: same look
/// and same data, but with headlines cut at two lines and a fixed height, so every card in a grid is the same
/// size. The app's own components are left as they are.

/// The story row: headline, coverage bar and time on the left, a photo on the right.
struct OnboardingStoryRow: View {
    let story: Story

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Text(story.title)
                    .typeStyle(.rowTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                StoryMetaLine(story: story)
            }
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Color.clear
                .frame(width: 108)
                .overlay { RemoteImage(url: story.leadImageURL, maxPixel: 360) }
                .clipped()
        }
        .frame(height: 124)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
    }
}

/// The blind-spot card: photo on top, then headline, coverage bar and time.
struct OnboardingStoryCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .overlay { RemoteImage(url: story.leadImageURL, maxPixel: 600) }
                .clipped()
            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Text(story.title)
                    .typeStyle(.rowTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                StoryMetaLine(story: story)
            }
            .padding(AppSpacing.m)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 262)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
    }
}

/// The law row: who it concerns, title, status in a plain sentence and the four-stage bar.
struct OnboardingLawRow: View {
    let law: Law

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            if let name = law.authorName {
                HStack(spacing: AppSpacing.s) {
                    AsyncImage(url: law.authorPhoto.flatMap(URL.init(string:))) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppColors.Adaptive.surfaceElevated)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    Text(name)
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                }
            } else {
                Color.clear.frame(height: 24)
            }
            Text(law.displayTitle)
                .typeStyle(.rowTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(LawExplainer.headline(for: law))
                .typeStyle(.meta)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .lineLimit(1)
            Spacer(minLength: 0)
            LawProgressBar(law: law)
        }
        .padding(AppSpacing.m)
        .frame(height: 176, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
    }
}

import SwiftUI

struct DailyBriefCardView: View {

    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(story.title)
                .font(.appHeadline)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.m)

            HStack(spacing: 0) {
                Text("\(story.articles.count) articles analysés")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .padding(.leading, AppSpacing.m)

                Spacer()

                Button { } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.top, AppSpacing.m)
        .frame(width: 250)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
    }
}

#if DEBUG
#Preview("DailyBriefCardView") {
    DailyBriefCardView(story: PreviewData.story)
        .padding()
        .background(AppColors.Adaptive.feedBackground)
}
#endif

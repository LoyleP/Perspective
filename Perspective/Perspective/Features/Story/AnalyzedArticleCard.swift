import SwiftUI

struct AnalyzedArticleCard: View {

    let article: Article
    var onTap: (() -> Void)? = nil

    var body: some View {
        let cardContent = cardBody
        if let onTap {
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text(article.title)
                .font(.appTitle2)
                .foregroundStyle(AppColors.Adaptive.textSecondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: AppSpacing.s) {
                if let lean = article.source.flatMap({ PoliticalLean.from($0.politicalLean) }) {
                    LeanTagView(lean: lean, style: .rounded)
                }
                if let source = article.source {
                    HStack(spacing: AppSpacing.xs) {
                        SourceAvatarView(source: source)
                        Text(source.name)
                            .font(.appFootnote)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .cardSurface(fill: AppColors.Adaptive.detailSurface)
    }
}

#if DEBUG
#Preview("AnalyzedArticleCard") {
    VStack(spacing: 12) {
        AnalyzedArticleCard(article: PreviewData.article1)
        AnalyzedArticleCard(article: PreviewData.article2)
        AnalyzedArticleCard(article: PreviewData.article3)
    }
    .padding()
    .background(AppColors.Adaptive.background)
}
#endif

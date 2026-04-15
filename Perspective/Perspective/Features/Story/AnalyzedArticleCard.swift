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
                    leanTag(lean)
                }
                if let source = article.source {
                    sourceRow(source)
                }
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }

    private func leanTag(_ lean: PoliticalLean) -> some View {
        Text(lean.shortLabel)
            .font(.appFootnote)
            .foregroundStyle(lean.tagTextColor)
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xs)
            .background(lean.spectrumColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.s).stroke(AppColors.stroke, lineWidth: 1))
    }

    private func sourceRow(_ source: Source) -> some View {
        HStack(spacing: AppSpacing.xs) {
            avatarCircle(source)
            Text(source.name)
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .lineLimit(1)
        }
    }

    private func avatarCircle(_ source: Source) -> some View {
        Group {
            if let s = source.logoURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        Color.clear.overlay(img.resizable().scaledToFill()).clipped()
                    } else {
                        sourceInitial(source)
                    }
                }
            } else {
                sourceInitial(source)
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private func sourceInitial(_ source: Source) -> some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
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

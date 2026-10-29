import SwiftUI

/// Articles from one political side, shown in a sheet when its carousel card is tapped.
struct SideArticlesSheet: View {
    let side: PoliticalLean
    let articles: [Article]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedArticle: Article?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(articles) { article in
                        Button {
                            selectedArticle = article
                        } label: {
                            ArticleSourceRow(article: article)
                        }
                        .buttonStyle(CardPressStyle())
                        Divider().overlay(AppColors.Adaptive.divider)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
            }
            .background(AppColors.Adaptive.background)
            .navigationTitle(side.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleBrowserView(articles: articles, initialArticle: article)
            }
            .overlay {
                if articles.isEmpty {
                    ContentUnavailableView(
                        "Aucun article",
                        hero: "newspaper",
                        description: Text("Aucun média de ce bord n'a couvert ce sujet.")
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Article row

/// Source logo, name, position and time above the article headline.
struct ArticleSourceRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            if let source = article.source {
                SourceAvatarView(source: source, size: 32)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(article.source?.name ?? "Source")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    if let lean = article.source?.lean {
                        Circle().fill(lean.spectrumColor).frame(width: 6, height: 6)
                        Text(lean.shortLabel)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                    Spacer(minLength: AppSpacing.s)
                    Text(article.publishedAt.relativeToNowFrench())
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(article.title)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, AppSpacing.st)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Side articles") {
    let story = Fixtures.stories[0]
    return SideArticlesSheet(
        side: .gauche,
        articles: story.articles.filter { PoliticalLean.from($0.source?.politicalLean ?? 4) == .gauche }
    )
    .environment(ReadingHistoryStore())
}
#endif

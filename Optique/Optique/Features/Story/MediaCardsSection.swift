import SwiftUI

/// "Ce que disent les médias": a carousel with one card per outlet covering the story, starting with the
/// most recent article. Each card shows the outlet, its position, and what it published (headline and
/// summary). Tapping a card opens that article in the reader.
struct MediaCardsSection: View {
    let articles: [Article]
    /// Off in demos (onboarding): the cards are only shown.
    var isInteractive = true

    @State private var selectedArticle: Article?

    /// The newest article of each outlet, most recent first.
    private var cards: [Article] {
        var latest: [UUID: Article] = [:]
        for article in articles {
            if let existing = latest[article.sourceID], existing.publishedAt >= article.publishedAt { continue }
            latest[article.sourceID] = article
        }
        return latest.values.sorted { $0.publishedAt > $1.publishedAt }
    }

    var body: some View {
        let all = cards
        return VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Ce que disent les médias", subtitle: all.count == 1 ? "1 média" : "\(all.count) médias")
                .padding(.horizontal, AppSpacing.m)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(all) { article in
                        Button { if isInteractive { selectedArticle = article } } label: { card(article) }
                            .buttonStyle(CardPressStyle())
                            .containerRelativeFrame(.horizontal) { width, _ in width * 0.84 }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, AppSpacing.m, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
        .navigationDestination(item: $selectedArticle) { article in
            ArticleBrowserView(articles: articles.sorted { $0.publishedAt > $1.publishedAt }, initialArticle: article)
        }
    }

    private func card(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            HStack(spacing: AppSpacing.st) {
                if let source = article.source {
                    SourceAvatarView(source: source, size: 36)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.source?.name ?? "Source")
                        .typeStyle(.ui)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: AppSpacing.s) {
                        if let lean = article.source?.lean {
                            LeanTagPill(lean: lean, text: lean.shortLabel)
                        }
                        Text(article.publishedAt.relativeToNowFrench())
                            .typeStyle(.meta)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(article.title)
                .typeStyle(.rowTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let summary = article.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                Text(summary)
                    .typeStyle(.body)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: AppSpacing.xs)
            HStack(spacing: 6) {
                Text("Voir l'article")
                    .typeStyle(.meta)
                LucideIcon("arrow-left", size: 14)
                    .rotationEffect(.degrees(180))
            }
            .foregroundStyle(AppColors.Adaptive.textPrimary)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Media cards") {
    ScrollView {
        MediaCardsSection(articles: Fixtures.stories[0].articles)
            .padding()
    }
    .background(AppColors.Adaptive.background)
    .environment(ReadingHistoryStore())
}
#endif

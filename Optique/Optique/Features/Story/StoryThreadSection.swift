import SwiftUI

/// "Fil de l'histoire": every article on the story as a thread, newest first. Outlet logos
/// form a left column joined by a thin vertical line; each post shows outlet, side, time and
/// headline. Tapping a post opens the article reader.
struct StoryThreadSection: View {
    let articles: [Article]

    @State private var selectedArticle: Article?
    @State private var visibleCount = 5

    private let pageSize = 5

    private var sorted: [Article] { articles.sorted { $0.publishedAt > $1.publishedAt } }

    var body: some View {
        let posts = Array(sorted.prefix(visibleCount))
        return VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Fil de l'histoire", subtitle: subtitle)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, article in
                    Button {
                        selectedArticle = article
                    } label: {
                        post(article, isLast: index == posts.count - 1)
                    }
                    .buttonStyle(CardPressStyle())
                }
            }

            if sorted.count > visibleCount {
                Button("Voir plus") {
                    withAnimation(.app) { visibleCount += pageSize }
                }
                .buttonStyle(.optiqueSecondary)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationDestination(item: $selectedArticle) { article in
            ArticleBrowserView(articles: sorted, initialArticle: article)
        }
    }

    private var subtitle: String {
        guard let first = sorted.last?.publishedAt, let last = sorted.first?.publishedAt else { return "" }
        let count = articles.count == 1 ? "1 article" : "\(articles.count) articles"
        let fr = Locale(identifier: "fr_FR")
        let span = "du \(first.formatted(.dateTime.day().month(.abbreviated).locale(fr))) au \(last.formatted(.dateTime.day().month(.abbreviated).locale(fr)))"
        return Calendar.current.isDate(first, inSameDayAs: last) ? count : "\(count) · \(span)"
    }

    // MARK: - Post

    private func post(_ article: Article, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            // Left column: logo, then the thread line down to the next logo.
            VStack(spacing: 4) {
                if let source = article.source {
                    SourceAvatarView(source: source, size: 40)
                } else {
                    Circle().fill(AppColors.Adaptive.surfaceElevated).frame(width: 40, height: 40)
                }
                if isLast {
                    Circle().fill(AppColors.Adaptive.divider).frame(width: 6, height: 6)
                } else {
                    Capsule()
                        .fill(AppColors.Adaptive.divider)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(article.source?.name ?? "Source")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(1)
                    Text(article.publishedAt.relativeToNowFrench())
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                    Spacer(minLength: AppSpacing.s)
                    if let lean = article.source?.lean {
                        Circle().fill(lean.spectrumColor).frame(width: 7, height: 7)
                        Text(lean.shortLabel)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                            .lineLimit(1)
                    }
                }
                Text(article.title)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(.bottom, AppSpacing.l)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Thread") {
    ScrollView {
        StoryThreadSection(articles: Fixtures.stories[0].articles)
            .padding()
    }
    .background(AppColors.Adaptive.background)
    .environment(ReadingHistoryStore())
}
#endif

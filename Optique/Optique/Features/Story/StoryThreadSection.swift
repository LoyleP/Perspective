import SwiftUI

/// "Évolution": every article on the story as a thread, newest first. Outlet logos
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
            SectionHeader(title: "Évolution", subtitle: subtitle)

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
                Button {
                    withAnimation(.app) { visibleCount += pageSize }
                } label: {
                    HStack(spacing: AppSpacing.s) {
                        LucideIcon("plus", size: 16)
                        Text("Voir plus")
                    }
                }
                .buttonStyle(.grayCTA)
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
                        .font(.geist(.body, .medium))
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(1)
                    if let lean = article.source?.lean {
                        LeanTagPill(lean: lean, text: lean.shortLabel)
                    }
                    Text(article.publishedAt.relativeToNowFrench())
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(article.title)
                    .typeStyle(.body)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(.bottom, AppSpacing.l)

            // Opens the article in the in-app browser.
            LucideIcon("chevron-right", size: 22)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(maxHeight: .infinity)
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

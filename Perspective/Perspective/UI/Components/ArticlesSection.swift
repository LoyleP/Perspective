import SwiftUI

struct ArticlesSection: View {

    let articles: [Article]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Articles (\(articles.count))")
                .font(.headline)

            ForEach(articlesByLean(), id: \.0) { lean, leanArticles in
                VStack(alignment: .leading, spacing: 8) {
                    Text(lean.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(lean.color)

                    ForEach(Array(leanArticles.enumerated()), id: \.element.id) { index, article in
                        articleRow(article)
                        if index < leanArticles.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func articlesByLean() -> [(PoliticalLean, [Article])] {
        let withSource = articles.filter { $0.source != nil }
        let grouped = Dictionary(grouping: withSource) { $0.source!.politicalLean }
        return grouped
            .sorted { $0.key < $1.key }
            .compactMap { leanInt, arts in
                guard let lean = PoliticalLean.from(leanInt) else { return nil }
                return (lean, arts)
            }
    }

    @ViewBuilder
    private func articleRow(_ article: Article) -> some View {
        if let url = URL(string: article.url) {
            Link(destination: url) {
                articleRowContent(article, hasLink: true)
            }
            .buttonStyle(.plain)
        } else {
            articleRowContent(article, hasLink: false)
        }
    }

    private func articleRowContent(_ article: Article, hasLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let sourceName = article.source?.name {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(article.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(article.publishedAt.relativeToNowFrench())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if hasLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

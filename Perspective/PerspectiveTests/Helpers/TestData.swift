import Foundation
@testable import Perspective

enum TestData {
    static let storyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let sourceID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!

    static func makeArticle(
        id: UUID = UUID(),
        sourceID: UUID = TestData.sourceID,
        title: String = "Test Article",
        isPrimary: Bool = true,
        politicalLean: Int = 4
    ) -> Article {
        Article(
            id: id,
            sourceID: sourceID,
            title: title,
            url: "https://example.com/\(id)",
            summary: nil,
            imageURL: nil,
            publishedAt: Date(timeIntervalSinceNow: -3600),
            fetchedAt: .now,
            storyID: storyID,
            rawKeywords: [],
            clickCount: 0,
            isPrimary: isPrimary,
            createdAt: .now,
            updatedAt: .now,
            source: Source(
                id: sourceID,
                name: "Test Source",
                url: "https://example.com",
                rssURL: "https://example.com/rss",
                logoURL: nil,
                politicalLean: politicalLean,
                ownerName: nil,
                ownerNotes: nil,
                ownerType: nil,
                isActive: true,
                createdAt: .now,
                updatedAt: .now
            )
        )
    }

    static func makeStory(
        id: UUID = storyID,
        title: String = "Test Story",
        articleCount: Int = 3,
        isFeatured: Bool = false
    ) -> Story {
        let articles = (0..<articleCount).map { i in
            makeArticle(id: UUID(), title: "Article \(i)")
        }
        return Story(
            id: id,
            title: title,
            summary: "Test summary",
            firstPublishedAt: Date(timeIntervalSinceNow: -86400),
            lastUpdatedAt: .now,
            topicTags: ["politique"],
            isFeatured: isFeatured,
            createdAt: .now,
            updatedAt: .now,
            articles: articles,
            coverage: nil,
            spectrumSummary: nil,
            summaryGeneratedAt: nil
        )
    }
}

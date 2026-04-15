import Foundation

struct Article: Codable, Identifiable, Hashable {
    let id: UUID
    let sourceID: UUID
    let title: String
    let url: String
    let summary: String?
    let imageURL: String?
    let publishedAt: Date
    let fetchedAt: Date
    let storyID: UUID?
    let rawKeywords: [String]
    let clickCount: Int
    let isPrimary: Bool
    let createdAt: Date
    let updatedAt: Date

    // Populated via Supabase join (select articles(*, sources(*)))
    let source: Source?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceID    = "source_id"
        case title
        case url
        case summary
        case imageURL    = "image_url"
        case publishedAt = "published_at"
        case fetchedAt   = "fetched_at"
        case storyID     = "story_id"
        case rawKeywords = "raw_keywords"
        case clickCount  = "click_count"
        case isPrimary   = "is_primary"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
        case source      = "sources"
    }
}

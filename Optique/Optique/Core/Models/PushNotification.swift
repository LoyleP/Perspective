import Foundation

struct PushNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let storyCount: Int
    let storyId: UUID?
    let sentAt: Date
    let createdAt: Date
    /// Primary articles per lean (index 0 = lean 1) for the linked story, when there is one.
    let leanCounts: [Int]?

    var coverage: CoverageStats? {
        leanCounts.flatMap { CoverageStats.from(storyID: storyId ?? id, counts: $0) }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case storyCount = "story_count"
        case storyId    = "story_id"
        case sentAt     = "sent_at"
        case createdAt  = "created_at"
        case leanCounts = "lean_counts"
    }
}

import Foundation

struct PushNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let storyCount: Int
    let storyId: UUID?
    let sentAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case storyCount = "story_count"
        case storyId    = "story_id"
        case sentAt     = "sent_at"
        case createdAt  = "created_at"
    }
}

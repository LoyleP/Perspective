import Foundation

/// A comment (or reply, when `parentID` is set) on a story's discussion.
struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let storyID: UUID
    let parentID: UUID?
    let author: String
    let text: String
    let createdAt: Date
    var likes: Int
    var likedByMe: Bool
}

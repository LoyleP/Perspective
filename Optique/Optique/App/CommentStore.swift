import SwiftUI

/// Story discussions. Stored on the device for now (no accounts or backend yet), newest last.
@MainActor
@Observable
final class CommentStore {

    static let shared = CommentStore()
    static let selfName = "Vous"

    private let storageKey = "comment_store_comments"
    private let defaults: UserDefaults
    private(set) var comments: [Comment] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Comment].self, from: data) {
            comments = decoded
        }
    }

    func count(for storyID: UUID) -> Int {
        comments.reduce(0) { $0 + ($1.storyID == storyID ? 1 : 0) }
    }

    func topLevel(for storyID: UUID) -> [Comment] {
        comments.filter { $0.storyID == storyID && $0.parentID == nil }
    }

    func replies(to commentID: UUID) -> [Comment] {
        comments.filter { $0.parentID == commentID }
    }

    func add(_ text: String, to storyID: UUID, replyingTo parentID: UUID? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        comments.append(Comment(
            id: UUID(), storyID: storyID, parentID: parentID, author: Self.selfName,
            text: trimmed, createdAt: Date(), likes: 0, likedByMe: false
        ))
        save()
    }

    func toggleLike(_ id: UUID) {
        guard let i = comments.firstIndex(where: { $0.id == id }) else { return }
        comments[i].likedByMe.toggle()
        comments[i].likes += comments[i].likedByMe ? 1 : -1
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(comments) { defaults.set(data, forKey: storageKey) }
    }
}

private struct CommentStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = CommentStore.shared
}

extension EnvironmentValues {
    var commentStore: CommentStore {
        get { self[CommentStoreKey.self] }
        set { self[CommentStoreKey.self] = newValue }
    }
}

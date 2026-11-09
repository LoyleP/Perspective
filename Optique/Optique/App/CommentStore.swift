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
        comments
            .filter { $0.storyID == storyID && $0.parentID == nil }
            .sorted { $0.createdAt > $1.createdAt }   // newest first, so your latest comment is on top
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

    #if DEBUG
    /// Fills a story that has no comments with sample ones, to judge the layout (debug builds only).
    func seedMockIfNeeded(for storyID: UUID) {
        guard count(for: storyID) == 0 else { return }
        let now = Date()
        func make(_ author: String, _ text: String, minutesAgo: Double, likes: Int, parent: UUID? = nil) -> Comment {
            Comment(id: UUID(), storyID: storyID, parentID: parent, author: author, text: text,
                    createdAt: now.addingTimeInterval(-minutesAgo * 60), likes: likes, likedByMe: false)
        }
        let a = make("Camille R.", "Merci pour ce récapitulatif, ça aide vraiment à comprendre les différents angles.", minutesAgo: 340, likes: 24)
        let b = make("Julien", "Ce qui me frappe, c'est l'écart entre la façon dont les médias de gauche et de droite en parlent.", minutesAgo: 190, likes: 41)
        let c = make("Nadia B.", "Quelqu'un a une source primaire pour ça ?", minutesAgo: 95, likes: 3)
        let d = make("Thomas L.", "Je n'avais pas vu cette info ailleurs, bon à savoir.", minutesAgo: 30, likes: 0)
        let e = make("Inès", "Très bonne idée de montrer les sources côte à côte 👏", minutesAgo: 6, likes: 7)
        comments += [a, b, c, d, e,
            make("Marc D.", "Tout à fait d'accord, c'est exactement ce que je me disais.", minutesAgo: 300, likes: 5, parent: a.id),
            make("Sophie", "Pareil pour moi, on y voit enfin plus clair.", minutesAgo: 280, likes: 2, parent: a.id),
            make("Camille R.", "Oui, et les citations des deux bords aident beaucoup.", minutesAgo: 150, likes: 1, parent: b.id),
            make("Paul", "Il y a un lien dans l'article du Monde, juste au-dessus.", minutesAgo: 60, likes: 4, parent: c.id),
        ]
        save()
    }
    #endif

    /// Removes every comment (debug menu, settings reset).
    func clearAll() {
        comments = []
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

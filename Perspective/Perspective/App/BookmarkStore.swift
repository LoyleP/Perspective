import Foundation

@MainActor
@Observable
final class BookmarkStore {

    private let storageKey = "bookmark_store_stories"
    private let defaults: UserDefaults
    private(set) var stories: [Story] = []

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func toggle(_ story: Story) {
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories.remove(at: idx)
        } else {
            stories.insert(story, at: 0)
        }
        save()
    }

    func isBookmarked(_ story: Story) -> Bool {
        stories.contains(where: { $0.id == story.id })
    }

    private func save() {
        guard let data = try? Self.encoder.encode(stories) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? Self.decoder.decode([Story].self, from: data)
        else { return }
        stories = decoded
    }
}

import Foundation

@Observable
final class BookmarkStore {

    private let storageKey = "bookmark_store_stories"
    private(set) var stories: [Story] = []

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    init() {
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
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? Self.decoder.decode([Story].self, from: data)
        else { return }
        stories = decoded
    }
}

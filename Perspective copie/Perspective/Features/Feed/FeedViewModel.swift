import Foundation

@Observable
final class FeedViewModel {

    var isLoading = false
    var error: Error?

    let cacheDuration: TimeInterval = 6 * 60 * 60
    var lastFetchedAt: Date?

    var allStories: [Story] = []

    // MARK: - Computed Properties

    var stories: [Story] {
        allStories
            .filter { $0.articles.count >= 2 }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
    }

    var cetteSemanineHero: Story? {
        stories.first(where: { $0.isFeatured }) ?? stories.first
    }

    var briefStories: [Story] {
        guard let heroID = cetteSemanineHero?.id else { return [] }
        return Array(stories.filter { $0.id != heroID }.prefix(2))
    }

    var feedStories: [Story] {
        let usedIDs = Set([cetteSemanineHero?.id].compactMap { $0 } + briefStories.map { $0.id })
        return stories.filter { !usedIDs.contains($0.id) }
    }

    // MARK: - Load

    func load() async {
        let isFresh = !allStories.isEmpty
            && lastFetchedAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        guard !isFresh else { return }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let page = try await StoryRepository.shared.fetchFeed(
                topic: nil,
                limit: 30,
                offset: 0
            )
            allStories = page
            lastFetchedAt = Date()
        } catch {
            print("❌ FeedViewModel.load() ERROR:")
            print("   Type: \(type(of: error))")
            print("   Description: \(error)")
            print("   LocalizedDescription: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   ❌ Key '\(key.stringValue)' not found")
                    print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   ❌ Type mismatch for type: \(type)")
                    print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   ❌ Value not found for type: \(type)")
                    print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   ❌ Data corrupted")
                    print("   CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                @unknown default:
                    print("   ❌ Unknown decoding error")
                }
            }
            self.error = error
        }
        isLoading = false
    }

    func refresh() async {
        isLoading = false
        await load()
    }
}

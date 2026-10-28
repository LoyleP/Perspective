import Foundation
import OSLog

final class StoryRepository: StoryRepositoryProtocol {

    static let shared = StoryRepository()

    private init() {}

    // MARK: - Public API

    func fetchFeed(topic: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [Story] {
        #if DEBUG
        if Fixtures.isActive {
            let all = try await Fixtures.apply(Fixtures.stories.filter { topic == nil || $0.topicTags.contains(topic!) })
            return Array(all.dropFirst(offset).prefix(limit))
        }
        #endif
        do {
            var query = ["limit": String(limit), "offset": String(offset)]
            if let topic { query["topic"] = topic }
            let stories: [Story] = try await APIClient.shared.get("feed", query: query)
            Log.repository.info("Fetched \(stories.count) stories")
            return stories
        } catch {
            Log.repository.error("fetchFeed failed: \(error)")
            throw AppError.from(error)
        }
    }

    func fetchStory(id: UUID) async throws -> Story? {
        #if DEBUG
        if Fixtures.isActive { return Fixtures.stories.first { $0.id == id } }
        #endif
        do {
            let story: Story = try await APIClient.shared.get("story", query: ["id": id.uuidString])
            return story
        } catch {
            Log.repository.error("fetchStory(\(id)) failed: \(error)")
            throw AppError.from(error)
        }
    }

    func searchStories(query: String, limit: Int) async throws -> [Story] {
        #if DEBUG
        if Fixtures.isActive {
            return try await Fixtures.apply(Fixtures.stories.filter { $0.title.localizedCaseInsensitiveContains(query) })
        }
        #endif
        do {
            return try await APIClient.shared.get("feed", query: ["q": query, "limit": String(limit)])
        } catch {
            Log.repository.error("searchStories failed: \(error)")
            throw AppError.from(error)
        }
    }
}

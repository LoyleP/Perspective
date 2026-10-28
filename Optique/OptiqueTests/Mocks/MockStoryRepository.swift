import Foundation
@testable import Optique

final class MockStoryRepository: StoryRepositoryProtocol, @unchecked Sendable {
    var feedResult: Result<[Story], Error> = .success([])
    var storyResult: Result<Story?, Error> = .success(nil)
    var fetchFeedCallCount = 0
    var lastFetchTopic: String?
    var lastFetchLimit: Int?
    var lastFetchOffset: Int?
    var searchResult: Result<[Story], Error> = .success([])
    var lastSearchQuery: String?

    func fetchFeed(topic: String?, limit: Int, offset: Int) async throws -> [Story] {
        fetchFeedCallCount += 1
        lastFetchTopic = topic
        lastFetchLimit = limit
        lastFetchOffset = offset
        return try feedResult.get()
    }

    func fetchStory(id: UUID) async throws -> Story? {
        return try storyResult.get()
    }

    func searchStories(query: String, limit: Int) async throws -> [Story] {
        lastSearchQuery = query
        return try searchResult.get()
    }
}

final class MockSourceRepository: SourceRepositoryProtocol, @unchecked Sendable {
    var sourcesResult: Result<[Source], Error> = .success([])

    func fetchAllSources() async throws -> [Source] { try sourcesResult.get() }
    func fetchSource(id: UUID) async throws -> Source? { try sourcesResult.get().first { $0.id == id } }
    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article] { [] }
}

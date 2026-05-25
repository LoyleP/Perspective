import Foundation
@testable import Perspective

final class MockStoryRepository: StoryRepositoryProtocol, @unchecked Sendable {
    var feedResult: Result<[Story], Error> = .success([])
    var storyResult: Result<Story?, Error> = .success(nil)
    var fetchFeedCallCount = 0
    var lastFetchTopic: String?
    var lastFetchLimit: Int?
    var lastFetchOffset: Int?

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
}

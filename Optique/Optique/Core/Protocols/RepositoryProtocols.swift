import Foundation

protocol StoryRepositoryProtocol: Sendable {
    func fetchFeed(topic: String?, limit: Int, offset: Int) async throws -> [Story]
    func fetchStory(id: UUID) async throws -> Story?
    func searchStories(query: String, limit: Int) async throws -> [Story]
    /// The last feed received for this request, without touching the network (nil if none).
    func cachedFeed(topic: String?, limit: Int, offset: Int) async -> [Story]?
}

extension StoryRepositoryProtocol {
    func cachedFeed(topic: String?, limit: Int, offset: Int) async -> [Story]? { nil }
}

protocol SourceRepositoryProtocol: Sendable {
    func fetchAllSources() async throws -> [Source]
    func fetchSource(id: UUID) async throws -> Source?
    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article]
    /// The last source list received, without touching the network (nil if none).
    func cachedSources() async -> [Source]?
    func cachedRecentArticles(sourceId: UUID, limit: Int) async -> [Article]?
}

extension SourceRepositoryProtocol {
    func cachedSources() async -> [Source]? { nil }
    func cachedRecentArticles(sourceId: UUID, limit: Int) async -> [Article]? { nil }
}

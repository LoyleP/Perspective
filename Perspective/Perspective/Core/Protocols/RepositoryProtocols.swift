import Foundation

protocol StoryRepositoryProtocol: Sendable {
    func fetchFeed(topic: String?, limit: Int, offset: Int) async throws -> [Story]
    func fetchStory(id: UUID) async throws -> Story?
}

protocol SourceRepositoryProtocol: Sendable {
    func fetchAllSources() async throws -> [Source]
    func fetchSource(id: UUID) async throws -> Source?
    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article]
}

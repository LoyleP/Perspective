import Foundation
import OSLog

final class SourceRepository: SourceRepositoryProtocol {

    static let shared = SourceRepository()

    private init() {}

    // MARK: - Public API

    func fetchAllSources() async throws -> [Source] {
        #if DEBUG
        if Fixtures.isActive { return try await Fixtures.apply(Fixtures.sources) }
        #endif
        do {
            let sources: [Source] = try await APIClient.shared.get("sources")
            return sources
        } catch {
            Log.repository.error("fetchAllSources failed: \(error)")
            throw AppError.from(error)
        }
    }

    func fetchSource(id: UUID) async throws -> Source? {
        #if DEBUG
        if Fixtures.isActive { return Fixtures.sources.first { $0.id == id } }
        #endif
        do {
            let source: Source = try await APIClient.shared.get("sources", query: ["id": id.uuidString])
            return source
        } catch {
            Log.repository.error("fetchSource(\(id)) failed: \(error)")
            throw AppError.from(error)
        }
    }

    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article] {
        #if DEBUG
        if Fixtures.isActive {
            return Array(Fixtures.stories.flatMap(\.articles).filter { $0.sourceID == sourceId }.prefix(limit))
        }
        #endif
        do {
            let articles: [Article] = try await APIClient.shared.get("source-articles", query: ["source_id": sourceId.uuidString, "limit": String(limit)])
            return articles
        } catch {
            Log.repository.error("fetchRecentArticles(\(sourceId)) failed: \(error)")
            throw AppError.from(error)
        }
    }
}

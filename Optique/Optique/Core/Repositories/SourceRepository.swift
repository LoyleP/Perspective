import Foundation
import OSLog

final class SourceRepository: SourceRepositoryProtocol {

    static let shared = SourceRepository()

    private init() {}

    // MARK: - Public API

    func fetchAllSources() async throws -> [Source] {
        do {
            let sources: [Source] = try await APIClient.shared.get("sources")
            return sources
        } catch {
            Log.repository.error("fetchAllSources failed: \(error)")
            throw AppError.from(error)
        }
    }

    func fetchSource(id: UUID) async throws -> Source? {
        do {
            let source: Source = try await APIClient.shared.get("sources", query: ["id": id.uuidString])
            return source
        } catch {
            Log.repository.error("fetchSource(\(id)) failed: \(error)")
            throw AppError.from(error)
        }
    }

    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article] {
        do {
            let articles: [Article] = try await APIClient.shared.get("source-articles", query: ["source_id": sourceId.uuidString, "limit": String(limit)])
            return articles
        } catch {
            Log.repository.error("fetchRecentArticles(\(sourceId)) failed: \(error)")
            throw AppError.from(error)
        }
    }
}

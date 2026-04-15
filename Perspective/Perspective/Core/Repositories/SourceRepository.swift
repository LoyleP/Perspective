import Foundation
import Supabase

final class SourceRepository {

    static let shared = SourceRepository()

    private var db: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    // MARK: - Public API

    func fetchAllSources() async throws -> [Source] {
        do {
            let sources: [Source] = try await db
                .from("sources")
                .select("*")
                .eq("is_active", value: true)
                .order("political_lean", ascending: true)
                .execute()
                .value
            return sources
        } catch {
            log(error, context: "fetchAllSources")
            throw AppError.from(error)
        }
    }

    func fetchSource(id: UUID) async throws -> Source? {
        do {
            let sources: [Source] = try await db
                .from("sources")
                .select("*")
                .eq("id", value: id.uuidString)
                .limit(1)
                .execute()
                .value
            return sources.first
        } catch {
            log(error, context: "fetchSource(id: \(id))")
            throw AppError.from(error)
        }
    }

    func fetchRecentArticles(sourceId: UUID, limit: Int) async throws -> [Article] {
        do {
            let articles: [Article] = try await db
                .from("articles")
                .select("*")
                .eq("source_id", value: sourceId.uuidString)
                .order("published_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return articles
        } catch {
            log(error, context: "fetchRecentArticles(sourceId: \(sourceId), limit: \(limit))")
            throw AppError.from(error)
        }
    }

    // MARK: - Private

    private func log(_ error: Error, context: String) {
        print("[SourceRepository] \(context) failed: \(error)")
    }
}

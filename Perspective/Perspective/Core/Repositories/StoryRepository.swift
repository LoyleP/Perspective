import Foundation
import OSLog
import Supabase

final class StoryRepository: StoryRepositoryProtocol {

    static let shared = StoryRepository()

    private var db: SupabaseClient { SupabaseService.shared.client }

    private let fullSelect = "*, story_coverage_view(*), articles!inner(*, sources(*))"

    private init() {}

    // MARK: - Public API

    func fetchFeed(topic: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [Story] {
        do {
            var filterBuilder = db
                .from("stories")
                .select(fullSelect)

            if let topic {
                filterBuilder = filterBuilder.contains("topic_tags", value: "{\(topic)}")
            }

            let stories: [Story] = try await filterBuilder
                .order("last_updated_at", ascending: false)
                .order("id", ascending: true)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            Log.repository.info("Fetched \(stories.count) stories")
            return stories
        } catch {
            Log.repository.error("fetchFeed failed: \(error)")
            throw AppError.from(error)
        }
    }

    func fetchStory(id: UUID) async throws -> Story? {
        do {
            let stories: [Story] = try await db
                .from("stories")
                .select(fullSelect)
                .eq("id", value: id.uuidString)
                .limit(1)
                .execute()
                .value
            return stories.first
        } catch {
            Log.repository.error("fetchStory(\(id)) failed: \(error)")
            throw AppError.from(error)
        }
    }
}

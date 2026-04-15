import Foundation
import Supabase

final class StoryRepository {

    static let shared = StoryRepository()

    private var db: SupabaseClient { SupabaseService.shared.client }

    // Select all articles, we'll filter to primary articles in the query
    private let fullSelect = "*, story_coverage_view(*), articles!inner(*, sources(*))"

    private init() {}

    // MARK: - Public API

    /// Fetches a paginated list of stories, optionally filtered by topic tag.
    func fetchFeed(topic: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [Story] {
        print("🔵 StoryRepository.fetchFeed() starting...")
        do {
            // Filters must be applied on PostgrestFilterBuilder, before
            // .order()/.range() which return PostgrestTransformBuilder.
            var filterBuilder = db
                .from("stories")
                .select(fullSelect)

            if let topic {
                filterBuilder = filterBuilder.contains("topic_tags", value: "{\(topic)}")
            }

            print("🔵 Executing query with select: \(fullSelect)")

            let stories: [Story] = try await filterBuilder
                .order("last_updated_at", ascending: false)
                .order("id", ascending: true)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            print("✅ Successfully decoded \(stories.count) stories")
            return stories
        } catch {
            print("❌ StoryRepository.fetchFeed() ERROR:")
            print("   Type: \(type(of: error))")
            print("   Error: \(error)")
            print("   LocalizedDescription: \(error.localizedDescription)")

            if let decodingError = error as? DecodingError {
                print("   🔍 DECODING ERROR DETAILS:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("      Missing key: '\(key.stringValue)'")
                    print("      Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("      Context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("      Type mismatch: expected \(type)")
                    print("      Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("      Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("      Value not found: \(type)")
                    print("      Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("      Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("      Data corrupted")
                    print("      Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("      Context: \(context.debugDescription)")
                @unknown default:
                    print("      Unknown decoding error")
                }
            }

            log(error, context: "fetchFeed(topic: \(topic ?? "nil"), offset: \(offset))")
            throw error
        }
    }

    /// Fetches a single story with full article and coverage detail.
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
            log(error, context: "fetchStory(id: \(id))")
            throw error
        }
    }

    // MARK: - Private

    private func log(_ error: Error, context: String) {
        print("[StoryRepository] \(context) failed: \(error)")
    }
}

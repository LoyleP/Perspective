import Foundation
import OSLog

extension StoryRepository {

    private struct Envelope: Decodable { let edition: Edition? }

    /// The latest edition of the Brief, or nil when there is none yet (or the server can't be reached).
    func fetchLatestEdition() async -> Edition? {
        #if DEBUG
        // Before the server publishes real ones: a sample edition from the test stories.
        if UserDefaults.standard.bool(forKey: "debugEdition") || Fixtures.isActive { return Edition.sample }
        #endif
        do {
            let envelope: Envelope = try await APIClient.shared.get("feed", query: ["edition": "1"])
            return envelope.edition
        } catch {
            Log.repository.error("fetchLatestEdition failed: \(error)")
            return nil
        }
    }
}

#if DEBUG
extension Edition {
    static var sample: Edition {
        let stories = Array(Fixtures.stories.prefix(5))
        return Edition(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000ED17") ?? UUID(),
            day: "2026-11-10",
            slot: .matin,
            publishedAt: Date(),
            headline: stories.first?.title ?? "",
            stories: stories
        )
    }
}
#endif

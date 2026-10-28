import Foundation
import OSLog

@MainActor
@Observable
final class StoryDetailViewModel {

    var story: Story

    private let repository: any StoryRepositoryProtocol

    init(story: Story, repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.story = story
        self.repository = repository
    }

    /// True when generation failed or returned nothing, so the view can stop showing a skeleton.
    private(set) var summaryUnavailable = false

    /// Asks the API to generate the per-position summary (it returns once the summary
    /// is stored), then reloads the story to pick it up.
    func triggerSummaryGeneration() async {
        guard story.spectrumSummary == nil else { return }
        summaryUnavailable = false
        #if DEBUG
        if Fixtures.isActive {
            summaryUnavailable = true
            return
        }
        #endif

        do {
            try await APIClient.shared.post("generate-spectrum-summary", body: ["story_id": story.id.uuidString])
            if let updated = try await repository.fetchStory(id: story.id) {
                story = updated
            }
        } catch {
            Log.story.error("Summary generation failed: \(error)")
        }
        summaryUnavailable = story.spectrumSummary == nil
    }
}

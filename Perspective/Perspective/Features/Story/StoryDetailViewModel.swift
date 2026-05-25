import Foundation
import Supabase

@MainActor
@Observable
final class StoryDetailViewModel {

    var story: Story

    private let repository: any StoryRepositoryProtocol

    init(story: Story, repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.story = story
        self.repository = repository
    }

    func triggerSummaryGeneration() async {
        guard story.spectrumSummary == nil else { return }

        do {
            try await SupabaseService.shared.client.functions.invoke(
                "generate-spectrum-summary",
                options: FunctionInvokeOptions(
                    body: ["story_id": story.id.uuidString]
                )
            )
        } catch {
            return
        }

        try? await Task.sleep(for: .seconds(3))

        guard let updated = try? await repository.fetchStory(id: story.id) else {
            return
        }
        story = updated
    }
}

import Foundation
import Supabase

@Observable
final class StoryDetailViewModel {

    var story: Story

    init(story: Story) {
        self.story = story
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
            // Generation failed — section will stay hidden silently.
            return
        }

        // Wait for Gemini to finish before refetching (~1-2s generation time).
        try? await Task.sleep(for: .seconds(3))

        guard let updated = try? await StoryRepository.shared.fetchStory(id: story.id) else {
            return
        }
        story = updated
    }
}

import Foundation
import OSLog

@MainActor
@Observable
final class FeedViewModel {

    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var allStories: [Story] = []
    /// Topic tab selected under the header; `.tout` is the unfiltered feed.
    private(set) var topic: StoryTopic = .tout

    private let cacheDuration: TimeInterval = 48 * 60 * 60
    private var lastFetchedAt: Date?
    private let repository: any StoryRepositoryProtocol

    init(repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.repository = repository
    }

    // MARK: - Computed Properties

    // Derived once per load; views read them in `body`, so they must be cheap.
    private(set) var stories: [Story] = []
    private(set) var cetteSemanineHero: Story?
    /// "L'essentiel": the five most-covered stories after the hero.
    private(set) var essentials: [Story] = []
    /// Everything not already shown as the hero or in "L'essentiel", newest first.
    private(set) var feedStories: [Story] = []

    private func rebuild() {
        stories = allStories
            .filter { $0.articles.count >= 2 }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
        let hero = stories.first(where: { $0.isFeatured }) ?? stories.first
        cetteSemanineHero = hero
        essentials = Array(
            stories
                .filter { $0.id != hero?.id }
                .sorted { $0.sources.count > $1.sources.count }
                .prefix(5)
        )
        let used = Set(([hero?.id].compactMap { $0 }) + essentials.map(\.id))
        feedStories = stories.filter { !used.contains($0.id) }
    }

    // MARK: - Load

    func load() async {
        let isFresh = !allStories.isEmpty
            && lastFetchedAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        guard !isFresh else { return }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let page = try await repository.fetchFeed(
                topic: topic.filterValue,
                limit: 30,
                offset: 0
            )
            allStories = page
            rebuild()
            lastFetchedAt = Date()
        } catch {
            Log.feed.error("Load failed: \(error)")
            self.error = AppError.from(error)
        }
        isLoading = false
    }

    /// Switches the topic tab and loads that topic's stories.
    func select(_ newTopic: StoryTopic) async {
        guard newTopic != topic else { return }
        topic = newTopic
        allStories = []
        rebuild()
        lastFetchedAt = nil
        isLoading = false
        await load()
    }

    func refresh() async {
        lastFetchedAt = nil
        isLoading = false
        await load()
    }
}

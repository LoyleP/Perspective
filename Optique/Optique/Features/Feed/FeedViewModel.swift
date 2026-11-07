import Foundation
import OSLog

@MainActor
@Observable
final class FeedViewModel {

    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var allStories: [Story] = []
    /// The topic this page shows; `.tout` is the unfiltered feed.
    let topic: StoryTopic

    /// News moves fast: refetch when the feed is older than this (the server refreshes hourly).
    private let cacheDuration: TimeInterval = 5 * 60
    private var lastFetchedAt: Date?
    private let repository: any StoryRepositoryProtocol

    init(topic: StoryTopic = .tout, repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.topic = topic
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
    /// On "À la une": stories where the political lens says nothing (sport, faits divers…), kept
    /// out of the top of the feed and grouped at the end. Empty on topic tabs.
    private(set) var lighterStories: [Story] = []
    /// Stories covered almost only by one side ("angles morts"), shown on "À la une".
    private(set) var blindspots: [Story] = []

    private func rebuild() {
        stories = allStories
            .filter { $0.articles.count >= 2 }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
        // On the main tab, the lens only leads where it means something.
        let splits = topic == .tout
        let lead = splits ? stories.filter(\.hasPoliticalAngle) : stories
        lighterStories = splits ? stories.filter { !$0.hasPoliticalAngle } : []
        // Hero: today's most covered story with a political angle (featured first), not just the latest.
        let recent = lead.filter { $0.lastUpdatedAt > Date().addingTimeInterval(-24 * 3600) }
        let hero = lead.first(where: \.isFeatured)
            ?? (recent.isEmpty ? lead : recent).max { $0.sources.count < $1.sources.count }
        cetteSemanineHero = hero
        essentials = Array(
            lead
                .filter { $0.id != hero?.id }
                .sorted { $0.sources.count > $1.sources.count }
                .prefix(5)
        )
        let used = Set(([hero?.id].compactMap { $0 }) + essentials.map(\.id))
        blindspots = splits
            ? Array(lead.filter { !used.contains($0.id) && $0.computedCoverage?.blindspotSide != nil }.prefix(6))
            : []
        let shown = used.union(blindspots.map(\.id))
        // The reader's topics (chosen at onboarding or in Réglages) come first among today's stories.
        let preferred = StoryTopic.preferred(from: UserDefaults.standard.string(forKey: "preferredTopics") ?? "")
            .compactMap(\.filterValue)
        let rest = lead.filter { !shown.contains($0.id) }
        let isPreferred: (Story) -> Bool = { story in
            story.lastUpdatedAt > Date().addingTimeInterval(-24 * 3600)
                && preferred.contains { story.topicTags.contains($0) || story.topic == $0 }
        }
        feedStories = splits ? rest.filter(isPreferred) + rest.filter { !isPreferred($0) } : rest
    }

    // MARK: - Load

    func load() async {
        let isFresh = !allStories.isEmpty
            && lastFetchedAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        guard !isFresh else { return }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        // Show the last feed received at once (memory, then disk) while the network catches up.
        if allStories.isEmpty,
           let cached = await repository.cachedFeed(topic: topic.filterValue, limit: 30, offset: 0),
           allStories.isEmpty {
            allStories = cached
            rebuild()
        }
        do {
            let page = try await repository.fetchFeed(topic: topic.filterValue, limit: 30, offset: 0)
            allStories = page
            rebuild()
            lastFetchedAt = Date()
        } catch {
            Log.feed.error("Load failed: \(error)")
            if allStories.isEmpty { self.error = AppError.from(error) }
        }
        isLoading = false
    }

    /// Back from the background: reload if the feed is stale.
    func refreshIfStale() async {
        guard let lastFetchedAt, Date().timeIntervalSince(lastFetchedAt) > cacheDuration else { return }
        await refresh()
    }

    func refresh() async {
        Analytics.track(.feedRefresh)
        lastFetchedAt = nil
        isLoading = false
        await load()
    }
}

import Foundation
import OSLog

@MainActor
@Observable
final class FeedViewModel {

    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var allStories: [Story] = []

    private let cacheDuration: TimeInterval = 48 * 60 * 60
    private var lastFetchedAt: Date?
    private let repository: any StoryRepositoryProtocol

    init(repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.repository = repository
    }

    // MARK: - Computed Properties

    var stories: [Story] {
        allStories
            .filter { $0.articles.count >= 2 }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
    }

    var cetteSemanineHero: Story? {
        stories.first(where: { $0.isFeatured }) ?? stories.first
    }

    var briefStories: [Story] {
        guard let heroID = cetteSemanineHero?.id else { return [] }
        return Array(stories.filter { $0.id != heroID }.prefix(2))
    }

    var feedStories: [Story] {
        let usedIDs = Set([cetteSemanineHero?.id].compactMap { $0 } + briefStories.map { $0.id })
        return stories.filter { !usedIDs.contains($0.id) }
    }

    var aggregateCoverage: CoverageStats? {
        CoverageStats.aggregate(stories.compactMap(\.coverage))
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
                topic: nil,
                limit: 30,
                offset: 0
            )
            allStories = page
            lastFetchedAt = Date()
        } catch {
            Log.feed.error("Load failed: \(error)")
            self.error = AppError.from(error)
        }
        isLoading = false
    }

    func refresh() async {
        lastFetchedAt = nil
        isLoading = false
        await load()
    }
}

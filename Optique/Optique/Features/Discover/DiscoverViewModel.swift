import Foundation
import OSLog

@MainActor
@Observable
final class DiscoverViewModel {

    /// Latest stories, used for topic tiles and blind spots.
    private(set) var stories: [Story] = [] {
        didSet { blindspots = Self.blindspots(in: stories) }
    }
    private(set) var sources: [Source] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    var searchText = ""
    private(set) var searchResults: [Story] = []
    private(set) var isSearching = false

    private let poolSize = 60
    private let searchLimit = 30
    private let cacheDuration: TimeInterval = 30 * 60
    private var lastFetchedAt: Date?
    private let repository: any StoryRepositoryProtocol
    private let sourceRepository: any SourceRepositoryProtocol

    init(
        repository: any StoryRepositoryProtocol = StoryRepository.shared,
        sourceRepository: any SourceRepositoryProtocol = SourceRepository.shared
    ) {
        self.repository = repository
        self.sourceRepository = sourceRepository
    }

    // MARK: - Derived

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stories covered mostly by one side, most-covered first. Worked out when the stories change,
    /// not on every redraw.
    private(set) var blindspots: [Story] = []

    private static func blindspots(in stories: [Story]) -> [Story] {
        Array(
            stories
                .filter { $0.computedCoverage?.blindspotSide != nil }
                .sorted { $0.sources.count > $1.sources.count }
                .prefix(8)
        )
    }

    func stories(in topic: StoryTopic) -> [Story] {
        guard let tag = topic.filterValue else { return stories }
        return stories.filter { $0.topicTags.contains(tag) }
    }

    // MARK: - Loading

    func load() async {
        let isFresh = !stories.isEmpty
            && lastFetchedAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        guard !isFresh, !isLoading else { return }
        isLoading = true
        error = nil
        // Last known stories at once, refreshed from the network behind them.
        if stories.isEmpty, let cached = await repository.cachedFeed(topic: nil, limit: poolSize, offset: 0), stories.isEmpty {
            stories = cached
        }
        if sources.isEmpty, let cached = await sourceRepository.cachedSources(), sources.isEmpty {
            sources = cached
        }
        do {
            stories = try await repository.fetchFeed(topic: nil, limit: poolSize, offset: 0)
            lastFetchedAt = Date()
        } catch {
            Log.feed.error("Discover load failed: \(error)")
            self.error = AppError.from(error)
        }
        if sources.isEmpty {
            sources = (try? await sourceRepository.fetchAllSources()) ?? []
        }
        isLoading = false
    }

    func refresh() async {
        lastFetchedAt = nil
        await load()
    }

    /// Searches headlines server-side. Call from `.task(id: searchText)` for debouncing.
    func search() async {
        let query = trimmedQuery
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await repository.searchStories(query: query, limit: searchLimit)
            guard query == trimmedQuery else { return }
            searchResults = results
        } catch {
            guard !Task.isCancelled else { return }
            Log.feed.error("Search failed: \(error)")
            searchResults = []
        }
    }
}

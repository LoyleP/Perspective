import Foundation

@MainActor
@Observable
final class DiscoverViewModel {
    private(set) var stories: [Story] = []
    var selectedTopics: Set<StoryTopic> = [.tout]
    var searchText: String = ""
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = true
    private(set) var error: AppError?

    private let pageSize = 20
    private var lastFetchedAt: Date?
    private let cacheDuration: TimeInterval = 6 * 60 * 60
    private let repository: any StoryRepositoryProtocol

    init(repository: any StoryRepositoryProtocol = StoryRepository.shared) {
        self.repository = repository
    }

    var filteredStories: [Story] {
        var result: [Story]

        if selectedTopics.contains(.tout) || selectedTopics.isEmpty {
            result = stories
        } else {
            let filters = selectedTopics.compactMap { $0.filterValue }
            if filters.isEmpty {
                result = stories
            } else {
                result = stories.filter { story in
                    filters.contains(where: { story.topicTags.contains($0) })
                }
            }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            result = result.filter { story in
                story.title.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }

        return result.sorted { $0.articles.count > $1.articles.count }
    }

    func toggleTopic(_ topic: StoryTopic) {
        if topic == .tout {
            selectedTopics = [.tout]
        } else {
            selectedTopics.remove(.tout)

            if selectedTopics.contains(topic) {
                selectedTopics.remove(topic)
                if selectedTopics.isEmpty {
                    selectedTopics = [.tout]
                }
            } else {
                selectedTopics.insert(topic)
            }
        }
    }

    func load() async {
        let isFresh = !stories.isEmpty
            && lastFetchedAt.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        guard !isFresh else { return }
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let page = try await repository.fetchFeed(
                topic: nil,
                limit: pageSize,
                offset: 0
            )
            stories = page
            hasMore = page.count == pageSize
            lastFetchedAt = Date()
        } catch {
            self.error = AppError.from(error)
        }
        isLoading = false
    }

    func refresh() async {
        lastFetchedAt = nil
        isLoading = false
        await load()
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let page = try await repository.fetchFeed(
                topic: nil,
                limit: pageSize,
                offset: stories.count
            )
            stories.append(contentsOf: page)
            hasMore = page.count == pageSize
        } catch {
            // Silently stop pagination; existing items remain visible.
        }
        isLoadingMore = false
    }
}

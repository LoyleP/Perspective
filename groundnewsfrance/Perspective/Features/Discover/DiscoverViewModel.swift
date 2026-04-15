import Foundation

@Observable
final class DiscoverViewModel {
    var stories: [Story] = []
    var selectedTopics: Set<StoryTopic> = [.tout]
    var searchText: String = ""
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var error: Error?

    private let pageSize = 20
    private var lastFetchedAt: Date?
    private let cacheDuration: TimeInterval = 6 * 60 * 60

    var filteredStories: [Story] {
        // Step 1: Filter by topic
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

        // Step 2: Filter by search text
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            result = result.filter { story in
                story.title.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }

        // Step 3: Sort by article count (descending)
        return result.sorted { $0.articles.count > $1.articles.count }
    }

    func toggleTopic(_ topic: StoryTopic) {
        if topic == .tout {
            // If selecting "Tout", clear all others
            selectedTopics = [.tout]
        } else {
            // Remove "Tout" if it was selected
            selectedTopics.remove(.tout)

            // Toggle the selected topic
            if selectedTopics.contains(topic) {
                selectedTopics.remove(topic)
                // If nothing left selected, default to "Tout"
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
            let page = try await StoryRepository.shared.fetchFeed(
                topic: nil,
                limit: pageSize,
                offset: 0
            )
            stories = page
            hasMore = page.count == pageSize
            lastFetchedAt = Date()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func refresh() async {
        isLoading = false
        await load()
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let page = try await StoryRepository.shared.fetchFeed(
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

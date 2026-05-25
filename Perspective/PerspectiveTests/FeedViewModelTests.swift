import Testing
import Foundation
@testable import Perspective

@MainActor
@Suite("FeedViewModel")
struct FeedViewModelTests {

    @Test("load fetches stories from repository")
    func loadFetchesStories() async {
        let mock = MockStoryRepository()
        let stories = [TestData.makeStory(), TestData.makeStory(id: UUID())]
        mock.feedResult = .success(stories)

        let vm = FeedViewModel(repository: mock)
        await vm.load()

        #expect(vm.allStories.count == 2)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
        #expect(mock.fetchFeedCallCount == 1)
    }

    @Test("load sets error on failure")
    func loadSetsError() async {
        let mock = MockStoryRepository()
        mock.feedResult = .failure(URLError(.notConnectedToInternet))

        let vm = FeedViewModel(repository: mock)
        await vm.load()

        #expect(vm.allStories.isEmpty)
        #expect(vm.error == .networkUnavailable)
    }

    @Test("load skips fetch when cache is fresh")
    func loadSkipsWhenCacheFresh() async {
        let mock = MockStoryRepository()
        mock.feedResult = .success([TestData.makeStory()])

        let vm = FeedViewModel(repository: mock)
        await vm.load()
        #expect(mock.fetchFeedCallCount == 1)

        await vm.load()
        #expect(mock.fetchFeedCallCount == 1)
    }

    @Test("refresh clears cache and reloads")
    func refreshClearsCacheAndReloads() async {
        let mock = MockStoryRepository()
        mock.feedResult = .success([TestData.makeStory()])

        let vm = FeedViewModel(repository: mock)
        await vm.load()
        #expect(mock.fetchFeedCallCount == 1)

        await vm.refresh()
        #expect(mock.fetchFeedCallCount == 2)
    }

    @Test("stories filters out single-article stories")
    func storiesFiltersMinArticles() async {
        let mock = MockStoryRepository()
        let twoArticles = TestData.makeStory(articleCount: 2)
        let oneArticle = TestData.makeStory(id: UUID(), articleCount: 1)
        mock.feedResult = .success([twoArticles, oneArticle])

        let vm = FeedViewModel(repository: mock)
        await vm.load()

        #expect(vm.stories.count == 1)
        #expect(vm.stories.first?.id == twoArticles.id)
    }

    @Test("cetteSemanineHero prefers featured story")
    func heroPrefersFeatured() async {
        let mock = MockStoryRepository()
        let regular = TestData.makeStory(articleCount: 3, isFeatured: false)
        let featured = TestData.makeStory(id: UUID(), articleCount: 3, isFeatured: true)
        mock.feedResult = .success([regular, featured])

        let vm = FeedViewModel(repository: mock)
        await vm.load()

        #expect(vm.cetteSemanineHero?.id == featured.id)
    }
}

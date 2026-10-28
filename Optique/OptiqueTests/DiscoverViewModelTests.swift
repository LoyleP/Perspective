import Testing
import Foundation
@testable import Optique

@MainActor
@Suite("DiscoverViewModel")
struct DiscoverViewModelTests {

    private func makeViewModel(_ stories: MockStoryRepository) -> DiscoverViewModel {
        DiscoverViewModel(repository: stories, sourceRepository: MockSourceRepository())
    }

    @Test("blindspots keeps stories covered ≥ 80 % by one side with 3+ sources")
    func blindspots() async {
        let mock = MockStoryRepository()
        let leftOnly = TestData.makeStory(title: "Gauche", leans: [1, 2, 3])
        let balanced = TestData.makeStory(title: "Équilibré", leans: [2, 4, 6])
        let tooFew = TestData.makeStory(title: "Peu", leans: [6, 7])
        mock.feedResult = .success([leftOnly, balanced, tooFew])

        let vm = makeViewModel(mock)
        await vm.load()

        #expect(vm.blindspots.map(\.id) == [leftOnly.id])
        #expect(leftOnly.computedCoverage?.blindspotSide == .gauche)
    }

    @Test("stories(in:) filters by topic tag")
    func storiesInTopic() async {
        let mock = MockStoryRepository()
        let tagged = TestData.makeStory(title: "Politique")   // tagged "politique"
        let untagged = TestData.makeStory(title: "Autre", leans: [4])
        mock.feedResult = .success([tagged, untagged])

        let vm = makeViewModel(mock)
        await vm.load()

        #expect(vm.stories(in: .politique).map(\.id) == [tagged.id])
        #expect(vm.stories(in: .sport).isEmpty)
    }

    @Test("search queries the repository and ignores one-letter input")
    func search() async {
        let mock = MockStoryRepository()
        let result = TestData.makeStory(title: "Réforme des retraites")
        mock.searchResult = .success([result])

        let vm = makeViewModel(mock)
        vm.searchText = "r"
        await vm.search()
        #expect(vm.searchResults.isEmpty)
        #expect(mock.lastSearchQuery == nil)

        vm.searchText = "  retraites "
        await vm.search()
        #expect(mock.lastSearchQuery == "retraites")
        #expect(vm.searchResults.map(\.id) == [result.id])
    }

    @Test("load sets error on failure")
    func loadSetsError() async {
        let mock = MockStoryRepository()
        mock.feedResult = .failure(URLError(.notConnectedToInternet))

        let vm = makeViewModel(mock)
        await vm.load()

        #expect(vm.error == .networkUnavailable)
    }
}

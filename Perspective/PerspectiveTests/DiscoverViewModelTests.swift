import Testing
import Foundation
@testable import Perspective

@MainActor
@Suite("DiscoverViewModel")
struct DiscoverViewModelTests {

    @Test("toggleTopic selects and deselects topics")
    func toggleTopicBasic() {
        let vm = DiscoverViewModel()

        #expect(vm.selectedTopics == [.tout])

        vm.toggleTopic(.politique)
        #expect(vm.selectedTopics.contains(.politique))
        #expect(!vm.selectedTopics.contains(.tout))

        vm.toggleTopic(.politique)
        #expect(vm.selectedTopics == [.tout])
    }

    @Test("toggleTopic selecting .tout clears other selections")
    func toggleTopicToutClearsOthers() {
        let vm = DiscoverViewModel()
        vm.toggleTopic(.politique)
        vm.toggleTopic(.economie)

        #expect(vm.selectedTopics.count == 2)

        vm.toggleTopic(.tout)
        #expect(vm.selectedTopics == [.tout])
    }

    @Test("filteredStories filters by search text")
    func filteredStoriesBySearch() async {
        let mock = MockStoryRepository()
        let s1 = TestData.makeStory(title: "Réforme des retraites")
        let s2 = TestData.makeStory(id: UUID(), title: "Intelligence artificielle")
        mock.feedResult = .success([s1, s2])

        let vm = DiscoverViewModel(repository: mock)
        await vm.load()

        vm.searchText = "retraites"
        #expect(vm.filteredStories.count == 1)
        #expect(vm.filteredStories.first?.title.contains("retraites") == true)
    }

    @Test("load sets error on failure")
    func loadSetsError() async {
        let mock = MockStoryRepository()
        mock.feedResult = .failure(URLError(.notConnectedToInternet))

        let vm = DiscoverViewModel(repository: mock)
        await vm.load()

        #expect(vm.error == .networkUnavailable)
    }
}

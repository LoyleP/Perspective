import Testing
import Foundation
@testable import Perspective

@MainActor
@Suite("BookmarkStore")
struct BookmarkStoreTests {

    private func makeStore() -> BookmarkStore {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return BookmarkStore(defaults: defaults)
    }

    @Test("toggle adds and removes story")
    func toggleAddsAndRemoves() {
        let store = makeStore()
        let story = TestData.makeStory()

        store.toggle(story)
        #expect(store.isBookmarked(story))
        #expect(store.stories.count == 1)

        store.toggle(story)
        #expect(!store.isBookmarked(story))
        #expect(store.stories.isEmpty)
    }

    @Test("isBookmarked returns false for unknown story")
    func isBookmarkedReturnsFalse() {
        let store = makeStore()
        let story = TestData.makeStory()

        #expect(!store.isBookmarked(story))
    }

    @Test("toggle inserts at beginning")
    func toggleInsertsAtBeginning() {
        let store = makeStore()
        let s1 = TestData.makeStory(id: UUID(), title: "First")
        let s2 = TestData.makeStory(id: UUID(), title: "Second")

        store.toggle(s1)
        store.toggle(s2)

        #expect(store.stories.first?.title == "Second")
    }
}

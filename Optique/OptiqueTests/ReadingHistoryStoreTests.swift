import Testing
import Foundation
@testable import Optique

@MainActor
@Suite("ReadingHistoryStore")
struct ReadingHistoryStoreTests {

    private func makeStore() -> ReadingHistoryStore {
        let suite = "reading-history-\(UUID().uuidString)"
        let file = FileManager.default.temporaryDirectory.appending(path: "\(suite).json")
        return ReadingHistoryStore(defaults: UserDefaults(suiteName: suite)!, storiesURL: file)
    }

    @Test("recordOpen keeps the most recent first without duplicates")
    func recordOpenOrdersAndDedupes() {
        let store = makeStore()
        let a = TestData.makeStory(title: "A", leans: [2])
        let b = TestData.makeStory(title: "B", leans: [6])

        store.recordOpen(a)
        store.recordOpen(b)
        store.recordOpen(a)

        #expect(store.stories.map(\.id) == [a.id, b.id])
    }

    @Test("leans are capped at the 500 most recent")
    func leansAreCapped() {
        let store = makeStore()
        for _ in 0..<510 { store.record(lean: 2) }
        store.record(lean: 6)

        #expect(store.leans.count == 500)
        #expect(store.leans.last == 6)
    }

    @Test("insight reflects the dominant side once there are enough reads")
    func insight() {
        let store = makeStore()
        store.record(lean: 1)
        #expect(store.insight == "Lisez quelques articles pour découvrir votre spectre")

        for lean in [1, 2, 2, 3, 6] { store.record(lean: lean) }
        #expect(store.insight == "Vous lisez surtout à gauche")
    }

    @Test("reset clears leans and stories")
    func reset() {
        let store = makeStore()
        store.record(lean: 4)
        store.recordOpen(TestData.makeStory(title: "A", leans: [4]))

        store.reset()

        #expect(store.leans.isEmpty)
        #expect(store.stories.isEmpty)
    }
}

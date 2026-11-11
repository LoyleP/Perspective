import Testing
import Foundation
@testable import Optique

@MainActor
@Suite("SessionState free topics", .serialized)
struct SessionStateTests {

    private func makeSession() -> SessionState {
        UserDefaults.standard.removeObject(forKey: "freeTopicsDay")
        UserDefaults.standard.removeObject(forKey: "freeTopicsOpened")
        UserDefaults.standard.set(false, forKey: "devIsPremium")
        return SessionState()
    }

    private var limit: Int { AppConfig.freeStoriesPerDay }

    @Test("the first topics are free and counted in order")
    func freeInOrder() {
        let session = makeSession()
        for index in 0..<limit {
            #expect(session.admit(UUID()) == .free(position: index, isNew: true))
        }
        #expect(session.storiesOpened == limit)
        #expect(session.remainingFree == 0)
    }

    @Test("the topic after the allowance is locked, and is not counted")
    func lockedAfterLimit() {
        let session = makeSession()
        for _ in 0..<limit { session.admit(UUID()) }
        let extra = UUID()
        #expect(session.access(for: extra) == .locked)
        #expect(session.admit(extra) == .locked)
        #expect(session.storiesOpened == limit)
        #expect(session.isLocked(extra))
    }

    @Test("a free topic stays free when opened again, even after the allowance is used up")
    func reopenStaysFree() {
        let session = makeSession()
        let ids = (0..<limit).map { _ in UUID() }
        ids.forEach { session.admit($0) }
        for (index, id) in ids.enumerated() {
            #expect(session.access(for: id) == .free(position: index, isNew: false))
            #expect(!session.isLocked(id))
        }
        #expect(session.storiesOpened == limit)
    }

    @Test("a locked topic stays locked when opened again")
    func lockedStaysLocked() {
        let session = makeSession()
        for _ in 0..<limit { session.admit(UUID()) }
        let extra = UUID()
        session.admit(extra)
        #expect(session.admit(extra) == .locked)
        #expect(session.isLocked(extra))
    }

    @Test("peeking at a topic never changes the count")
    func peekingIsPure() {
        let session = makeSession()
        let id = UUID()
        for _ in 0..<10 { _ = session.access(for: id) }
        #expect(session.storiesOpened == 0)
    }

    @Test("the last free topic is the one at position limit - 1")
    func lastFreePosition() {
        let session = makeSession()
        for _ in 0..<(limit - 1) { session.admit(UUID()) }
        #expect(session.admit(UUID()) == .free(position: limit - 1, isNew: true))
    }

    @Test("old saved lists longer than the allowance still lock the extra topics")
    func oldLongList() {
        UserDefaults.standard.set(SessionState.dayStringForTests, forKey: "freeTopicsDay")
        let ids = (0..<(limit + 3)).map { _ in UUID() }
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: "freeTopicsOpened")
        UserDefaults.standard.set(false, forKey: "devIsPremium")
        let session = SessionState()
        #expect(!session.isLocked(ids[limit - 1]))
        #expect(session.isLocked(ids[limit]))
        #expect(session.isLocked(ids[limit + 2]))
    }

    @Test("Optique+ is never limited")
    func premiumUnlimited() {
        let session = makeSession()
        session.setTestPremium(true)
        defer { session.setTestPremium(false) }
        for _ in 0..<(limit + 2) { #expect(session.admit(UUID()) == .unlimited) }
        #expect(session.storiesOpened == 0)
    }
}

import Foundation

/// Reading allowance for the freemium model: a free reader opens `AppConfig.freeStoriesPerSession`
/// different topics per session (not persisted between launches); Optique+ lifts the limit.
@MainActor
@Observable
final class SessionState {

    /// Topics opened this session, in the order they were first opened.
    private(set) var openedStories: [UUID] = []
    let storeManager = StoreManager()

    /// Test versions: Réglages can switch between the free and the Optique+ view of the app.
    var testPremium: Bool {
        didSet { UserDefaults.standard.set(testPremium, forKey: "devIsPremium") }
    }

    init() {
        testPremium = UserDefaults.standard.bool(forKey: "devIsPremium")
    }

    var isPremium: Bool { testPremium || storeManager.isPremium }

    var freeLimit: Int { AppConfig.freeStoriesPerSession }
    var storiesOpened: Int { openedStories.count }

    /// Free topics left, never below zero.
    var remainingFree: Int { max(freeLimit - openedStories.count, 0) }

    /// True once this topic is past the free allowance: it opens as a preview only.
    func isLocked(_ id: UUID) -> Bool {
        guard AppConfig.paywallEnabled, !isPremium else { return false }
        // A topic not opened yet is free while there is allowance left.
        if let index = openedStories.firstIndex(of: id) { return index >= freeLimit }
        return openedStories.count >= freeLimit
    }

    func registerOpen(_ id: UUID) {
        guard !openedStories.contains(id) else { return }
        openedStories.append(id)
    }

    func resetCounter() { openedStories.removeAll() }

    /// Debug: uses up the free allowance, so the next topic opens locked.
    func fillCounter() {
        while openedStories.count < freeLimit { openedStories.append(UUID()) }
    }
}

import Foundation

// Tracks per-session story opens for the soft paywall gate.
// Not persisted between launches (PRD: "compteur in-memory").
@Observable
final class SessionState {
    var storiesOpened = 0
    var isPremium: Bool

    init() {
        #if DEBUG
        isPremium = UserDefaults.standard.bool(forKey: "devIsPremium")
        #else
        isPremium = false
        #endif
    }

    var shouldShowPaywall: Bool {
        !isPremium && storiesOpened >= 5
    }

    func recordStoryOpen() {
        storiesOpened += 1
    }
}

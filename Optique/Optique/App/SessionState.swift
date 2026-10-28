import Foundation

// Tracks per-session story opens for the soft paywall gate.
// Not persisted between launches (PRD: "compteur in-memory").
@MainActor
@Observable
final class SessionState {
    var storiesOpened = 0
    let storeManager = StoreManager()

    var isPremium: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "devIsPremium") || storeManager.isPremium
        #else
        return storeManager.isPremium
        #endif
    }

    var shouldShowPaywall: Bool {
        !isPremium && storiesOpened >= 5
    }

    func recordStoryOpen() {
        storiesOpened += 1
    }
}

import Foundation

/// Reading allowance for the freemium model: a free reader opens `AppConfig.freeStoriesPerDay`
/// different topics per day (the counter is kept between launches and starts again at midnight,
/// device time); Optique+ lifts the limit.
@MainActor
@Observable
final class SessionState {

    private static let dayKey = "freeTopicsDay"
    private static let idsKey = "freeTopicsOpened"

    /// Topics opened on `day`, in the order they were first opened.
    private var openedToday: [UUID] = []
    private var day: String = SessionState.today
    let storeManager = StoreManager()

    /// Test versions: Réglages can switch between the free and the Optique+ view of the app.
    var testPremium: Bool {
        didSet { UserDefaults.standard.set(testPremium, forKey: "devIsPremium") }
    }

    init() {
        testPremium = UserDefaults.standard.bool(forKey: "devIsPremium")
        let defaults = UserDefaults.standard
        day = defaults.string(forKey: Self.dayKey) ?? Self.today
        openedToday = (defaults.stringArray(forKey: Self.idsKey) ?? []).compactMap(UUID.init(uuidString:))
    }

    private static var today: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// The topics opened today: empty once the day has changed, even if the app stayed open.
    private var opened: [UUID] { day == Self.today ? openedToday : [] }

    var isPremium: Bool { testPremium || storeManager.isPremium }

    var freeLimit: Int { AppConfig.freeStoriesPerDay }
    var storiesOpened: Int { opened.count }

    /// Free topics left today, never below zero.
    var remainingFree: Int { max(freeLimit - opened.count, 0) }

    /// True once this topic is past the free allowance: it opens as a preview only.
    func isLocked(_ id: UUID) -> Bool {
        guard AppConfig.paywallEnabled, !isPremium else { return false }
        // A topic not opened yet is free while there is allowance left.
        if let index = opened.firstIndex(of: id) { return index >= freeLimit }
        return opened.count >= freeLimit
    }

    func registerOpen(_ id: UUID) {
        rollOverIfNeeded()
        guard !openedToday.contains(id) else { return }
        openedToday.append(id)
        save()
    }

    func resetCounter() {
        openedToday.removeAll()
        day = Self.today
        save()
    }

    /// Debug: uses up the free allowance, so the next topic opens locked.
    func fillCounter() {
        rollOverIfNeeded()
        while openedToday.count < freeLimit { openedToday.append(UUID()) }
        save()
    }

    private func rollOverIfNeeded() {
        guard day != Self.today else { return }
        day = Self.today
        openedToday = []
    }

    private func save() {
        UserDefaults.standard.set(day, forKey: Self.dayKey)
        UserDefaults.standard.set(openedToday.map(\.uuidString), forKey: Self.idsKey)
    }
}

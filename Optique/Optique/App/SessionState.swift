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
    private(set) var testPremium: Bool

    func setTestPremium(_ value: Bool) {
        testPremium = value
        UserDefaults.standard.set(value, forKey: "devIsPremium")
    }

    init() {
        testPremium = UserDefaults.standard.bool(forKey: "devIsPremium")
        let defaults = UserDefaults.standard
        day = defaults.string(forKey: Self.dayKey) ?? Self.today
        openedToday = (defaults.stringArray(forKey: Self.idsKey) ?? []).compactMap(UUID.init(uuidString:))
    }

    /// Today's key as stored, for tests.
    static var dayStringForTests: String { today }

    private static var today: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// The topics opened today: empty once the day has changed, even if the app stayed open.
    /// Only the first `freeLimit` ever count: a topic is free if and only if it is among them.
    private var opened: [UUID] { day == Self.today ? Array(openedToday.prefix(freeLimit)) : [] }

    var isPremium: Bool { testPremium || storeManager.isPremium }

    var freeLimit: Int { AppConfig.freeStoriesPerDay }
    var storiesOpened: Int { opened.count }

    /// Free topics left today, never below zero.
    var remainingFree: Int { max(freeLimit - opened.count, 0) }

    /// What a reader gets on one topic. Decided once, when the topic is opened, and kept for as long as it stays open
    /// (see `admit`), so the lock and the "last free topic" badge always agree.
    enum Access: Equatable {
        /// No limit applies (Optique+, or the paywall is switched off).
        case unlimited
        /// One of today's free topics. `position` is 0-based; `isNew` is true the first time it is opened today.
        case free(position: Int, isNew: Bool)
        /// Past the allowance: only a preview.
        case locked

        var isLocked: Bool { self == .locked }
    }

    /// What opening `id` would give right now. Changes nothing, so a view can call it for its first frame.
    func access(for id: UUID) -> Access {
        guard AppConfig.paywallEnabled, !isPremium else { return .unlimited }
        let list = opened
        if let index = list.firstIndex(of: id) { return .free(position: index, isNew: false) }
        return list.count < freeLimit ? .free(position: list.count, isNew: true) : .locked
    }

    /// Opens `id`: counts it if it is a new free topic, and returns the access it was given. A locked topic is
    /// never counted, so the list never holds more than `freeLimit` topics and re-opening a topic is always
    /// answered the same way for the rest of the day.
    @discardableResult
    func admit(_ id: UUID) -> Access {
        rollOverIfNeeded()
        let result = access(for: id)
        if case .free(_, true) = result {
            openedToday = Array(openedToday.prefix(freeLimit))
            openedToday.append(id)
            save()
        }
        return result
    }

    /// True once this topic is past the free allowance: it opens as a preview only.
    func isLocked(_ id: UUID) -> Bool { access(for: id).isLocked }

    /// Counts a topic as opened (same as `admit`, for callers that don't need the answer).
    func registerOpen(_ id: UUID) { admit(id) }

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

    func rollOverIfNeeded() {
        guard day != Self.today else { return }
        day = Self.today
        openedToday = []
    }

    private func save() {
        UserDefaults.standard.set(day, forKey: Self.dayKey)
        UserDefaults.standard.set(openedToday.map(\.uuidString), forKey: Self.idsKey)
    }
}

import Foundation

@MainActor
@Observable
final class ReadingHistoryStore {

    private let storageKey = "readingHistory"
    private let defaults: UserDefaults
    private(set) var leans: [Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.leans = defaults.array(forKey: "readingHistory") as? [Int] ?? []
    }

    func record(lean: Int) {
        leans.append(lean)
        defaults.set(leans, forKey: storageKey)
    }

    func reset() {
        leans = []
        defaults.removeObject(forKey: storageKey)
    }

    var breakdown: [(lean: PoliticalLean, count: Int)] {
        (1...7).compactMap { leanInt in
            let count = leans.filter { $0 == leanInt }.count
            guard count > 0, let lean = PoliticalLean.from(leanInt) else { return nil }
            return (lean: lean, count: count)
        }
        .sorted { $0.count > $1.count }
    }
}

import Foundation

/// What the user reads: the lean of every article opened in the reader (for the
/// reading spectrum) and the stories they opened (for the history list).
@MainActor
@Observable
final class ReadingHistoryStore {

    private let leansKey = "readingHistory"
    private let maxLeans = 500
    private let maxStories = 50
    private let defaults: UserDefaults
    private let storiesURL: URL

    /// Leans (1–7) of the most recent articles read, oldest first.
    private(set) var leans: [Int]
    /// Stories opened, most recent first.
    private(set) var stories: [Story] = []

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(
        defaults: UserDefaults = .standard,
        storiesURL: URL = URL.applicationSupportDirectory.appending(path: "reading-history.json")
    ) {
        self.defaults = defaults
        self.storiesURL = storiesURL
        self.leans = Array((defaults.array(forKey: leansKey) as? [Int] ?? []).suffix(maxLeans))
        if let data = try? Data(contentsOf: storiesURL),
           let decoded = try? Self.decoder.decode([Story].self, from: data) {
            stories = decoded
        }
    }

    // MARK: - Recording

    func record(lean: Int) {
        leans.append(lean)
        if leans.count > maxLeans { leans.removeFirst(leans.count - maxLeans) }
        defaults.set(leans, forKey: leansKey)
    }

    func recordOpen(_ story: Story) {
        stories.removeAll { $0.id == story.id }
        stories.insert(story, at: 0)
        if stories.count > maxStories { stories.removeLast(stories.count - maxStories) }
        saveStories()
    }

    func remove(_ story: Story) {
        stories.removeAll { $0.id == story.id }
        saveStories()
    }

    func reset() {
        leans = []
        stories = []
        defaults.removeObject(forKey: leansKey)
        try? FileManager.default.removeItem(at: storiesURL)
    }

    private func saveStories() {
        guard let data = try? Self.encoder.encode(stories) else { return }
        try? FileManager.default.createDirectory(
            at: storiesURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storiesURL, options: .atomic)
    }

    // MARK: - Derived

    var breakdown: [(lean: PoliticalLean, count: Int)] {
        (1...7).compactMap { leanInt in
            let count = leans.filter { $0 == leanInt }.count
            guard count > 0, let lean = PoliticalLean.from(leanInt) else { return nil }
            return (lean: lean, count: count)
        }
        .sorted { $0.count > $1.count }
    }

    /// Reading spread as coverage stats, so it can reuse the spectrum components.
    var coverage: CoverageStats? {
        var counts = [Int](repeating: 0, count: 7)
        for lean in leans where (1...7).contains(lean) { counts[lean - 1] += 1 }
        return CoverageStats.from(storyID: UUID(), counts: counts)
    }

    /// One-line reading of the spread, e.g. "Vous lisez surtout à gauche".
    var insight: String {
        guard let coverage, coverage.totalCount >= 5 else {
            return "Lisez quelques articles pour découvrir votre spectre"
        }
        if coverage.centreShare >= 0.5 { return "Vous lisez surtout le centre" }
        let gap = coverage.leftShare - coverage.rightShare
        if abs(gap) < 0.15 { return "Vous lisez des deux bords" }
        return gap > 0 ? "Vous lisez surtout à gauche" : "Vous lisez surtout à droite"
    }
}

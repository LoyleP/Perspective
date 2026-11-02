import Foundation

// MARK: - Spectrum summary models

struct SpectrumPerspective: Codable, Hashable, Identifiable {
    var id: String { String(lean.rawValue) }
    let lean: PoliticalLean
    let summary: String
    let sourceCount: Int

    enum CodingKeys: String, CodingKey {
        case lean
        case summary
        case sourceCount = "source_count"
    }

    private static let leanStringMap: [String: PoliticalLean] = [
        "extreme_gauche": .extremeGauche,
        "gauche":         .gauche,
        "centre_gauche":  .gauche,
        "centre":         .centre,
        "centre_droite":  .droite,
        "droite":         .droite,
        "extreme_droite": .extremeDroite,
    ]

    private static let leanStringReverseMap: [Int: String] = [
        PoliticalLean.extremeGauche.rawValue:  "extreme_gauche",
        PoliticalLean.gauche.rawValue:         "gauche",
        PoliticalLean.centre.rawValue:         "centre",
        PoliticalLean.droite.rawValue:         "droite",
        PoliticalLean.extremeDroite.rawValue:  "extreme_droite",
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let leanString = try container.decode(String.self, forKey: .lean)
        guard let resolved = Self.leanStringMap[leanString] else {
            throw DecodingError.dataCorruptedError(
                forKey: .lean, in: container,
                debugDescription: "Unknown lean string: \(leanString)"
            )
        }
        lean        = resolved
        // Gemini sometimes returns summary as an array of bullet strings
        if let str = try? container.decode(String.self, forKey: .summary) {
            summary = str
        } else {
            let parts = try container.decode([String].self, forKey: .summary)
            summary = parts.joined(separator: " ")
        }
        sourceCount = try container.decode(Int.self,    forKey: .sourceCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.leanStringReverseMap[lean.rawValue] ?? "", forKey: .lean)
        try container.encode(summary,     forKey: .summary)
        try container.encode(sourceCount, forKey: .sourceCount)
    }
}

struct SpectrumSummary: Codable, Hashable {
    let generatedAt: Date
    let perspectives: [SpectrumPerspective]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case perspectives
    }
}

// MARK: - Story

struct Story: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String?
    let firstPublishedAt: Date
    let lastUpdatedAt: Date
    let topicTags: [String]
    let isFeatured: Bool
    let createdAt: Date
    let updatedAt: Date

    // Populated by the API
    let articles: [Article]

    // story_coverage_view is now a table with FK, so PostgREST returns a single object
    let coverage: CoverageStats?

    let spectrumSummary: SpectrumSummary?
    let summaryGeneratedAt: Date?

    /// One plain sentence on what happened, written ahead of time by the refresh (nil until then).
    let dek: String?
    /// Topic and whether the political lens means anything for this story (nil = not classified yet).
    let topic: String?
    let isPolitical: Bool?

    // Derived once at init: views read these in `body` on every scroll/tab update.
    let computedCoverage: CoverageStats?
    let sources: [Source]
    let leadImageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case firstPublishedAt  = "first_published_at"
        case lastUpdatedAt     = "last_updated_at"
        case topicTags         = "topic_tags"
        case isFeatured        = "is_featured"
        case createdAt         = "created_at"
        case updatedAt         = "updated_at"
        case articles
        case coverage          = "story_coverage_view"
        case spectrumSummary   = "spectrum_summary"
        case summaryGeneratedAt = "summary_generated_at"
        case dek
        case topic
        case isPolitical = "is_political"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = Self.cleanedTitle(try container.decode(String.self, forKey: .title))
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        firstPublishedAt = try container.decode(Date.self, forKey: .firstPublishedAt)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        topicTags = try container.decode([String].self, forKey: .topicTags)
        isFeatured = try container.decode(Bool.self, forKey: .isFeatured)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Filter articles to only primary ones
        let allArticles = try container.decode([Article].self, forKey: .articles)
        articles = allArticles.filter { $0.isPrimary }

        coverage = try container.decodeIfPresent(CoverageStats.self, forKey: .coverage)
        spectrumSummary = try container.decodeIfPresent(SpectrumSummary.self, forKey: .spectrumSummary)
        summaryGeneratedAt = try container.decodeIfPresent(Date.self, forKey: .summaryGeneratedAt)
        dek = try container.decodeIfPresent(String.self, forKey: .dek).flatMap { $0.isEmpty ? nil : Self.cleanedTitle($0) }
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        isPolitical = try container.decodeIfPresent(Bool.self, forKey: .isPolitical)
        (computedCoverage, sources, leadImageURL) = Self.derive(id: id, articles: articles, coverage: coverage)
    }

    init(
        id: UUID,
        title: String,
        summary: String?,
        firstPublishedAt: Date,
        lastUpdatedAt: Date,
        topicTags: [String],
        isFeatured: Bool,
        createdAt: Date,
        updatedAt: Date,
        articles: [Article],
        coverage: CoverageStats?,
        spectrumSummary: SpectrumSummary?,
        summaryGeneratedAt: Date?,
        dek: String? = nil,
        topic: String? = nil,
        isPolitical: Bool? = nil
    ) {
        self.id = id
        self.title = Self.cleanedTitle(title)
        self.summary = summary
        self.firstPublishedAt = firstPublishedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.topicTags = topicTags
        self.isFeatured = isFeatured
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.articles = articles
        self.coverage = coverage
        self.spectrumSummary = spectrumSummary
        self.summaryGeneratedAt = summaryGeneratedAt
        self.dek = dek
        self.topic = topic
        self.isPolitical = isPolitical
        (computedCoverage, self.sources, leadImageURL) = Self.derive(id: id, articles: articles, coverage: coverage)
    }

    var sourceCount: Int { articles.count }

    /// The line under the title: the written dek, else the story's own summary.
    var standfirst: String? { dek ?? summary.flatMap { $0.isEmpty ? nil : $0 } }

    /// Whether the left/right lens says something about this story (sport, faits divers… don't).
    /// Unclassified stories fall back to their topic tags.
    var hasPoliticalAngle: Bool {
        if let isPolitical { return isPolitical }
        return !topicTags.contains("sport") && !topicTags.contains("culture")
    }

    /// Titles not rewritten yet can come in lowercase: always start with a capital.
    private static func cleanedTitle(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return t }
        return first.uppercased() + t.dropFirst()
    }

    // Coverage derived from the analyzed articles' source leans. Preferred over
    // the joined `coverage` (story_coverage_view), which can be stale and skew
    // the spectrum. Falls back to the view only when no article carries a lean.
    private static func derive(id: UUID, articles: [Article], coverage: CoverageStats?)
        -> (CoverageStats?, [Source], URL?) {
        var seen = Set<UUID>()
        let sources = articles
            .compactMap(\.source)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.politicalLean < $1.politicalLean }
        let lead = articles.lazy.compactMap { $0.imageURL.flatMap(URL.init) }.first
        return (CoverageStats.from(storyID: id, articles: articles) ?? coverage, sources, lead)
    }

    // Identity + the fields that change after load; hashing every article is needlessly slow.
    static func == (a: Story, b: Story) -> Bool {
        a.id == b.id && a.summary == b.summary && a.lastUpdatedAt == b.lastUpdatedAt
            && a.articles.count == b.articles.count && a.spectrumSummary == b.spectrumSummary
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Presentation helpers

extension Story {
    /// "il y a 2 h" (cards: the source logos already show who covers it)
    var timeLine: String { lastUpdatedAt.relativeToNowFrench() }

    /// "8 sources · il y a 2 h"
    var metaLine: String {
        let count = sources.count == 1 ? "1 source" : "\(sources.count) sources"
        return "\(count) · \(lastUpdatedAt.relativeToNowFrench())"
    }
}

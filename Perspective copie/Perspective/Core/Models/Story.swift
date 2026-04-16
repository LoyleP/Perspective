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
        "centre_gauche":  .centreGauche,
        "centre":         .centre,
        "centre_droite":  .centreDroite,
        "droite":         .droite,
        "extreme_droite": .extremeDroite,
    ]

    private static let leanStringReverseMap: [Int: String] = [
        PoliticalLean.extremeGauche.rawValue:  "extreme_gauche",
        PoliticalLean.gauche.rawValue:         "gauche",
        PoliticalLean.centreGauche.rawValue:   "centre_gauche",
        PoliticalLean.centre.rawValue:         "centre",
        PoliticalLean.centreDroite.rawValue:   "centre_droite",
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
        summary     = try container.decode(String.self, forKey: .summary)
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

    // Populated via Supabase join
    let articles: [Article]

    // story_coverage_view is now a table with FK, so PostgREST returns a single object
    let coverage: CoverageStats?

    let spectrumSummary: SpectrumSummary?
    let summaryGeneratedAt: Date?

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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
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
        summaryGeneratedAt: Date?
    ) {
        self.id = id
        self.title = title
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
    }

    var sourceCount: Int { articles.count }
}

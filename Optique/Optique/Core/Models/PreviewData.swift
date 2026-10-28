#if DEBUG
import Foundation

// MARK: - SpectrumPerspective preview init
// SpectrumPerspective only exposes init(from:) so we add a direct init here.
extension SpectrumPerspective {
    init(lean: PoliticalLean, summary: String, sourceCount: Int) {
        self.lean = lean
        self.summary = summary
        self.sourceCount = sourceCount
    }
}

// MARK: - Mock data

enum PreviewData {

    static let storyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // MARK: Sources

    static let leMonde = Source(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "Le Monde",
        url: "https://lemonde.fr",
        rssURL: "https://lemonde.fr/rss",
        logoURL: nil,
        politicalLean: 4,
        ownerName: "Le Monde Groupe",
        ownerNotes: "Propriété du groupe Le Monde.",
        ownerType: .billionaire,
        isActive: true,
        createdAt: .now,
        updatedAt: .now
    )

    static let leFigaro = Source(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "Le Figaro",
        url: "https://lefigaro.fr",
        rssURL: "https://lefigaro.fr/rss",
        logoURL: nil,
        politicalLean: 6,
        ownerName: "Groupe Dassault",
        ownerNotes: "Appartient à la famille Dassault.",
        ownerType: .billionaire,
        isActive: true,
        createdAt: .now,
        updatedAt: .now
    )

    static let liberation = Source(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        name: "Libération",
        url: "https://liberation.fr",
        rssURL: "https://liberation.fr/rss",
        logoURL: nil,
        politicalLean: 2,
        ownerName: nil,
        ownerNotes: nil,
        ownerType: .pressGroup,
        isActive: true,
        createdAt: .now,
        updatedAt: .now
    )

    // MARK: Articles

    static let article1 = Article(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        sourceID: leMonde.id,
        title: "La réforme des retraites suscite des débats intenses au Parlement",
        url: "https://lemonde.fr/article-test",
        summary: "Le Parlement examine le projet de loi sur les retraites cette semaine.",
        imageURL: nil,
        publishedAt: Date(timeIntervalSinceNow: -3600),
        fetchedAt: .now,
        storyID: storyID,
        rawKeywords: ["retraites", "parlement"],
        clickCount: 12,
        isPrimary: true,
        createdAt: .now,
        updatedAt: .now,
        source: leMonde
    )

    static let article2 = Article(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
        sourceID: leFigaro.id,
        title: "Retraites : le gouvernement défend sa réforme face à l'opposition",
        url: "https://lefigaro.fr/article-test",
        summary: "Le Premier ministre a réaffirmé sa volonté de mener la réforme à son terme.",
        imageURL: nil,
        publishedAt: Date(timeIntervalSinceNow: -7200),
        fetchedAt: .now,
        storyID: storyID,
        rawKeywords: ["retraites", "gouvernement"],
        clickCount: 8,
        isPrimary: true,
        createdAt: .now,
        updatedAt: .now,
        source: leFigaro
    )

    static let article3 = Article(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
        sourceID: liberation.id,
        title: "Contre la réforme des retraites, les syndicats appellent à la mobilisation nationale",
        url: "https://liberation.fr/article-test",
        summary: "Les principales centrales syndicales ont annoncé une nouvelle journée de grève.",
        imageURL: nil,
        publishedAt: Date(timeIntervalSinceNow: -1800),
        fetchedAt: .now,
        storyID: storyID,
        rawKeywords: ["retraites", "syndicats", "grève"],
        clickCount: 21,
        isPrimary: true,
        createdAt: .now,
        updatedAt: .now,
        source: liberation
    )

    // MARK: Coverage

    static let coverage = CoverageStats(
        storyID: storyID,
        lean1Count: 1,
        lean2Count: 2,
        lean3Count: 1,
        lean4Count: 2,
        lean5Count: 1,
        lean6Count: 2,
        lean7Count: 1,
        totalCount: 10,
        lean1Pct: 0.10,
        lean2Pct: 0.20,
        lean3Pct: 0.10,
        lean4Pct: 0.20,
        lean5Pct: 0.10,
        lean6Pct: 0.20,
        lean7Pct: 0.10
    )

    // MARK: Spectrum summary

    static let spectrumSummary = SpectrumSummary(
        generatedAt: .now,
        perspectives: [
            SpectrumPerspective(
                lean: .gauche,
                summary: "Les syndicats dénoncent une attaque contre le modèle social français\nLes travailleurs du secteur public sont particulièrement mobilisés\nLes partis de gauche réclament le retrait immédiat du texte",
                sourceCount: 1
            ),
            SpectrumPerspective(
                lean: .centre,
                summary: "Le gouvernement insiste sur la nécessité d'équilibrer le système\nLes économistes sont partagés sur l'impact à long terme",
                sourceCount: 1
            ),
            SpectrumPerspective(
                lean: .droite,
                summary: "La réforme est présentée comme inévitable face aux déficits prévisionnels\nLes marchés financiers saluent la rigueur budgétaire affichée",
                sourceCount: 1
            ),
        ]
    )

    // MARK: Stories

    static let story = Story(
        id: storyID,
        title: "Réforme des retraites : le bras de fer entre gouvernement et syndicats",
        summary: "Alors que le gouvernement s'apprête à présenter son projet de réforme, les syndicats appellent à la mobilisation et les partis d'opposition affûtent leurs arguments.",
        firstPublishedAt: Date(timeIntervalSinceNow: -86400),
        lastUpdatedAt: .now,
        topicTags: ["politique", "économie", "social"],
        isFeatured: true,
        createdAt: .now,
        updatedAt: .now,
        articles: [article1, article2, article3],
        coverage: coverage,
        spectrumSummary: spectrumSummary,
        summaryGeneratedAt: .now
    )

    static let storyMinimal = Story(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Intelligence artificielle : la France investit dans la souveraineté numérique",
        summary: nil,
        firstPublishedAt: Date(timeIntervalSinceNow: -43200),
        lastUpdatedAt: .now,
        topicTags: ["technologie"],
        isFeatured: false,
        createdAt: .now,
        updatedAt: .now,
        articles: [article1],
        coverage: nil,
        spectrumSummary: nil,
        summaryGeneratedAt: nil
    )
}
#endif

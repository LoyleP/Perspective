#if DEBUG
import Foundation

/// Offline sample data for SwiftUI previews and the `--screen` debug launcher.
///
/// Active in Xcode previews, or when the app is launched with `--fixtures`
/// (implied by `--screen`). In that mode the repositories and notification fetch return
/// this data instead of calling the API; `--state loading|empty|error` forces that state.
enum Fixtures {

    enum State: String {
        case normal, loading, empty, error
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--fixtures")
            || ProcessInfo.processInfo.arguments.contains("--screen")
    }

    static var state: State {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--state"), index + 1 < args.count else { return .normal }
        return State(rawValue: args[index + 1]) ?? .normal
    }

    /// Returns `items` honouring the forced state: never returns for `.loading`,
    /// throws for `.error`, returns `[]` for `.empty`.
    static func apply<T>(_ items: [T]) async throws -> [T] {
        switch state {
        case .normal: return items
        case .empty: return []
        case .error: throw URLError(.notConnectedToInternet)
        case .loading:
            try await Task.sleep(for: .seconds(3600))
            return items
        }
    }

    // MARK: Sources

    static func source(_ name: String, lean: Int, owner: String? = nil, type: OwnerType? = nil) -> Source {
        Source(
            id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", abs(name.hashValue) % 1_000_000_000))!,
            name: name,
            url: "https://example.com/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            rssURL: "https://example.com/rss",
            logoURL: nil,
            politicalLean: lean,
            ownerName: owner,
            ownerNotes: owner == nil ? nil : "Propriété d'après les données publiques, mise à jour manuellement.",
            ownerType: type,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )
    }

    static let sources: [Source] = [
        source("L'Humanité", lean: 1, type: .cooperative),
        source("Reporterre", lean: 1, type: .nonprofit),
        source("Libération", lean: 2, owner: "Altice / Patrick Drahi", type: .billionaire),
        source("Mediapart", lean: 2, type: .independent),
        source("Le Monde", lean: 3, owner: "Xavier Niel, Matthieu Pigasse", type: .billionaire),
        source("Le Nouvel Obs", lean: 3, type: .privateOwned),
        source("France Info", lean: 4, owner: "France Télévisions", type: .publicMedia),
        source("20 Minutes", lean: 4, owner: "Groupe Rossel", type: .pressGroup),
        source("BFM TV", lean: 5, owner: "Altice / Patrick Drahi", type: .billionaire),
        source("Le Parisien", lean: 5, owner: "LVMH / Bernard Arnault", type: .billionaire),
        source("Le Figaro", lean: 6, owner: "Dassault", type: .privateConglomerate),
        source("Valeurs Actuelles", lean: 7, type: .privateOwned)
    ]

    // MARK: Stories

    private static func story(
        _ title: String,
        leans: [Int],
        hoursAgo: Double,
        tags: [String] = ["politique"],
        featured: Bool = false,
        summary: Bool = false
    ) -> Story {
        let id = UUID()
        var used = Set<UUID>()
        let articles: [Article] = leans.enumerated().compactMap { index, lean in
            let pool = sources.filter { $0.politicalLean == lean && !used.contains($0.id) }
            guard let source = pool.first else { return nil }
            used.insert(source.id)
            return Article(
                id: UUID(),
                sourceID: source.id,
                title: "\(title) — vu par \(source.name)",
                url: "https://example.com/\(id)/\(index)",
                summary: nil,
                imageURL: nil,
                publishedAt: Date(timeIntervalSinceNow: -hoursAgo * 3600 - Double(index) * 600),
                fetchedAt: .now,
                storyID: id,
                rawKeywords: [],
                clickCount: 0,
                isPrimary: true,
                createdAt: .now,
                updatedAt: .now,
                source: source
            )
        }
        return Story(
            id: id,
            title: title,
            summary: nil,
            firstPublishedAt: Date(timeIntervalSinceNow: -hoursAgo * 3600 - 7200),
            lastUpdatedAt: Date(timeIntervalSinceNow: -hoursAgo * 3600),
            topicTags: tags,
            isFeatured: featured,
            createdAt: .now,
            updatedAt: .now,
            articles: articles,
            coverage: nil,
            spectrumSummary: summary ? PreviewData.spectrumSummary : nil,
            summaryGeneratedAt: summary ? .now : nil
        )
    }

    static let stories: [Story] = [
        story("Réforme des retraites : le bras de fer entre gouvernement et syndicats",
              leans: [1, 2, 3, 4, 4, 5, 6, 7], hoursAgo: 1, featured: true, summary: true),
        story("Collision entre deux trains en Espagne : au moins trente morts",
              leans: [2, 3, 4, 4, 5, 5], hoursAgo: 2, tags: ["international"], summary: true),
        story("Le taux de chômage augmente de 0,9 % au troisième trimestre, une hausse de 2,1 % sur un an",
              leans: [2, 4, 5, 6], hoursAgo: 3, tags: ["economie"]),
        story("Présidentielle 2027 : Édouard Philippe doublé par Jean-Luc Mélenchon dans un sondage qui bouscule la droite et divise la gauche sur la stratégie à adopter",
              leans: [1, 2, 4, 6, 7], hoursAgo: 5),
        story("Un nouveau texte sur la sécurité adopté au Sénat",
              leans: [5, 6, 7], hoursAgo: 6, tags: ["justice"]),
        story("Une aide jusqu'à 10 000 euros pour les commerçants touchés",
              leans: [1, 2, 3], hoursAgo: 8, tags: ["economie"]),
        story("Coupe de France : le tirage au sort du 7e tour",
              leans: [4, 5], hoursAgo: 9, tags: ["sport"]),
        story("Festival de Cannes : la sélection officielle dévoilée",
              leans: [3, 4, 4, 5], hoursAgo: 12, tags: ["culture"]),
        story("Canicule : vigilance orange dans douze départements",
              leans: [2, 3, 4, 5, 5], hoursAgo: 14, tags: ["environnement"]),
        story("Un seul média en parle",
              leans: [4], hoursAgo: 20, tags: ["societe"])
    ]

    // MARK: Notifications

    static var notifications: [PushNotification] {
        stories.prefix(5).enumerated().map { index, story in
            let counts = (1...7).map { lean in story.articles.filter { $0.source?.politicalLean == lean }.count }
            return PushNotification(
                id: UUID(),
                title: story.title,
                body: "\(story.sources.count) sources • nouvelle actualité",
                storyCount: 1,
                storyId: story.id,
                sentAt: Date(timeIntervalSinceNow: -Double(index) * 5 * 3600),
                createdAt: .now,
                leanCounts: counts
            )
        }
    }
}
#endif

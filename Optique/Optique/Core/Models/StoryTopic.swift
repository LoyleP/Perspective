import Foundation

enum StoryTopic: String, CaseIterable, Identifiable {
    case tout          = "Tout"
    case politique     = "Politique"
    case economie      = "Économie"
    case societe       = "Société"
    case international = "International"
    case environnement = "Environnement"
    case justice       = "Justice"
    case culture       = "Culture"
    case sport         = "Sport"

    var id: String { rawValue }

    // Value sent to the API topic filter; nil means no filter.
    var filterValue: String? {
        switch self {
        case .tout:          return nil
        case .politique:     return "politique"
        case .economie:      return "economie"
        case .societe:       return "societe"
        case .international: return "international"
        case .environnement: return "environnement"
        case .justice:       return "justice"
        case .culture:       return "culture"
        case .sport:         return "sport"
        }
    }

    /// Heroicon name (see `HeroIcon`).
    var heroIcon: String {
        switch self {
        case .tout:          return "squares-2x2"
        case .politique:     return "building-library"
        case .economie:      return "arrow-trending-up"
        case .societe:       return "users"
        case .international: return "globe-europe-africa"
        case .environnement: return "sun"
        case .justice:       return "scale"
        case .culture:       return "film"
        case .sport:         return "trophy"
        }
    }

    /// Topics a user can pick (everything but "Tout").
    static var selectable: [StoryTopic] { allCases.filter { $0 != .tout } }

    /// Parses the comma-separated `preferredTopics` setting.
    static func preferred(from raw: String) -> Set<StoryTopic> {
        Set(raw.split(separator: ",").compactMap { value in
            selectable.first { $0.filterValue == String(value) }
        })
    }

    /// Serialises topics for the `preferredTopics` setting.
    static func storageValue(_ topics: Set<StoryTopic>) -> String {
        selectable.filter(topics.contains).compactMap(\.filterValue).joined(separator: ",")
    }
}

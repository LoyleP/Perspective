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

    var id: String { rawValue }

    // Value sent to Supabase contains() filter; nil means no filter.
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
        }
    }
}

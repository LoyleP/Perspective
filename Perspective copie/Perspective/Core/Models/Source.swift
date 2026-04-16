import Foundation
import SwiftUI
import UIKit

enum OwnerType: String, Codable {
    case billionaire = "billionaire"
    case publicMedia = "public"
    case stateOwned = "state_owned"
    case independent = "independent"
    case pressGroup  = "press_group"
    case privateConglomerate = "private_conglomerate"
    case cooperative = "cooperative"
    case nonprofit = "nonprofit"
    case privateOwned = "private"
    case unknown     = "unknown"

    var displayName: String {
        switch self {
        case .billionaire: return "Milliardaires"
        case .publicMedia: return "Public"
        case .stateOwned: return "État"
        case .independent: return "Indépendants"
        case .pressGroup:  return "Groupes de presse"
        case .privateConglomerate: return "Conglomérat privé"
        case .cooperative: return "Coopérative"
        case .nonprofit: return "À but non lucratif"
        case .privateOwned: return "Privé"
        case .unknown:     return "Inconnu"
        }
    }

    var color: Color {
        switch self {
        case .billionaire:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 212/255, green: 148/255, blue: 74/255, alpha: 1)
                    : UIColor(red: 201/255, green: 135/255, blue: 58/255, alpha: 1)
            })
        case .publicMedia, .stateOwned:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 102/255, green: 153/255, blue: 221/255, alpha: 1)
                    : UIColor(red: 74/255, green: 127/255, blue: 193/255, alpha: 1)
            })
        case .independent:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 90/255, green: 174/255, blue: 123/255, alpha: 1)
                    : UIColor(red: 74/255, green: 158/255, blue: 107/255, alpha: 1)
            })
        case .pressGroup:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 150/255, green: 136/255, blue: 196/255, alpha: 1)
                    : UIColor(red: 123/255, green: 111/255, blue: 171/255, alpha: 1)
            })
        case .privateConglomerate:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 220/255, green: 120/255, blue: 95/255, alpha: 1)
                    : UIColor(red: 200/255, green: 100/255, blue: 75/255, alpha: 1)
            })
        case .cooperative:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 120/255, green: 190/255, blue: 140/255, alpha: 1)
                    : UIColor(red: 100/255, green: 170/255, blue: 120/255, alpha: 1)
            })
        case .nonprofit:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 95/255, green: 160/255, blue: 130/255, alpha: 1)
                    : UIColor(red: 75/255, green: 140/255, blue: 110/255, alpha: 1)
            })
        case .privateOwned:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 190/255, green: 110/255, blue: 85/255, alpha: 1)
                    : UIColor(red: 170/255, green: 90/255, blue: 65/255, alpha: 1)
            })
        case .unknown:
            return Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 181/255, green: 181/255, blue: 181/255, alpha: 1)
                    : UIColor(red: 161/255, green: 161/255, blue: 161/255, alpha: 1)
            })
        }
    }
}

struct Source: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: String
    let rssURL: String
    let logoURL: String?
    let politicalLean: Int
    let ownerName: String?
    let ownerNotes: String?
    let ownerType: OwnerType?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    var lean: PoliticalLean? { PoliticalLean.from(politicalLean) }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case rssURL        = "rss_url"
        case logoURL       = "logo_url"
        case politicalLean = "political_lean"
        case ownerName     = "owner_name"
        case ownerNotes    = "owner_notes"
        case ownerType     = "owner_type"
        case isActive      = "is_active"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }
}

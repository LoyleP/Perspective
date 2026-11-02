import Foundation

/// One reading (or final stage) of a law's path through Parliament, e.g. "1re lecture" at the Sénat.
struct LawStep: Codable, Hashable, Identifiable {
    var id: String { code }
    /// Source code: AN1, SN1, AN2, CMP, CC, PROM…
    let code: String
    /// AN, SN, CMP, CC or GVT (promulgation).
    let chamber: String
    let label: String
    let startedAt: String?
    /// Where the reading stands: depot, commission, seance, vote (or done for promulgation).
    let stage: String
    /// "adopté", "modifié", "rejeté"… once the chamber has voted.
    let decision: String?
    let commissionAt: String?
    let debateAt: String?
    let decidedAt: String?
    /// Official title and Légifrance link once promulgated.
    let lawTitle: String?
    let url: String?

    /// "Assemblée", "Sénat", …
    var place: String {
        switch chamber {
        case "AN": return "Assemblée"
        case "SN": return "Sénat"
        case "CMP": return "Députés et sénateurs"
        case "CC": return "Conseil constitutionnel"
        case "GVT": return "Journal officiel"
        default: return chamber
        }
    }

    var isRejected: Bool { decision?.lowercased().hasPrefix("rejet") ?? false }
}

struct Law: Codable, Hashable, Identifiable {
    var id: String { uid }
    let uid: String
    let title: String
    let shortTitle: String?
    /// "Projet de loi" (government) or "Proposition de loi" (members).
    let kind: String?
    let status: String?
    let state: String?
    let accelerated: Bool
    let depositedAt: Date?
    let lastActAt: Date?
    let steps: [LawStep]
    let summary: String?
    let storyCount: Int?
    let senatUrl: String?
    /// Generic stages still to come ("1re lecture · Sénat", "Promulgation"…).
    let upcoming: [String]
    /// Present on the detail endpoint only.
    let stories: [Story]?

    enum CodingKeys: String, CodingKey {
        case uid, title, kind, status, state, accelerated, steps, summary, upcoming, stories
        case shortTitle = "short_title"
        case depositedAt = "deposited_at"
        case lastActAt = "last_act_at"
        case storyCount = "story_count"
        case senatUrl = "senat_url"
    }

    var displayTitle: String {
        let raw = shortTitle?.isEmpty == false ? shortTitle! : title
        guard let first = raw.first else { return raw }
        return first.uppercased() + raw.dropFirst()
    }

    var current: LawStep? { steps.last }
    var isPromulgated: Bool { steps.contains { $0.code == "PROM" } }

    var assembleeURL: URL? { URL(string: "https://www.assemblee-nationale.fr/dyn/17/dossiers/\(uid)") }

    /// "Projet de loi · procédure accélérée"
    var kindLine: String {
        [kind ?? "Texte", accelerated ? "procédure accélérée" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}

struct LawsPage: Decodable {
    let checkedAt: Date?
    let laws: [Law]

    enum CodingKeys: String, CodingKey {
        case laws
        case checkedAt = "checked_at"
    }
}

import Foundation

/// Plain-language wording for where a law stands and what each stage means.
enum LawExplainer {

    /// "Sénat · 1re lecture · en commission · 28 oct. 2026"
    static func status(of law: Law) -> String {
        guard let step = law.current else { return law.status ?? "" }
        if law.isPromulgated { return "Promulguée · \(LawDates.short(step.startedAt) ?? "")" }
        var parts = [step.place, step.label]
        switch step.stage {
        case "commission": parts.append("en commission")
        case "seance": parts.append("en séance publique")
        case "vote": if let decision = step.decision { parts.append(decision) }
        default: parts.append("déposé")
        }
        if let date = LawDates.short(step.decidedAt ?? step.debateAt ?? step.commissionAt ?? step.startedAt) {
            parts.append(date)
        }
        return parts.joined(separator: " · ")
    }

    /// What is happening now, in one or two sentences.
    static func now(for law: Law) -> String {
        guard let step = law.current else { return "Le texte vient d'être déposé." }
        let members = step.chamber == "SN" ? "les sénateurs" : "les députés"
        switch step.code {
        case "CMP":
            return "Les deux chambres ne sont pas d'accord : sept députés et sept sénateurs cherchent une version commune du texte."
        case "CC":
            return "Le Conseil constitutionnel vérifie que la loi respecte la Constitution avant qu'elle puisse s'appliquer."
        case "PROM":
            return "La loi a été promulguée et publiée au Journal officiel : elle s'applique désormais."
        default:
            break
        }
        switch step.stage {
        case "commission":
            return "Une commission de \(step.chamber == "SN" ? "sénateurs" : "députés") étudie le texte, l'amende et prépare le débat. C'est souvent là que se jouent les modifications."
        case "seance":
            return "Le texte est débattu dans l'hémicycle : \(members) examinent chaque article et votent les amendements."
        case "vote":
            let decision = step.decision ?? "voté"
            return "\(step.place) a voté : texte \(decision). " + (step.isRejected
                ? "Le texte peut repartir dans l'autre chambre ou s'arrêter là."
                : "Il passe maintenant à l'étape suivante.")
        default:
            return "Le texte vient d'être déposé \(step.chamber == "SN" ? "au Sénat" : "à l'Assemblée") ; il sera d'abord examiné en commission."
        }
    }

    /// The four moments of a reading, with the index of the current one.
    static let readingStages = ["Dépôt", "Commission", "Séance", "Vote"]

    static func readingIndex(_ step: LawStep) -> Int {
        switch step.stage {
        case "commission": return 1
        case "seance": return 2
        case "vote", "done": return 3
        default: return 0
        }
    }
}

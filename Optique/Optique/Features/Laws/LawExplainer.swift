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

    private static func article(_ chamber: String) -> String { chamber == "SN" ? "le Sénat" : "l'Assemblée" }

    /// The status in one plain sentence, e.g. "Le Sénat étudie le texte".
    static func headline(for law: Law) -> String {
        guard let step = law.current else { return "Texte déposé" }
        let who = article(step.chamber)
        let Who = who.prefix(1).uppercased() + who.dropFirst()
        switch step.code {
        case "PROM": return "Loi promulguée"
        case "CC": return "Le Conseil constitutionnel vérifie le texte"
        case "CMP": return "Députés et sénateurs cherchent un accord"
        default: break
        }
        switch step.stage {
        case "commission": return "\(Who) étudie le texte"
        case "seance": return "Débat en cours à \(step.chamber == "SN" ? "au Sénat" : "l'Assemblée")".replacingOccurrences(of: "à au", with: "au")
        case "vote":
            let verb = step.isRejected ? "Rejeté" : (step.decision?.lowercased().hasPrefix("modif") == true ? "Modifié" : "Adopté")
            return "\(verb) par \(who)"
        default: return "Déposé \(step.chamber == "SN" ? "au Sénat" : "à l'Assemblée")"
        }
    }

    /// What comes next, in plain words.
    static func next(for law: Law) -> String? {
        guard let step = law.current, !law.isPromulgated else { return nil }
        switch step.code {
        case "CMP": return "Les deux chambres revotent la version commune"
        case "CC": return "Promulgation"
        default: break
        }
        switch step.stage {
        case "depot": return "Examen en commission"
        case "commission": return "Débat dans l'hémicycle"
        case "seance": return "Vote"
        default:
            guard let first = law.upcoming.first else { return nil }
            if first.hasPrefix("1re lecture · ") {
                return "Examen par \(first.contains("Sénat") ? "le Sénat" : "l'Assemblée")"
            }
            if first == "Adoption définitive" { return "Vote d'un texte identique dans les deux chambres" }
            return first
        }
    }

    /// The four stages of the simple bar, and how many are reached.
    static let progressStages = ["Déposé", "Voté par une chambre", "Voté par les deux", "Loi"]

    /// Where the law stands on the four-segment bar after each of its steps, in segment units (0…4).
    /// Segment 1 ("Déposé") is full once a text exists; the first reading fills segment 2; every later
    /// step before the Conseil constitutionnel / promulgation shares segment 3 equally (so a law with
    /// several readings divides that segment into as many parts); the Conseil constitutionnel and
    /// the promulgation share segment 4. The step in progress counts partially.
    static func positions(of law: Law) -> [Double] {
        let steps = law.steps
        let isReading: (LawStep) -> Bool = { $0.code.hasPrefix("AN") || $0.code.hasPrefix("SN") }
        let firstReading = steps.firstIndex(where: isReading)
        let finals = steps.indices.filter { steps[$0].code == "CC" || steps[$0].code == "PROM" }
        let middle = steps.indices.filter { $0 != firstReading && !finals.contains($0) }

        /// How far through its own stage a step is (0…1).
        func fraction(_ step: LawStep) -> Double {
            if step.code == "CC" || step.code == "PROM" || step.code == "CMP" { return step.stage == "vote" || step.code == "PROM" ? 1 : 0.5 }
            switch step.stage {
            case "commission": return 0.25
            case "seance": return 0.55
            case "vote", "done": return 1
            default: return 0
            }
        }

        return steps.indices.map { index in
            let step = steps[index]
            if index == firstReading { return 1 + fraction(step) }
            if let k = middle.firstIndex(of: index) {
                let n = Double(middle.count)
                return 2 + (Double(k) + fraction(step)) / n
            }
            // CC then PROM share the last segment.
            let slots = Double(finals.count)
            let k = Double(finals.firstIndex(of: index) ?? 0)
            return 3 + (k + (step.code == "PROM" ? 1 : fraction(step))) / max(slots, 1)
        }
    }

    /// Position of the law as a whole (its latest step).
    static func progressPosition(of law: Law) -> Double {
        if law.isPromulgated { return 4 }
        return positions(of: law).last ?? 1
    }

    static func progress(of law: Law) -> Int { Int(progressPosition(of: law)) }

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

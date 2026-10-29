import SwiftUI

// French political spectrum in 5 positions. Raw values keep the stored 1–7 scale: the former
// "centre-gauche" (3) is folded into gauche and "centre-droite" (5) into droite.
// Convention: red = left, neutral gray = centre, blue = right
enum PoliticalLean: Int, Codable, CaseIterable, Identifiable {
    case extremeGauche   = 1
    case gauche          = 2
    case centre          = 4
    case droite          = 6
    case extremeDroite   = 7

    var id: Int { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        guard let value = PoliticalLean.from(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown PoliticalLean rawValue: \(raw)"
            )
        }
        self = value
    }

    var label: String {
        switch self {
        case .extremeGauche:  return "Extrême-gauche"
        case .gauche:         return "Gauche"
        case .centre:         return "Centre"
        case .droite:         return "Droite"
        case .extremeDroite:  return "Extrême-droite"
        }
    }

    var shortLabel: String {
        switch self {
        case .extremeGauche:  return "E. gauche"
        case .gauche:         return "Gauche"
        case .centre:         return "Centre"
        case .droite:         return "Droite"
        case .extremeDroite:  return "E. droite"
        }
    }

    // Readable text on a solid `spectrumColor` fill (≥ 4.5:1 in both themes).
    var tagTextColor: Color {
        switch self {
        case .extremeGauche, .extremeDroite:
            return .white
        case .gauche, .droite:
            return Color(light: "FFFFFF", dark: "000000")
        case .centre:
            return .black
        }
    }

    var spectrumColor: Color {
        switch self {
        case .extremeGauche: return AppColors.Spectrum.eGauche
        case .gauche:        return AppColors.Spectrum.gauche
        case .centre:        return AppColors.Spectrum.centre
        case .droite:        return AppColors.Spectrum.droite
        case .extremeDroite: return AppColors.Spectrum.eDroite
        }
    }

    // Kept as an alias so existing call sites keep working; the app is dark-only.
    var color: Color { spectrumColor }

    /// Single-letter-ish code for tight spaces (spectrum axis, logo badges).
    var code: String {
        switch self {
        case .extremeGauche: return "EG"
        case .gauche:        return "G"
        case .centre:        return "C"
        case .droite:        return "D"
        case .extremeDroite: return "ED"
        }
    }

    /// Maps a stored 1–7 position to one of the 5 positions (3 → gauche, 5 → droite).
    static func from(_ rawValue: Int) -> PoliticalLean? {
        switch rawValue {
        case 3: return .gauche
        case 5: return .droite
        default: return PoliticalLean(rawValue: rawValue)
        }
    }
}

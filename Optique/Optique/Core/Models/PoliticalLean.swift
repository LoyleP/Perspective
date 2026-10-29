import SwiftUI

// French political spectrum — 1 (extrême-gauche) to 7 (extrême-droite)
// Convention: red = left, neutral gray = centre, blue = right
enum PoliticalLean: Int, Codable, CaseIterable, Identifiable {
    case extremeGauche   = 1
    case gauche          = 2
    case centreGauche    = 3
    case centre          = 4
    case centreDroite    = 5
    case droite          = 6
    case extremeDroite   = 7

    var id: Int { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        guard let value = PoliticalLean(rawValue: raw) else {
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
        case .centreGauche:   return "Centre-gauche"
        case .centre:         return "Centre"
        case .centreDroite:   return "Centre-droite"
        case .droite:         return "Droite"
        case .extremeDroite:  return "Extrême-droite"
        }
    }

    var shortLabel: String {
        switch self {
        case .extremeGauche:  return "E. gauche"
        case .gauche:         return "Gauche"
        case .centreGauche:   return "C. gauche"
        case .centre:         return "Centre"
        case .centreDroite:   return "C. droite"
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
        case .centreGauche, .centre, .centreDroite:
            return .black
        }
    }

    var spectrumColor: Color {
        switch self {
        case .extremeGauche: return AppColors.Spectrum.eGauche
        case .gauche:        return AppColors.Spectrum.gauche
        case .centreGauche:  return AppColors.Spectrum.centreGauche
        case .centre:        return AppColors.Spectrum.centre
        case .centreDroite:  return AppColors.Spectrum.centreDroite
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
        case .centreGauche:  return "CG"
        case .centre:        return "C"
        case .centreDroite:  return "CD"
        case .droite:        return "D"
        case .extremeDroite: return "ED"
        }
    }

    static func from(_ rawValue: Int) -> PoliticalLean? {
        PoliticalLean(rawValue: rawValue)
    }
}

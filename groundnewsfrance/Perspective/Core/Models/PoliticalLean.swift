import SwiftUI
import UIKit

// French political spectrum — 1 (extrême-gauche) to 7 (extrême-droite)
// Convention: red = left, neutral gray = centre, blue = right
// Colors defined as adaptive UIColor trait collections per HIG (light + dark variants)
// and exposed as SwiftUI Color for use in views.
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

    // Exact Figma token colors (non-adaptive). Used for tag backgrounds.
    var tagTextColor: Color {
        switch self {
        case .centre:                    return AppColors.Neutral.n700
        case .centreGauche, .centreDroite: return AppColors.Neutral.n200
        default:                         return AppColors.Neutral.n200
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

    // Adaptive colors: vivid in light mode, slightly softened in dark mode
    // to maintain legibility on dark backgrounds (HIG §Color).
    var color: Color {
        Color(uiColor: adaptiveUIColor)
    }

    // Colors sourced from Figma / Perspective / Variables (node 141:805).
    // centreGauche/centreDroite: interpolated between their neighbours.
    // Dark mode: all values brightened ~20% for legibility on dark backgrounds.
    private var adaptiveUIColor: UIColor {
        switch self {
        case .extremeGauche:
            // spectrum/e-gauche: #7b2222
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.64, green: 0.24, blue: 0.24, alpha: 1)
                : UIColor(red: 0.48, green: 0.13, blue: 0.13, alpha: 1) }
        case .gauche:
            // spectrum/gauche: #c0392b
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.90, green: 0.35, blue: 0.27, alpha: 1)
                : UIColor(red: 0.75, green: 0.22, blue: 0.17, alpha: 1) }
        case .centreGauche:
            // spectrum/centre-gauche: #CC6666 — muted rose between gauche and centre
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.88, green: 0.47, blue: 0.47, alpha: 1)
                : UIColor(red: 0.80, green: 0.40, blue: 0.40, alpha: 1) }
        case .centre:
            // spectrum/centre: #ffffff (white)
            // Dark mode uses neutral mid-gray for legibility.
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1)
                : UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1) }
        case .centreDroite:
            // spectrum/centre-droite: #5577BB — muted steel-blue between centre and droite
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.40, green: 0.53, blue: 0.80, alpha: 1)
                : UIColor(red: 0.33, green: 0.47, blue: 0.73, alpha: 1) }
        case .droite:
            // spectrum/droite: #2e4a8b
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.38, green: 0.55, blue: 0.85, alpha: 1)
                : UIColor(red: 0.18, green: 0.29, blue: 0.55, alpha: 1) }
        case .extremeDroite:
            // spectrum/e-droite: #131e45
            return UIColor { t in t.userInterfaceStyle == .dark
                ? UIColor(red: 0.24, green: 0.35, blue: 0.60, alpha: 1)
                : UIColor(red: 0.07, green: 0.12, blue: 0.27, alpha: 1) }
        }
    }

    static func from(_ rawValue: Int) -> PoliticalLean? {
        PoliticalLean(rawValue: rawValue)
    }
}

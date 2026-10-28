import SwiftUI

// MARK: - Colors
// Source: Figma / Perspective / Variables (node 141:805)

enum AppColors {

    // Dark-first ink scale. The app is permanently dark (image-led direction).
    enum Neutral {
        static let n50  = Color(hex: "F5F5F4")
        static let n100 = Color(hex: "E7E7E5")
        static let n200 = Color(hex: "D4D4D2")
        static let n300 = Color(hex: "B4B4B1")
        static let n400 = Color(hex: "8E8E8B")
        static let n500 = Color(hex: "6B6B69")
        static let n600 = Color(hex: "4A4A49")
        static let n700 = Color(hex: "2E2E2F")
        static let n800 = Color(hex: "202022")
        static let n900 = Color(hex: "151517")
        static let n950 = Color(hex: "0A0A0B")
    }

    // 7-step diverging scale: red (left) → neutral → blue (right).
    // Lightness is symmetric (outer ≈ dark, middle ≈ mid, inner ≈ light) so the
    // distance from the centre also reads without hue. Every step is ≥ 3:1 on n950.
    enum Spectrum {
        static let eGauche      = Color(hex: "C2272D")
        static let gauche       = Color(hex: "EF5A5F")
        static let centreGauche = Color(hex: "F5A3A6")
        static let centre       = Color(hex: "B5B5BA")
        static let centreDroite = Color(hex: "A3BEFA")
        static let droite       = Color(hex: "4F86F7")
        static let eDroite      = Color(hex: "2D55D8")
    }

    // Brand accent: warm amber, deliberately neither red nor blue so it never
    // reads as a political position.
    enum Brand {
        static let accent     = Color(hex: "FFB547")
        static let accentSoft = Color(hex: "FFB547").opacity(0.16)
    }

    // Global stroke — white @ 8%
    static let stroke = Color.white.opacity(0.08)
}

// MARK: - Spacing
// Source: Figma / Perspective / Variables (node 141:874)
// 9-step 4pt grid. Figma didn't expose raw values — using PRD scale.

enum AppSpacing {
    static let xs:   CGFloat = 4
    static let s:    CGFloat = 8
    static let st:   CGFloat = 12
    static let m:    CGFloat = 16
    static let ml:   CGFloat = 20
    static let l:    CGFloat = 24
    static let xl:   CGFloat = 32
    static let xxl:  CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radii
// Source: Figma / Perspective / Variables (node 141:849)

enum AppRadius {
    static let xs:   CGFloat = 4
    static let s:    CGFloat = 6
    static let st:   CGFloat = 8
    static let m:    CGFloat = 10
    static let ml:   CGFloat = 12
    static let l:    CGFloat = 16
    static let xl:   CGFloat = 20
    static let pill: CGFloat = 9999
}

// MARK: - Color(hex:) helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

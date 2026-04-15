import SwiftUI

// MARK: - Colors
// Source: Figma / Perspective / Variables (node 141:805)

enum AppColors {

    enum Neutral {
        static let n50  = Color(hex: "fafafa")
        static let n100 = Color(hex: "f5f5f5")
        static let n200 = Color(hex: "e5e5e5")
        static let n300 = Color(hex: "d4d4d4")
        static let n400 = Color(hex: "a1a1a1")
        static let n500 = Color(hex: "737373")
        static let n600 = Color(hex: "525252")
        static let n700 = Color(hex: "404040")
        static let n800 = Color(hex: "262626")
        static let n900 = Color(hex: "171717")
        static let n950 = Color(hex: "0a0a0a")
    }

    enum Spectrum {
        static let eGauche      = Color(hex: "963636")
        static let gauche       = Color(hex: "D96559")
        static let centreGauche = Color(hex: "ECACAC")
        // centre = white per Figma; note: invisible as a tag tint on light bg
        static let centre       = Color(hex: "ffffff")
        static let centreDroite = Color(hex: "ECACAC")
        static let droite       = Color(hex: "4778E9")
        static let eDroite      = Color(hex: "2C46A0")
    }

    // Global stroke — rgba(255,255,255,0.08)
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

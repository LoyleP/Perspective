import SwiftUI
import UIKit

// MARK: - Colors
// Source: Figma / Perspective / Variables (node 141:805)

enum AppColors {

    /// Fixed greys, used only to build the adaptive tokens below.
    enum Neutral {
        static let n50  = Color(hex: "F5F5F5")
        static let n100 = Color(hex: "EAEAEA")
        static let n200 = Color(hex: "D0D0D0")
        static let n300 = Color(hex: "A0A0A0")
        static let n400 = Color(hex: "8E8E8E")
        static let n500 = Color(hex: "757575")
        static let n600 = Color(hex: "6B6B6B")
        static let n700 = Color(hex: "404040")
        static let n800 = Color(hex: "262626")
        static let n900 = Color(hex: "111111")
        static let n950 = Color(hex: "000000")
    }

    /// 7-step diverging scale: red (left) → grey → blue (right). The only color in the app.
    /// Each step has a dark-theme and a light-theme value so it stays ≥ 3:1 on its background.
    enum Spectrum {
        static let eGauche      = Color(light: "A81F26", dark: "C2272D")
        static let gauche       = Color(light: "D9383F", dark: "EF5A5F")
        static let centreGauche = Color(light: "DE6A70", dark: "F5A3A6")
        static let centre       = Color(light: "86868C", dark: "B5B5BA")
        static let centreDroite = Color(light: "6B93E8", dark: "A3BEFA")
        static let droite       = Color(light: "3A6FE0", dark: "4F86F7")
        static let eDroite      = Color(light: "2442B8", dark: "2D55D8")
    }

    /// There is no brand color: emphasis is ink (black on white, white on black).
    /// `accent` is that ink, `onInk` the inverse for text on ink fills, `onImage` for text over photos.
    enum Brand {
        static let accent     = Color(light: "000000", dark: "FFFFFF")
        static let accentSoft = Color(light: "1A000000", dark: "24FFFFFF")
        static let onInk      = Color(light: "FFFFFF", dark: "000000")
        static let onImage    = Color.white
    }

    // Global stroke
    static let stroke = Color(light: "14000000", dark: "1AFFFFFF")
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
    /// Color that switches between two hex values with the interface style.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

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

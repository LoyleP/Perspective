import SwiftUI
import UIKit

// MARK: - Colors
// Source: Figma / Perspective / Variables (node 141:805)

enum AppColors {

    /// Tailwind CSS Zinc scale (v3/v4 values). Every grey in the UI comes from here; semantic tokens
    /// below pick steps for each theme. The lean (spectrum) colors are not part of it.
    enum Zinc {
        static let z50  = Color(hex: "FAFAFA")
        static let z100 = Color(hex: "F4F4F5")
        static let z200 = Color(hex: "E4E4E7")
        static let z300 = Color(hex: "D4D4D8")
        static let z400 = Color(hex: "A1A1AA")
        static let z500 = Color(hex: "71717A")
        static let z600 = Color(hex: "52525B")
        static let z700 = Color(hex: "3F3F46")
        static let z800 = Color(hex: "27272A")
        static let z900 = Color(hex: "18181B")
        static let z950 = Color(hex: "09090B")

        /// Hex strings, for tokens that switch between themes (`Color(light:dark:)`).
        enum Hex {
            static let z50 = "FAFAFA", z100 = "F4F4F5", z200 = "E4E4E7", z300 = "D4D4D8", z400 = "A1A1AA"
            static let z500 = "71717A", z600 = "52525B", z700 = "3F3F46", z800 = "27272A", z900 = "18181B"
            static let z950 = "09090B"
        }
    }

    /// 5-step diverging scale: red (left) → grey → blue (right). The only color in the app.
    /// Each step has a dark-theme and a light-theme value so it stays ≥ 3:1 on its background.
    enum Spectrum {
        static let eGauche      = Color(light: "A81F26", dark: "C2272D")
        static let gauche       = Color(light: "D9383F", dark: "EF5A5F")
        static let centre       = Color(light: "86868C", dark: "B5B5BA")
        static let droite       = Color(light: "3A6FE0", dark: "4F86F7")
        static let eDroite      = Color(light: "2442B8", dark: "2D55D8")
    }

    /// There is no brand color: emphasis is ink (zinc-950 on white, zinc-50 on zinc-950).
    /// `accent` is that ink, `onInk` the inverse for text on ink fills, `onImage` for text over photos.
    enum Brand {
        static let accent     = Color(light: Zinc.Hex.z950, dark: Zinc.Hex.z50)
        static let accentSoft = Color(light: "1A09090B", dark: "24FAFAFA")
        static let onInk      = Color(light: Zinc.Hex.z50, dark: Zinc.Hex.z950)
        static let onImage    = Color.white
    }

    // Global stroke
    static let stroke = Color(light: "1409090B", dark: "1AFAFAFA")
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
    static let xs:   CGFloat = 2
    static let s:    CGFloat = 4
    static let st:   CGFloat = 6
    static let m:    CGFloat = 8
    static let ml:   CGFloat = 10
    static let l:    CGFloat = 12
    static let xl:   CGFloat = 16
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

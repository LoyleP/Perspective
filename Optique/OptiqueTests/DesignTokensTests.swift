import Testing
import UIKit
import SwiftUI
@testable import Optique

/// The grey scale is Tailwind's Zinc; the lean (spectrum) colors are deliberately left alone.
@Suite("Design tokens")
struct DesignTokensTests {

    private func hex(_ color: Color, dark: Bool) -> String {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    private func luminance(_ hex: String) -> Double {
        let value = Int(hex, radix: 16) ?? 0
        let channels = [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF].map { c -> Double in
            let v = Double(c) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private func contrast(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test("Zinc scale matches Tailwind")
    func zincScale() {
        let expected = ["FAFAFA", "F4F4F5", "E4E4E7", "D4D4D8", "A1A1AA", "71717A", "52525B", "3F3F46", "27272A", "18181B", "09090B"]
        typealias Z = AppColors.Zinc
        let actual = [Z.z50, Z.z100, Z.z200, Z.z300, Z.z400, Z.z500, Z.z600, Z.z700, Z.z800, Z.z900, Z.z950]
            .map { hex($0, dark: false) }
        #expect(actual == expected)
    }

    @Test("Semantic tokens use Zinc steps in both themes")
    func semanticTokens() {
        typealias A = AppColors.Adaptive
        let light: [(Color, String)] = [
            (A.background, "FFFFFF"), (A.cardSurface, "F4F4F5"), (A.surfaceElevated, "E4E4E7"),
            (A.textPrimary, "09090B"), (A.textSecondary, "18181B"), (A.textBody, "3F3F46"),
            (A.textTertiary, "3F3F46"), (A.textMeta, "52525B"), (A.placeholder, "E4E4E7")
        ]
        let dark: [(Color, String)] = [
            (A.background, "09090B"), (A.cardSurface, "18181B"), (A.surfaceElevated, "27272A"),
            (A.textPrimary, "FAFAFA"), (A.textSecondary, "F4F4F5"), (A.textBody, "D4D4D8"),
            (A.textTertiary, "D4D4D8"), (A.textMeta, "A1A1AA"), (A.placeholder, "27272A")
        ]
        for (color, expected) in light { #expect(hex(color, dark: false) == expected) }
        for (color, expected) in dark { #expect(hex(color, dark: true) == expected) }
    }

    @Test("Ink and its inverse")
    func ink() {
        #expect(hex(AppColors.Brand.accent, dark: false) == "09090B")
        #expect(hex(AppColors.Brand.accent, dark: true) == "FAFAFA")
        #expect(hex(AppColors.Brand.onInk, dark: false) == "FAFAFA")
        #expect(hex(AppColors.Brand.onInk, dark: true) == "09090B")
    }

    @Test("Lean colors are unchanged")
    func spectrumUntouched() {
        typealias S = AppColors.Spectrum
        let expected: [(Color, String, String)] = [
            (S.eGauche, "A81F26", "C2272D"), (S.gauche, "D9383F", "EF5A5F"), (S.centre, "86868C", "B5B5BA"),
            (S.droite, "3A6FE0", "4F86F7"), (S.eDroite, "2442B8", "2D55D8")
        ]
        for (color, light, dark) in expected {
            #expect(hex(color, dark: false) == light)
            #expect(hex(color, dark: true) == dark)
        }
    }

    @Test("Text keeps WCAG AA (4.5:1) contrast on the page and on cards")
    func textContrast() {
        typealias A = AppColors.Adaptive
        for isDark in [false, true] {
            for surface in [A.background, A.cardSurface] {
                let bg = hex(surface, dark: isDark)
                for text in [A.textPrimary, A.textSecondary, A.textBody, A.textTertiary, A.textMeta] {
                    let ratio = contrast(hex(text, dark: isDark), bg)
                    #expect(ratio >= 4.5, "\(hex(text, dark: isDark)) on \(bg) (\(isDark ? "dark" : "light")) = \(ratio)")
                }
            }
        }
    }
}

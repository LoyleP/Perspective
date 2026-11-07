import SwiftUI

/// One tag naming where a story's coverage leans, or "Équilibré" when no position clearly leads.
struct LeanTags: View {
    let coverage: CoverageStats

    /// A balanced story is tagged with the position holding the most coverage.
    private var verdict: LeanVerdict {
        let kind = coverage.leanVerdictKind
        guard kind == .balanced, let lean = PoliticalLean(rawValue: coverage.dominantLean) else { return kind }
        return .leaning(lean)
    }

    static func isShown(for coverage: CoverageStats) -> Bool { true }

    var body: some View {
        // The gray centre is lighter than the gray used for too few sources.
        LeanTagPill(lean: verdict.lean, text: verdict.tag, lighter: verdict == .leaning(.centre))
    }
}

/// The tag itself: a pill tinted with the position's hue.
struct LeanTagPill: View {
    let lean: PoliticalLean
    let text: String
    /// Raises the background lightness (used to set "au centre" apart from the neutral grays).
    var lighter = false

    var body: some View {
        Text(text)
            .typeStyle(.metaMedium)
            .foregroundStyle(lean.pillText)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(lean.pillBackground(lighter: lighter), in: Capsule())
    }
}

extension PoliticalLean {
    /// Pale tint (OKLCH L 0.936, C 0.032) of the position's hue, e.g. oklch(0.936 0.032 17.717) for red.
    fileprivate static let paleL = 0.936, deepL = 0.30, tintChroma = 0.032

    /// Dark mode: pale text on a deep (L 0.30) background of the same hue. Light mode: inverted.
    var tagText: Color { oklch(dark: Self.paleL, light: Self.deepL) }
    /// The pill is the tag inverted: pale text on the deep tone.
    var pillText: Color { .white }
    /// A solid, saturated fill in the position's own hue (the gray centre stays neutral): the
    /// extremes are deeper than gauche / droite.
    func pillBackground(lighter: Bool = false) -> Color {
        let extreme = self == .extremeGauche || self == .extremeDroite
        if lighter { return oklch(dark: 0.62, light: 0.60, chroma: 0) }
        return oklch(dark: extreme ? 0.46 : 0.56, light: extreme ? 0.46 : 0.56, chroma: extreme ? 0.15 : 0.15)
    }
    /// The two extremes sit slightly darker than the other positions.
    func tagBackground(lighter: Bool = false) -> Color {
        let extreme = self == .extremeGauche || self == .extremeDroite
        if lighter { return oklch(dark: Self.deepL + 0.14, light: 0.975) }
        return oklch(dark: extreme ? Self.deepL - 0.07 : Self.deepL, light: extreme ? 0.88 : Self.paleL)
    }

    /// Hand-picked tints: (pale lightness, hue in degrees) for the right, oklch(0.932 0.032 255.585).
    fileprivate var tint: (paleL: Double, hue: Double)? {
        switch self {
        case .droite, .extremeDroite: return (0.932, 255.585)
        default: return nil
        }
    }

    fileprivate func oklch(dark: Double, light: Double, chroma chromaOverride: Double? = nil) -> Color {
        // The pale value is swapped for the hand-picked one when there is one.
        let pale = tint?.paleL ?? Self.paleL
        let dark = dark == Self.paleL ? pale : dark
        let light = light == Self.paleL ? pale : light
        let fixedHue = tint.map { $0.hue * .pi / 180 }
        let base = UIColor(spectrumColor)
        return Color(UIColor { traits in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
            func lin(_ c: CGFloat) -> Double { let v = Double(c); return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            let (lr, lg, lb) = (lin(r), lin(g), lin(b))
            let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
            let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
            let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
            let okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
            let okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
            let chroma = (okA * okA + okB * okB).squareRoot()
            let hue = fixedHue ?? atan2(okB, okA)
            // Neutral positions (the gray centre) stay neutral.
            let c = (chroma < 0.02 && fixedHue == nil) ? 0 : (chromaOverride ?? Self.tintChroma)
            let L = traits.userInterfaceStyle == .dark ? dark : light
            let a2 = c * cos(hue), b2 = c * sin(hue)
            let l3 = pow(L + 0.3963377774 * a2 + 0.2158037573 * b2, 3)
            let m3 = pow(L - 0.1055613458 * a2 - 0.0638541728 * b2, 3)
            let s3 = pow(L - 0.0894841775 * a2 - 1.2914855480 * b2, 3)
            let lr2 = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
            let lg2 = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
            let lb2 = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
            func gam(_ v: Double) -> CGFloat {
                let x = min(max(v, 0), 1)
                return CGFloat(x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055)
            }
            return UIColor(red: gam(lr2), green: gam(lg2), blue: gam(lb2), alpha: 1)
        })
    }
}

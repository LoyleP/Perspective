import SwiftUI

/// One tag naming where a story's coverage leans, or "Équilibré" when no position clearly leads.
struct LeanTags: View {
    let coverage: CoverageStats

    /// A position leads when it is at least this far (share points) ahead of the next one.
    private let clearLead = 0.10

    private var verdict: (lean: PoliticalLean, text: String) {
        let ranked = PoliticalLean.allCases.sorted { coverage.share(of: $0) > coverage.share(of: $1) }
        guard let first = ranked.first else { return (.centre, "Équilibré") }
        let gap = coverage.share(of: first) - (ranked.dropFirst().first.map { coverage.share(of: $0) } ?? 0)
        guard gap >= clearLead else { return (.centre, "Équilibré") }
        switch first {
        case .extremeGauche: return (first, "Extrême gauche")
        case .gauche: return (first, "Penche à gauche")
        case .centre: return (first, "Penche au centre")
        case .droite: return (first, "Penche à droite")
        case .extremeDroite: return (first, "Extrême droite")
        }
    }

    var body: some View {
        let v = verdict
        Text(v.text)
            .font(.appCaption)
            .foregroundStyle(v.lean.tagText)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(v.lean.tagBackground, in: Capsule())
    }
}

private extension PoliticalLean {
    /// Tag background: the position's hue at 20 % lightness in dark mode, 80 % in light mode.
    var tagBackground: Color { withLightness(dark: 0.2, light: 0.8) }

    /// Tag text: the inverse, 90 % lightness in dark mode, 10 % in light mode.
    var tagText: Color { withLightness(dark: 0.9, light: 0.1) }

    private func withLightness(dark: CGFloat, light: CGFloat) -> Color {
        let base = UIColor(spectrumColor)
        return Color(UIColor { traits in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
            let maxC = max(r, g, b), minC = min(r, g, b), d = maxC - minC
            var h: CGFloat = 0, sat: CGFloat = 0
            let l = (maxC + minC) / 2
            if d > 0 {
                sat = d / (1 - abs(2 * l - 1))
                if maxC == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
                else if maxC == g { h = (b - r) / d + 2 }
                else { h = (r - g) / d + 4 }
                h = (h < 0 ? h + 6 : h) / 6
            }
            let nl = traits.userInterfaceStyle == .dark ? dark : light
            let c = (1 - abs(2 * nl - 1)) * sat
            let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
            let m = nl - c / 2
            let (r1, g1, b1): (CGFloat, CGFloat, CGFloat)
            switch Int(h * 6) {
            case 0: (r1, g1, b1) = (c, x, 0)
            case 1: (r1, g1, b1) = (x, c, 0)
            case 2: (r1, g1, b1) = (0, c, x)
            case 3: (r1, g1, b1) = (0, x, c)
            case 4: (r1, g1, b1) = (x, 0, c)
            default: (r1, g1, b1) = (c, 0, x)
            }
            return UIColor(red: r1 + m, green: g1 + m, blue: b1 + m, alpha: 1)
        })
    }
}

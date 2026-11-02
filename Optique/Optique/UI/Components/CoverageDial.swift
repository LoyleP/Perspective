import SwiftUI

/// A half-donut gauge of the coverage, far left to far right. Each position with coverage is an arc
/// in its colour, sized by its share; the selected arc is thicker and fully lit, the others dimmed.
/// The centre names the selected position and its share. A tap on any arc selects it.
struct CoverageDial: View {
    /// Coverage share per position, in left-to-right order.
    let shares: [(lean: PoliticalLean, share: Double)]
    let selected: PoliticalLean?
    let onSelect: (PoliticalLean) -> Void

    /// Gap between two arcs, in degrees.
    private let gap = 2.0
    private let thickness: CGFloat = 44

    private struct Arc { let lean: PoliticalLean; let start: Double; let end: Double }   // degrees, 180 = far left … 0 = far right

    private var arcs: [Arc] {
        let visible = shares.filter { $0.share > 0 }
        let total = visible.reduce(0) { $0 + $1.share }
        guard total > 0 else { return [] }
        var angle = 180.0
        return visible.map { entry in
            let sweep = 180.0 * entry.share / total
            defer { angle -= sweep }
            return Arc(lean: entry.lean, start: angle, end: angle - sweep)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width / 2, geo.size.height) - 8
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - 4)
            let arcs = arcs
            let radius = outer - thickness / 2

            ZStack {
                ForEach(arcs, id: \.lean) { arc in
                    let isSelected = selected == arc.lean
                    ArcShape(start: arc.start - gap / 2, end: arc.end + gap / 2, radius: radius, center: center)
                        .stroke(arc.lean.spectrumColor.opacity(selected == nil || isSelected ? 1 : 0.35),
                                style: StrokeStyle(lineWidth: isSelected ? thickness + 8 : thickness, lineCap: .butt))
                }
                .animation(.app, value: selected)

                VStack(spacing: 2) {
                    Text(selectedLabel)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                    Text(selectedShare)
                        .font(.appTitle)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                }
                .position(x: center.x, y: center.y - (radius - thickness / 2) * 0.42)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { tap in
                    let angle = atan2(Double(center.y - tap.location.y), Double(tap.location.x - center.x)) * 180 / .pi
                    let degrees = tap.location.y > center.y
                        ? (tap.location.x < center.x ? 180 : 0)
                        : min(max(angle, 0), 180)
                    if let hit = arcs.first(where: { degrees <= $0.start && degrees >= $0.end }) ?? arcs.last {
                        onSelect(hit.lean)
                    }
                }
            )
        }
        .aspectRatio(2, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Répartition de la couverture par position")
        .accessibilityValue("\(selectedLabel), \(selectedShare)")
    }

    private var selectedLabel: String { selected?.label ?? "Couverture" }

    private var selectedShare: String {
        let value = shares.first { $0.lean == selected }?.share ?? 0
        let total = shares.reduce(0) { $0 + $1.share }
        return "\(Int((total > 0 ? value / total * 100 : 0).rounded())) %"
    }
}

private struct ArcShape: Shape {
    var start: Double
    var end: Double
    let radius: CGFloat
    let center: CGPoint

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set { start = newValue.first; end = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        // Our angles run anticlockwise with y up; SwiftUI's run clockwise with y down.
        var path = Path()
        guard start > end else { return path }
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-start), endAngle: .degrees(-end), clockwise: false)
        return path
    }
}

#if DEBUG
#Preview {
    CoverageDial(
        shares: [(.extremeGauche, 0.08), (.gauche, 0.35), (.centre, 0.3), (.droite, 0.22), (.extremeDroite, 0.05)],
        selected: .gauche,
        onSelect: { _ in }
    )
    .padding()
    .background(AppColors.Adaptive.background)
}
#endif

import SwiftUI

/// A half-donut gauge of the coverage, far left to far right. Each position with coverage is an arc
/// in its colour, sized by its share; the selected arc is thicker and fully lit, the others dimmed.
/// The centre names the selected position and its share. A tap on any arc selects it.
struct CoverageDial: View {
    /// Coverage share per position, in left-to-right order.
    let shares: [(lean: PoliticalLean, share: Double)]
    let selected: PoliticalLean?
    let onSelect: (PoliticalLean) -> Void

    /// Width of the gap between two arcs, in points: the same along its whole length.
    private let gap: CGFloat = 4
    private let thickness: CGFloat = 44
    /// Radius of the rounded corners of each slice.
    private let corner: CGFloat = 6

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
                    let color = arc.lean.spectrumColor
                    let dimmed = selected != nil && !isSelected
                    let width = isSelected ? thickness + 8 : thickness
                    // Rounded corners: the sector is shrunk by `corner` on every side, then stroked with a
                    // round join of the same width, which rounds all four corners with that radius.
                    // Each straight edge sits half the gap (plus the corner) away from the boundary
                    // between two slices and runs parallel to it, so the gap has a constant width.
                    let sector = SectorShape(start: arc.start, end: arc.end,
                                             inner: radius - width / 2 + corner, outer: radius + width / 2 - corner,
                                             offset: gap / 2 + corner, center: center)
                    // Fill and stroke are composited together (compositingGroup) before the dimmed
                    // opacity is applied, so their overlap doesn't stack into a visible lighter outline.
                    sector
                        .fill(color)
                        .overlay(sector.stroke(color, style: StrokeStyle(lineWidth: corner * 2, lineJoin: .round)))
                        .compositingGroup()
                        .opacity(dimmed ? 0.35 : 1)
                }
                .animation(.app, value: selected)

                VStack(spacing: 2) {
                    Text(selectedLabel)
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                    Text(selectedShare)
                        .typeStyle(.screenTitle)
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

/// A ring sector between two radii, `start`…`end` in degrees (180 = far left, 0 = far right). Its two
/// straight edges run parallel to the slice boundaries, pulled in by `offset` points, so two
/// neighbouring slices are separated by a gap of even width (not a wedge).
private struct SectorShape: Shape {
    var start: Double
    var end: Double
    var inner: CGFloat
    var outer: CGFloat
    let offset: CGFloat
    let center: CGPoint

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(start, end), AnimatablePair(inner, outer)) }
        set { start = newValue.first.first; end = newValue.first.second; inner = newValue.second.first; outer = newValue.second.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard outer > inner, inner > offset else { return path }
        // A point on a line parallel to the boundary, `offset` away, sits asin(offset / r) of angle in from it.
        let outerPad = asin(Double(offset / outer)) * 180 / .pi
        let innerPad = asin(Double(offset / inner)) * 180 / .pi
        let o0 = start - outerPad, o1 = end + outerPad
        let i0 = start - innerPad, i1 = end + innerPad
        guard o0 > o1, i0 > i1 else { return path }
        // Our angles run anticlockwise with y up; SwiftUI's run clockwise with y down.
        path.addArc(center: center, radius: outer, startAngle: .degrees(-o0), endAngle: .degrees(-o1), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .degrees(-i1), endAngle: .degrees(-i0), clockwise: true)
        path.closeSubpath()
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

import SwiftUI

/// A tilted grid of cards that drifts from right to left, forever: several rows at slightly different
/// speeds, each looping seamlessly. Meant as a backdrop, so it never takes a touch. The items are shared
/// out round-robin across the rows.
struct MarqueeGrid<Item: Identifiable, Card: View>: View {
    let items: [Item]
    var rows = 3
    var cardWidth: CGFloat
    var spacing: CGFloat = 12
    /// Clockwise tilt, in degrees.
    var angle: Double = 8
    /// Points per second for each row.
    var speeds: [CGFloat] = [26, 38, 31]
    @ViewBuilder let card: (Item) -> Card

    /// The width the grid is given. The rows are far wider than it, so they are pinned to it: otherwise
    /// they stretch their parent and push the screen's text and buttons out of view.
    @State private var width: CGFloat = 0

    var body: some View {
        VStack(spacing: spacing) {
            // Takes the width offered, which is what the rows are then pinned to.
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            ForEach(0..<rows, id: \.self) { row in
                MarqueeRow(
                    width: max(width, 1),
                    items: rowItems(row),
                    cardWidth: cardWidth,
                    spacing: spacing,
                    speed: speeds[row % speeds.count],
                    startOffset: CGFloat(row) * cardWidth * 0.55,
                    card: card
                )
            }
        }
        .rotationEffect(.degrees(angle))
        .scaleEffect(1.15)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func rowItems(_ row: Int) -> [Item] {
        items.enumerated().filter { $0.offset % rows == row }.map(\.element)
    }
}

private struct MarqueeRow<Item: Identifiable, Card: View>: View {
    let width: CGFloat
    let items: [Item]
    let cardWidth: CGFloat
    let spacing: CGFloat
    let speed: CGFloat
    let startOffset: CGFloat
    let card: (Item) -> Card

    @State private var shift: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One full loop: the set of cards, repeated enough to be wider than the screen.
    private var loop: [(id: Int, item: Item)] {
        guard !items.isEmpty else { return [] }
        let unit = CGFloat(items.count) * (cardWidth + spacing)
        let repeats = max(1, Int((700 / unit).rounded(.up)))
        return (0..<(items.count * repeats)).map { ($0, items[$0 % items.count]) }
    }

    private var loopWidth: CGFloat { CGFloat(loop.count) * (cardWidth + spacing) }

    var body: some View {
        let cards = loop
        HStack(alignment: .top, spacing: spacing) {
            // Two copies: when the first has scrolled out, the second sits exactly where it started.
            ForEach(0..<2, id: \.self) { copy in
                ForEach(cards, id: \.id) { entry in
                    card(entry.item)
                        .frame(width: cardWidth)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        // Drawn once into a texture: scrolling then only moves that texture instead of redrawing every card.
        .drawingGroup()
        .offset(x: -startOffset + shift)
        .frame(width: width, alignment: .leading)
        .onAppear {
            guard !reduceMotion, loopWidth > 0 else { return }
            withAnimation(.linear(duration: Double(loopWidth / speed)).repeatForever(autoreverses: false)) {
                shift = -loopWidth
            }
        }
    }
}

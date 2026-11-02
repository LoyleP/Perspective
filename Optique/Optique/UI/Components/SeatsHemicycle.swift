import SwiftUI

/// A parliament hemicycle for one vote. Seats are dots on five concentric arcs, grouped by parliamentary
/// group from the far left to the far right and coloured with the group's lean colour. Within a group,
/// the members who voted yes are fully lit; no votes and abstentions (hollow) are dimmed, and members
/// who did not vote are faintest. Without group data it falls back to a plain yes / no split.
struct SeatsHemicycle: View {
    let vote: LawVote

    private static let seatCount = 120
    private static let rows = 5

    private enum Kind { case yes, abstained, no, absent }
    private struct Seat { let color: Color; let kind: Kind }

    var body: some View {
        GeometryReader { geo in
            let points = Self.seatPoints(in: geo.size)
            let seats = Self.seats(for: vote)
            let dot = Self.dotSize(in: geo.size)
            Canvas { context, _ in
                for (index, point) in points.enumerated() where index < seats.count {
                    let seat = seats[index]
                    let rect = CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)
                    switch seat.kind {
                    case .yes:
                        context.fill(Path(ellipseIn: rect), with: .color(seat.color))
                    case .no:
                        context.fill(Path(ellipseIn: rect), with: .color(seat.color.opacity(0.3)))
                    case .abstained:
                        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.7, dy: 0.7)),
                                       with: .color(seat.color.opacity(0.45)), lineWidth: 1.3)
                    case .absent:
                        context.fill(Path(ellipseIn: rect), with: .color(seat.color.opacity(0.1)))
                    }
                }
            }
        }
        // Tall enough for the outer arc plus one dot of margin above it (no clipping at the top).
        .aspectRatio(1.85, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("\(vote.yes) pour, \(vote.no) contre, \(vote.abstained) abstentions")
    }

    private static func dotSize(in size: CGSize) -> CGFloat {
        let outer = size.width / 2
        return outer * 0.5 / CGFloat(rows) * 0.74
    }

    /// Seat positions sorted from the far left of the arc to the far right.
    private static func seatPoints(in size: CGSize) -> [CGPoint] {
        let margin = dotSize(in: size) / 2 + 2
        let outer = size.width / 2 - margin
        let inner = outer * 0.5
        let center = CGPoint(x: size.width / 2, y: size.height - margin)
        let radii = (0..<rows).map { inner + (outer - inner) * CGFloat($0) / CGFloat(rows - 1) }
        let radiusSum = radii.reduce(0, +)
        var perRow = radii.map { Int((Double(seatCount) * Double($0 / radiusSum)).rounded()) }
        perRow[perRow.count - 1] += seatCount - perRow.reduce(0, +)

        var points: [(angle: Double, row: Int, point: CGPoint)] = []
        for (row, radius) in radii.enumerated() {
            let n = perRow[row]
            for j in 0..<n {
                let angle = Double.pi - Double.pi * Double(j) / Double(max(n - 1, 1))
                points.append((angle, row, CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                                                   y: center.y - radius * CGFloat(sin(angle)))))
            }
        }
        return points.sorted { $0.angle != $1.angle ? $0.angle > $1.angle : $0.row < $1.row }.map(\.point)
    }

    private static func leanColor(_ lean: Int) -> Color {
        PoliticalLean(rawValue: lean)?.spectrumColor ?? AppColors.Adaptive.textMeta
    }

    /// Largest-remainder allocation of `total` seats over `weights` (every non-zero weight keeps one seat
    /// when `minimum` is set).
    private static func allocate(_ weights: [Int], total: Int, minimum: Bool) -> [Int] {
        let sum = weights.reduce(0, +)
        guard sum > 0, total > 0 else { return Array(repeating: 0, count: weights.count) }
        var seats = weights.map { w -> Int in
            let exact = Int((Double(total) * Double(w) / Double(sum)).rounded(.down))
            return minimum && w > 0 ? max(exact, 1) : exact
        }
        var remainders = weights.enumerated().map { ($0.offset, Double(total) * Double($0.element) / Double(sum) - Double(seats[$0.offset])) }
        remainders.sort { $0.1 > $1.1 }
        var i = 0
        while seats.reduce(0, +) < total { seats[remainders[i % remainders.count].0] += 1; i += 1 }
        while seats.reduce(0, +) > total, let biggest = seats.indices.max(by: { seats[$0] < seats[$1] }), seats[biggest] > 0 {
            seats[biggest] -= 1
        }
        return seats
    }

    private static func seats(for vote: LawVote) -> [Seat] {
        guard let groups = vote.groups, !groups.isEmpty else { return plainSeats(for: vote) }
        // One block of seats per group, in the order the server sent them (far left to far right).
        let blocks = allocate(groups.map(\.members), total: seatCount, minimum: false)
        var out: [Seat] = []
        for (group, size) in zip(groups, blocks) where size > 0 {
            let color = leanColor(group.lean)
            let parts = allocate([group.yes, group.abstained, group.no, group.absent], total: size, minimum: false)
            let kinds: [Kind] = [.yes, .abstained, .no, .absent]
            for (kind, count) in zip(kinds, parts) { out += Array(repeating: Seat(color: color, kind: kind), count: count) }
        }
        return out
    }

    private static func plainSeats(for vote: LawVote) -> [Seat] {
        let ink = AppColors.Adaptive.textPrimary
        let parts = allocate([vote.yes, vote.abstained, vote.no, vote.absent], total: seatCount, minimum: true)
        let kinds: [Kind] = [.yes, .abstained, .no, .absent]
        return zip(kinds, parts).flatMap { Array(repeating: Seat(color: ink, kind: $0.0), count: $0.1) }
    }
}

#if DEBUG
#Preview {
    SeatsHemicycle(vote: LawVote(
        chamber: "AN", date: "2026-06-23", adopted: true, yes: 289, no: 175, abstained: 12, voters: 476, seats: 577,
        groups: [
            LawVoteGroup(name: "LFI-NFP", lean: 1, members: 71, yes: 60, no: 2, abstained: 0),
            LawVoteGroup(name: "SOC", lean: 2, members: 68, yes: 41, no: 5, abstained: 19),
            LawVoteGroup(name: "EPR", lean: 4, members: 91, yes: 66, no: 5, abstained: 11),
            LawVoteGroup(name: "DR", lean: 6, members: 48, yes: 1, no: 34, abstained: 10),
            LawVoteGroup(name: "RN", lean: 7, members: 122, yes: 0, no: 120, abstained: 0)
        ]))
        .padding()
        .background(AppColors.Adaptive.background)
}
#endif

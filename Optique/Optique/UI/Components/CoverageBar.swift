import SwiftUI

/// The coverage as a thin, static bar, far left to far right: each position with coverage is a segment in
/// its full colour sized by its share, with its small percentage under it (hidden when the segment is too
/// narrow to carry it). No selection, no interaction.
struct CoverageBar: View {
    /// Coverage share per position, in left-to-right order.
    let shares: [(lean: PoliticalLean, share: Double)]
    /// The line under the bar, e.g. "Relayé par tous les bords".
    var verdict: String? = nil

    private let gap: CGFloat = 4
    private let barHeight: CGFloat = 10
    private let minLabelWidth: CGFloat = 34

    private var visible: [(lean: PoliticalLean, share: Double)] { shares.filter { $0.share > 0 } }
    private var total: Double { visible.reduce(0) { $0 + $1.share } }

    private func percent(_ share: Double) -> String { "\(Int((total > 0 ? share / total * 100 : 0).rounded())) %" }

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - gap * CGFloat(max(visible.count - 1, 0)), 0)
            let widths = visible.map { usable * $0.share / max(total, 0.0001) }
            VStack(alignment: .leading, spacing: 8) {
                do {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: gap) {
                            ForEach(Array(visible.enumerated()), id: \.element.lean) { index, entry in
                                Capsule()
                                    .fill(entry.lean.spectrumColor)
                                    .frame(width: widths[index], height: barHeight)
                            }
                        }
                        HStack(spacing: gap) {
                            ForEach(Array(visible.enumerated()), id: \.element.lean) { index, entry in
                                Text(percent(entry.share))
                                    .typeStyle(.meta)
                                    .monospacedDigit()
                                    .foregroundStyle(AppColors.Adaptive.textMeta)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .frame(width: widths[index])
                                    .opacity(widths[index] >= minLabelWidth ? 1 : 0)
                            }
                        }
                    }
                }
                if let verdict {
                    Text(verdict)
                        .typeStyle(.metaMedium)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .frame(height: barHeight + 6 + 16 + (verdict == nil ? 0 : 8 + 18))
        .accessibilityElement()
        .accessibilityLabel("Répartition de la couverture par position")
        .accessibilityValue(visible.map { "\($0.lean.label) \(percent($0.share))" }.joined(separator: ", "))
    }
}

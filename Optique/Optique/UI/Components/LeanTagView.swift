import SwiftUI

/// Chip naming a political position, with a color dot and an optional share.
struct LeanTagView: View {
    let lean: PoliticalLean
    var style: Style = .capsule
    /// Share of coverage (0…1) shown before the label, e.g. "38 % Centre".
    var value: Double? = nil

    enum Style {
        case capsule   // full label
        case rounded   // short label
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(lean.spectrumColor)
                .frame(width: 8, height: 8)
            if let value {
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            Text(style == .capsule ? lean.label : lean.shortLabel)
        }
        .font(.appCaption)
        .foregroundStyle(AppColors.Adaptive.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.Adaptive.surfaceElevated, in: shape)
    }

    private var shape: some Shape {
        RoundedRectangle(cornerRadius: style == .capsule ? .infinity : AppRadius.s)
    }
}

#if DEBUG
#Preview("Tags") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PoliticalLean.allCases) { LeanTagView(lean: $0) }
        LeanTagView(lean: .centre, style: .rounded, value: 0.38)
    }
    .padding()
    .background(AppColors.Adaptive.background)
}
#endif

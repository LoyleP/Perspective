import SwiftUI

struct FeedCoverageBarView: View {

    let coverage: CoverageStats

    private var segments: [(lean: PoliticalLean, pct: Double)] {
        [
            (.extremeGauche, coverage.lean1Pct),
            (.gauche,        coverage.lean2Pct),
            (.centreGauche,  coverage.lean3Pct),
            (.centre,        coverage.lean4Pct),
            (.centreDroite,  coverage.lean5Pct),
            (.droite,        coverage.lean6Pct),
            (.extremeDroite, coverage.lean7Pct),
        ].filter { $0.pct > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Couverture politique")
                .font(.appFootnote)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.Adaptive.textSecondary)

            stackedBar

            if !coverage.coverageNarrative.isEmpty {
                Text(coverage.coverageNarrative)
                    .font(.appCaption1)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .padding(AppSpacing.m)
        .cardSurface()
    }

    private var stackedBar: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let totalSpacing = spacing * CGFloat(max(0, segments.count - 1))
            let available = geo.size.width - totalSpacing
            HStack(spacing: spacing) {
                ForEach(segments, id: \.lean) { segment in
                    RoundedRectangle(cornerRadius: AppRadius.xs)
                        .fill(segment.lean.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.xs)
                                .stroke(AppColors.stroke, lineWidth: 0.5)
                        )
                        .frame(width: max(4, available * segment.pct))
                }
            }
        }
        .frame(height: 20)
    }
}

#if DEBUG
#Preview("FeedCoverageBarView") {
    FeedCoverageBarView(coverage: PreviewData.coverage)
        .padding()
        .background(AppColors.Adaptive.feedBackground)
}
#endif

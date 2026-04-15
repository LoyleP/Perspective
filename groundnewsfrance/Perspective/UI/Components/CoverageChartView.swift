import SwiftUI

struct CoverageChartView: View {

    let coverage: CoverageStats

    private struct Bucket: Identifiable {
        let lean: PoliticalLean
        let pct: Double
        var id: Int { lean.rawValue }
        var pctInt: Int { Int((pct * 100).rounded()) }
    }

    private var buckets: [Bucket] {
        [
            Bucket(lean: .extremeGauche, pct: coverage.lean1Pct),
            Bucket(lean: .gauche,        pct: coverage.lean2Pct),
            Bucket(lean: .centreGauche,  pct: coverage.lean3Pct),
            Bucket(lean: .centre,        pct: coverage.lean4Pct),
            Bucket(lean: .centreDroite,  pct: coverage.lean5Pct),
            Bucket(lean: .droite,        pct: coverage.lean6Pct),
            Bucket(lean: .extremeDroite, pct: coverage.lean7Pct),
        ]
    }

    private var visible: [Bucket] { buckets.filter { $0.pct > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            stackedBar
            legendRows
        }
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.detailSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
    }

    // MARK: - Stacked bar

    private var stackedBar: some View {
        let spacing: CGFloat = 2
        let segments = visible
        return GeometryReader { geo in
            let totalSpacing = spacing * CGFloat(max(0, segments.count - 1))
            let available = geo.size.width - totalSpacing
            HStack(spacing: spacing) {
                ForEach(segments) { bucket in
                    RoundedRectangle(cornerRadius: AppRadius.xs)
                        .fill(bucket.lean.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.xs)
                                .stroke(AppColors.stroke, lineWidth: 0.5)
                        )
                        .frame(width: max(4, available * bucket.pct))
                }
            }
        }
        .frame(height: 20)
    }

    // MARK: - Legend rows

    private var legendRows: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(buckets) { bucket in
                legendRow(bucket)
            }
        }
    }

    private func legendRow(_ bucket: Bucket) -> some View {
        HStack(spacing: AppSpacing.s) {
            RoundedRectangle(cornerRadius: AppRadius.xs)
                .fill(bucket.lean.color)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xs)
                        .stroke(AppColors.stroke, lineWidth: 1)
                )
                .frame(width: 12, height: 12)

            Text(bucket.lean.label)
                .font(.appFootnote)
                .foregroundStyle(
                    bucket.pct > 0 ? AppColors.Adaptive.textSecondary : AppColors.Adaptive.textMeta
                )
                .frame(minWidth: 90, alignment: .leading)

            Spacer()

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppRadius.xs)
                    .fill(AppColors.Adaptive.placeholder)
                    .frame(width: 80, height: 8)
                if bucket.pct > 0 {
                    RoundedRectangle(cornerRadius: AppRadius.xs)
                        .fill(bucket.lean.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.xs)
                                .stroke(AppColors.stroke, lineWidth: 0.5)
                        )
                        .frame(width: max(4, 80 * bucket.pct), height: 8)
                }
            }

            Text("\(bucket.pctInt)%")
                .font(.appFootnote)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(
                    bucket.pct > 0 ? AppColors.Adaptive.textSecondary : AppColors.Adaptive.textMeta
                )
                .frame(width: 34, alignment: .trailing)
        }
    }
}

#if DEBUG
#Preview("CoverageChartView") {
    CoverageChartView(coverage: PreviewData.coverage)
        .padding()
        .background(AppColors.Adaptive.background)
}
#endif

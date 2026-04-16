import SwiftUI

struct CoverageTagsView: View {

    let coverage: CoverageStats
    var maxTags: Int = 2
    var tagPadding: CGFloat = 8

    var body: some View {
        let tags = topTags
        if !tags.isEmpty {
            HStack(spacing: AppSpacing.xs) {
                ForEach(tags, id: \.lean.id) { item in
                    tag(lean: item.lean, percentage: item.percentage)
                }
            }
        }
    }

    private func tag(lean: PoliticalLean, percentage: Int) -> some View {
        Text("\(percentage)% \(lean.shortLabel)")
            .font(.appFootnote)
            .foregroundStyle(lean.tagTextColor)
            .padding(.horizontal, tagPadding)
            .padding(.vertical, 4)
            .background(lean.spectrumColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.s).stroke(AppColors.stroke, lineWidth: 1))
    }

    private struct TagItem {
        let lean: PoliticalLean
        let percentage: Int
    }

    private var topTags: [TagItem] {
        guard coverage.totalCount > 0 else { return [] }
        let pairs: [(count: Int, lean: PoliticalLean)] = [
            (coverage.lean1Count, .extremeGauche),
            (coverage.lean2Count, .gauche),
            (coverage.lean3Count, .centreGauche),
            (coverage.lean4Count, .centre),
            (coverage.lean5Count, .centreDroite),
            (coverage.lean6Count, .droite),
            (coverage.lean7Count, .extremeDroite)
        ]
        return pairs
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
            .prefix(maxTags)
            .map { pair in
                let pct = Int((Double(pair.count) / Double(coverage.totalCount) * 100).rounded())
                return TagItem(lean: pair.lean, percentage: pct)
            }
    }
}

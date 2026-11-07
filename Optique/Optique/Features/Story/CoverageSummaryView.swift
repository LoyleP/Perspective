import SwiftUI

/// The coverage bar on its own, right under a story's description: the share of each position, static.
struct CoverageSummaryView: View {
    let story: Story

    var body: some View {
        if let coverage = story.computedCoverage {
            CoverageBar(shares: PoliticalLean.allCases.map { ($0, coverage.share(of: $0)) })
                .padding(.horizontal, AppSpacing.m)
        }
    }
}

#if DEBUG
#Preview("Coverage summary") {
    CoverageSummaryView(story: Fixtures.stories[0])
        .background(AppColors.Adaptive.background)
}
#endif

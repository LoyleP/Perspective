import SwiftUI

/// Coverage across the 7-point spectrum.
/// - `.compact`: thin line whose segments are proportional to each position's share.
/// - `.detailed`: verdict, source logos stacked above each position, the 7-step
///   axis, and left / centre / right shares.
struct SpectrumBar: View {
    let coverage: CoverageStats
    var style: Style = .compact
    /// Sources to place above the axis in `.detailed`.
    var sources: [Source] = []
    /// Thickness of the `.compact` line.
    var barHeight: CGFloat = 4

    enum Style {
        case compact
        case detailed
    }

    var body: some View {
        Group {
            switch style {
            case .compact: compact
            case .detailed: detailed
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Compact

    private var compact: some View {
        ProportionalHStack(spacing: 2) {
            ForEach(PoliticalLean.allCases) { lean in
                let share = coverage.spectrumData[lean.rawValue - 1]
                if share > 0 {
                    Capsule()
                        .fill(lean.spectrumColor)
                        .layoutValue(key: ShareKey.self, value: share)
                }
            }
        }
        .frame(height: barHeight)
    }

    // MARK: - Detailed

    private var detailed: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    verdict
                    Spacer()
                    sourceCount
                }
                VStack(alignment: .leading, spacing: 2) {
                    verdict
                    sourceCount
                }
            }

            VStack(spacing: AppSpacing.s) {
                if !sources.isEmpty {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(PoliticalLean.allCases) { lean in
                            logoColumn(for: lean)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                HStack(spacing: 4) {
                    ForEach(PoliticalLean.allCases) { lean in
                        let present = (coverage.countsByLean[lean] ?? 0) > 0
                        VStack(spacing: 6) {
                            Capsule()
                                .fill(lean.spectrumColor.opacity(present ? 1 : 0.18))
                                .frame(height: 6)
                            Text(lean.code)
                                .font(.appCaption2)
                                .lineLimit(1)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .foregroundStyle(present ? AppColors.Adaptive.textTertiary : AppColors.Adaptive.textMeta.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    shares
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    shares
                }
            }
        }
    }

    private var verdict: some View {
        Text(coverage.verdict)
            .font(.appHeadline)
            .foregroundStyle(AppColors.Adaptive.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sourceCount: some View {
        let count = sources.isEmpty ? coverage.totalCount : sources.count
        return Text(count == 1 ? "1 source" : "\(count) sources")
            .font(.appFootnote)
            .foregroundStyle(AppColors.Adaptive.textMeta)
    }

    @ViewBuilder
    private var shares: some View {
        shareLabel("Gauche", coverage.leftShare, AppColors.Spectrum.gauche)
        Spacer(minLength: AppSpacing.s)
        shareLabel("Centre", coverage.centreShare, AppColors.Spectrum.centre)
        Spacer(minLength: AppSpacing.s)
        shareLabel("Droite", coverage.rightShare, AppColors.Spectrum.droite)
    }

    private func logoColumn(for lean: PoliticalLean) -> some View {
        let leanSources = sources.filter { $0.politicalLean == lean.rawValue }
        return VStack(spacing: -6) {
            ForEach(leanSources.prefix(3)) { source in
                SourceAvatarView(source: source, size: 30)
                    .overlay(Circle().stroke(AppColors.Adaptive.cardSurface, lineWidth: 2))
            }
            if leanSources.count > 3 {
                Text("+\(leanSources.count - 3)")
                    .font(.appCaption1)
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
                    .padding(.top, 10)
            }
        }
    }

    private func shareLabel(_ title: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .foregroundStyle(AppColors.Adaptive.textTertiary)
            Text(value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(AppColors.Adaptive.textPrimary)
        }
        .font(.appFootnote)
        .fixedSize()
    }

    private var accessibilityText: String {
        let pct: (Double) -> String = { $0.formatted(.percent.precision(.fractionLength(0))) }
        return "Couverture : \(pct(coverage.leftShare)) à gauche, \(pct(coverage.centreShare)) au centre, \(pct(coverage.rightShare)) à droite. \(coverage.verdict)."
    }
}

// MARK: - Proportional layout

private struct ShareKey: LayoutValueKey {
    static let defaultValue: Double = 1
}

/// Lays children out horizontally with widths proportional to their `ShareKey`.
private struct ProportionalHStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 100, height: 4))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let total = subviews.reduce(0) { $0 + $1[ShareKey.self] }
        guard total > 0 else { return }
        let available = bounds.width - spacing * CGFloat(max(subviews.count - 1, 0))
        var x = bounds.minX
        for subview in subviews {
            let width = max(available * subview[ShareKey.self] / total, 2)
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }
}

#if DEBUG
#Preview("Compact") {
    VStack(spacing: 16) {
        ForEach(Fixtures.stories.prefix(5)) { story in
            if let coverage = story.computedCoverage { SpectrumBar(coverage: coverage) }
        }
    }
    .padding()
    .background(AppColors.Adaptive.background)
}

#Preview("Detailed") {
    let story = Fixtures.stories[0]
    return SpectrumBar(coverage: story.computedCoverage!, style: .detailed, sources: story.sources)
        .padding()
        .cardSurface()
        .padding()
        .background(AppColors.Adaptive.background)
}

#Preview("Detailed – accessibility text") {
    let story = Fixtures.stories[0]
    return ScrollView {
        SpectrumBar(coverage: story.computedCoverage!, style: .detailed, sources: story.sources)
            .padding()
            .cardSurface()
            .padding()
    }
    .background(AppColors.Adaptive.background)
    .dynamicTypeSize(.accessibility3)
}
#endif

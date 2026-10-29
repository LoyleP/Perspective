import SwiftUI

/// One card per political side, scrolled horizontally: the centered card is full size, the
/// others are smaller and dimmer, and scrolling snaps a card to the center. Each card shows
/// the side's share, source logos and AI summary. Tapping a card reports the side so the
/// caller can show its articles.
struct SideCarouselView: View {
    let story: Story
    let isSummaryUnavailable: Bool
    /// Called when a card with articles is tapped.
    var onSelectSide: (PoliticalLean) -> Void = { _ in }

    @State private var selected: PoliticalLean.ID?
    @State private var width: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardFraction: CGFloat { dynamicTypeSize.isAccessibilitySize ? 0.88 : 0.76 }
    private var cardWidth: CGFloat { max(width * cardFraction, 190) }
    private var sideMargin: CGFloat { max((width - cardWidth) / 2, AppSpacing.m) }

    private var coverage: CoverageStats? { story.computedCoverage }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            header
                .padding(.horizontal, AppSpacing.m)

            // Built only once the width is known, so the side margins (and therefore the first
            // centered card) are right from the first frame.
            if width > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppSpacing.st) {
                        ForEach(PoliticalLean.allCases) { lean in
                            card(for: lean)
                                .frame(width: cardWidth)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .scrollTransition(axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(1 - min(abs(phase.value), 1) * 0.12)
                                        .opacity(1 - min(abs(phase.value), 1) * 0.45)
                                }
                                .id(lean.id)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideMargin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selected, anchor: .center)
                .defaultScrollAnchor(.center)
            } else {
                Color.clear.frame(height: 200)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { width = geo.size.width }
                    .onChange(of: geo.size.width) { _, new in width = new }
            }
        )
        .onAppear {
            if selected == nil { selected = PoliticalLean.centre.id }
        }
    }

    // MARK: - Header

    private var header: some View {
        let count = story.sources.count
        return VStack(alignment: .leading, spacing: 2) {
            Text("Ce que disent les médias")
                .font(.appHeading)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("\(coverage?.verdict ?? "Peu de sources") · \(count == 1 ? "1 source" : "\(count) sources")")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    // MARK: - Cards

    private func card(for lean: PoliticalLean) -> some View {
        let sources = story.sources.filter { PoliticalLean.from($0.politicalLean) == lean }
        let count = coverage?.countsByLean[lean] ?? 0
        let share = coverage?.share(of: lean) ?? 0
        let isEmpty = count == 0
        let perspective = story.spectrumSummary?.perspectives.first { $0.lean == lean }

        return Button {
            guard !isEmpty else { return }
            onSelectSide(lean)
        } label: {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Capsule()
                .fill(lean.spectrumColor)
                .frame(width: 36, height: 4)
                .accessibilityHidden(true)

            Text(lean.label)
                .font(.appBodyStrong)
                .foregroundStyle(AppColors.Adaptive.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                Text(share, format: .percent.precision(.fractionLength(0)))
                    .font(.appTitle)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text(count == 1 ? "1 source" : "\(count) sources")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }

            if isEmpty {
                Text("Aucun média de ce bord n'a couvert ce sujet.")
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            } else {
                SourceStack(sources: sources, limit: 3, size: 24, ringColor: AppColors.Adaptive.cardSurface)
                summaryBlock(perspective: perspective, lean: lean)
            }
        }
        .padding(AppSpacing.st)
        .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(AppColors.stroke, lineWidth: 1))
        .opacity(isEmpty ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        }
        .buttonStyle(CardPressStyle())
        .disabled(isEmpty)
        .accessibilityHint(isEmpty ? "" : "Affiche les articles de ce bord")
    }

    @ViewBuilder
    private func summaryBlock(perspective: SpectrumPerspective?, lean: PoliticalLean) -> some View {
        if let perspective {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                ForEach(Self.bullets(perspective), id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                        Circle()
                            .fill(lean.spectrumColor)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                            .accessibilityHidden(true)
                        Text(bullet)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.Adaptive.textBody)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else if isSummaryUnavailable || story.spectrumSummary != nil {
            Text("Résumé indisponible.")
                .font(.appBody)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        } else {
            SkeletonLines(count: 4, lineHeight: 12)
        }
    }

    // MARK: - Helpers

    private static func bullets(_ perspective: SpectrumPerspective) -> [String] {
        perspective.summary
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("•") ? String($0.dropFirst()).trimmingCharacters(in: .whitespaces) : $0 }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { $0 }
    }
}

#if DEBUG
#Preview("Side carousel") {
    ScrollView {
        SideCarouselView(story: Fixtures.stories[0], isSummaryUnavailable: false)
    }
    .background(AppColors.Adaptive.background)
}

#Preview("Side carousel – no summary yet, empty sides") {
    ScrollView {
        SideCarouselView(story: Fixtures.stories[5], isSummaryUnavailable: false)
    }
    .background(AppColors.Adaptive.background)
}

#Preview("Side carousel – accessibility text") {
    ScrollView {
        SideCarouselView(story: Fixtures.stories[0], isSummaryUnavailable: false)
    }
    .background(AppColors.Adaptive.background)
    .dynamicTypeSize(.accessibility2)
}
#endif

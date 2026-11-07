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
    /// Demo mode (onboarding): moves from side to side by itself until the reader touches it.
    var autoPlays = false

    @State private var selected: PoliticalLean.ID?
    @State private var lastAutoSelection: PoliticalLean.ID?
    @State private var readerTookOver = false

    init(story: Story, isSummaryUnavailable: Bool, autoPlays: Bool = false, onSelectSide: @escaping (PoliticalLean) -> Void = { _ in }) {
        self.story = story
        self.isSummaryUnavailable = isSummaryUnavailable
        self.autoPlays = autoPlays
        self.onSelectSide = onSelectSide
        let top = story.computedCoverage.flatMap { coverage in
            PoliticalLean.allCases.max { coverage.share(of: $0) < coverage.share(of: $1) }
        }
        _selected = State(initialValue: (top ?? .centre).id)
    }
    @State private var width: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardFraction: CGFloat { dynamicTypeSize.isAccessibilitySize ? 0.88 : 0.76 }
    private var cardWidth: CGFloat { max(width * cardFraction, 190) }
    private var sideMargin: CGFloat { max((width - cardWidth) / 2, AppSpacing.m) }

    private var coverage: CoverageStats? { story.computedCoverage }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            pie
                .padding(.horizontal, AppSpacing.m)

            // Built only once the width is known, so the side margins (and therefore the first
            // centered card) are right from the first frame.
            if width > 0 {
                ScrollViewReader { proxy in
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
                .onChange(of: selected) { _, id in
                    if autoPlays, id != lastAutoSelection { readerTookOver = true }
                    if let id { Analytics.track(.sideCardSwipe, ["story": story.id.uuidString, "side": String(id)]) }
                }
                .sensoryFeedback(.selection, trigger: selected)
                .onAppear {
                    guard let id = selected else { return }
                    DispatchQueue.main.async { proxy.scrollTo(id, anchor: .center) }
                }
                .task(id: autoPlays) { await autoPlay() }
                }
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
    }

    // MARK: - Dial

    /// Positions that have coverage, left to right, with their article counts.
    private var slices: [(lean: PoliticalLean, count: Int)] {
        PoliticalLean.allCases.compactMap { lean in
            let count = coverage?.countsByLean[lean] ?? 0
            return count > 0 ? (lean, count) : nil
        }
    }

    /// The demo: every few seconds the needle swings to the next side that has coverage, and its card slides in.
    private func autoPlay() async {
        guard autoPlays else { return }
        let covered = PoliticalLean.allCases.filter { (coverage?.countsByLean[$0] ?? 0) > 0 }
        guard covered.count > 1 else { return }
        try? await Task.sleep(for: .seconds(1.6))
        var index = covered.firstIndex { $0.id == selected } ?? 0
        while !Task.isCancelled && !readerTookOver {
            index = (index + 1) % covered.count
            lastAutoSelection = covered[index].id
            withAnimation(.app) { selected = covered[index].id }
            try? await Task.sleep(for: .seconds(2.8))
        }
    }

    private func select(_ lean: PoliticalLean) {
        withAnimation(.app) { selected = lean.id }
    }

    /// Dial of the coverage across the scale (all five positions, left to right). Tapping an arc
    /// brings that position's card to the centre of the carousel and swings the needle to it.
    @ViewBuilder
    private var pie: some View {
        if let coverage {
            CoverageDial(
                shares: PoliticalLean.allCases.map { ($0, coverage.share(of: $0)) },
                selected: selected.flatMap { id in PoliticalLean.allCases.first { $0.id == id } },
                onSelect: select
            )
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Cards

    private func card(for lean: PoliticalLean) -> some View {
        let sources = story.sources.filter { PoliticalLean.from($0.politicalLean) == lean }
        let count = coverage?.countsByLean[lean] ?? 0
        let isEmpty = count == 0
        let perspective = story.spectrumSummary?.perspectives.first { $0.lean == lean }

        return Button {
            guard !isEmpty else { return }
            onSelectSide(lean)
        } label: {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            if isEmpty {
                // Without a title on the card, the empty state says which side it is.
                Text(lean.label)
                    .typeStyle(.ui)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                Text("Aucun média de ce bord n'a couvert ce sujet.")
                    .typeStyle(.body)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            } else {
                SourceStack(sources: sources, limit: 3, size: 24, ringColor: AppColors.Adaptive.cardSurface)
                summaryBlock(perspective: perspective, lean: lean)
                Spacer(minLength: 0)
                // Straight to the articles, instead of guessing that the card is tappable.
                HStack(spacing: 6) {
                    Text(count == 1 ? "Lire l'article" : "Lire les \(count) articles")
                        .typeStyle(.meta)
                    LucideIcon("chevron-right", size: 14)
                }
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.st)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Each card carries a pale tint of its own side's hue.
        .background(lean.tagBackground(), in: RoundedRectangle(cornerRadius: AppRadius.xl))
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
                            .fill(AppColors.Adaptive.textMeta)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                            .accessibilityHidden(true)
                        Text(bullet)
                            .typeStyle(.body)
                            .lineSpacing(3)
                            .foregroundStyle(AppColors.Adaptive.textBody)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else {
            // No written summary yet (or it failed): show what this side's outlets actually titled,
            // so the card is never empty or stuck loading.
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Leurs titres")
                    .typeStyle(.meta)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                ForEach(headlines(for: lean), id: \.self) { title in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                        Circle()
                            .fill(AppColors.Adaptive.textMeta)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                            .accessibilityHidden(true)
                        Text(title)
                            .typeStyle(.body)
                            .foregroundStyle(AppColors.Adaptive.textBody)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Up to three distinct headlines from this side's outlets, newest first.
    private func headlines(for lean: PoliticalLean) -> [String] {
        var seen = Set<String>()
        return story.articles
            .filter { PoliticalLean.from($0.source?.politicalLean ?? 4) == lean }
            .sorted { $0.publishedAt > $1.publishedAt }
            .map(\.title)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }

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

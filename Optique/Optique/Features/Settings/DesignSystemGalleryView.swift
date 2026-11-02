#if DEBUG
import SwiftUI

/// Debug-only catalogue of design tokens and shared components, rendered with live feed data.
struct DesignSystemGalleryView: View {
    @State private var stories: [Story] = []
    @State private var showsComments = false
    /// Shown as a leading "Accueil" button when the gallery was launched on its own.
    var onHome: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                colors
                typography
                chips
                carousel
                comments
                if let story = stories.first {
                    spectrum(story)
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        SectionHeader(title: "Cartes", subtitle: "StoryHeroCard · StoryRow", actionTitle: "Tout voir") {}
                        StoryHeroCard(story: story)
                        ForEach(stories.dropFirst().prefix(3)) { story in
                            StoryRow(story: story)
                            Divider().overlay(AppColors.Adaptive.divider)
                        }
                    }
                }
                tagVariants
                loading
                buttons
            }
            .padding(AppSpacing.m)
        }
        .background(AppColors.Adaptive.background)
        .overlay {
            if showsComments {
                CommentsSheet(story: Fixtures.stories[0], startsTyping: false) { showsComments = false }
            }
        }
        .navigationTitle("Design system")
        .toolbar {
            if let onHome {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onHome) { Label("Accueil", hero: "home") }
                }
            }
        }
        .task {
            stories = (try? await StoryRepository.shared.fetchFeed(limit: 6)) ?? [PreviewData.story]
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            SectionHeader(title: "Couleurs")
            HStack(spacing: 4) {
                ForEach(PoliticalLean.allCases) { lean in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: AppRadius.st)
                            .fill(lean.spectrumColor)
                            .frame(height: 44)
                            .overlay(Text(lean.code).font(.appCaption).foregroundStyle(lean.tagTextColor))
                    }
                }
            }
            HStack(spacing: 4) {
                swatch(AppColors.Brand.accent, "Accent")
                swatch(AppColors.Adaptive.cardSurface, "Carte")
                swatch(AppColors.Adaptive.surfaceElevated, "Élevé")
                swatch(AppColors.Adaptive.textPrimary, "Texte")
            }
        }
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: AppRadius.st)
                .fill(color)
                .frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.st).stroke(AppColors.stroke))
            Text(name).font(.appCaption).foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            SectionHeader(title: "Typographie")
            Text("8 sources · il y a 2 h").overlineStyle(AppColors.Brand.accent)
            Text("À la une").font(.appTitle)
            Text("Titre sur image").font(.appTitle)
            Text("Titre de l'article").font(.appHeading)
            Text("Titre de ligne").font(.appBodyStrong)
            Text("Corps de texte, aligné sur Dynamic Type.").font(.appBody).foregroundStyle(AppColors.Adaptive.textBody)
            Text("Métadonnées").font(.appCaption).foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .foregroundStyle(AppColors.Adaptive.textPrimary)
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            SectionHeader(title: "Tags de position", subtitle: "LeanTags · teinte OKLCH par position")
            FlowRow {
                LeanTagPill(lean: .extremeGauche, text: "Couverture à l'extrême gauche")
                LeanTagPill(lean: .gauche, text: "Couverture à gauche")
                LeanTagPill(lean: .centre, text: "Couverture au centre", lighter: true)
                LeanTagPill(lean: .droite, text: "Couverture à droite")
                LeanTagPill(lean: .extremeDroite, text: "Couverture à l'extrême droite")
                LeanTagPill(lean: .centre, text: "Couverture équilibrée")
                LeanTagPill(lean: .centre, text: "Peu de sources")
            }
        }
    }

    /// The story page's per-position carousel, on a mock story.
    private var carousel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            SectionHeader(title: "Carrousel des positions", subtitle: "SideCarouselView · s'ouvre sur la majorité")
            SideCarouselView(story: Fixtures.stories[0], isSummaryUnavailable: false)
        }
    }

    private var comments: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            SectionHeader(title: "Commentaires", subtitle: "CommentsSheet · saisie et liste")
            Button("Ouvrir la feuille de commentaires") { showsComments = true }
                .buttonStyle(.optiqueSecondary)
        }
    }

    private func spectrum(_ story: Story) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Spectre", subtitle: story.title)
            if let coverage = story.computedCoverage {
                SpectrumBar(coverage: coverage)
                SpectrumBar(coverage: coverage, style: .detailed, sources: story.sources)
                    .padding(AppSpacing.m)
                    .cardSurface()
            }
            SourceStack(sources: story.sources)
        }
    }

    /// Every tag the cards can show, from mock stories (this file is DEBUG-only).
    private var tagVariants: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Tags de couverture", subtitle: "Données fictives, debug uniquement")
            ForEach(Fixtures.tagVariants) { story in
                StoryRow(story: story)
                Divider().overlay(AppColors.Adaptive.divider)
            }
            StoryHeroCard(story: Fixtures.tagVariants[1], size: .medium)
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            SectionHeader(title: "Chargement")
            SkeletonLines(count: 3)
        }
    }

    private var buttons: some View {
        VStack(spacing: AppSpacing.st) {
            Button("Continuer") {}
                .buttonStyle(.optiquePrimary)
            Button("Plus tard") {}
                .buttonStyle(.optiqueSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Minimal wrapping row for the gallery chips.
private struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
#endif

import SwiftUI

/// One law: what it does in plain language, its path through Parliament with where it stands now,
/// and the news stories covering it.
struct LawDetailView: View {
    let law: Law
    @State private var detail: Law?
    @State private var selectedStory: Story?
    @Environment(\.openURL) private var openURL

    private var shown: Law { detail ?? law }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                titleBlock
                summaryBlock
                pathBlock
                stories
                links
            }
            .padding(.vertical, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedStory) { story in
            StoryDetailView(story: story)
        }
        .task {
            while !Task.isCancelled {
                if let fresh = try? await LawRepository.shared.fetchLaw(uid: law.uid) { detail = fresh }
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(shown.kindLine)
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
            Text(shown.displayTitle)
                .font(.appTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if shown.shortTitle != nil {
                Text(shown.title.capitalizedFirst)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("En bref")
                .font(.appHeading)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
            Text(shown.summary ?? "Le résumé en langage clair est en préparation.")
                .font(.appBody)
                .foregroundStyle(shown.summary == nil ? AppColors.Adaptive.textMeta : AppColors.Adaptive.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.m)
    }

    private var pathBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Parcours")
                .font(.appHeading)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .padding(.horizontal, AppSpacing.m)
            LawPathView(law: shown)
            if let step = shown.current {
                VStack(alignment: .leading, spacing: AppSpacing.st) {
                    if !shown.isPromulgated, step.code.hasPrefix("AN") || step.code.hasPrefix("SN") {
                        readingProgress(step)
                    }
                    Text(LawExplainer.now(for: shown))
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.m)
                .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
                .padding(.horizontal, AppSpacing.m)
            }
        }
    }

    /// Dépôt · Commission · Séance · Vote for the current reading, with the current moment lit.
    private func readingProgress(_ step: LawStep) -> some View {
        let index = LawExplainer.readingIndex(step)
        return VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("\(step.place) · \(step.label)")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
            HStack(spacing: 4) {
                ForEach(Array(LawExplainer.readingStages.enumerated()), id: \.offset) { i, name in
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(i <= index ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.divider)
                            .frame(height: 4)
                        Text(name)
                            .font(.appCaption)
                            .foregroundStyle(i == index ? AppColors.Adaptive.textPrimary : AppColors.Adaptive.textMeta)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var stories: some View {
        if let stories = shown.stories, !stories.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Dans l'actualité")
                    .font(.appHeading)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .padding(.bottom, AppSpacing.s)
                ForEach(stories) { story in
                    Button { selectedStory = story } label: { StoryRow(story: story) }
                        .buttonStyle(.plain)
                    Divider().overlay(AppColors.Adaptive.divider)
                }
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            if let url = shown.assembleeURL {
                Button("Dossier sur le site de l'Assemblée") { openURL(url) }
            }
            if let senat = shown.senatUrl, let url = URL(string: senat) {
                Button("Dossier sur le site du Sénat") { openURL(url) }
            }
            if let prom = shown.steps.first(where: { $0.code == "PROM" }), let link = prom.url, let url = URL(string: link) {
                Button("Texte publié sur Légifrance") { openURL(url) }
            }
            Text("Données : Assemblée nationale et Sénat, via l'API Parlement de Tricoteuses.")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .font(.appBodyStrong)
        .tint(AppColors.Adaptive.textPrimary)
        .padding(.horizontal, AppSpacing.m)
    }
}

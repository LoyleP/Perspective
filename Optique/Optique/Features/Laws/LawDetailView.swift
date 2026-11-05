import SwiftUI

/// One law: what it does in plain language, its path through Parliament with where it stands now,
/// and the news stories covering it.
struct LawDetailView: View {
    let law: Law
    @State private var detail: Law?
    @State private var selectedStory: Story?
    @State private var showsPath = false
    @Environment(\.openURL) private var openURL

    private var shown: Law { detail ?? law }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    titleBlock
                    summaryBlock
                }
                pathBlock
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    stories
                    links
                }
            }
            .padding(.vertical, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .appBackButton()
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showsPath) {
            LawStepsCarousel(law: shown, selectedStep: .constant(nil), vertical: true)
            .background(AppColors.Adaptive.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .appBackButton()
        }
        .navigationDestination(item: $selectedStory) { story in
            StoryDetailView(story: story)
        }
        .onAppear { Analytics.track(.lawOpen, ["law": law.uid]) }
        .task {
            // The law's page as last received (often prefetched by the list) shows at once.
            if detail == nil, let cached = await LawRepository.shared.cachedLaw(uid: law.uid) { detail = cached }
            while !Task.isCancelled {
                if let fresh = try? await LawRepository.shared.fetchLaw(uid: law.uid) { detail = fresh }
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let name = shown.authorName {
                HStack(spacing: AppSpacing.s) {
                    AsyncImage(url: shown.authorPhoto.flatMap(URL.init(string:))) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppColors.Adaptive.surfaceElevated)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    Text(name)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            } else {
                Text(shown.kindLine)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            Text(shown.displayTitle)
                .font(.appTitle)
                .foregroundStyle(AppColors.Adaptive.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.m)
    }

    /// Plain-language summary, shown only once it exists.
    @ViewBuilder
    private var summaryBlock: some View {
        if let summary = shown.summary {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(summary)
                    .font(.appBody)
                    .lineSpacing(4)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }

    /// Parcours: where the law stands in a plain sentence with the four-stage bar, then one card per
    /// stage (same carousel as the story page's position cards).
    private var pathBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Text(LawExplainer.headline(for: shown))
                    .font(.appHeading)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                LawProgressBar(law: shown, showsLabels: true)
                if let next = LawExplainer.next(for: shown) {
                    Text("Prochaine étape : \(next)")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                }
                Button { showsPath = true } label: {
                    HStack(spacing: AppSpacing.s) {
                        Text("Voir tout le parcours")
                        HeroIcon("chevron-right", size: 16)
                    }
                }
                .buttonStyle(.grayCTA)
                .padding(.top, AppSpacing.s)
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }

    @ViewBuilder
    private var stories: some View {
        if let stories = shown.stories, !stories.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
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
                link("Dossier sur le site de l'Assemblée", url)
            }
            if let senat = shown.senatUrl, let url = URL(string: senat) {
                link("Dossier sur le site du Sénat", url)
            }
            if let prom = shown.steps.first(where: { $0.code == "PROM" }), let target = prom.url, let url = URL(string: target) {
                link("Texte publié sur Légifrance", url)
            }
            Text("Données : Assemblée nationale et Sénat, via l'API Parlement de Tricoteuses.")
                .font(.appCaption)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
        .padding(.horizontal, AppSpacing.m)
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button { openURL(url) } label: {
            HStack(spacing: AppSpacing.s) {
                HeroIcon("link", size: 18)
                Text(title)
                    .font(.appBody)
            }
            .foregroundStyle(AppColors.Adaptive.textPrimary)
        }
        .buttonStyle(.plain)
    }
}

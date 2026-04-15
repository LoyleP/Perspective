import SwiftUI

struct StoryDetailView: View {

    @State private var viewModel: StoryDetailViewModel

    @Environment(SessionState.self) private var session
    @Environment(BookmarkStore.self) private var bookmarks
    @State private var showPaywallBanner = false
    @State private var showPaywallSheet = false
    @State private var selectedArticle: Article?

    init(story: Story) {
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                headerSection

                if let summary = viewModel.story.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.m)
                }

                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    Text("TL;DR")
                        .font(.appTitle2)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .padding(.horizontal, AppSpacing.m)
                    SpectrumSummaryView(spectrumSummary: viewModel.story.spectrumSummary)
                }

                NavigationLink(destination: StoryThreadView(story: viewModel.story)) {
                    HStack(spacing: AppSpacing.m) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Fil de l'histoire")
                                .font(.appTitle2)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                            Text("Voir les événements dans l'ordre chronologique")
                                .font(.appFootnote)
                                .foregroundStyle(AppColors.Adaptive.textMeta)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                    .padding(AppSpacing.m)
                    .background(AppColors.Adaptive.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.ml).stroke(AppColors.stroke, lineWidth: 1))
                    .padding(.horizontal, AppSpacing.m)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    Text("Articles analysés")
                        .font(.appTitle2)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .padding(.horizontal, AppSpacing.m)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: AppSpacing.m) {
                            ForEach(Array(viewModel.story.articles.prefix(30))) { article in
                                AnalyzedArticleCard(article: article) {
                                    selectedArticle = article
                                }
                                .containerRelativeFrame(.horizontal) { w, _ in w * 0.78 }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, AppSpacing.m, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                }

                let sourcedArticles = viewModel.story.articles.filter { $0.source != nil }
                if !sourcedArticles.isEmpty {
                    NavigationLink(destination: SourcesView()) {
                        VStack(alignment: .leading, spacing: AppSpacing.m) {
                            Text("Propriété des médias")
                                .font(.appTitle2)
                                .foregroundStyle(AppColors.Adaptive.textPrimary)
                                .padding(.horizontal, AppSpacing.m)
                            OwnershipBreakdownView(articles: sourcedArticles)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let coverage = viewModel.story.coverage, coverage.totalCount > 0 {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        Text("Couverture politique")
                            .font(.appTitle2)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .padding(.horizontal, AppSpacing.m)
                        CoverageChartView(coverage: coverage)
                            .padding(.horizontal, AppSpacing.m)
                    }
                }
            }
            .padding(.top, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .tint(AppColors.Adaptive.textPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    bookmarks.toggle(viewModel.story)
                } label: {
                    Image(systemName: bookmarks.isBookmarked(viewModel.story) ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.Adaptive.background, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if showPaywallBanner {
                PaywallBannerView(isPresented: $showPaywallBanner) {
                    showPaywallSheet = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallView()
        }
        .sheet(item: $selectedArticle) { article in
            ArticleBrowserView(
                articles: Array(viewModel.story.articles.prefix(30)),
                initialArticle: article
            )
        }
        .onAppear {
            session.recordStoryOpen()
            if session.shouldShowPaywall {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showPaywallBanner = true
                }
            }
            Task { await viewModel.triggerSummaryGeneration() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            if let coverage = viewModel.story.coverage, coverage.totalCount > 0 {
                CoverageTagsView(coverage: coverage)
            }
            HStack(alignment: .top, spacing: AppSpacing.m) {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    Text(viewModel.story.title)
                        .font(.appTitle2)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    sourceMetaRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let url = firstImageURL {
                    Color.clear
                        .overlay(
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFill()
                                } else {
                                    AppColors.Adaptive.placeholder
                                }
                            }
                        )
                        .clipped()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
                }
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }

    private var sourceMetaRow: some View {
        HStack(spacing: 6) {
            let sources = uniqueSources
            if !sources.isEmpty {
                avatarStack(sources)
            }
            Text("•")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .accessibilityHidden(true)
            Text("\(viewModel.story.articles.count) articles analysés")
                .font(.appFootnote)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        }
    }

    private func avatarStack(_ sources: [Source]) -> some View {
        let visible = Array(sources.prefix(2))
        let extra = sources.count - visible.count
        return HStack(spacing: 6) {
            HStack(spacing: -4) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { i, src in
                    avatarCircle(src).zIndex(Double(visible.count - i))
                }
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
    }

    private func avatarCircle(_ source: Source) -> some View {
        Group {
            if let s = source.logoURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        Color.clear.overlay(img.resizable().scaledToFill()).clipped()
                    } else {
                        sourceInitial(source)
                    }
                }
            } else {
                sourceInitial(source)
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private func sourceInitial(_ source: Source) -> some View {
        let lean = source.lean
        return ZStack {
            Circle().fill(lean?.spectrumColor ?? AppColors.Adaptive.placeholder)
            Text(String(source.name.prefix(1)).uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(lean?.tagTextColor ?? AppColors.Adaptive.textSecondary)
        }
    }

    // MARK: - Helpers

    private var firstImageURL: URL? {
        viewModel.story.articles.compactMap { $0.imageURL.flatMap(URL.init) }.first
    }

    private var uniqueSources: [Source] {
        var seen = Set<UUID>()
        return viewModel.story.articles.compactMap { $0.source }
            .filter { seen.insert($0.id).inserted }
    }
}

#if DEBUG
#Preview("StoryDetailView") {
    NavigationStack {
        StoryDetailView(story: PreviewData.story)
    }
    .environment(SessionState())
}
#endif


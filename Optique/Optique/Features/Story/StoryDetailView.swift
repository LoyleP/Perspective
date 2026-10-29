import SwiftUI

struct StoryDetailView: View {

    @State private var viewModel: StoryDetailViewModel

    @Environment(SessionState.self) private var session
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var readingHistory
    @State private var showPaywallBanner = false
    @State private var showPaywallSheet = false
    @State private var selectedArticle: Article?
    @State private var showAllArticles = false
    @State private var showThread = false

    private let collapsedArticleCount = 5

    init(story: Story) {
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
    }

    private var story: Story { viewModel.story }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if let coverage = story.computedCoverage, coverage.totalCount > 0 {
                        SpectrumBar(coverage: coverage, style: .detailed, sources: story.sources)
                            .padding(AppSpacing.m)
                            .cardSurface()
                    }

                    if let summary = story.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.appBody)
                            .foregroundStyle(AppColors.Adaptive.textBody)
                            .lineSpacing(4)
                    }

                    PerspectivesView(
                        summary: story.spectrumSummary,
                        isUnavailable: viewModel.summaryUnavailable
                    )

                    articlesSection

                    threadLink
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.l)

                let sourced = story.articles.filter { $0.source != nil }
                if !sourced.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        SectionHeader(title: "Propriété des médias", subtitle: "Qui possède les médias qui en parlent")
                            .padding(.horizontal, AppSpacing.m)
                        OwnershipBreakdownView(articles: sourced)
                    }
                    .padding(.top, AppSpacing.xl)
                }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .ignoresSafeArea(edges: .top)
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Partager")
                }
                Button {
                    bookmarks.toggle(story)
                } label: {
                    Image(systemName: bookmarks.isBookmarked(story) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(bookmarks.isBookmarked(story) ? "Retirer des enregistrés" : "Enregistrer")
            }
        }
        .tint(AppColors.Adaptive.textPrimary)
        .navigationDestination(isPresented: $showThread) {
            StoryThreadView(story: story)
        }
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
            ArticleBrowserView(articles: sortedArticles, initialArticle: article)
        }
        .onAppear {
            session.recordStoryOpen()
            readingHistory.recordOpen(story)
            if session.shouldShowPaywall {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showPaywallBanner = true
                }
            }
        }
        .task { await viewModel.triggerSummaryGeneration() }
    }

    // MARK: - Header

    /// Lead photo (stretches when pulled down), fading into the page; the headline sits below it.
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            RemoteImage(url: story.leadImageURL, tint: leadTint)
                .frame(maxWidth: .infinity)
                .frame(height: story.leadImageURL == nil ? 120 : 320)
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.45), location: 0),
                            .init(color: .clear, location: 0.3),
                            .init(color: AppColors.Adaptive.background.opacity(0.6), location: 0.8),
                            .init(color: AppColors.Adaptive.background, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
                .visualEffect { effect, proxy in
                    let pull = max(proxy.frame(in: .scrollView).minY, 0)
                    return effect.scaleEffect(1 + pull / max(proxy.size.height, 1), anchor: .bottom)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Text(story.metaLine)
                    .overlineStyle()
                Text(story.title)
                    .font(.appLargeTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }

    private var leadTint: Color? {
        story.computedCoverage.flatMap { PoliticalLean(rawValue: $0.dominantLean)?.spectrumColor }
    }

    // MARK: - Articles

    /// Articles ordered left → right, newest first within a position.
    private var sortedArticles: [Article] {
        story.articles.sorted {
            let l = $0.source?.politicalLean ?? 4, r = $1.source?.politicalLean ?? 4
            return l != r ? l < r : $0.publishedAt > $1.publishedAt
        }
    }

    private var articlesSection: some View {
        let articles = sortedArticles
        let visible = showAllArticles ? articles : Array(articles.prefix(collapsedArticleCount))
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Les articles", subtitle: "De la gauche vers la droite")
                .padding(.bottom, AppSpacing.xs)
            ForEach(visible) { article in
                Button {
                    selectedArticle = article
                } label: {
                    ArticleSourceRow(article: article)
                }
                .buttonStyle(CardPressStyle())
                Divider().overlay(AppColors.Adaptive.divider)
            }
            if articles.count > collapsedArticleCount {
                Button(showAllArticles ? "Afficher moins" : "Voir les \(articles.count) articles") {
                    withAnimation(.snappy) { showAllArticles.toggle() }
                }
                .buttonStyle(.optiqueSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.m)
            }
        }
    }

    // MARK: - Thread

    private var threadLink: some View {
        Button {
            showThread = true
        } label: {
            HStack(spacing: AppSpacing.m) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.appTitle3)
                    .foregroundStyle(AppColors.Brand.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fil de l'histoire")
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text("Depuis \(story.firstPublishedAt.relativeToNowFrench()) · mis à jour \(story.lastUpdatedAt.relativeToNowFrench())")
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appFootnote)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
            }
            .padding(AppSpacing.m)
            .cardSurface()
        }
        .buttonStyle(CardPressStyle())
    }
}

// MARK: - Article row

/// Source logo, name, position and time above the article headline.
private struct ArticleSourceRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.st) {
            if let source = article.source {
                SourceAvatarView(source: source, size: 32)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(article.source?.name ?? "Source")
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    if let lean = article.source?.lean {
                        Circle().fill(lean.spectrumColor).frame(width: 6, height: 6)
                        Text(lean.shortLabel)
                            .font(.appFootnote)
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                    Spacer(minLength: AppSpacing.s)
                    Text(article.publishedAt.relativeToNowFrench())
                        .font(.appFootnote)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(article.title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.Adaptive.textBody)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, AppSpacing.st)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("StoryDetailView") {
    NavigationStack {
        StoryDetailView(story: PreviewData.story)
    }
    .environment(SessionState())
    .environment(BookmarkStore())
    .environment(ReadingHistoryStore())
}
#endif

#if DEBUG
#Preview("StoryDetailView – no image, single source") {
    NavigationStack { StoryDetailView(story: Fixtures.stories[9]) }
        .environment(SessionState())
        .environment(BookmarkStore())
        .environment(ReadingHistoryStore())
}
#endif

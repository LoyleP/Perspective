import SwiftUI

struct StoryDetailView: View {

    @State private var viewModel: StoryDetailViewModel

    @Environment(SessionState.self) private var session
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var readingHistory
    @Environment(\.tabBarState) private var tabBar
    @Environment(\.commentStore) private var comments
    @State private var showPaywallBanner = false
    @State private var showPaywallSheet = false
    /// Side whose articles are shown in the sheet (opened by tapping a card).
    @State private var sheetSide: PoliticalLean?
    @State private var showComments = false

    init(story: Story) {
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
    }

    private var story: Story { viewModel.story }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if let summary = story.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .lineSpacing(4)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, AppSpacing.l)
                }

                if story.computedCoverage != nil {
                    SideCarouselView(
                        story: story,
                        isSummaryUnavailable: viewModel.summaryUnavailable
                    ) { side in
                        sheetSide = side
                    }
                    .padding(.top, AppSpacing.l)
                }

                discussion
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.top, AppSpacing.xl)

                StoryThreadSection(articles: story.articles)
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.top, AppSpacing.xl)

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
        .shrinksTabBarOnScroll()
        .ignoresSafeArea(edges: .top)
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        HeroIcon("arrow-up-on-square", size: 22)
                    }
                    .accessibilityLabel("Partager")
                }
                Button {
                    bookmarks.toggle(story)
                } label: {
                    HeroIcon("bookmark", solid: bookmarks.isBookmarked(story), size: 22)
                }
                .accessibilityLabel(bookmarks.isBookmarked(story) ? "Retirer des enregistrés" : "Enregistrer")
            }
        }
        .tint(AppColors.Adaptive.textPrimary)
        .overlay(alignment: .bottom) {
            if showPaywallBanner {
                PaywallBannerView(isPresented: $showPaywallBanner) {
                    showPaywallSheet = true
                }
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallView()
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(story: story)
        }
        .sheet(item: $sheetSide) { side in
            SideArticlesSheet(side: side, articles: articles(for: side))
        }
        .onAppear {
            session.recordStoryOpen()
            readingHistory.recordOpen(story)
            if session.shouldShowPaywall {
                withAnimation(.app) {
                    showPaywallBanner = true
                }
            }
        }
        .onDisappear { tabBar.isCompact = false }
        .task { await viewModel.triggerSummaryGeneration() }
    }

    // MARK: - Discussion

    /// Entry to the comments sheet: title with the count, then a field-like button.
    private var discussion: some View {
        let count = comments.count(for: story.id)
        return VStack(alignment: .leading, spacing: AppSpacing.st) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                Text("Discussion")
                    .font(.appHeading)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if count > 0 {
                    Text("\(count)")
                        .font(.appCaption)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
            Button { showComments = true } label: {
                HStack(spacing: AppSpacing.st) {
                    Image("ProfilePlaceholder")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    Text("Ajouter un commentaire…")
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                    Spacer(minLength: 0)
                }
                .padding(.leading, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs)
                .frame(minHeight: 44)
                .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ouvrir la discussion")
        }
    }

    // MARK: - Header

    /// Lead photo (stretches when pulled down); the headline sits below it.
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            // Color.clear sizes to the proposed width; the filled photo is an overlay, so its
            // overflow can't widen the layout.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: story.leadImageURL == nil ? 120 : 320)
                .overlay { RemoteImage(url: story.leadImageURL, tint: leadTint) }
                .clipped()
                .visualEffect { effect, proxy in
                    let pull = max(proxy.frame(in: .scrollView).minY, 0)
                    return effect.scaleEffect(1 + pull / max(proxy.size.height, 1), anchor: .bottom)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Text(story.metaLine)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                Text(story.title)
                    .font(.appTitle)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(3)
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

    /// Articles from outlets on `side`, newest first.
    private func articles(for side: PoliticalLean) -> [Article] {
        story.articles
            .filter { PoliticalLean.from($0.source?.politicalLean ?? 4) == side }
            .sorted { $0.publishedAt > $1.publishedAt }
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

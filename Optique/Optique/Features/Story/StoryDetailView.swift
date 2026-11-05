import SwiftUI

struct StoryDetailView: View {

    @State private var viewModel: StoryDetailViewModel

    @Environment(SessionState.self) private var session
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var readingHistory
    @Environment(\.tabBarState) private var tabBar
    @Environment(\.commentStore) private var comments
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywallSheet = false
    /// Free topics left, shown for a few seconds when the allowance is nearly used.
    @State private var toastRemaining: Int?
    /// Side whose articles are shown in the sheet (opened by tapping a card).
    @State private var sheetSide: PoliticalLean?
    /// Set to open the comments sheet; carries whether to start with the keyboard up.
    @State private var commentsRequest: CommentsRequest?

    init(story: Story) {
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
    }

    private var story: Story { viewModel.story }

    // MARK: - Reading limit

    private var isLocked: Bool { session.isLocked(story.id) }

    /// Past the free allowance the page keeps its headline and standfirst; everything below is a blurred
    /// preview behind the limit card.
    @ViewBuilder
    private func gated<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isLocked {
            // One container, so the blur, the fade and the card apply once to the whole preview.
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxHeight: 440, alignment: .top)
                .clipped()
                .blur(radius: 7)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay(alignment: .top) {
                    ReadingLimitGate(
                        used: session.freeLimit,
                        total: session.freeLimit,
                        onUpgrade: { showPaywallSheet = true },
                        onBack: { dismiss() }
                    )
                    .padding(.top, AppSpacing.l)
                }
        } else {
            VStack(alignment: .leading, spacing: 0) { content() }
        }
    }

    private func showFreeToastIfNeeded() {
        guard AppConfig.paywallEnabled, !session.isPremium, !session.isLocked(story.id),
              session.remainingFree <= 2 else { return }
        let remaining = session.remainingFree
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            toastRemaining = remaining
            Haptics.lightImpact()
            try? await Task.sleep(for: .seconds(4))
            toastRemaining = nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                // What happened, in one sentence, right under the headline.
                if let summary = story.standfirst {
                    Text(summary)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .lineSpacing(4)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, AppSpacing.st)
                }

                gated {
                if story.computedCoverage != nil {
                    SideCarouselView(
                        story: story,
                        isSummaryUnavailable: viewModel.summaryUnavailable
                    ) { side in
                        Analytics.track(.sideArticlesOpen, ["story": story.id.uuidString, "side": side.label])
                        sheetSide = side
                    }
                    .padding(.top, AppSpacing.l)
                }

                if AppConfig.commentsEnabled {
                    discussion
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, AppSpacing.xl)
                }

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
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .shrinksTabBarOnScroll()
        // The nav bar would swallow taps meant for the area outside the comments panel.
        .toolbar(commentsRequest == nil ? .automatic : .hidden, for: .navigationBar)
        .appBackButton(swipeDisabled: commentsRequest != nil)
        .ignoresSafeArea(edges: .top)
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        NavIcon("square.and.arrow.up")
                    }
                    .accessibilityLabel("Partager")
                }
                Button {
                    bookmarks.toggle(story)
                } label: {
                    NavIcon(bookmarks.isBookmarked(story) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(bookmarks.isBookmarked(story) ? "Retirer des enregistrés" : "Enregistrer")
                .sensoryFeedback(trigger: bookmarks.isBookmarked(story)) { _, saved in
                    saved ? .success : .impact(weight: .light)
                }
            }
        }
        .tint(AppColors.Adaptive.textPrimary)
        .overlay(alignment: .bottom) {
            if let remaining = toastRemaining {
                FreeTopicToast(remaining: remaining) {
                    toastRemaining = nil
                    showPaywallSheet = true
                }
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.15), value: isLocked)
        .sheet(isPresented: $showPaywallSheet) {
            PaywallView()
        }
        .overlay {
            // The panel runs its own entry and exit (backdrop included); this only mounts it.
            if let request = commentsRequest {
                CommentsSheet(story: story, startsTyping: request.typing) {
                    commentsRequest = nil
                }
                .id(request.id)
                .transition(.identity)
            }
        }
        .sheet(item: $sheetSide) { side in
            SideArticlesSheet(side: side, articles: articles(for: side))
        }
        .onAppear {
            session.registerOpen(story.id)
            Analytics.track(.storyOpen, ["story": story.id.uuidString, "has_summary": story.spectrumSummary == nil ? "0" : "1"])
            readingHistory.recordOpen(story)
            showFreeToastIfNeeded()
        }
        .onDisappear { tabBar.isCompact = false }
        .task { await viewModel.triggerSummaryGeneration() }
    }

    // MARK: - Discussion

    /// The first three comments, a "Voir plus" that opens the sheet, and a field-like button to write one.
    private var discussion: some View {
        let count = comments.count(for: story.id)
        let all = comments.topLevel(for: story.id)
        let shown = Array(all.prefix(3))
        return VStack(alignment: .leading, spacing: AppSpacing.st) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                Text("Commentaires")
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

            ForEach(shown) { comment in
                commentPreview(comment)
            }

            Button { openComments(typing: true) } label: {
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
                .background(AppColors.Adaptive.cardSurface, in: Capsule())
                .overlay(Capsule().stroke(Color(light: AppColors.Zinc.Hex.z50, dark: AppColors.Zinc.Hex.z800), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ajouter un commentaire")
        }
    }

    private func openComments(typing: Bool) {
        commentsRequest = CommentsRequest(typing: typing)
    }

    private func commentPreview(_ comment: Comment) -> some View {
        let replyCount = comments.replies(to: comment.id).count
        return HStack(alignment: .top, spacing: AppSpacing.st) {
            CommentAvatar(author: comment.author, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.s) {
                    Text(comment.author)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text(comment.createdAt.relativeToNowFrench())
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(comment.text)
                    .font(.appBody)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if replyCount > 0 {
                    Text(replyCount == 1 ? "1 réponse" : "\(replyCount) réponses")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if comment.likes > 0 {
                VStack(spacing: 2) {
                    HeroIcon("heart", solid: comment.likedByMe, size: 18)
                    Text("\(comment.likes)").font(.appCaption).monospacedDigit()
                }
                .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openComments(typing: false) }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Header

    /// Lead photo (stretches when pulled down); the headline sits below it.
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            // Color.clear sizes to the proposed width; the filled photo is an overlay, so its
            // overflow can't widen the layout.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: story.leadImageURL == nil ? 120 : 340)
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

private struct CommentsRequest: Identifiable {
    let id = UUID()
    let typing: Bool
}

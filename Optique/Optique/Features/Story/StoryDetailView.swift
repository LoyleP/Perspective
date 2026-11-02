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
    /// Set to open the comments sheet; carries whether to start with the keyboard up.
    @State private var commentsRequest: CommentsRequest?

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
        // The nav bar would swallow taps meant for the area outside the comments panel.
        .toolbar(commentsRequest == nil ? .automatic : .hidden, for: .navigationBar)
        .background(SwipeBackDisabler(isDisabled: commentsRequest != nil))
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

            if count > shown.count {
                Button { openComments(typing: false) } label: {
                    Text("Voir plus")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                .buttonStyle(.plain)
                .padding(.vertical, AppSpacing.xs)
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
                .overlay(Capsule().stroke(AppColors.stroke, lineWidth: 1))
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

private struct CommentsRequest: Identifiable {
    let id = UUID()
    let typing: Bool
}

/// Swiping right goes back to the previous page, except while the comments panel is open (its
/// drag-to-close could otherwise also trigger it and close the story). Uses a plain view that finds its navigation controller through the
/// responder chain (a background view controller is not part of that hierarchy in SwiftUI).
private struct SwipeBackDisabler: UIViewRepresentable {
    let isDisabled: Bool

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.isDisabled = isDisabled
        view.apply()
    }

    final class Probe: UIView {
        private weak var navigation: UINavigationController?
        var isDisabled = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        private func findNavigationController() -> UINavigationController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController {
                    if let nav = controller.navigationController { return nav }
                }
                responder = current.next
            }
            return nil
        }

        func apply() {
            if navigation == nil { navigation = findNavigationController() }
            setSwipeBack(enabled: !isDisabled)
        }

        /// Every swipe-back recognizer: the edge one, iOS 26's full-width one, and the parallax
        /// transition pans UIKit puts on the navigation controller's view.
        private func swipeBackRecognizers() -> [UIGestureRecognizer] {
            guard let navigation else { return [] }
            var recognizers = (navigation.view.gestureRecognizers ?? []).filter {
                String(describing: type(of: $0)).contains("ParallaxTransitionPan")
            }
            if let edge = navigation.interactivePopGestureRecognizer { recognizers.append(edge) }
            if #available(iOS 26.0, *), let content = navigation.interactiveContentPopGestureRecognizer {
                recognizers.append(content)
            }
            return recognizers
        }

        private func setSwipeBack(enabled: Bool) {
            for recognizer in swipeBackRecognizers() { recognizer.isEnabled = enabled }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                apply()
            } else {
                setSwipeBack(enabled: true)
                navigation = nil
            }
        }

        // SwiftUI can switch the gesture back on during layout passes; keep it off.
        override func layoutSubviews() {
            super.layoutSubviews()
            if window != nil { apply() }
        }
    }
}

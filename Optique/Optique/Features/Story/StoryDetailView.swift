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
    /// Set to open the comments sheet; carries whether to start with the keyboard up.
    @State private var commentsRequest: CommentsRequest?

    init(story: Story) {
        _viewModel = State(initialValue: StoryDetailViewModel(story: story))
    }

    @State private var isAtTop = false
    @State private var dragStartedAtTop: Bool?

    private var story: Story { viewModel.story }

    // MARK: - Reading limit

    /// Fixed when the page first appears: other topics opened meanwhile, or the day changing, never flip this
    /// page between locked and open. Until then (the very first frame) it is read without counting anything.
    @State private var admission: SessionState.Access?
    private var access: SessionState.Access {
        guard AppConfig.paywallEnabled, !session.isPremium else { return .unlimited }   // Optique+ unlocks at once
        return admission ?? session.access(for: story.id)
    }
    private var isLocked: Bool { access.isLocked }
    @State private var toastTask: Task<Void, Never>?

    /// Past the free allowance the page keeps its headline only; the bullet points and everything below is a blurred
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

    /// The heads-up under the free allowance, shown only on a topic opened for the first time today, never on
    /// a locked one nor on a topic opened again.
    private func showFreeToastIfNeeded(for access: SessionState.Access) {
        guard case .free(let position, let isNew) = access, isNew else { return }
        let remaining = session.freeLimit - (position + 1)
        guard remaining <= 2 else { return }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            toastRemaining = remaining
            Haptics.lightImpact()
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            toastRemaining = nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                // What happened, in one sentence, right under the headline.
                if let summary = story.standfirst, !isLocked {
                    DescriptionBullets(text: summary)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, AppSpacing.l)
                }

                gated {
                if story.computedCoverage != nil {
                    CoverageSummaryView(story: story)
                        .padding(.top, AppSpacing.l)
                }

                if !story.articles.isEmpty {
                    MediaCardsSection(articles: story.articles)
                        .padding(.top, AppSpacing.xxl)
                }

                if AppConfig.commentsEnabled {
                    discussion
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.top, AppSpacing.xxl)
                }

                let sourced = story.articles.filter { $0.source != nil }
                if !sourced.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        SectionHeader(title: "Propriété des médias", subtitle: "Qui possède les médias qui en parlent")
                            .padding(.horizontal, AppSpacing.m)
                        OwnershipBreakdownView(articles: sourced)
                    }
                    .padding(.top, AppSpacing.xxl)
                }
                }
            }
            .padding(.bottom, AppSpacing.xxl)
            .noTopBounce()
        }
        .shrinksTabBarOnScroll()
        .tabBarClearance()
        .trackingScrollTop { isAtTop = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { _ in
                    if dragStartedAtTop == nil { dragStartedAtTop = isAtTop }
                }
                .onEnded { value in
                    defer { dragStartedAtTop = nil }
                    guard dragStartedAtTop == true, commentsRequest == nil,
                          value.translation.height > abs(value.translation.width) * 1.5,
                          value.translation.height > 70 || value.predictedEndTranslation.height > 250 else { return }
                    dismiss()
                }
        )
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
                        NavIcon("share")
                    }
                    .accessibilityLabel("Partager")
                }
                Button {
                    bookmarks.toggle(story)
                } label: {
                    NavIcon("bookmark", filled: bookmarks.isBookmarked(story))
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
                .transition(.rise)
            }
        }
        .animation(.enter, value: isLocked)
        .fullScreenCover(isPresented: $showPaywallSheet) {
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
        .onAppear {
            // Counted once per visit to this page, however many times it reappears (back from a sheet, a cancelled swipe).
            if admission == nil {
                let granted = session.admit(story.id)
                admission = granted
                showFreeToastIfNeeded(for: granted)
            }
            Analytics.track(.storyOpen, ["story": story.id.uuidString, "has_summary": story.spectrumSummary == nil ? "0" : "1"])
            readingHistory.recordOpen(story)
        }
        .onDisappear {
            tabBar.isCompact = false
            toastTask?.cancel()
            toastRemaining = nil
        }
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
                    .typeStyle(.section)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if count > 0 {
                    Text("\(count)")
                        .typeStyle(.meta)
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
                        .typeStyle(.body)
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
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                    Text(comment.createdAt.relativeToNowFrench())
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(comment.text)
                    .typeStyle(.body)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if replyCount > 0 {
                    Text(replyCount == 1 ? "1 réponse" : "\(replyCount) réponses")
                        .typeStyle(.meta)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if comment.likes > 0 {
                VStack(spacing: 2) {
                    LucideIcon("heart", filled: comment.likedByMe, size: 18)
                    Text("\(comment.likes)").typeStyle(.meta).monospacedDigit()
                }
                .foregroundStyle(AppColors.Adaptive.textMeta)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openComments(typing: false) }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Header

    /// Lead photo; the headline sits below it.
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            // Color.clear sizes to the proposed width; the filled photo is an overlay, so its
            // overflow can't widen the layout.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: story.leadImageURL == nil ? 220 : 340)
                .overlay { RemoteImage(url: story.leadImageURL, tint: leadTint, topic: story.placeholderTopic, alternates: story.imageAlternates) }
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.st) {
                Text(story.timeLine)
                    .typeStyle(.meta)
                    .foregroundStyle(AppColors.Adaptive.textMeta)
                Text(story.title)
                    .typeStyle(.display)
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

private extension View {
    /// Reports whether the scroll view rests at its top edge (iOS 18+; before that it reports nothing).
    @ViewBuilder
    func trackingScrollTop(_ update: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top <= 1 } action: { _, top in
                update(top)
            }
        } else {
            self
        }
    }
}

/// The description as bullet points, one per line. Descriptions written before the bullet format are
/// split into sentences instead.
private struct DescriptionBullets: View {
    let text: String

    private var bullets: [String] {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "•-– ").union(.whitespaces)) }
            .filter { !$0.isEmpty }
        if lines.count > 1 { return Array(lines.prefix(4)) }
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, _ in
            if let sub = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty { sentences.append(sub) }
        }
        return Array(sentences.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.s) {
                    Circle()
                        .fill(AppColors.Adaptive.textMeta)
                        .frame(width: 5, height: 5)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 5 }
                        .accessibilityHidden(true)
                    Text(bullet)
                        .typeStyle(.standfirst)
                        .foregroundStyle(AppColors.Adaptive.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

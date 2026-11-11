import SwiftUI

/// "À la une": a row of topic pills over horizontally swiping pages, one page per topic. Tapping a
/// pill slides to its page and swiping a page moves the highlighted pill with it.
struct FeedView: View {

    @State private var topic: StoryTopic? = .tout
    @State private var pillsScroll = PillsScroll()
    @State private var search = FeedSearchState()
    @State private var showsProfile = false
    /// Where the pages are, in pages (1.5 is halfway between the second and the third), so the black pill follows a swipe.
    @State private var pageProgress = PageProgress()
    @State private var deepLinkStory: Story?
    @Namespace private var transition
    private let notificationManager = NotificationManager.shared

    private var topics: [StoryTopic] {
        let last: [StoryTopic] = [.societe, .culture, .sport]
        return [.tout] + StoryTopic.selectable.filter { !last.contains($0) } + last
    }
    private var current: StoryTopic { topic ?? .tout }

    var body: some View {
        ScrollAwayPills(model: pillsScroll) {
            TopicPills(topics: topics, selection: Binding(get: { current }, set: { topic = $0 }), tracker: pageProgress)
        } pages: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element) { index, page in
                        // Only the page on screen and its neighbours load, so a swipe lands on stories.
                        let currentIndex = topics.firstIndex(of: current) ?? 0
                        FeedTopicPage(topic: page, isNear: abs(index - currentIndex) <= 1, isCurrent: page == current, transition: transition)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $topic)
            .trackingPageProgress { pageProgress.value = $0 }
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        // The feed leaves room for the header; the search page covers the feed while searching.
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 44) }
        .overlay {
            if search.isActive {
                FeedSearchContent(search: search)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            FeedHeader(search: search) { showsProfile = true }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showsProfile) { ProfileView() }
        .navigationDestination(for: StoryTopic.self) { topic in
            TopicStoriesView(topic: topic)
        }
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story)
                .zoomDestination(id: ZoomID(topic: current, story: story.id), in: transition)
        }
        // Notification tapped: open its story on top of the feed.
        .navigationDestination(item: $deepLinkStory) { story in
            StoryDetailView(story: story)
        }
        .onChange(of: notificationManager.pendingStoryID, initial: true) { _, storyID in
            guard let storyID else { return }
            notificationManager.pendingStoryID = nil
            Task { deepLinkStory = try? await StoryRepository.shared.fetchStory(id: storyID) }
        }
        .onChange(of: topic) { _, _ in Haptics.selection() }
        .task { await notificationManager.checkAuthorizationStatus() }
    }
}

/// One topic's stories.
private struct FeedTopicPage: View {
    let topic: StoryTopic
    let isNear: Bool
    let isCurrent: Bool
    let transition: Namespace.ID

    @State private var viewModel: FeedViewModel
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var readingHistory
    @AppStorage("alertsPromptDismissed") private var alertsPromptDismissed = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var visibleCount = 6
    /// Becomes true on the first scroll; the lower part of the feed is only built from then on.
    @State private var showsRest = false
    /// True once the page builds its stories: until then it shows the placeholder, not "no stories". A neighbouring
    /// page builds a moment after the swipe settled, never during it; the page on screen builds at once.
    @State private var started = false
    /// The coverage bar's callout shows once, on the first feed after onboarding.
    @AppStorage("coverageTipSeen") private var coverageTipSeen = false
    @State private var showsCoverageTip = false
    /// The latest edition of the Brief, shown above the lead story on À la une.
    @State private var edition: Edition?
    @State private var playing: Edition?
    /// The story chosen in the Brief: pushed once the player has closed.
    @State private var storyFromBrief: Story?
    @State private var pendingBriefStory: Story?
    @AppStorage("lastSeenEdition") private var lastSeenEdition = ""
    private let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init(topic: StoryTopic, isNear: Bool, isCurrent: Bool, transition: Namespace.ID) {
        self.topic = topic
        self.isNear = isNear
        self.isCurrent = isCurrent
        self.transition = transition
        _viewModel = State(initialValue: FeedViewModel(topic: topic))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollsAwayPills(isCurrent: isCurrent)
        .revealsRestOnScroll(showsRest) { showsRest = true }
        .refreshable {
            await viewModel.refresh()
            if topic == .tout { edition = await StoryRepository.shared.fetchLatestEdition() }
        }
        .shrinksTabBarOnScroll()
        .fullScreenCover(item: $playing, onDismiss: {
            if let story = pendingBriefStory { pendingBriefStory = nil; storyFromBrief = story }
        }) { edition in
            EditionPlayerView(edition: edition) { pendingBriefStory = $0 }
        }
        .navigationDestination(item: $storyFromBrief) { StoryDetailView(story: $0) }
        .task {
            if topic == .tout { edition = await StoryRepository.shared.fetchLatestEdition() }
        }
        .task(id: isNear) {
            guard isNear else { return }
            // The data comes first, off the swipe; the cards are built when it is there.
            await viewModel.load()
            if !isCurrent { try? await Task.sleep(for: .milliseconds(450)) }
            started = true
        }
        .onChange(of: isCurrent) { _, now in if now { started = true } }
        // The first screenful is built first; the rest of the page follows once it is up.
        .task(id: started) {
            guard started, visibleCount < 12 else { return }
            try? await Task.sleep(for: .milliseconds(350))
            visibleCount = 12
        }
        // News goes stale fast: coming back to the app reloads a feed older than a few minutes.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isNear { Task { await viewModel.refreshIfStale() } }
        }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if !started || (viewModel.isLoading && viewModel.allStories.isEmpty) {
            loadingSkeleton
        } else if let error = viewModel.error, viewModel.allStories.isEmpty {
            unavailable(
                title: "Impossible de charger",
                message: error.localizedDescription,
                icon: "wifi-off",
                action: "Réessayer"
            )
        } else if viewModel.stories.isEmpty {
            unavailable(
                title: "Aucune actualité",
                message: "Aucun sujet n'est disponible pour le moment.",
                icon: "newspaper",
                action: "Rafraîchir"
            )
        } else {
            stories
        }
    }

    // MARK: - Stories

    @ViewBuilder
    private var stories: some View {
        if topic != .tout {
            topicStories
        } else {
            frontStories
        }
    }

    @ViewBuilder
    private var topicStories: some View {
        TopicMasthead(topic: topic, count: viewModel.stories.count)

        if showsAlertsPrompt {
            alertsPrompt
                .padding(.top, AppSpacing.l)
        }

        TopicBody(
            topic: topic,
            stories: Array(viewModel.stories.prefix(visibleCount)),
            link: { story, label in
                AnyView(
                    storyLink(story) {
                        label.zoomSource(id: ZoomID(topic: topic, story: story.id), in: transition)
                    }
                )
            }
        )
        .padding(.top, AppSpacing.l)

        if visibleCount < viewModel.stories.count {
            Button("Voir plus") { visibleCount += 12 }
                .buttonStyle(.optiqueSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.l)
        }
    }

    @ViewBuilder
    private var frontStories: some View {
        if let edition {
            EditionCard(edition: edition) {
                lastSeenEdition = edition.id.uuidString
                playing = edition
            }
            .padding(.bottom, AppSpacing.l)
        }

        if let hero = viewModel.cetteSemanineHero {
            storyLink(hero) {
                StoryHeroCard(story: hero)
                    .zoomSource(id: ZoomID(topic: topic, story: hero.id), in: transition)
            }
            // A zero-height anchor on the card's bottom edge: the callout hangs from it, tail up at the bar.
            // It is always there and scales from its own tail tip (top centre), in and out.
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(height: 0)
                    .overlay(alignment: .top) {
                        Button {
                            withAnimation(.emphasis) { showsCoverageTip = false }
                        } label: {
                            CoverageTip()
                                .scaleEffect(showsCoverageTip ? 1 : 0.001, anchor: .top)
                                .opacity(showsCoverageTip ? 1 : 0)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .offset(y: -44)
                        .allowsHitTesting(showsCoverageTip)
                        .accessibilityHidden(!showsCoverageTip)
                    }
            }
            .zIndex(1)
            #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: DebugMenu.coverageTipNotification)) { _ in
                guard isCurrent else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    withAnimation(.emphasis) { showsCoverageTip = true }
                }
            }
            #endif
            .task(id: hero.id) {
                guard isCurrent, !coverageTipSeen else { return }
                // Wait for the splash to be gone, then a beat, so the callout is seen arriving.
                var waited = 0
                while !LaunchGate.shared.entered, waited < 80 {
                    try? await Task.sleep(for: .milliseconds(100))
                    waited += 1
                }
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                coverageTipSeen = true
                withAnimation(.emphasis) { showsCoverageTip = true }
            }
        }

        if showsAlertsPrompt {
            alertsPrompt
                .padding(.top, AppSpacing.xl)
        }

        if !viewModel.essentials.isEmpty {
            essentials
                .padding(.top, AppSpacing.xl)
        }

        // Everything under "L'essentiel" is built once the reader scrolls (or when there is nothing to scroll),
        // so the first screen appears without the rest of the feed competing for the same frames.
        if showsRest { rest }
    }

    @ViewBuilder
    private var rest: some View {
        SectionHeader(title: "Dernières actualités")
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xs)

        let visible = Array(viewModel.feedStories.prefix(visibleCount))
        ForEach(Array(visible.enumerated()), id: \.element.id) { index, story in
            // Every fifth story with a photo breaks the list rhythm with an image card.
            if index > 0 && index.isMultiple(of: 5) && story.leadImageURL != nil {
                storyLink(story) {
                    StoryHeroCard(story: story, size: .medium)
                        .zoomSource(id: ZoomID(topic: topic, story: story.id), in: transition)
                }
            } else {
                storyLink(story) {
                    StoryRow(story: story)
                        .zoomSource(id: ZoomID(topic: topic, story: story.id), in: transition)
                }
            }
        }

        if visibleCount < viewModel.feedStories.count {
            Button("Voir plus") { visibleCount += 12 }
                .buttonStyle(.optiqueSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.l)
        }

        if !viewModel.lighterStories.isEmpty {
            SectionHeader(title: "Sport, culture et faits divers", subtitle: "Des sujets sans enjeu politique")
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xs)
            ForEach(viewModel.lighterStories.prefix(8)) { story in
                storyLink(story) {
                    StoryRow(story: story)
                        .zoomSource(id: ZoomID(topic: topic, story: story.id), in: transition)
                }
            }
        }
    }

    /// Alerts are offered once the reader has opened a first story, not at first launch.
    private var showsAlertsPrompt: Bool {
        !alertsPromptDismissed && !readingHistory.stories.isEmpty
            && notificationManager.authorizationStatus == .notDetermined
    }

    private var alertsPrompt: some View {
        VStack(alignment: .leading, spacing: AppSpacing.st) {
            Label("Être prévenu des grands sujets ?", lucide: "bell")
                .font(.geist(.body, .medium))
                .foregroundStyle(AppColors.Adaptive.textPrimary)
            Text("Une alerte quand un sujet est repris par plusieurs médias, avec le bord qui en parle le plus. Au plus une par heure.")
                .typeStyle(.body)
                .foregroundStyle(AppColors.Adaptive.textBody)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: AppSpacing.s) {
                Button("Activer") {
                    Task {
                        try? await notificationManager.requestAuthorization()
                        await notificationManager.checkAuthorizationStatus()
                        notificationsEnabled = notificationManager.authorizationStatus == .authorized
                        alertsPromptDismissed = true
                    }
                }
                .buttonStyle(.optiquePrimary)
                Button("Non merci") { alertsPromptDismissed = true }
                    .buttonStyle(.optiqueSecondary)
            }
        }
        .padding(AppSpacing.m)
        .background(AppColors.Adaptive.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.xl))
    }

    private var essentials: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "L'essentiel", subtitle: "Les sujets les plus couverts")
                .padding(.bottom, AppSpacing.xs)
            ForEach(Array(viewModel.essentials.enumerated()), id: \.element.id) { index, story in
                storyLink(story) {
                    StoryRow(story: story, rank: index + 1)
                        .zoomSource(id: ZoomID(topic: topic, story: story.id), in: transition)
                }
            }
        }
    }

    private func storyLink<Content: View>(_ story: Story, @ViewBuilder label: () -> Content) -> some View {
        NavigationLink(value: story, label: label)
            .buttonStyle(CardPressStyle())
            .contextMenu {
                Button {
                    let wasSaved = bookmarks.isBookmarked(story)
                    bookmarks.toggle(story)
                    if wasSaved { Haptics.lightImpact() } else { Haptics.success() }
                } label: {
                    if bookmarks.isBookmarked(story) {
                        Label("Retirer des enregistrés", lucide: "bookmark-minus")
                    } else {
                        Label("Enregistrer", lucide: "bookmark")
                    }
                }
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        Label("Partager", lucide: "share")
                    }
                }
            }
    }

    // MARK: - Loading and empty states

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(AppColors.Adaptive.placeholder)
                .aspectRatio(4.0 / 5.0, contentMode: .fit)
                .shimmering()
            ForEach(0..<3, id: \.self) { _ in
                SkeletonLines(count: 3, lineHeight: 14)
            }
        }
        .padding(.top, AppSpacing.l)
    }

    private func unavailable(title: String, message: String, icon: String, action: String) -> some View {
        ContentUnavailableView {
            Label(title, lucide: icon, size: 44)
        } description: {
            Text(message)
        } actions: {
            Button(action) { Task { await viewModel.refresh() } }
                .buttonStyle(.optiquePrimary)
        }
        .padding(.top, AppSpacing.xxxl)
    }
}

// MARK: - Zoom transition

/// A story on a given topic page: the same story can sit on several pages, so the topic is part of the id.
struct ZoomID: Hashable {
    let topic: StoryTopic
    let story: UUID
}

// MARK: - Zoom transition source

extension View {
    /// Marks the view as the source of the iOS 18 zoom navigation transition.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

extension View {
    /// Opens with the iOS 18 zoom transition from the matching `zoomSource`.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("FeedView") {
    NavigationStack {
        FeedView()
    }
    .environment(SessionState())
    .environment(BookmarkStore())
}
#endif

#if DEBUG
#Preview("FeedView – accessibility text") {
    NavigationStack { FeedView() }
        .environment(SessionState())
        .environment(BookmarkStore())
        .dynamicTypeSize(.accessibility2)
}
#endif

private extension View {
    /// Calls `reveal` once the page has been scrolled, or when its content doesn't fill the screen.
    /// Before iOS 18 nothing reports the scroll, so it is revealed after a moment instead.
    @ViewBuilder
    func revealsRestOnScroll(_ revealed: Bool, reveal: @escaping () -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 4 || geo.contentSize.height <= geo.containerSize.height + 1
            } action: { _, shouldReveal in
                if shouldReveal, !revealed { reveal() }
            }
        } else {
            task {
                try? await Task.sleep(for: .seconds(1.5))
                reveal()
            }
        }
    }
}

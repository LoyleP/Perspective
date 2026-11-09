import SwiftUI

/// "À la une": a row of topic pills over horizontally swiping pages, one page per topic. Tapping a
/// pill slides to its page and swiping a page moves the highlighted pill with it.
struct FeedView: View {

    @State private var topic: StoryTopic? = .tout
    /// Where the pages are, in pages (1.5 is halfway between the second and the third), so the black pill follows a swipe.
    @State private var pageProgress: CGFloat?
    @State private var deepLinkStory: Story?
    @Namespace private var transition
    private let notificationManager = NotificationManager.shared

    private var topics: [StoryTopic] { [.tout] + StoryTopic.selectable }
    private var current: StoryTopic { topic ?? .tout }

    var body: some View {
        VStack(spacing: 0) {
            TopicPills(topics: topics, selection: Binding(get: { current }, set: { topic = $0 }), progress: pageProgress)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element) { index, page in
                        // Only the page on screen and its neighbours load, so a swipe lands on stories.
                        let currentIndex = topics.firstIndex(of: current) ?? 0
                        FeedTopicPage(topic: page, isNear: abs(index - currentIndex) <= 1, transition: transition)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $topic)
            .trackingPageProgress { pageProgress = $0 }
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .appHeaderToolbar()
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
    let transition: Namespace.ID

    @State private var viewModel: FeedViewModel
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var readingHistory
    @AppStorage("alertsPromptDismissed") private var alertsPromptDismissed = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @State private var visibleCount = 12
    /// True once the page has started loading: until then it shows the placeholder, not "no stories".
    @State private var started = false
    private let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init(topic: StoryTopic, isNear: Bool, transition: Namespace.ID) {
        self.topic = topic
        self.isNear = isNear
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
        .refreshable { await viewModel.refresh() }
        .shrinksTabBarOnScroll()
        .task(id: isNear) {
            guard isNear else { return }
            started = true
            await viewModel.load()
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
        if let hero = viewModel.cetteSemanineHero {
            storyLink(hero) {
                StoryHeroCard(story: hero)
                    .zoomSource(id: ZoomID(topic: topic, story: hero.id), in: transition)
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

        if !viewModel.blindspots.isEmpty {
            blindspots
                .padding(.top, AppSpacing.xl)
        }

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

    /// Stories one side barely covers: what each camp's readers don't see.
    private var blindspots: some View {
        BlindspotCarousel(stories: viewModel.blindspots, subtitle: "Des sujets couverts surtout par un seul bord") { story, card in
            storyLink(story) {
                card.zoomSource(id: ZoomID(topic: topic, story: story.id), in: transition)
            }
        }
        .padding(.horizontal, -AppSpacing.m)
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
    /// Reports the horizontal scroll position in pages (iOS 18+; before that nothing is reported and the pill
    /// follows the selection).
    @ViewBuilder
    func trackingPageProgress(_ update: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x / max($0.containerSize.width, 1) } action: { _, progress in
                update(progress)
            }
        } else {
            self
        }
    }
}

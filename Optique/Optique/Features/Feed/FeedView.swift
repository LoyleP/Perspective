import SwiftUI

struct FeedView: View {

    @State private var viewModel = FeedViewModel()
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(ReadingHistoryStore.self) private var readingHistory
    @AppStorage("alertsPromptDismissed") private var alertsPromptDismissed = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @Namespace private var transition
    @State private var visibleCount = 12
    @State private var deepLinkStory: Story?
    @State private var topic: StoryTopic = .tout
    /// True from the tab tap until the new topic has loaded: shows the loader immediately.
    @State private var isSwitching = false
    private let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()
            TopicTabs(selection: $topic, onWillSwitch: { isSwitching = true }, onSwitchCancelled: { isSwitching = false })

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
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story)
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
        .onChange(of: topic) { _, new in
            visibleCount = 12
            Task {
                await viewModel.select(new)
                isSwitching = false
            }
        }
        .task {
            await viewModel.load()
            await notificationManager.checkAuthorizationStatus()
        }
        // News goes stale fast: coming back to the app reloads a feed older than a few minutes.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refreshIfStale() } }
        }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if isSwitching || (viewModel.isLoading && viewModel.allStories.isEmpty) {
            loadingSkeleton
        } else if let error = viewModel.error, viewModel.allStories.isEmpty {
            unavailable(
                title: "Impossible de charger",
                message: error.localizedDescription,
                icon: "signal-slash",
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
                    .zoomSource(id: hero.id, in: transition)
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
                        .zoomSource(id: story.id, in: transition)
                }
                .padding(.vertical, AppSpacing.m)
            } else {
                storyLink(story) {
                    StoryRow(story: story)
                        .zoomSource(id: story.id, in: transition)
                }
                Divider().overlay(AppColors.Adaptive.divider)
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
                        .zoomSource(id: story.id, in: transition)
                }
                Divider().overlay(AppColors.Adaptive.divider)
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
            Label("Être prévenu des grands sujets ?", hero: "bell")
                .font(.geist(.body, .medium))
                .foregroundStyle(AppColors.Adaptive.textPrimary)
            Text("Une alerte quand un sujet est repris par plusieurs médias, avec le bord qui en parle le plus. Au plus une par heure.")
                .font(.appBody)
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
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Angles morts", subtitle: "Ce qu'un bord ne vous montre pas")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: AppSpacing.st) {
                    ForEach(viewModel.blindspots) { story in
                        storyLink(story) {
                            StoryHeroCard(story: story, size: .medium)
                                .overlay(alignment: .topLeading) {
                                    if let side = story.computedCoverage?.blindspotSide {
                                        BlindspotBadge(side: side).padding(AppSpacing.st)
                                    }
                                }
                                .zoomSource(id: story.id, in: transition)
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.8 }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private var essentials: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "L'essentiel", subtitle: "Les sujets les plus couverts")
                .padding(.bottom, AppSpacing.s)
            ForEach(Array(viewModel.essentials.enumerated()), id: \.element.id) { index, story in
                storyLink(story) {
                    EssentialRow(rank: index + 1, story: story)
                        .zoomSource(id: story.id, in: transition)
                }
                if index < viewModel.essentials.count - 1 {
                    // Inset past the rank gutter so the rule lines up with the text.
                    Divider().overlay(AppColors.Adaptive.divider).padding(.leading, 38)
                }
            }
        }
    }

    private func storyLink<Content: View>(_ story: Story, @ViewBuilder label: () -> Content) -> some View {
        NavigationLink(value: story, label: label)
            .buttonStyle(CardPressStyle())
            .contextMenu {
                Button {
                    bookmarks.toggle(story)
                } label: {
                    if bookmarks.isBookmarked(story) {
                        Label("Retirer des enregistrés", hero: "bookmark-slash")
                    } else {
                        Label("Enregistrer", hero: "bookmark")
                    }
                }
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        Label("Partager", hero: "arrow-up-on-square")
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
            Label(title, hero: icon, size: 44)
        } description: {
            Text(message)
        } actions: {
            Button(action) { Task { await viewModel.refresh() } }
                .buttonStyle(.optiquePrimary)
        }
        .padding(.top, AppSpacing.xxxl)
    }
}

// MARK: - L'essentiel row

private struct EssentialRow: View {
    let rank: Int
    let story: Story

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.m) {
            Text("\(rank)")
                .font(.appCaption)
                .monospacedDigit()
                .foregroundStyle(AppColors.Adaptive.textMeta)
                .frame(width: 22, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: AppSpacing.s) {
                    Text(story.timeLine)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
                Text(story.title)
                    .font(.geist(.body, .medium))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let dek = story.standfirst {
                    Text(dek)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: AppSpacing.s) {
                    // The coverage tag only where the left/right lens means something.
                    if let coverage = story.computedCoverage, story.hasPoliticalAngle {
                        LeanTags(coverage: coverage)
                    }
                    SourceStack(sources: story.sources, size: 18, ringColor: AppColors.Adaptive.background)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.st)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
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

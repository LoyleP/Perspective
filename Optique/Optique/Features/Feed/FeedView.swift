import SwiftUI

struct FeedView: View {

    @State private var viewModel = FeedViewModel()
    @Environment(BookmarkStore.self) private var bookmarks
    @Namespace private var transition
    @State private var visibleCount = 12
    @State private var deepLinkStory: Story?
    @State private var topic: StoryTopic = .tout
    /// True from the tab tap until the new topic has loaded: shows the loader immediately.
    @State private var isSwitching = false
    private let notificationManager = NotificationManager.shared

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
            if #available(iOS 18.0, *) {
                StoryDetailView(story: story)
                    .navigationTransition(.zoom(sourceID: story.id, in: transition))
            } else {
                StoryDetailView(story: story)
            }
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
        .task { await viewModel.load() }
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

        if !viewModel.essentials.isEmpty {
            essentials
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
                Text(story.title)
                    .font(.appBodyStrong)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if let dek = story.summary, !dek.isEmpty {
                    Text(dek)
                        .font(.appBody)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: AppSpacing.s) {
                    if let coverage = story.computedCoverage {
                        SpectrumBar(coverage: coverage)
                            .frame(width: 56)
                    }
                    Text(story.metaLine)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.Adaptive.textMeta)
                }
            }
            Spacer(minLength: 0)
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

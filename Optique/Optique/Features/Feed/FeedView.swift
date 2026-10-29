import SwiftUI

struct FeedView: View {

    @State private var viewModel = FeedViewModel()
    @Environment(BookmarkStore.self) private var bookmarks
    @Namespace private var transition
    @State private var visibleCount = 12
    @State private var latestAlertAt: Date?
    @State private var deepLinkStory: Story?
    @AppStorage("lastSeenAlertsAt") private var lastSeenAlertsAt: Double = 0
    private let notificationManager = NotificationManager.shared

    private var hasUnreadAlerts: Bool {
        guard let latestAlertAt else { return false }
        return latestAlertAt.timeIntervalSince1970 > lastSeenAlertsAt
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .refreshable { await viewModel.refresh() }
        .navigationTitle("À la une")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Story.self) { story in
            if #available(iOS 18.0, *) {
                StoryDetailView(story: story)
                    .navigationTransition(.zoom(sourceID: story.id, in: transition))
            } else {
                StoryDetailView(story: story)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AlertesView()
                } label: {
                    Image(systemName: hasUnreadAlerts ? "bell.badge" : "bell")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColors.Adaptive.textPrimary, AppColors.Adaptive.textPrimary)
                }
                .accessibilityLabel(hasUnreadAlerts ? "Alertes, nouvelles alertes" : "Alertes")
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
        .task { await viewModel.load() }
        .task { latestAlertAt = await notificationManager.latestNotificationDate() }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.allStories.isEmpty {
            loadingSkeleton
        } else if let error = viewModel.error, viewModel.allStories.isEmpty {
            unavailable(
                title: "Impossible de charger",
                message: error.localizedDescription,
                systemImage: "wifi.slash",
                action: "Réessayer"
            )
        } else if viewModel.stories.isEmpty {
            unavailable(
                title: "Aucune actualité",
                message: "Aucun sujet n'est disponible pour le moment.",
                systemImage: "newspaper",
                action: "Rafraîchir"
            )
        } else {
            stories
        }
    }

    // MARK: - Stories

    @ViewBuilder
    private var stories: some View {
        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
            .overlineStyle()
            .padding(.bottom, AppSpacing.st)

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
                    Divider().overlay(AppColors.Adaptive.divider)
                }
            }
        }
        .padding(AppSpacing.m)
        .cardSurface()
    }

    private func storyLink<Content: View>(_ story: Story, @ViewBuilder label: () -> Content) -> some View {
        NavigationLink(value: story, label: label)
            .buttonStyle(CardPressStyle())
            .contextMenu {
                Button {
                    bookmarks.toggle(story)
                } label: {
                    if bookmarks.isBookmarked(story) {
                        Label("Retirer des enregistrés", systemImage: "bookmark.slash")
                    } else {
                        Label("Enregistrer", systemImage: "bookmark")
                    }
                }
                if let url = story.articles.first.flatMap({ URL(string: $0.url) }) {
                    ShareLink(item: url, subject: Text(story.title)) {
                        Label("Partager", systemImage: "square.and.arrow.up")
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

    private func unavailable(title: String, message: String, systemImage: String, action: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
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
                .font(.geist(30, .medium, relativeTo: .title))
                .foregroundStyle(AppColors.Brand.accent)
                .frame(minWidth: 22, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack(spacing: AppSpacing.s) {
                    if let coverage = story.computedCoverage {
                        SpectrumBar(coverage: coverage)
                            .frame(width: 56)
                    }
                    Text(story.metaLine)
                        .font(.appFootnote)
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

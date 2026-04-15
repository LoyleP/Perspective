import SwiftUI


struct FeedView: View {

    @State private var viewModel = FeedViewModel()
    @Environment(SessionState.self) private var session
    @Environment(BookmarkStore.self) private var bookmarks
    @Namespace private var contentNamespace
    @State private var feedVisibleCount = 10

    var body: some View {
        content
            .navigationTitle("À la une")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                configureNavigationBarAppearance()
            }
            .navigationDestination(for: Story.self) { story in
                if #available(iOS 18.0, *) {
                    StoryDetailView(story: story)
                        .navigationTransition(.zoom(sourceID: story.id, in: contentNamespace))
                } else {
                    StoryDetailView(story: story)
                }
            }
            .task {
                await viewModel.load()
            }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.allStories.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else if let error = viewModel.error, viewModel.allStories.isEmpty {
            errorView(error)
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else {
            feedList
        }
    }

    // MARK: - Feed list

    private var feedList: some View {
        List {
            if viewModel.stories.isEmpty {
                emptyStateRow
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                // Hero card
                if let hero = viewModel.cetteSemanineHero {
                    ZStack {
                        NavigationLink(value: hero) { EmptyView() }.opacity(0)
                        if #available(iOS 18.0, *) {
                            StoryCardView(story: hero, variant: .big)
                                .matchedTransitionSource(id: hero.id, in: contentNamespace)
                        } else {
                            StoryCardView(story: hero, variant: .big)
                        }
                    }
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.m, bottom: 0, trailing: AppSpacing.m))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Daily brief
                if !viewModel.briefStories.isEmpty {
                    DailyBriefSectionView(stories: viewModel.briefStories)
                        .listRowInsets(EdgeInsets(top: AppSpacing.l, leading: AppSpacing.m, bottom: AppSpacing.l, trailing: AppSpacing.m))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // Feed stories
                let visibleStories = Array(viewModel.feedStories.prefix(feedVisibleCount))
                ForEach(visibleStories) { story in
                    ZStack {
                        NavigationLink(value: story) { EmptyView() }.opacity(0)
                        StoryCardView(story: story, variant: .extended)
                    }
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            bookmarks.toggle(story)
                        } label: {
                            Label(
                                bookmarks.isBookmarked(story) ? "Retirer" : "Sauvegarder",
                                systemImage: bookmarks.isBookmarked(story) ? "bookmark.slash.fill" : "bookmark.fill"
                            )
                        }
                        .tint(bookmarks.isBookmarked(story) ? .red : .blue)
                    }
                }

                // Voir plus
                if feedVisibleCount < viewModel.feedStories.count {
                    Button {
                        feedVisibleCount += 10
                    } label: {
                        Text("Voir plus")
                            .font(.appHeadline)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.m)
                    }
                    .listRowInsets(EdgeInsets(top: AppSpacing.m, leading: AppSpacing.m, bottom: AppSpacing.l, trailing: AppSpacing.m))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Empty state

    private var emptyStateRow: some View {
        ContentUnavailableView {
            Label("Aucun article disponible", systemImage: "newspaper")
        } description: {
            Text("Aucune histoire n'est disponible pour le moment.")
                .foregroundStyle(AppColors.Adaptive.textMeta)
        } actions: {
            Button("Rafraîchir") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.Adaptive.textPrimary)
        }
    }

    // MARK: - Helpers

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()

        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor(AppColors.Adaptive.textPrimary)
        ]

        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(AppColors.Adaptive.textPrimary)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Impossible de charger", systemImage: "wifi.slash")
        } description: {
            Text(error.localizedDescription)
                .foregroundStyle(AppColors.Adaptive.textMeta)
        } actions: {
            Button("Réessayer") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.Adaptive.textPrimary)
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

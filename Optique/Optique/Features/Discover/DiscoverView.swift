import SwiftUI

/// Explorer tab: blind spots, topics and sources when idle; headline search results while typing.
struct DiscoverView: View {

    /// Search text, owned by the root so it survives tab switches.
    @Binding var searchText: String

    @State private var viewModel = DiscoverViewModel()
    @State private var showAllSources = false
    @AppStorage("preferredTopics") private var preferredTopicsRaw = ""
    @Namespace private var transition

    var body: some View {
        ScrollView {
            if viewModel.trimmedQuery.isEmpty {
                idleContent
            } else {
                searchResults
            }
        }
        .shrinksTabBarOnScroll()
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .appHeaderToolbar()
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Rechercher un sujet"
        )
        .onChange(of: searchText, initial: true) { _, text in
            viewModel.searchText = text
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewModel.search()
        }
        .refreshable { await viewModel.refresh() }
        .navigationDestination(for: Story.self) { story in
            if #available(iOS 18.0, *) {
                StoryDetailView(story: story)
                    .navigationTransition(.zoom(sourceID: story.id, in: transition))
            } else {
                StoryDetailView(story: story)
            }
        }
        .navigationDestination(for: StoryTopic.self) { topic in
            TopicStoriesView(topic: topic)
        }
        .navigationDestination(isPresented: $showAllSources) {
            SourcesView()
        }
        .task { await viewModel.load() }
    }

    // MARK: - Idle

    @ViewBuilder
    private var idleContent: some View {
        if viewModel.isLoading && viewModel.stories.isEmpty {
            loadingSkeleton
        } else if let error = viewModel.error, viewModel.stories.isEmpty {
            ContentUnavailableView {
                Label("Impossible de charger", hero: "signal-slash", size: 44)
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Réessayer") { Task { await viewModel.refresh() } }
                    .buttonStyle(.optiquePrimary)
            }
            .padding(.top, AppSpacing.xxxl)
        } else {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                if !viewModel.blindspots.isEmpty {
                    blindspots
                }
                topics
                if !viewModel.sources.isEmpty {
                    sources
                }
            }
            .padding(.top, AppSpacing.s)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private var blindspots: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Angles morts", subtitle: "Des sujets couverts surtout par un seul bord")
                .padding(.horizontal, AppSpacing.m)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: AppSpacing.st) {
                    ForEach(viewModel.blindspots) { story in
                        NavigationLink(value: story) {
                            StoryHeroCard(story: story, size: .medium)
                                .overlay(alignment: .topLeading) {
                                    if let side = story.computedCoverage?.blindspotSide {
                                        BlindspotBadge(side: side)
                                            .padding(AppSpacing.st)
                                    }
                                }
                                .zoomSource(id: story.id, in: transition)
                        }
                        .buttonStyle(CardPressStyle())
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.86 }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, AppSpacing.m, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var topics: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeader(title: "Thèmes")
            ForEach(orderedTopics) { topic in
                NavigationLink(value: topic) {
                    HStack {
                        Text(topic.rawValue)
                            .font(.appBodyStrong)
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                        Spacer(minLength: AppSpacing.s)
                        Text("\(viewModel.stories(in: topic).count)")
                            .font(.appCaption)
                            .monospacedDigit()
                            .foregroundStyle(AppColors.Adaptive.textMeta)
                    }
                    .padding(.vertical, AppSpacing.st)
                    .contentShape(Rectangle())
                }
                .buttonStyle(CardPressStyle())
                Divider().overlay(AppColors.Adaptive.divider)
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }

    /// Preferred topics first, then the rest, each in the default order.
    private var orderedTopics: [StoryTopic] {
        let preferred = StoryTopic.preferred(from: preferredTopicsRaw)
        return StoryTopic.selectable.filter(preferred.contains) + StoryTopic.selectable.filter { !preferred.contains($0) }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(
                title: "Les médias",
                subtitle: "\(viewModel.sources.count) sources analysées",
                actionTitle: "Tout voir"
            ) {
                showAllSources = true
            }
            .padding(.horizontal, AppSpacing.m)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: AppSpacing.m) {
                    ForEach(viewModel.sources) { source in
                        NavigationLink {
                            SourceDetailView(source: source)
                        } label: {
                            VStack(spacing: AppSpacing.s) {
                                SourceAvatarView(source: source, size: 56)
                                Text(source.name)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.Adaptive.textTertiary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
            }
            .contentMargins(.horizontal, AppSpacing.m, for: .scrollContent)
        }
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(AppColors.Adaptive.placeholder)
                .aspectRatio(3.0 / 2.0, contentMode: .fit)
                .shimmering()
            SkeletonLines(count: 4, lineHeight: 14)
        }
        .padding(AppSpacing.m)
    }

    // MARK: - Search

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.searchResults.isEmpty {
            if viewModel.isSearching || viewModel.trimmedQuery.count < 2 {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xxl)
            } else {
                ContentUnavailableView.search(text: viewModel.trimmedQuery)
                    .padding(.top, AppSpacing.xxl)
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.searchResults) { story in
                    NavigationLink(value: story) {
                        StoryRow(story: story)
                            .zoomSource(id: story.id, in: transition)
                    }
                    .buttonStyle(CardPressStyle())
                    Divider().overlay(AppColors.Adaptive.divider)
                }
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }
}

// MARK: - Blind spot badge

private struct BlindspotBadge: View {
    let side: BlindspotSide

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(side.lean.spectrumColor)
                .frame(width: 8, height: 8)
            Text(side.label)
        }
        .font(.appCaption)
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: Capsule())
    }
}

#if DEBUG
#Preview("DiscoverView") {
    NavigationStack {
        DiscoverView(searchText: .constant(""))
    }
    .environment(SessionState())
    .environment(BookmarkStore())
}
#endif

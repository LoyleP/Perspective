import SwiftUI

/// Explorer tab: blind spots, topics and sources when idle; headline search results while typing.
struct DiscoverView: View {

    /// Search text, owned by the root so it survives tab switches.
    @Binding var searchText: String
    /// Changes when the Explorer tab button is tapped: opens the search field and the keyboard.
    var focusToken = 0

    @FocusState private var searchFocused: Bool
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
        .searchFocusedIfAvailable($searchFocused)
        .onChange(of: focusToken) { _, _ in searchFocused = true }
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
            StoryDetailView(story: story)
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
                Label("Impossible de charger", lucide: "wifi-off", size: 44)
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
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Thèmes")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(orderedTopics) { topic in
                    NavigationLink(value: topic) {
                        ThemeTile(topic: topic)
                    }
                    .buttonStyle(CardPressStyle())
                }
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
                                    .typeStyle(.meta)
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
                }
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }
}

// MARK: - Theme tile

/// A coloured card for one theme: its name bottom left, its icon large and cropped at the right.
private struct ThemeTile: View {
    let topic: StoryTopic

    var body: some View {
        let colors = topic.tileColors
        RoundedRectangle(cornerRadius: AppRadius.xl + 4)
            .fill(LinearGradient(colors: [Color(hex: colors.top), Color(hex: colors.bottom)], startPoint: .top, endPoint: .bottom))
            .aspectRatio(1.78, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                LucideIcon(topic.lucideIcon, size: 96)
                    .foregroundStyle(.white.opacity(0.3))
                    .rotationEffect(.degrees(-8))
                    .offset(x: 18, y: 14)
            }
            .overlay(alignment: .bottomLeading) {
                Text(topic.rawValue)
                    .font(.geist(.body, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(AppSpacing.m)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl + 4))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(topic.rawValue)
    }
}

private extension StoryTopic {
    /// Gradient of the theme's tile, light at the top.
    var tileColors: (top: String, bottom: String) {
        switch self {
        case .tout:          return ("6B7280", "374151")
        case .politique:     return ("5B6577", "1F2937")
        case .economie:      return ("5FA3F5", "2A62D9")
        case .societe:       return ("F6B26B", "E4742A")
        case .international: return ("C26BE8", "7E2FD0")
        case .environnement: return ("6FD6C2", "1C9C8B")
        case .justice:       return ("B5B1BF", "7C7888")
        case .culture:       return ("F27A7A", "D93636")
        case .sport:         return ("7AD184", "2E9E3D")
        }
    }
}

// MARK: - Blind spot badge

/// "Surtout à gauche"-style badge on a blind-spot story card.
struct BlindspotBadge: View {
    let side: BlindspotSide

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(side.lean.spectrumColor)
                .frame(width: 8, height: 8)
            Text(side.label)
        }
        .typeStyle(.meta)
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

private extension View {
    @ViewBuilder
    func searchFocusedIfAvailable(_ focused: FocusState<Bool>.Binding) -> some View {
        if #available(iOS 18.0, *) { searchFocused(focused) } else { self }
    }
}

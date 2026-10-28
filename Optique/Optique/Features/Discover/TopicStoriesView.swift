import SwiftUI
import OSLog

/// Stories tagged with one topic, newest first, paginated.
struct TopicStoriesView: View {
    let topic: StoryTopic

    @State private var stories: [Story] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var didFail = false

    private let pageSize = 20

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if stories.isEmpty {
                    if isLoading || (!didFail && hasMore) {
                        SkeletonLines(count: 6, lineHeight: 14)
                            .padding(.top, AppSpacing.l)
                    } else {
                        ContentUnavailableView(
                            "Aucun sujet",
                            systemImage: topic.systemImage,
                            description: Text(didFail ? "Impossible de charger ce thème." : "Aucun sujet récent dans ce thème.")
                        )
                        .padding(.top, AppSpacing.xxl)
                    }
                }

                ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                    NavigationLink(value: story) {
                        if index == 0 && story.leadImageURL != nil {
                            StoryHeroCard(story: story, size: .medium)
                                .padding(.vertical, AppSpacing.s)
                        } else {
                            StoryRow(story: story)
                        }
                    }
                    .buttonStyle(CardPressStyle())
                    if index > 0 || story.leadImageURL == nil {
                        Divider().overlay(AppColors.Adaptive.divider)
                    }
                }

                if hasMore && !stories.isEmpty {
                    Button(isLoading ? "Chargement…" : "Voir plus") {
                        Task { await loadMore() }
                    }
                    .buttonStyle(.optiqueSecondary)
                    .disabled(isLoading)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.l)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.Adaptive.background.ignoresSafeArea())
        .navigationTitle(topic.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if stories.isEmpty { await loadMore() }
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await StoryRepository.shared.fetchFeed(
                topic: topic.filterValue,
                limit: pageSize,
                offset: stories.count
            )
            stories += page
            hasMore = page.count == pageSize
        } catch {
            Log.feed.error("Topic load failed: \(error)")
            didFail = true
            hasMore = false
        }
    }
}

#if DEBUG
#Preview("Topic") {
    NavigationStack { TopicStoriesView(topic: .politique) }
}
#endif

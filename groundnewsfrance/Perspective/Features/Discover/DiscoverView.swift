import SwiftUI

struct DiscoverView: View {

    @State private var viewModel = DiscoverViewModel()
    @State private var visibleCount = 10
    @State private var showFilterSheet = false
    @Environment(SessionState.self) private var session

    var body: some View {
        content
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story)
        }
        .searchable(text: $viewModel.searchText, prompt: "Rechercher des actualités")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(AppColors.Adaptive.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(
                selectedTopics: $viewModel.selectedTopics,
                onToggle: { topic in
                    viewModel.toggleTopic(topic)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .task { await viewModel.load() }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.stories.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else if let error = viewModel.error, viewModel.stories.isEmpty {
            errorView(error)
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else if viewModel.stories.isEmpty {
            ContentUnavailableView("Aucune histoire", systemImage: "newspaper")
                .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        } else {
            feedScroll
        }
    }

    private var feedScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.st) {
                ForEach(visibleStories) { story in
                    NavigationLink(value: story) {
                        StoryCardView(story: story)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                if viewModel.isLoadingMore {
                    ProgressView().padding(.vertical, AppSpacing.m)
                } else if hasMoreStories {
                    Button {
                        visibleCount += 10
                        if visibleCount >= viewModel.filteredStories.count
                            && viewModel.hasMore {
                            Task { await viewModel.loadMore() }
                        }
                    } label: {
                        Text("Voir plus")
                            .font(.appFootnote)
                            .foregroundStyle(AppColors.Adaptive.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.st)
                            .background(AppColors.Adaptive.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .refreshable { await viewModel.refresh() }
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
        .onChange(of: viewModel.selectedTopics) { oldValue, newValue in
            visibleCount = 10
        }
        .onChange(of: viewModel.searchText) { oldValue, newValue in
            visibleCount = 10
        }
    }
    
    private var visibleStories: [Story] {
        Array(viewModel.filteredStories.prefix(visibleCount))
    }

    private var hasMoreStories: Bool {
        visibleCount < viewModel.filteredStories.count || viewModel.hasMore
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Impossible de charger", systemImage: "wifi.slash")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Réessayer") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Binding var selectedTopics: Set<StoryTopic>
    var onToggle: (StoryTopic) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.st) {
                    ForEach(StoryTopic.allCases) { topic in
                        Button {
                            onToggle(topic)
                        } label: {
                            topicCard(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.Adaptive.feedBackground.ignoresSafeArea())
            .navigationTitle("Filtrer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppColors.Adaptive.textPrimary)
                    }
                }
            }
        }
        .presentationBackground(AppColors.Adaptive.feedBackground)
    }

    private func topicCard(_ topic: StoryTopic) -> some View {
        let isSelected = selectedTopics.contains(topic)

        return HStack(spacing: AppSpacing.m) {
            Text(topic.rawValue)
                .font(.appTitle3)
                .foregroundStyle(AppColors.Adaptive.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppColors.Adaptive.textPrimary)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(AppColors.Adaptive.textTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .background(AppColors.Adaptive.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.ml))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.ml)
                .stroke(isSelected ? AppColors.Adaptive.textPrimary : AppColors.stroke, lineWidth: isSelected ? 2 : 1)
        )
    }
}

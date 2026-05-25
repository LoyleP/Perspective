import SwiftUI

struct SavedView: View {

    @Environment(BookmarkStore.self) private var bookmarks

    var body: some View {
        content
            .navigationTitle("Enregistrés")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Story.self) { story in
                StoryDetailView(story: story)
            }
            .perspectiveNavigationBar()
    }

    @ViewBuilder
    private var content: some View {
        if bookmarks.stories.isEmpty {
            emptyState
        } else {
            storyList
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Aucun article enregistré", systemImage: "bookmark")
        } description: {
            Text("Appuyez sur le signet dans un article pour l'enregistrer ici.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

    // MARK: - Story list

    private var storyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                VStack(spacing: AppSpacing.st) {
                    ForEach(bookmarks.stories) { story in
                        NavigationLink(value: story) {
                            StoryCardView(story: story)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.top, AppSpacing.m)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background { AppColors.Adaptive.feedBackground.ignoresSafeArea() }
    }

}

#if DEBUG
#Preview("SavedView – empty") {
    NavigationStack {
        SavedView()
    }
    .environment(BookmarkStore())
}

#Preview("SavedView – with stories") {
    @Previewable @State var store = BookmarkStore()
    let _ = store.toggle(PreviewData.story)
    NavigationStack {
        SavedView()
    }
    .environment(store)
}
#endif

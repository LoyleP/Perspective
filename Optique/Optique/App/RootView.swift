import SwiftUI

struct RootView: View {

    @State private var session = SessionState()
    @State private var bookmarks = BookmarkStore()
    @State private var readingHistory = ReadingHistoryStore()
    @State private var selectedTab = 0
    @State private var discoverSearchText = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let notificationManager = NotificationManager.shared

    #if DEBUG
    /// Bumped on every InjectionIII reload so the whole tree re-renders with the injected code.
    @State private var injectionCount = 0
    #endif

    var body: some View {
        tabs
            #if DEBUG
            .id(injectionCount)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))) { _ in
                injectionCount += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: DebugMenu.reloadNotification)) { _ in
                injectionCount += 1
            }
            #endif
    }

    private var tabs: some View {
        ZStack {
            tab(0) { NavigationStack { FeedView() } }
            tab(1) { NavigationStack { ProfileView() } }
            tab(2) { NavigationStack { DiscoverView(searchText: $discoverSearchText) } }
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(
                items: [
                    .init(id: 0, accessibilityLabel: "À la une", icon: "AppLogoTab", isAsset: true),
                    .init(id: 1, accessibilityLabel: "Mon Optique", icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill"),
                    .init(id: 2, accessibilityLabel: "Explorer", icon: "magnifyingglass")
                ],
                selection: $selectedTab
            )
            .ignoresSafeArea(.keyboard)
        }
        .tint(AppColors.Brand.accent)
        // Must come before the .environment calls: the debug menu sheet reads those objects,
        // and a sheet only inherits the environment of the view it is attached to.
        .debugMenu()
        .environment(session)
        .environment(bookmarks)
        .environment(readingHistory)
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .onChange(of: notificationManager.pendingStoryID) { _, storyID in
            // FeedView opens the story; make sure it is the visible tab.
            if storyID != nil { selectedTab = 0 }
        }
    }

    /// All tabs stay alive (scroll position and navigation are kept); only the selected one shows.
    private func tab<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: FloatingTabBar.height)
            }
            .opacity(selectedTab == index ? 1 : 0)
            .allowsHitTesting(selectedTab == index)
            .accessibilityHidden(selectedTab != index)
    }
}

#if !DEBUG
extension View {
    func debugMenu() -> some View { self }
}
#endif

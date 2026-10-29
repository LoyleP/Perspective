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

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("À la une", image: "AppLogoTab", value: 0) {
                NavigationStack {
                    FeedView()
                }
            }

            Tab("Mon Optique", systemImage: "person.crop.circle", value: 1) {
                NavigationStack {
                    ProfileView()
                }
            }

            Tab("Explorer", systemImage: "magnifyingglass", value: 2, role: .search) {
                NavigationStack {
                    DiscoverView(searchText: $discoverSearchText)
                }
            }
        }
        .tint(AppColors.Brand.accent)
        .minimizesTabBarOnScroll()
        .environment(session)
        .environment(bookmarks)
        .environment(readingHistory)
        .debugMenu()
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .onChange(of: notificationManager.pendingStoryID) { _, storyID in
            // FeedView opens the story; make sure it is the visible tab.
            if storyID != nil { selectedTab = 0 }
        }
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView()
            }
            .tag(0)
            .tabItem {
                Label { Text("À la une") } icon: { Image("AppLogoTab") }
            }

            NavigationStack {
                ProfileView()
            }
            .tag(1)
            .tabItem {
                Label { Text("Mon Optique") } icon: { Image(systemName: "person.crop.circle") }
            }

            NavigationStack {
                DiscoverView(searchText: $discoverSearchText)
            }
            .tag(2)
            .tabItem {
                Label { Text("Explorer") } icon: { Image(systemName: "magnifyingglass") }
            }
        }
        .tint(AppColors.Brand.accent)
        .environment(session)
        .environment(bookmarks)
        .environment(readingHistory)
        .debugMenu()
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .onChange(of: notificationManager.pendingStoryID) { _, storyID in
            if storyID != nil { selectedTab = 0 }
        }
    }
}

private extension View {
    /// iOS 26: the floating tab bar shrinks while scrolling down.
    @ViewBuilder
    func minimizesTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

#if !DEBUG
extension View {
    func debugMenu() -> some View { self }
}
#endif

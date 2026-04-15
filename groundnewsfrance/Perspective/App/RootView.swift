import SwiftUI

struct RootView: View {

    @State private var session = SessionState()
    @State private var bookmarks = BookmarkStore()
    @State private var selectedTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let notificationManager = NotificationManager.shared

    var body: some View {
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

            Tab("Alertes", systemImage: "bell", value: 1) {
                // AlertesView owns its own NavigationStack for deep-link navigation
                AlertesView()
            }

            Tab("Profil", systemImage: "person", value: 2) {
                NavigationStack {
                    ProfileView()
                }
            }

            Tab(value: 3, role: .search) {
                NavigationStack {
                    DiscoverView()
                }
            }
        }
        .tint(AppColors.Neutral.n100)
        .environment(session)
        .environment(bookmarks)
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .onChange(of: notificationManager.pendingStoryID) { _, storyID in
            if storyID != nil { selectedTab = 1 }
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
                DiscoverView()
            }
            .tag(1)
            .tabItem {
                Label { Text("Découvrir") } icon: { Image(systemName: "square.grid.2x2") }
            }

            // AlertesView owns its own NavigationStack for deep-link navigation
            AlertesView()
                .tag(2)
                .tabItem {
                    Label { Text("Alertes") } icon: { Image(systemName: selectedTab == 2 ? "bell.fill" : "bell") }
                }

            NavigationStack {
                ProfileView()
            }
            .tag(3)
            .tabItem {
                Label { Text("Profil") } icon: { Image(systemName: selectedTab == 3 ? "person.fill" : "person") }
            }
        }
        .tint(AppColors.Neutral.n100)
        .environment(session)
        .environment(bookmarks)
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .onChange(of: notificationManager.pendingStoryID) { _, storyID in
            if storyID != nil { selectedTab = 2 }
        }
    }
}

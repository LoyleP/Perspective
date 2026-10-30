import SwiftUI

struct RootView: View {

    @State private var session = SessionState()
    @State private var bookmarks = BookmarkStore()
    @State private var readingHistory = ReadingHistoryStore()
    @State private var selectedTab = 0
    @State private var discoverSearchText = ""
    @State private var tabBarState = TabBarState()
    @State private var latestAlertAt: Date?
    /// Home-indicator inset: the tab bar sits 24pt from the screen edge, so content only needs the rest.
    @State private var bottomSafeInset: CGFloat = 0
    @State private var lastAlertCheck = Date()
    @AppStorage("lastSeenAlertsAt") private var lastSeenAlertsAt: Double = 0
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

    /// A newer alert exists than the last time the Alertes tab was opened.
    private var hasUnreadAlerts: Bool {
        guard selectedTab != 2, let latestAlertAt else { return false }
        return latestAlertAt.timeIntervalSince1970 > lastSeenAlertsAt
    }

    private var tabs: some View {
        ZStack {
            Color.clear
                .overlay(GeometryReader { geo in
                    Color.clear
                        .onAppear { bottomSafeInset = geo.safeAreaInsets.bottom }
                        .onChange(of: geo.safeAreaInsets.bottom) { _, new in bottomSafeInset = new }
                })
                .ignoresSafeArea(edges: [])
            tab(0) { NavigationStack { FeedView() } }
            tab(1) { NavigationStack { DiscoverView(searchText: $discoverSearchText) } }
            tab(2) { NavigationStack { AlertesView(isActive: selectedTab == 2) } }
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(
                items: [
                    .init(id: 0, accessibilityLabel: "À la une", icon: "home", hasSolid: true),
                    .init(id: 1, accessibilityLabel: "Explorer", icon: "magnifying-glass"),
                    .init(id: 2, accessibilityLabel: hasUnreadAlerts ? "Alertes, nouvelles alertes" : "Alertes",
                          icon: "bell", hasSolid: true, showsBadge: hasUnreadAlerts)
                ],
                selection: $selectedTab
            )
            .ignoresSafeArea(.keyboard)
            .ignoresSafeArea(.container, edges: .bottom)
            .scaleEffect(tabBarState.isCompact ? 0.82 : 1, anchor: .bottom)
            .offset(y: tabBarState.isHidden ? 160 : 0)
            .animation(.app, value: tabBarState.isHidden)
            .animation(.app, value: tabBarState.isCompact)
            .opacity(tabBarState.isHidden ? 0 : 1)
            .allowsHitTesting(!tabBarState.isHidden)
        }
        .tint(AppColors.Brand.accent)
        // Must come before the .environment calls: the debug menu sheet reads those objects,
        // and a sheet only inherits the environment of the view it is attached to.
        .debugMenu()
        .environment(session)
        .environment(bookmarks)
        .environment(readingHistory)
        .environment(\.tabBarState, tabBarState)
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .task { latestAlertAt = await notificationManager.latestNotificationDate() }
        .onChange(of: selectedTab) { _, tab in
            // Opening the Alertes tab marks everything as seen.
            if tab == 2 { lastSeenAlertsAt = Date().timeIntervalSince1970 }
            // Throttled: a network call on every tab switch adds work right during the transition.
            guard Date().timeIntervalSince(lastAlertCheck) > 60 else { return }
            lastAlertCheck = Date()
            Task { latestAlertAt = await notificationManager.latestNotificationDate() }
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
                Color.clear.frame(height: max(FloatingTabBar.height - bottomSafeInset, 0))
            }
            .opacity(selectedTab == index ? 1 : 0)
            .animation(nil, value: selectedTab)   // switching tabs is instant
            .allowsHitTesting(selectedTab == index)
            .accessibilityHidden(selectedTab != index)
    }
}

#if !DEBUG
extension View {
    func debugMenu() -> some View { self }
}
#endif

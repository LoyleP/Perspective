import SwiftUI

struct RootView: View {

    @State private var session = SessionState()
    @State private var bookmarks = BookmarkStore()
    @State private var readingHistory = ReadingHistoryStore()
    @State private var selectedTab = 0
    @State private var discoverSearchText = ""
    @State private var tabBarState = TabBarState()
    @State private var navRegistry = NavRegistry()
    /// The tab bar steps aside while the keyboard is up.
    @State private var keyboardVisible = false
    /// Bumped to ask the Explorer tab to open its search field and show the keyboard.
    @State private var searchFocusToken = 0
    @State private var latestAlertAt: Date?
    /// Home-indicator inset: the tab bar sits 24pt from the screen edge, so content only needs the rest.
    @State private var bottomSafeInset: CGFloat = 0
    @State private var lastAlertCheck = Date()
    /// The paywall that opens once, right after the onboarding.
    @State private var showsWelcomePaywall = false
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
            tab(0) { NavigationStack { FeedView().background(NavControllerReader(tab: 0, registry: navRegistry)) } }
            tab(3) { NavigationStack { LawsView(isActive: selectedTab == 3).background(NavControllerReader(tab: 3, registry: navRegistry)) } }
            tab(1) { NavigationStack { DiscoverView(searchText: $discoverSearchText, focusToken: searchFocusToken).background(NavControllerReader(tab: 1, registry: navRegistry)) } }
            tab(2) { NavigationStack { AlertesView(isActive: selectedTab == 2).background(NavControllerReader(tab: 2, registry: navRegistry)) } }
        }
        .overlay(alignment: .bottom) {
            FloatingTabBar(
                items: [
                    .init(id: 0, accessibilityLabel: "À la une", icon: "house"),
                    .init(id: 3, accessibilityLabel: "Lois", icon: "scroll-text"),
                    .init(id: 1, accessibilityLabel: "Explorer", icon: "search"),
                    .init(id: 2, accessibilityLabel: hasUnreadAlerts ? "Alertes, nouvelles alertes" : "Alertes",
                          icon: "bell", showsBadge: hasUnreadAlerts)
                ],
                selection: $selectedTab,
                onTap: tapped
            )
            .ignoresSafeArea(.keyboard)
            .ignoresSafeArea(.container, edges: .bottom)
            .scaleEffect(tabBarState.isCompact ? 0.82 : 1, anchor: .bottom)
            .offset(y: tabBarState.isHidden || keyboardVisible ? 160 : 0)
            .animation(.app, value: tabBarState.isHidden)
            .animation(.app, value: keyboardVisible)
            .animation(.app, value: tabBarState.isCompact)
            .opacity(tabBarState.isHidden || keyboardVisible ? 0 : 1)
            .allowsHitTesting(!tabBarState.isHidden && !keyboardVisible)
        }
        .tint(AppColors.Brand.accent)
        // Must come before the .environment calls: the debug menu sheet reads those objects,
        // and a sheet only inherits the environment of the view it is attached to.
        .debugMenu()
        .sheet(isPresented: $showsWelcomePaywall) {
            PaywallView()
        }
        .environment(session)
        .environment(bookmarks)
        .environment(readingHistory)
        .environment(\.tabBarState, tabBarState)
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView()
        }
        .onChange(of: hasCompletedOnboarding) { wasDone, isDone in
            // Finishing the onboarding always lands on the home feed, even when it was started from a page
            // deep in the app (the "new user" test setting restarts it from the profile).
            if isDone, !wasDone {
                for tab in 0...3 { _ = navRegistry.popToRoot(tab) }
                selectedTab = 0
            }
            // Entering the app after the onboarding: the plan comes up first, for readers who aren't Optique+ yet.
            guard isDone, !wasDone, AppConfig.paywallEnabled, !session.isPremium else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(650))   // lets the onboarding finish closing
                showsWelcomePaywall = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
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

    /// Any tap on a tab button brings that tab to its first page (even from a sub page); Explorer
    /// also opens the search keyboard.
    private func tapped(_ tab: Int) {
        // A tap on the shrunken bar brings it back to full size.
        if tabBarState.isCompact { tabBarState.isCompact = false }
        let alreadyThere = selectedTab == tab
        let popped = navRegistry.popToRoot(tab)
        if popped { Haptics.lightImpact() }
        // The keyboard only comes up when Explorer is already the tab on screen.
        if tab == 1 && alreadyThere {
            DispatchQueue.main.asyncAfter(deadline: .now() + (popped ? 0.45 : 0.15)) { searchFocusToken += 1 }
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


/// Finds each tab's navigation controller so a tap on its tab button can pop it back to the first page.
@MainActor
final class NavRegistry {
    private var controllers: [Int: WeakNav] = [:]
    private struct WeakNav { weak var value: UINavigationController? }

    func register(_ tab: Int, _ nav: UINavigationController) { controllers[tab] = WeakNav(value: nav) }

    /// Pops the tab to its first page; true when there was something to pop.
    @discardableResult
    func popToRoot(_ tab: Int) -> Bool {
        guard let nav = controllers[tab]?.value, nav.viewControllers.count > 1 else { return false }
        nav.popToRootViewController(animated: true)
        return true
    }
}

struct NavControllerReader: UIViewRepresentable {
    let tab: Int
    let registry: NavRegistry

    func makeUIView(context: Context) -> UIView { Probe(tab: tab, registry: registry) }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class Probe: UIView {
        let tab: Int
        let registry: NavRegistry
        init(tab: Int, registry: NavRegistry) {
            self.tab = tab; self.registry = registry
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var responder: UIResponder? = self
                while let next = responder?.next {
                    if let vc = next as? UIViewController, let nav = vc.navigationController {
                        self.registry.register(self.tab, nav)
                        return
                    }
                    responder = next
                }
            }
        }
    }
}

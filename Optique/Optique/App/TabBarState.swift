import SwiftUI

/// Lets a pushed screen (the article reader) hide the floating tab bar while it is on screen.
@MainActor
@Observable
final class TabBarState {
    var isHidden = false
    /// Scrolling down shrinks the bar; scrolling back up restores it.
    var isCompact = false
}

private struct TabBarScrollModifier: ViewModifier {
    @Environment(\.tabBarState) private var tabBar

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in
                let delta = new - old
                if new <= 0 || delta < -4 {
                    if tabBar.isCompact { tabBar.isCompact = false }
                } else if delta > 4, new > 40 {
                    if !tabBar.isCompact { tabBar.isCompact = true }
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Shrinks the floating tab bar while the user scrolls down, restores it on scroll up.
    func shrinksTabBarOnScroll() -> some View { modifier(TabBarScrollModifier()) }
}

private struct TabBarStateKey: EnvironmentKey {
    @MainActor static let defaultValue = TabBarState()
}

extension EnvironmentValues {
    var tabBarState: TabBarState {
        get { self[TabBarStateKey.self] }
        set { self[TabBarStateKey.self] = newValue }
    }
}

private struct TabBarClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Room the floating tab bar takes at the bottom of a pushed page (set by RootView).
    var tabBarClearance: CGFloat {
        get { self[TabBarClearanceKey.self] }
        set { self[TabBarClearanceKey.self] = newValue }
    }
}

private struct TabBarClearanceModifier: ViewModifier {
    @Environment(\.tabBarState) private var tabBar
    @Environment(\.tabBarClearance) private var clearance

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: tabBar.isHidden ? 0 : clearance)
        }
    }
}

extension View {
    /// Pushed pages don't inherit the tab's bottom inset, so they leave room for the floating bar themselves.
    func tabBarClearance() -> some View { modifier(TabBarClearanceModifier()) }
}

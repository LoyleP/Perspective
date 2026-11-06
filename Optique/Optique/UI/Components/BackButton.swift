import SwiftUI

/// The app's return button is the system's own: UIKit draws it and owns the swipe-back gestures
/// (edge and full-width), so they work on every page, every iOS version, with nothing to keep in
/// sync. Every pushed page still goes through `.appBackButton()`, the single place to change that.
private struct AppBackButton: ViewModifier {
    /// True while a panel on the page uses the swipe itself (the comments panel).
    let swipeDisabled: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(false)
            .background(SwipeBackDisabler(isDisabled: swipeDisabled))
    }
}

extension View {
    /// The system back button and swipe-back; `swipeDisabled` switches the swipe off for a while.
    func appBackButton(swipeDisabled: Bool = false) -> some View {
        modifier(AppBackButton(swipeDisabled: swipeDisabled))
    }
}

import SwiftUI

/// The one return button of the app: a bold chevron in the navigation bar's round glass button.
/// Every pushed page gets it through `.appBackButton()`, so they cannot drift apart: change the look
/// here (or in `NavIcon`) and every return button changes with it.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            NavIcon("chevron.left")
        }
        .accessibilityLabel("Retour")
    }
}

private struct AppBackButton: ViewModifier {
    /// True while a panel on the page uses the swipe itself (the comments panel).
    let swipeDisabled: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BackButton() }
            }
            // The system's back swipe is switched off with its button; this brings it back.
            .background(SwipeBackDisabler(isDisabled: swipeDisabled))
    }
}

extension View {
    /// Replaces the system back button with `BackButton` and keeps the swipe-back gesture.
    func appBackButton(swipeDisabled: Bool = false) -> some View {
        modifier(AppBackButton(swipeDisabled: swipeDisabled))
    }
}
